# Tools

| file | runs on | what |
|---|---|---|
| `opps.sh` | device | cpufreq's OPPs, governor, time in each state, `vdd_arm` and its limits |
| `sweep.sh` | device | every OPP up and down, with `armclk`, APLL and `vdd_arm` |
| `stress.sh` | device | four cores busy, random OPP every 0.1 s for 3 min, then default governors for 2 min |
| `bench.sh` | device | sustained and burst runs under `ondemand` with the floor at 1008 and at 600 MHz |
| `resume.sh` | device | suspend/resume cycles by RTC alarm, each followed by random CPU OPPs under load with memtester |
| `power.sh` | device | battery draw at idle with the floor at 1008 and 600 MHz; unplug USB, logs to `/storage` |
| `resume.sh` | device | suspend/resume cycles (RTC wake), random OPPs with all cores busy and memtester right after each resume; logs to `/storage` |

ROCKNIX has no `userspace` cpufreq governor; the scripts pin a rate with `performance` and `scaling_max_freq`, or set a floor with `scaling_min_freq`.
