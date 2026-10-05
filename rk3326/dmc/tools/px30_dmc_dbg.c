// SPDX-License-Identifier: GPL-2.0-only
/*
 * Probe module for the PX30/RK3326 BL31 DDR frequency interface: the px30_dmc
 * driver with each step optional and logged before it runs.
 * Boot with initcall_blacklist=px30_dmc_driver_init, then
 * insmod px30_dmc_dbg.ko [gov=userspace] [round=1] [lcdc=0] [timing=0]
 *        [nowait=0] [nogetrate=0] [delay_ms=300]
 */

#include <linux/arm-smccc.h>
#include <linux/completion.h>
#include <linux/devfreq.h>
#include <linux/devfreq-event.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/mod_devicetable.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/pm_opp.h>
#include <linux/pm_qos.h>
#include <linux/regulator/consumer.h>
#include <linux/sizes.h>
#include <linux/delay.h>

/* lcdc_type for BL31; non-zero makes it wait for VOP line flag 1 */
static unsigned int lcdc;
module_param(lcdc, uint, 0644);
static unsigned int delay_ms = 300;
module_param(delay_ms, uint, 0644);
static char *gov = "userspace";
module_param(gov, charp, 0444);
static bool nowait;
module_param(nowait, bool, 0644);
static bool nogetrate;
module_param(nogetrate, bool, 0644);
static bool timing;
module_param(timing, bool, 0444);
static bool round = true;
module_param(round, bool, 0644);


#define DBG(dev, fmt, ...) do { dev_info(dev, fmt, ##__VA_ARGS__); if (delay_ms) msleep(delay_ms); } while (0)

#include <soc/rockchip/pm_domains.h>
#include <soc/rockchip/rockchip_sip.h>

#include "px30_dmc_timing.h"
#include "examples/rf3536k3ka-ddr-timing.h"

#define PX30_SIP_SHARE_MEM		0x82000009
#define PX30_SHARE_PAGE_TYPE_DDR	2
#define PX30_DRAM_GET_VERSION		0x08
#define PX30_SET_RATE_PENDING		-6

/* Start of the request page shared with BL31 */
struct px30_dmc_params {
	u32 hz;
	u32 lcdc_type;
	u32 vop;
	u32 vop_dclk_mode;
	u32 sr_idle_en;
	u32 addr_mcu_el3;
	u32 wait_flag1;
	u32 wait_flag0;
	u32 complt_hwirq;
	u32 update_drv_odt_cfg;
	u32 update_deskew_cfg;
	u32 freq_count;
	u32 freq_info_mhz[6];
	u32 wait_mode;
	u32 vop_scan_line_time_ns;
};

struct px30_dmc {
	struct device *dev;
	struct devfreq *devfreq;
	struct devfreq_dev_profile profile;
	struct devfreq_simple_ondemand_data ondemand;
	struct devfreq_event_dev *edev;
	struct regulator *vdd;
	struct px30_dmc_params __iomem *params;
	struct completion done;
	struct pm_qos_request qos;
	int irq;
	unsigned long rate;
	unsigned long volt;
};

static struct arm_smccc_res px30_dmc_sip(unsigned long arg0, unsigned long cmd)
{
	struct arm_smccc_res res;

	arm_smccc_smc(ROCKCHIP_SIP_DRAM_FREQ, arg0, 0, cmd, 0, 0, 0, 0, &res);
	return res;
}

/* BSP px30_de_skew_set_2_reg: pack 4-bit de-skew values into the firmware layout */
static void px30_pack_deskew(const u32 *ca, const u32 *cs0, const u32 *cs1,
			     struct px30_ddr_dts_config_timing *tim)
{
	u32 n, offset, shift;

	for (n = 0; n < 30; n++) {
		offset = n / 2;
		shift = (n % 2) ? 0 : 4;
		tim->ca_skew[offset] |= ca[n] << shift;
	}
	for (n = 0; n < 84; n++) {
		offset = ((n / 21) * 11) + ((n % 21) / 2);
		shift = ((n % 21) == 20) ? 0 : (((n % 21) % 2) ? 0 : 4);
		tim->cs0_skew[offset] |= cs0[n] << shift;
		tim->cs1_skew[offset] |= cs1[n] << shift;
	}
}

