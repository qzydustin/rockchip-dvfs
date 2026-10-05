# Validation

R36S clone (HG36 panel 640×480), ROCKNIX `rk3326-gameconsole-eeclone`, with DDR frequency scaling enabled.

## Every OPP

[tools/sweep.sh](tools/sweep.sh): `userspace` governor, GPU idle, DDR at its lowest OPP; values from `/sys/kernel/debug/clk` and the regulator class:

| request | `clk_gpu` | parent | `vdd_logic` |
|---|---|---|---|
| 200 MHz | 200 MHz | gpll | 950 mV |
| 300 MHz | 300 MHz | gpll | 975 mV |
| 400 MHz | 400 MHz | gpll | 1050 mV |
| 480 MHz | 480 MHz | usb480m | 1125 mV |
| 520 MHz | 520 MHz | npll | 1175 mV |

Also 480→520, 520→480, 480→400 and 400→520 directly: exact. The eeclone's 1.0 V `vdd_logic` minimum ([design.md](design.md#vdd_logic-at-least-10-v-on-the-eeclone)) removes the 200 and 300 MHz rows; the rest are unchanged.

## Performance

[tools/bench.sh](tools/bench.sh): DDR pinned at 666 MHz, glmark2-es2-wayland `--off-screen`, GPU pinned:

| GPU | glmark2 score |
|---|---|
| 480 MHz (the fixed rate before) | 311 |
| 520 MHz | 330 (+6 %) |

Idle: 200 MHz at 950 mV instead of 480 MHz at 1150 mV.

## Stress

[tools/stress.sh](tools/stress.sh).

| test | result |
|---|---|
| glmark2 looping, a random OPP every 0.3 s for 3 min (552 changes) | no hang, no kbase errors |
| glmark2 looping, GPU and DDR both `simple_ondemand` for 2 min (630 GPU, 360 DDR transitions; GPU reaches 520) | no hang, no kbase errors |
| first attempt, split clock tree with `CLK_SET_RATE_PARENT` on the dividers, same ondemand load | **SoC hung** — see [design.md](design.md#one-composite-as-the-vendor-kernel-has-it) |

Re-run with the 1.0 V minimum (GPU 400–520 MHz): 549 random changes and 493 GPU / 439 DDR `simple_ondemand` transitions, no errors.

## Shared rail

[tools/rail.sh](tools/rail.sh).

| step | GPU | DDR | `vdd_logic` |
|---|---|---|---|
| GPU 200, DDR → 666 | 200 MHz | 666 MHz | 1050 mV |
| GPU → 520 | 520 MHz | 666 MHz | 1175 mV |
| DDR → 194 | 520 MHz | 194 MHz | 1175 mV |
| GPU → 200 | 200 MHz | 194 MHz | 950 mV |

## usb480m

GPU pinned at 480 MHz (usb480m), glmark2 looping, state logged every second to `/storage` ([tools/usb480m-test.sh](tools/usb480m-test.sh)); the USB cable unplugged and replugged during the window (re-enumeration in `dmesg` inside it). 118 samples, all `clk_gpu=480000000 src=usb480m`, usb480m enabled throughout, no gap in the log, glmark2 never exited.

ROCKNIX's `powerstate` service resets the GPU governor when the charger is unplugged, which moves the GPU off usb480m; it was stopped for this test so the GPU stayed at 480 MHz.

## Audio

`vdd_logic` set by pinning GPU and DDR, EmulationStation menu, listening while scrolling:

| DDR | GPU | `vdd_logic` | noise | menu sound |
|---|---|---|---|---|
| 666 MHz | 200 MHz | 1050 mV | none | |
| 194 MHz | 200 MHz | 950 mV | yes | delayed |
| 328 MHz | 200 MHz | 950 mV | yes | delayed |
| 194 MHz | 480 MHz | 1125 mV | none | immediate, occasional crackle |
| lowest GPU/DDR OPPs raised to 1.0 V | | ≥ 1000 mV | none | immediate, no crackle |

Forcing the `vdd_logic` buck into PWM mode did not help. CPU pinned, GPU and DDR on `simple_ondemand` at their lowest:

| CPU | `vdd_logic` | noise |
|---|---|---|
| 1296 MHz | 1000 mV (vendor bus rule) | none |
| 816 MHz | 950 mV | yes |

With the 1.0 V minimum: idle at GPU 400 MHz, DDR 194 MHz, 1050 mV; no noise, immediate menu sounds, no crackles.

## Other

| test | result |
|---|---|
| deep suspend and resume with glmark2 running | scaling and parents unchanged afterwards |
| NPLL 1188 → 1040 MHz | UART (xin24m), eMMC HS200 (gpll, 150 MHz), panel clock (cpll, 30 MHz) unchanged |
