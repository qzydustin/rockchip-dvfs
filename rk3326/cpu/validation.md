# Validation

R36S clone, ROCKNIX `rk3326-gameconsole-eeclone`, with DDR and GPU frequency scaling enabled; only the dtb changed.

## Every OPP

[tools/sweep.sh](tools/sweep.sh) (ROCKNIX has no `userspace` cpufreq governor; `performance` with `scaling_max_freq`):

| OPP | `armclk` | APLL | `vdd_arm` |
|---|---|---|---|
| 600 MHz | 600 MHz | 600 MHz | 950 mV |
| 816 MHz | 816 MHz | 816 MHz | 1050 mV |
| 1008 MHz | 1008 MHz | 1008 MHz | 1175 mV |
| 1200 MHz | 1200 MHz | 1200 MHz | 1300 mV |
| 1296 MHz | 1296 MHz | 1296 MHz | 1350 mV |

## Stress

[tools/stress.sh](tools/stress.sh): four cores busy, a random OPP every 0.1 s for 3 min (1023 changes), then CPU, GPU and DDR on their default governors under the same load for 2 min. 6942 CPU transitions, no errors, 69 °C at the end.

## Performance

[tools/bench.sh](tools/bench.sh), `ondemand`, floor at the old 1008 MHz versus 600 MHz, two runs each:

| | floor 1008 MHz | floor 600 MHz |
|---|---|---|
| sustained (md5sum 64 MB) | 844 / 827 ms | 833 / 839 ms |
| 20 bursts (md5sum 8 MB after 1 s idle) | 124 / 124 ms | 125 / 124 ms |

No difference: `ondemand` reaches the top before a burst is over.

## Idle

EmulationStation menu, 60 s, time in each OPP:

| floor | 600 | 816 | 1008 | 1200 |
|---|---|---|---|---|
| 1008 MHz (before) | – | – | 53.5 s | 6.5 s |
| 600 MHz | 15.4 s | 38.1 s | 2.6 s | 3.7 s |

Battery draw on battery, same menu, [tools/power.sh](tools/power.sh), 30 samples per phase, two phases each:

| floor | current | power |
|---|---|---|
| 1008 MHz | 321 / 321 mA | 1.32 / 1.31 W |
| 600 MHz | 326 / 322 mA | 1.34 / 1.31 W |

No difference within the fuel gauge's resolution (readings scatter by ±25 mA). The menu's 1.3 W is mostly panel, backlight and EmulationStation itself; the CPU's share at these rates is a few tens of mW.

## Suspend

Deep suspend and resume: all four CPUs back, `ondemand` and every OPP working afterwards.

The GKD Pixel2 port (PX30S, LPDDR4, ROCKNIX #2993) reported memory corruption from CPU frequency and voltage changes shortly after resume. [tools/resume.sh](tools/resume.sh) targets that: 10 cycles of RTC wake-up through `systemctl suspend` (ROCKNIX's sleep hooks run), each followed at once by 30 s of a random CPU OPP every 0.05 s with three cores busy and `memtester 64M` running. 268–281 changes per cycle, 0 memtester failures, no kernel errors.
