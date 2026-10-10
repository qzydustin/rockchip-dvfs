# Validation

R36S clone (HG36 panel 640×480, LPDDR3 1 GB), ROCKNIX `rk3326-gameconsole-eeclone`, BL31 v1.34.

## Performance

DMC pinned with `userspace`; 328 MHz stands in for the loader's fixed 332 MHz. CPU pinned at 1296 MHz, EmulationStation stopped (sway kept for glmark2).

| tinymembench | 328 MHz | 666 MHz | change |
|---|---|---|---|
| standard memcpy | 733 MB/s | 1523 MB/s | +108 % |
| standard memset | 2284 MB/s | 4673 MB/s | +105 % |
| NEON LDP/STP copy | 749 MB/s | 1607 MB/s | +115 % |
| random read latency, 8 MB | 252 ns | 161 ns | −36 % |
| random read latency, 64 MB | 259 ns | 167 ns | −36 % |

| glmark2-es2 off-screen | 328 MHz | 666 MHz | change |
|---|---|---|---|
| build (no VBO) | 283 | 413 | +46 % |
| build (VBO) | 384 | 538 | +40 % |
| texture linear | 482 | 761 | +58 % |
| shading phong | 201 | 261 | +30 % |
| bump normals | 469 | 618 | +32 % |
| effect2d 3×3 | 256 | 302 | +18 % |
| desktop blur | 120 | 137 | +14 % |
| terrain | 14 | 16 | +14 % |
| refract | 29 | 44 | +52 % |
| **score** | **247** | **342** | **+38 %** |

## Switching

| | result |
|---|---|
| every OPP up and down, read back from BL31 | exact |
| switch time (`echo` to return) | 6–11 ms |
| `simple_ondemand` | 194 MHz in the menu, 666 MHz under load, back down when idle |
| forced switch every 0.65 s while scrolling the menu / running glmark2 full screen | no tearing or flicker, 0 timeouts |
| display off (VOP suspended) | ok |
| deep suspend and resume with the governor active | scaling continues |

## Memory integrity

| test | switching | result |
|---|---|---|
| `memtester 300M` | every 0.3 s across 194/666/328/450, 2259 switches | ok |
| `memtester 635M` (all free RAM) | `simple_ondemand`, 1339 s | ok |
| eMMC 12 GiB write/verify (HS200) | concurrent with the 300 MB run | 0 mismatches, 0 MMC errors |

0 completion timeouts in all runs.

## Above 666 MHz

Not part of the driver ([design.md](design.md#opps-194--328--450--528--666-mhz)). Test images with extra OPPs for LPDDR3 boards, on the same board (LPDDR3-1866):

| | 786 MHz, 1.10 V | 924 MHz, 1.15 V |
|---|---|---|
| `ROUND_RATE` | exact | exact; 933 MHz, LPDDR3-1866's limit, rounds down to 924 |
| switch time | 8–14 ms | 8 ms |
| `memtester 300M` ×2, pinned | ok | ok |
| `memtester 300M`, all OPPs every 0.3 s | ok, 2034 switches | ok, 2001 switches |
| `memtester 300M`, 194 ↔ top every 0.3 s | ok, 2381 switches | ok, 2275 switches |
| `memtester 300M`, next OPP down ↔ top every 0.3 s | ok, 3646 switches (666 ↔ 786) | 2 failures in one of three runs (786 ↔ 924) |
| `memtester 300M`, `simple_ondemand` | ok | ok |

At 924 MHz glmark2 also crashed once mid-run, and the USB gadget dropped once during 786 ↔ 924 switching.

Performance, CPU pinned at 1296 MHz, DDR pinned, EmulationStation running (hence the lower 666 MHz figures than above):

| | 666 MHz | 786 MHz | 924 MHz |
|---|---|---|---|
| standard memcpy | 1455 MB/s | 1784 MB/s (+23 %) | 1813 MB/s (+25 %) |
| standard memset | 4584 MB/s | 5362 MB/s (+17 %) | 6438 MB/s (+40 %) |
| NEON LDP/STP copy | 1515 MB/s | 1782 MB/s (+18 %) | 2001 MB/s (+32 %) |
| random read latency, 64 MB | 224 ns | 210 ns (−6 %) | 197 ns (−12 %) |
| glmark2-es2 off-screen score | 343 | 359 (+5 %) | crashed |