static void px30_load_timing(struct px30_dmc *dmc)
{
	struct px30_ddr_dts_config_timing *tim;
	u32 *p, i;

	tim = kzalloc(sizeof(*tim), GFP_KERNEL);
	if (!tim)
		return;
	p = (u32 *)tim;
	for (i = 0; i < ARRAY_SIZE(px30_dts_timing); i++)
		p[i] = stock_timing[i];
	px30_pack_deskew(stock_ca, stock_cs0, stock_cs1, tim);
	tim->available = 1;
	memcpy_toio((void __iomem *)dmc->params + SZ_4K, tim, sizeof(*tim));
	dev_info(dmc->dev, "timing page loaded: %zu bytes, available=%u\n", sizeof(*tim),
		 readl((void __iomem *)dmc->params + SZ_4K + offsetof(struct px30_ddr_dts_config_timing, available)));
	kfree(tim);
}

static irqreturn_t px30_dmc_done_irq(int irq, void *data)
{
	struct px30_dmc *dmc = data;

	dev_info(dmc->dev, "completion irq\n");
	complete(&dmc->done);
	return IRQ_HANDLED;
}

static int px30_dmc_set_rate(struct px30_dmc *dmc, unsigned long rate,
			     unsigned int lcdc_type)
{
	struct arm_smccc_res res;

	DBG(dmc->dev, "SET_RATE %lu -> %lu lcdc=%u\n", dmc->rate, rate, lcdc_type);
	if (round) {
		writel(rate, &dmc->params->hz);
		res = px30_dmc_sip(PX30_SHARE_PAGE_TYPE_DDR,
				   ROCKCHIP_SIP_CONFIG_DRAM_ROUND_RATE);
		DBG(dmc->dev, "ROUND_RATE %lu: a0=%lx a1=%lx\n", rate, res.a0, res.a1);
		if (!res.a0 && res.a1)
			rate = res.a1;
	}
	writel_relaxed(rate, &dmc->params->hz);
	writel_relaxed(lcdc_type, &dmc->params->lcdc_type);
	writel_relaxed(!!lcdc_type, &dmc->params->wait_flag1);
	writel_relaxed(!!lcdc_type, &dmc->params->wait_flag0);
	/* BL31 reads the request as soon as it is entered */
	wmb();

	reinit_completion(&dmc->done);
	res = px30_dmc_sip(PX30_SHARE_PAGE_TYPE_DDR,
			   ROCKCHIP_SIP_CONFIG_DRAM_SET_RATE);
	DBG(dmc->dev, "SET_RATE smc a0=%lx a1=%lx\n", res.a0, res.a1);
	if ((int)res.a1 == PX30_SET_RATE_PENDING && !nowait) {
		/* BL31 finishes from FIQ, keep the CPUs out of deep idle */
		cpu_latency_qos_update_request(&dmc->qos, 0);
		enable_irq(dmc->irq);
		if (!wait_for_completion_timeout(&dmc->done, msecs_to_jiffies(85)))
			DBG(dmc->dev, "timed out switching to %lu Hz\n", rate);
		else
			DBG(dmc->dev, "completion irq received\n");
		disable_irq(dmc->irq);
		cpu_latency_qos_update_request(&dmc->qos, PM_QOS_DEFAULT_VALUE);
	} else if (nowait) {
		DBG(dmc->dev, "nowait: not waiting for completion\n");
	}
	if (res.a0)
		return -EIO;
	if (nogetrate) {
		DBG(dmc->dev, "nogetrate: skipping GET_RATE\n");
		dmc->rate = rate;
		return 0;
	}
	DBG(dmc->dev, "GET_RATE...\n");

	res = px30_dmc_sip(PX30_SHARE_PAGE_TYPE_DDR,
			   ROCKCHIP_SIP_CONFIG_DRAM_GET_RATE);
	if (res.a0)
		return -EIO;

	dmc->rate = res.a1;
	dev_info(dmc->dev, "GET_RATE a0=%lx rate=%lu\n", res.a0, dmc->rate);
	return dmc->rate == rate ? 0 : -EIO;
}

