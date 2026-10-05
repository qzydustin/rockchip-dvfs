# Vendor kernel and other ports

Sources: `rockchip-linux/kernel` `develop-5.10` (`drivers/clk/rockchip/clk-px30.c`, `arch/arm64/boot/dts/rockchip/px30.dtsi`, `rk3326.dtsi`, `drivers/gpu/arm/bifrost/backend/gpu/mali_kbase_devfreq.c`); the stock R36S-clone dtb `rf3536k3ka.dtb`; dArkOS4Clone (vendor 4.4) on the same board.

## Clock

`clk-px30.c` registers `clk_gpu_src` as a `COMPOSITE` (mux `CLKSEL_CON1[7:6]`, divider `CLKSEL_CON1[3:0]`, gate `CLKGATE_CON0[8]`) and `clk_gpu` as a `GATE` on it. Two parent lists:

```c
PNAME(mux_gpll_dmycpll_usb480m_npll_p)    = { "gpll", "dummy_cpll", "usb480m", "npll" };
PNAME(mux_gpll_dmycpll_usb480m_dmynpll_p) = { "gpll", "dummy_cpll", "usb480m", "dummy_npll" };

if (of_machine_is_compatible("rockchip,px30"))
        register px30_gpu_src_clk;    /* no npll */
else
        register rk3326_gpu_src_clk;  /* npll allowed */
```

PX30 boards may use NPLL for something else; RK3326 reserves it for the GPU.

Parents observed on dArkOS4Clone, `devfreq userspace`, `/sys/kernel/debug/clk/clk_gpu_src/clk_parent`: 200/300/400 MHz gpll, 480 usb480m, 520 npll.

## Device tree

`px30.dtsi`: GPU OPPs 200/300/400/480 MHz, `opp-microvolt` 950/975/1050/1125 mV with `-L0`…`-L3` per PVTM bin, `rockchip,pvtm-voltage-sel`, low-temperature voltage adjust, `upthreshold 40`, `downdifferential 10`.

`rk3326.dtsi`:

```
&cru { assigned-clocks = <&cru PLL_NPLL>; assigned-clock-rates = <1040000000>; };
&gpu_opp_table {
        opp-520000000 { opp-microvolt = <1175000>; -L0 1175000 -L1 1150000 -L2 1100000 -L3 1050000 };
};
```

Stock `rf3536k3ka.dtb`: GPU OPPs 200/300/400/480/520 MHz at the same voltages, `vdd_logic` 0.95–1.35 V. Hardkernel's ODROID-GO Advance vendor dts limits `vdd_logic` to 1.15 V.

## kbase

`mali_kbase_devfreq.c` goes through `dev_pm_opp_set_rate()` with Rockchip's OPP helpers: `rockchip_set_intermediate_rate()`, then `regulator_set_voltage(vdd, u_volt, INT_MAX)` (minimum only) before raising the clock / after lowering it.

## Other ports

| who | where | approach |
|---|---|---|
| mainline | `clk-px30.c`, `px30.dtsi` | split mux / div / half div / mux tree; OPPs 200–480 MHz; NPLL 1188 MHz; no 1040 MHz PLL rate |
| ROCKNIX (before #3438) | `rk3326.dtsi` | mainline tree; OPPs replaced by a single 560 MHz at 1.15 V (actually 480 MHz) |
| ROCKNIX GKD Pixel2 | `rk3326s-gkd-pixel2.dts` | board-local copy of the vendor 200–520 MHz table; without the clock change 520 is not reached |
| kk (AveyondFly) | `distribution_rocknix` `next`, patch 003 + `000-rk3326-dts.patch` | same composite as the vendor, 1040 MHz PLL rate; OPPs 200–520 in `px30.dtsi`, NPLL 1040 in `rk3326.dtsi` for all boards |

#3438 uses the same clock layout as kk's 003. It differs in placing 520 MHz and NPLL per board, and in the kbase voltage change, which kk's tree does not need because it has no DMC sharing the rail.
