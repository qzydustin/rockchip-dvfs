# Vendor kernel and other ports

Sources: `rockchip-linux/kernel`, branches `develop-4.4` (what ArkOS-based images run) and `develop-5.10` / `develop-6.1`. Files: `drivers/devfreq/rockchip_dmc.c`, `drivers/clk/rockchip/clk-ddr.c`, `drivers/firmware/rockchip_sip.c`, `drivers/gpu/drm/rockchip/rockchip_drm_vop.c`, `arch/arm64/boot/dts/rockchip/px30.dtsi`.

## Probe (`px30_dmc_init`)

1. `GET_VERSION`; refuse below 0x103.
2. `SIP_SHARE_MEM` for `DIV_ROUND_UP(sizeof(timing), 4096) + 1` pages of type DDR. Page 0 holds the request, page 1 the DDR timing block.
3. `of_get_px30_timings()` fills page 1 from the `ddr_timing` phandle (61 parameters plus CA/CS0/CS1 de-skew, packed by `px30_de_skew_set_2_reg()`), `available = 1` on success, `0` otherwise.
4. Request the `complete_irq` interrupt (flags 0, so always enabled), write its hwirq to `complt_hwirq`.
5. `DRAM_INIT`.

## A switch

PX30 does not set `is_set_rate_direct` (only RK3528, RK356x and RK3588 do in 5.10), so the devfreq target goes through `clk_set_rate()` on the `dmc_clk`, a `ROCKCHIP_DDRCLK_SIP_V2` clock in `clk-ddr.c`:

- `round_rate` → write `hz`, `SIP ROUND_RATE`, return `x1`.
- `set_rate` → write `hz`, `lcdc_type = rk_drm_get_lcdc_type()`, `wait_flag1 = wait_flag0 = 1`, `SIP SET_RATE`; if `x1 == -6`, `rockchip_dmcfreq_wait_complete()`.
- `recalc_rate` → `SIP GET_RATE`.

The clock framework always calls `round_rate` before `set_rate`, so every PX30 switch issues `ROUND_RATE` then `SET_RATE`. Nothing in the code says this order is required; it is a side effect of using the clock framework. The direct path used for newer SoCs (`rockchip_ddr_set_rate()`) skips rounding, but those SoCs hand BL31 a frequency table at init (`freq_count`, `freq_info_mhz`).

`rockchip_dmcfreq_wait_complete()`: sets a CPU latency QoS of 0 so no core enters a deep idle state, waits up to 85 ms (`17 * 5`) for the completion interrupt, restores QoS.

Around the switch the driver takes `rockchip_dmcfreq_write_trylock()`, the same rwsem the VOP takes in its enable/disable paths, and the PMU block lock.

## VOP

`vop_crtc_atomic_enable()` (4.4) programs `line_flag_num[0] = act_end` and `line_flag_num[1] = act_end - us_to_vertical_line(mode, for_ddr_freq)`, where `for_ddr_freq` is 1000 µs only on VOP 3.2 / 3.8; on PX30 it is 0, so both flags sit at the end of the active area. Our driver does not synchronise with the display ([design.md](design.md#no-display-synchronisation)).

## Device tree and policy

`dmc` node: `interrupts = <GIC_SPI 105 IRQ_TYPE_LEVEL_HIGH>`, `ddr_timing`, `system-status-freq` (normal 666, reboot 450, suspend 194, video 450, performance 1056 MHz), `auto-freq-en`, `upthreshold 40`, `downdifferential 20`. OPPs 194/328/450/666/786 (some boards add 924/1056); 950 mV up to 450, 1050 mV at 666, 1100 mV at 786, with per-leakage-bin variants.

The stock R36S-clone dtb (`rf3536k3ka.dtb`, observed): OPPs 194/328/450/528/666/786, `auto-freq-en = 0`, `auto-min-freq = 450000`, full `ddr_timing` node. On dArkOS4Clone (4.4) the governor is `dmc_ondemand`, cmdline `max_ddrfreq=666`, idle at 328 MHz.

## Other ports

| who | where | approach | state |
|---|---|---|---|
| mainline | `drivers/devfreq/rk3399_dmc.c`, `drivers/clk/rockchip/clk-ddr.c` | RK3399 only; same SIP interface through a clock whose ops call ATF | upstream; no PX30 match |
| kk (AveyondFly) | `distribution_rocknix` branch `next`, patches 026/027 (mainline 6.12) | extends `rk3399_dmc.c` and `rockchip-dfi` for PX30; shared pages, completion IRQ, DT timing block, scan-line time (027); OPPs 194–528 in dts; option to start with the `performance` governor | downstream only |
| REG-Linux | dts | adds a `dmc` node, no driver | no effect |
| ROCKNIX | RK3566 PRs #2360, #2423 | RK356x DMC driver | closed unmerged (conflicts, asked to split) |

kk's 026 calls `ROUND_RATE` before `SET_RATE`. It was not reused because it grows `rk3399_dmc.c` with PX30 branches (DT timing parsing, de-skew packing, a second set-rate path); ours is a small standalone driver with no DT timing data.