static int px30_dmc_target(struct device *dev, unsigned long *freq, u32 flags)
{
	struct px30_dmc *dmc = dev_get_drvdata(dev);
	unsigned long old = dmc->rate, rate, volt;
	struct dev_pm_opp *opp;
	int ret;

	opp = devfreq_recommended_opp(dev, freq, flags);
	if (IS_ERR(opp))
		return PTR_ERR(opp);
	rate = dev_pm_opp_get_freq(opp);
	volt = dev_pm_opp_get_voltage(opp);
	dev_pm_opp_put(opp);

	if (rate == old)
		return 0;

	/* vdd_logic also feeds the GPU, so only ask for a minimum */
	if (rate > old) {
		ret = regulator_set_voltage(dmc->vdd, volt, INT_MAX);
		if (ret)
			return ret;
	}

	DBG(dev, "pmu_block...\n");
	ret = rockchip_pmu_block();
	DBG(dev, "pmu_block ret=%d\n", ret);
	if (!ret) {
		ret = px30_dmc_set_rate(dmc, rate, lcdc);
		rockchip_pmu_unblock();
	}
	if (ret) {
		if (rate > old)
			regulator_set_voltage(dmc->vdd, dmc->volt, INT_MAX);
		return ret;
	}

	if (rate < old)
		regulator_set_voltage(dmc->vdd, volt, INT_MAX);

	dmc->volt = volt;
	*freq = rate;
	return 0;
}

static int px30_dmc_get_dev_status(struct device *dev,
				   struct devfreq_dev_status *stat)
{
	struct px30_dmc *dmc = dev_get_drvdata(dev);
	struct devfreq_event_data edata;
	int ret;

	ret = devfreq_event_get_event(dmc->edev, &edata);
	if (ret < 0)
		return ret;

	stat->current_frequency = dmc->rate;
	stat->busy_time = edata.load_count;
	stat->total_time = edata.total_count;
	return 0;
}

static int px30_dmc_get_cur_freq(struct device *dev, unsigned long *freq)
{
	struct px30_dmc *dmc = dev_get_drvdata(dev);

	*freq = dmc->rate;
	return 0;
}

static void px30_dmc_disable_edev(void *data)
{
	devfreq_event_disable_edev(data);
}

static void px30_dmc_remove_qos(void *data)
{
	cpu_latency_qos_remove_request(data);
}

