# Design

One change: the EE clone gets back the lower CPU OPPs that ROCKNIX deletes for every RK3326 board. Changes: [ROCKNIX/distribution #3439](https://github.com/ROCKNIX/distribution/pull/3439).

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

That leaves 1008 and 1296 MHz (1416 needs `boost`, which ROCKNIX's turbo mode setting turns on). The CPU never goes below 1008 MHz at 1175 mV. It also removes the 600 MHz OPP's `opp-suspend`, and ROCKNIX's own sleep script, which switches to `powersave` before suspend to drop to the lowest frequency, ends up at 1008.

## Why they were deleted

The deletions come from JELOS and were carried over into ROCKNIX and kk's tree:

| when | JELOS change |
|---|---|
| 2023-05 | first RK3326 device patch: 600 MHz deleted, no reason given |
| 2023-12 | "RK3326 - Tune available clocks and increase ram freq": 816 and 1200 MHz deleted, together with the low GPU steps, and DDR raised |
| 2024-01 | "Add overclocking options to RK3326": the 1416 MHz turbo OPP |

In review, ROCKNIX developers recalled from that time that with the low OPPs present the CPU would not reach the top (overclock) frequency, and that battery life barely changed. On the GKD Pixel2 (RK3326S), whose board dts keeps the vendor table, a 1.5 GHz step crashed on transitions from a low frequency when overclock was turned on under a dynamic governor, and was disabled there. Neither problem reproduced on the EE clone, including transitions straight from 600 to 1416 MHz ([validation.md](validation.md#overclock)).

## Change

The EE clone's dts adds the three steps back at mainline's `px30.dtsi` values, which are the vendor values: 600/816/1200 MHz at 950/1050/1300 mV, `opp-suspend` on 600 MHz. Its table becomes 600/816/1008/1200/1296 MHz plus the 1416 MHz turbo OPP, unchanged.

`rk3326.dtsi` and the other boards keep the reduced table, the same scope as the DDR scaling: older boards weren't tested. The GKD Pixel2 uses its own board table and is not affected either way. The first version removed the `/delete-node/` lines from `rk3326.dtsi` for every board; an overlay with the three steps was also built, but on RK3326 it can only be enabled by editing `extlinux.conf` by hand.

`clk-px30.c` already has every rate in both the APLL table and the `armclk` table, and `vdd_arm` is used by the CPU only, so nothing else changes.

Not added: the vendor's 408, 1104 and 1248 MHz steps. Mainline's table is the baseline every other PX30 board uses; going beyond it is a separate question.

## Governor

ROCKNIX runs `ondemand` with `up_threshold` 95 and a 6.7 ms sampling period. With the lower OPPs it moves between 600 and 816 MHz in the menu, about 85 transitions a second (20 without them). This costs nothing measurable ([validation.md](validation.md#performance)), and saves nothing measurable either ([validation.md](validation.md#idle)).
