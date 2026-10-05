# Design

Three changes: the GPU OPP table, the GPU clock tree, and how kbase asks for voltage. Driver: [ROCKNIX/distribution #3438](https://github.com/ROCKNIX/distribution/pull/3438).

## What was wrong

ROCKNIX's `rk3326.dtsi` deleted the mainline GPU OPPs (200/300/400/480 MHz) and added a single 560 MHz OPP at 1.15 V. The clock tree cannot make 560 MHz, so `clk_set_rate(560 MHz)` lands on gpll / 2.5 = 480 MHz while devfreq reports 560:

```
gpu devfreq cur=560000000 avail=560000000
clk_gpu      rate=480000000 parent=clk_gpu_np5
clk_gpu_src  rate=1200000000 parent=gpll
vdd_logic    1150000 uV
```

Net effect: no scaling, the GPU never idles below 480 MHz, `vdd_logic` never drops below 1.15 V, and the GPU cooling device has no lower step to throttle to.

## Clock tree

```
                 ┌ gpll    1200 MHz
clk_gpu_src  mux ┤ cpll     600 MHz (dummy on PX30/RK3326)
 (CLKSEL_CON1    ├ usb480m  480 MHz (USB2 PHY output)
  bits 7:6)      └ npll    1040 MHz
      │
     div  (CLKSEL_CON1 bits 3:0)
      │
   clk_gpu  gate
```

### One composite, as the vendor kernel has it

Mainline models the GPU clock as a mux clock, an integer divider clock, a half divider (`clk_gpu_np5`) and a second mux choosing between the two dividers. Two problems:

1. The dividers have no `CLK_SET_RATE_PARENT`, so a rate request never reaches `clk_gpu_src`: the GPU only divides gpll and 520 MHz is unreachable.
2. Adding `CLK_SET_RATE_PARENT` fixes reachability but not ordering. When a switch needs a new parent, the clock framework writes the parent's mux first and the child's divider afterwards. Leaving 480 MHz (usb480m / 1) for 520 (npll / 2) or 400 (gpll / 3) runs the GPU at 1040 or 1200 MHz until the divider write lands. We tried this first: it passed every single-step test and hung the SoC within minutes under `simple_ondemand` with glmark2 running.

A `COMPOSITE` of mux and divider in one clock fixes both. Its `determine_rate` picks the parent that divides best without changing any PLL (`clk_gpu_src` has no `CLK_SET_RATE_PARENT`), and `clk_composite_set_rate_and_parent()` lowers the divider before switching the parent when the new parent would overshoot. This is the vendor layout (`clk-px30.c`, `rk3326_gpu_src_clk`) and kk's.

The half divider and the second mux (`CLKSEL_CON1` bit 15) are dropped. Bit 15 resets to 0 (integer divider path) and nothing writes it; the vendor kernel relies on the same.

### Parents per OPP

| OPP | parent | divider |
|---|---|---|
| 200 MHz | gpll | 6 |
| 300 MHz | gpll | 4 |
| 400 MHz | gpll | 3 |
| 480 MHz | usb480m | 1 |
| 520 MHz | npll | 2 |

Chosen by the clock framework, and identical to what the vendor 4.4 kernel picks on the same board (observed). usb480m is the only parent that divides to 480 exactly. The GPU holds the PHY's output clock while it uses it, so the PHY keeps it running with the cable unplugged ([validation.md](validation.md#usb480m)). On a board where the PHY is not probed usb480m is not at 480 MHz and the mux simply does not pick it.

### NPLL at 1040 MHz

Mainline sets NPLL to 1188 MHz; the vendor `rk3326.dtsi` sets 1040 for exactly this, npll / 2 = 520. On RK3326 NPLL's only other consumer is the second VOP's pixel clock, and that VOP is deleted in `rk3326.dtsi`. UART, eMMC and the panel clock are unchanged (observed). The Rockchip PLL driver only accepts rates from its table, so `1040000000` is added to `px30_pll_rates`.

## OPPs

Mainline's `px30.dtsi` table, unchanged: 200/300/400/480 MHz at 950/975/1050/1125 mV. These are the vendor values. 520 MHz at 1175 mV comes from the vendor `rk3326.dtsi`.

The vendor kernel lowers voltages per chip from PVTM (`opp-microvolt-L0`…`L3`, down to 1050 mV at 520 MHz). Mainline has no such selection; the default (`L0`, worst bin) is used.

520 MHz and NPLL 1040 MHz are set per board, only on `rk3326-gameconsole-eeclone`: its `vdd_logic` allows 0.95–1.35 V (as the stock dtb). odroid-go, r3xs, xu10 and gameforce-chi limit `vdd_logic` to 1.15 V, as Hardkernel's vendor dts does; there kbase would fail every request for 1175 mV.

## `vdd_logic` is shared with the DDR controller

kbase asks for exact voltages, `regulator_set_voltage(reg, v, v)`. The DMC driver asks for a minimum. The regulator core intersects the consumers' ranges and returns `-EINVAL` when they don't overlap: GPU at 200 MHz pins `[950, 950]` mV, so the DMC cannot get 1050 mV for 666 MHz, and the other way round. With ROCKNIX's single 560 MHz OPP the GPU asks for 1150 mV, above every DDR step, so the conflict only appears once GPU scaling is restored.

The patch makes it ask for `[v, INT_MAX]`, as the vendor kbase does. A higher voltage than the OPP's never hurts the GPU.

## Patches

| file | what |
|---|---|
| `linux/037-px30-gpu-clock-source.patch` | `clk_gpu_src` composite, `clk_gpu` gate, 1040 MHz PLL rate |
| `mali-bifrost/005-devfreq-shared-supply-min-voltage.patch` | kbase: minimum voltage |
| `rk3326.dtsi` | drop the 560 MHz OPP override |
| `rk3326-gameconsole-eeclone.dts` | NPLL 1040 MHz, 520 MHz OPP |