static int px30_dmc_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct arm_smccc_res res;
	struct dev_pm_opp *opp;
	struct px30_dmc *dmc;
	unsigned long freq;
	int ret;

	res = px30_dmc_sip(0, PX30_DRAM_GET_VERSION);
	dev_info(dev, "GET_VERSION a0=%lx a1=%lx\n", res.a0, res.a1);
	if (res.a0 || res.a1 < 0x103)
		return dev_err_probe(dev, -ENODEV,
				     "BL31 without DRAM DVFS (0x%lx)\n", res.a1);

	dmc = devm_kzalloc(dev, sizeof(*dmc), GFP_KERNEL);
	if (!dmc)
		return -ENOMEM;
	dmc->dev = dev;
	init_completion(&dmc->done);
	platform_set_drvdata(pdev, dmc);

	dmc->vdd = devm_regulator_get(dev, "center");
	if (IS_ERR(dmc->vdd))
		return dev_err_probe(dev, PTR_ERR(dmc->vdd),
				     "failed to get center supply\n");

	dmc->edev = devfreq_event_get_edev_by_phandle(dev, "devfreq-events", 0);
	if (IS_ERR(dmc->edev))
		return -EPROBE_DEFER;

	/* Request page plus an all-zero page: no DT DDR timings, keep TPL's */
	arm_smccc_smc(PX30_SIP_SHARE_MEM, 2, PX30_SHARE_PAGE_TYPE_DDR, 0,
		      0, 0, 0, 0, &res);
	dev_info(dev, "SHARE_MEM a0=%lx a1=%lx a2=%lx\n", res.a0, res.a1, res.a2);
	if (res.a0)
		return dev_err_probe(dev, -ENOMEM, "no BL31 share memory\n");
	dmc->params = devm_ioremap(dev, res.a1, 2 * SZ_4K);
	if (!dmc->params) {
		dev_info(dev, "ioremap failed, trying memremap\n");
		dmc->params = devm_memremap(dev, res.a1, 2 * SZ_4K, MEMREMAP_WB);
		if (IS_ERR(dmc->params))
			return PTR_ERR(dmc->params);
	}
	memset_io(dmc->params, 0, 2 * SZ_4K);
	if (timing)
		px30_load_timing(dmc);

	dmc->irq = platform_get_irq_byname(pdev, "complete");
	if (dmc->irq < 0)
		return dmc->irq;
	ret = devm_request_irq(dev, dmc->irq, px30_dmc_done_irq,
			       IRQF_NO_AUTOEN, dev_name(dev), dmc);
	if (ret)
		return ret;
	writel(irqd_to_hwirq(irq_get_irq_data(dmc->irq)),
	       &dmc->params->complt_hwirq);

	res = px30_dmc_sip(PX30_SHARE_PAGE_TYPE_DDR,
			   ROCKCHIP_SIP_CONFIG_DRAM_INIT);
	if (res.a0)
		return dev_err_probe(dev, -EIO, "BL31 DRAM init failed\n");

	res = px30_dmc_sip(PX30_SHARE_PAGE_TYPE_DDR,
			   ROCKCHIP_SIP_CONFIG_DRAM_GET_RATE);
	if (res.a0)
		return dev_err_probe(dev, -EIO, "BL31 DRAM get rate failed\n");
	dmc->rate = res.a1;
	dev_info(dev, "DRAM_INIT ok, GET_RATE a0=%lx rate=%lu hwirq=%u\n", res.a0, dmc->rate,
		 readl(&dmc->params->complt_hwirq));
	{
		u32 buf[24], i;
		for (i = 0; i < 24; i++)
			buf[i] = readl(((u32 __iomem *)dmc->params) + i);
		print_hex_dump(KERN_INFO, "px30-dmc params: ", DUMP_PREFIX_OFFSET, 16, 4, buf, sizeof(buf), false);
		for (i = 0; i < 8; i++)
			buf[i] = readl(((u32 __iomem *)dmc->params) + 1024 + i);
		print_hex_dump(KERN_INFO, "px30-dmc timing: ", DUMP_PREFIX_OFFSET, 16, 4, buf, 32, false);
	}

	ret = devm_pm_opp_of_add_table(dev);
	if (ret)
		return dev_err_probe(dev, ret, "invalid operating points\n");

	ret = devfreq_event_enable_edev(dmc->edev);
	if (ret)
		return ret;
	ret = devm_add_action_or_reset(dev, px30_dmc_disable_edev, dmc->edev);
	if (ret)
		return ret;

	cpu_latency_qos_add_request(&dmc->qos, PM_QOS_DEFAULT_VALUE);
	ret = devm_add_action_or_reset(dev, px30_dmc_remove_qos, &dmc->qos);
	if (ret)
		return ret;

	freq = dmc->rate;
	opp = devfreq_recommended_opp(dev, &freq, DEVFREQ_FLAG_LEAST_UPPER_BOUND);
	if (IS_ERR(opp))
		return PTR_ERR(opp);
	dmc->volt = dev_pm_opp_get_voltage(opp);
	dev_pm_opp_put(opp);
	ret = regulator_set_voltage(dmc->vdd, dmc->volt, INT_MAX);
	if (ret)
		return ret;

	dmc->ondemand.upthreshold = 40;
	dmc->ondemand.downdifferential = 20;
	dmc->profile = (struct devfreq_dev_profile) {
		.polling_ms	= 50,
		.target		= px30_dmc_target,
		.get_dev_status	= px30_dmc_get_dev_status,
		.get_cur_freq	= px30_dmc_get_cur_freq,
		.initial_freq	= freq,
	};

	dmc->devfreq = devm_devfreq_add_device(dev, &dmc->profile, gov,
					       &dmc->ondemand);
	if (IS_ERR(dmc->devfreq))
		return PTR_ERR(dmc->devfreq);

	return devm_devfreq_register_opp_notifier(dev, dmc->devfreq);
}

static int px30_dmc_suspend(struct device *dev)
{
	struct px30_dmc *dmc = dev_get_drvdata(dev);
	int ret;

	ret = devfreq_event_disable_edev(dmc->edev);
	if (ret < 0)
		return ret;

	return devfreq_suspend_device(dmc->devfreq);
}

static int px30_dmc_resume(struct device *dev)
{
	struct px30_dmc *dmc = dev_get_drvdata(dev);
	int ret;

	ret = devfreq_event_enable_edev(dmc->edev);
	if (ret < 0)
		return ret;

	return devfreq_resume_device(dmc->devfreq);
}

static DEFINE_SIMPLE_DEV_PM_OPS(px30_dmc_pm, px30_dmc_suspend, px30_dmc_resume);

static const struct of_device_id px30_dmc_of_match[] = {
	{ .compatible = "rockchip,px30-dmc" },
	{ }
};
MODULE_DEVICE_TABLE(of, px30_dmc_of_match);

static struct platform_driver px30_dmc_dbg_driver = {
	.probe	= px30_dmc_probe,
	.driver = {
		.name		= "px30-dmc-dbg",
		.pm		= pm_sleep_ptr(&px30_dmc_pm),
		.of_match_table	= px30_dmc_of_match,
	},
};
module_platform_driver(px30_dmc_dbg_driver);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("PX30 DDR frequency scaling through Rockchip BL31");
