# Tools

| file | runs on | what |
|---|---|---|
| `px30_dmc_dbg.c`, `px30_dmc_timing.h`, `Makefile` | build host | probe module: the driver with each step optional and logged |
| `build-module.sh` | build host | builds the module against a ROCKNIX build tree, in the ROCKNIX build container |
| `extract-ddr-timing.py` | build host | turns a vendor dtb's `ddr_timing` node into `examples/<board>-ddr-timing.h` |
| `sweep.sh` | device | every OPP up and down, read back |
| `memtest-cycling.sh` | device | memtester while switching every 0.3 s, then under `simple_ondemand` |
| `bench.sh` | device | tinymembench + glmark2 at pinned rates |
| `overlays/` | device | `dmc-enable`, `dmc-opp-786`, `ramoops` (persistent kernel log) |

## Probe module

Copy this directory into the ROCKNIX checkout and run `./build-module.sh <checkout>`. On the device, add `initcall_blacklist=px30_dmc_driver_init` to `extlinux.conf` if the driver is built in, then `insmod`. Follow the log with `ssh root@<device> cat /dev/kmsg`.

| parameter | default | effect |
|---|---|---|
| `gov` | `userspace` | initial governor |
| `round` | `1` | `ROUND_RATE` before `SET_RATE`; `0` hangs the SoC |
| `lcdc` | `0` | `lcdc_type` for BL31; non-zero waits for VOP line flag 1 |
| `timing` | `0` | fill page 1 from `examples/*-ddr-timing.h`, `available = 1` |
| `nowait` | `0` | don't wait for the completion interrupt |
| `nogetrate` | `0` | skip `GET_RATE` |
| `delay_ms` | `300` | sleep after each log line, so it gets out before a hang; `0` for normal use |

## Overlays

`dtc -@ -I dts -O dtb -o x.dtbo x.dts`, copy to `/flash/overlays/`, append to `FDTOVERLAYS` in `extlinux.conf`. For ramoops pick a free window from `/proc/iomem`; read `/sys/fs/pstore` after the next boot.
