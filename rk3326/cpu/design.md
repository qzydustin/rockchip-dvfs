# Design

One change: stop deleting the lower CPU OPPs. Branch: `qzydustin/distribution` `px30-cpu`.

## What was wrong

ROCKNIX's `rk3326.dtsi` deletes three of mainline's five CPU OPPs and adds a 1416 MHz turbo OPP:

```
&cpu0_opp_table {
	/delete-node/ opp-600000000;
	/delete-node/ opp-816000000;
	/delete-node/ opp-1200000000;
	opp-1416000000 { ... turbo-mode; };
};
```

That leaves 1008 and 1296 MHz (1416 needs `boost`, which is off). The CPU never goes below 1008 MHz at 1175 mV. It also removes the 600 MHz OPP's `opp-suspend`, and ROCKNIX's own sleep script, which switches to `powersave` before suspend to drop to the lowest frequency, ends up at 1008.

The deletions come from `000-rk3326-dts.patch` of the JELOS era, carried over in the 7.1 kernel bump; no reason is recorded. kk's tree has the same lines.

## Change

Remove the three `/delete-node/` lines. The CPU gets mainline's `px30.dtsi` table back: 600/816/1008/1200/1296 MHz at 950/1050/1175/1300/1350 mV, the vendor values, with `opp-suspend` on 600 MHz. The 1416 MHz turbo OPP stays as it is.

`clk-px30.c` already has every rate in both the APLL table and the `armclk` table, and `vdd_arm` is used by the CPU only, so nothing else changes.

Not added: the vendor's 408, 1104 and 1248 MHz steps. Mainline's table is the baseline every other PX30 board uses; going beyond it is a separate question.

## Governor

ROCKNIX runs `ondemand` with `up_threshold` 95 and a 6.7 ms sampling period. With the lower OPPs it moves between 600 and 816 MHz in the menu, about 85 transitions a second (20 without them). This costs nothing measurable ([validation.md](validation.md#performance)).
