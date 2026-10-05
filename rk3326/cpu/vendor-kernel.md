# Vendor kernel and other ports

## Vendor

Stock R36S-clone dtb (`rf3536k3ka.dtb`), `cpu0-opp-table`:

| OPP | `opp-microvolt` (target, min, max) |
|---|---|
| 408 MHz | 950 / 950 / 1350 mV |
| 600 MHz | 950 / 950 / 1350 mV |
| 816 MHz | 1050 / 1050 / 1350 mV |
| 1008 MHz | 1175 / 1175 / 1350 mV |
| 1104 MHz | 1300 / 1300 / 1350 mV |
| 1200 MHz | 1300 / 1300 / 1350 mV |
| 1248 MHz | 1350 / 1350 / 1350 mV |
| 1296 MHz | 1350 / 1350 / 1350 mV |
| 1416, 1512 MHz | disabled |

Per-chip `-L0` values equal the defaults on this table. A separate `px30s-cpu0-opp-table` (850–1150 mV) is used on PX30S chips.

## Others

| who | where | CPU OPPs |
|---|---|---|
| mainline | `px30.dtsi` | 600, 816, 1008, 1200, 1296 MHz; `opp-suspend` on 600 |
| ROCKNIX (before) | `rk3326.dtsi` | 1008, 1296 MHz + 1416 turbo |
| ROCKNIX GKD Pixel2 | `rk3326s-gkd-pixel2.dts` | board-local copy of the vendor table (all nine steps), with a comment that the shared table is reduced |
| kk (AveyondFly) | `distribution_rocknix` `next`, `000-rk3326-dts.patch` | same deletions as ROCKNIX |
