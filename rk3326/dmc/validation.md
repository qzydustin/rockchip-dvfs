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
