# BL31 DDR frequency interface (PX30)

Firmware: rkbin `rk3326_bl31` v1.34 and v1.37, both report interface version 0x106. **Source** = vendor kernel (see [vendor-kernel.md](vendor-kernel.md)); **observed** = measured on the test board.

## Calls

SMCCC fast calls, SiP range. Function id in `x0`, arguments in `x1..x3`, results in `x0` (status), `x1`, `x2`.

| id | vendor name | x1 | x2 | x3 | result |
|---|---|---|---|---|---|
| `0x82000009` | `SIP_SHARE_MEM` | page count | page type (`2` = DDR) | – | `x1` = physical address |
| `0x82000008` | `SIP_DRAM_CONFIG` | page type `2` (`0` for `GET_VERSION`) | `0` | command | command specific |

Status: `0` ok, `-1` unknown, `-2` not supported, `-3` invalid params, `-4` invalid address, `-5` denied (**source**). `SET_RATE` normally returns `x1 = -6` (`SIP_RET_SET_RATE_TIMEOUT`): not an error, the switch is scheduled and finishes later. Occasionally it switches synchronously and returns the new rate in `x1` instead (observed: 6 of 317 switches); then no interrupt follows.

| x3 | command | use on PX30 |
|---|---|---|
| `0x00` | `DRAM_INIT` | once, after the pages are filled |
| `0x01` | `SET_RATE` | switch to `hz` |
| `0x02` | `ROUND_RATE` | round `hz`; **required before every `SET_RATE`** (observed) |
| `0x03` | `SET_AT_SR` | auto self-refresh, vendor suspend path |
| `0x05` | `GET_RATE` | `x1` = current rate in Hz |
| `0x08` | `GET_VERSION` | `x1` = interface version (vendor requires ≥ 0x103) |
| `0x04`, `0x06`, `0x07`, `0x09`–`0x12` | | not used on PX30 |

Mainline's `rockchip_sip.h` names `0x08` `SET_ODT_PD`; on this firmware it is `GET_VERSION`.

## Shared pages

`SIP_SHARE_MEM(2, 2)` returned `0x00100000` (observed): firmware-owned memory below the kernel's RAM (`0x00200000`), so map it with `ioremap()`. Zero both pages; the firmware does not.

Page 0:

| offset | field | meaning |
|---|---|---|
| `0x00` | `hz` | input to `ROUND_RATE` and `SET_RATE` |
| `0x04` | `lcdc_type` | display to synchronise with; `0` none, `7` MIPI (full list in `rk_fb.h`: 1 RGB, 2 LVDS, 3 dual LVDS, 4 MCU, 5 TV, 6 HDMI, 8 dual MIPI, 9 eDP, 13 DP) |
| `0x08` | `vop` | VOP index, 0 |
| `0x0c` | `vop_dclk_mode` | 0 |
| `0x10` | `sr_idle_en` | 0 |
| `0x14` | `addr_mcu_el3` | RK3399 only |
| `0x18` | `wait_flag1` | wait for VOP line flag 1 |
| `0x1c` | `wait_flag0` | wait for VOP line flag 0 |
| `0x20` | `complt_hwirq` | GIC hwirq to pend when an asynchronous switch finishes |
| `0x24` | `update_drv_odt_cfg` | 0 |
| `0x28` | `update_deskew_cfg` | 0 |
| `0x2c`–`0x48` | `freq_count`, `freq_info_mhz[6]`, `wait_mode` | newer SoCs |
| `0x4c` | `vop_scan_line_time_ns` | line time of the scanning display |

After `DRAM_INIT` the firmware wrote nothing back into page 0 (observed).

Page 1: `struct px30_ddr_dts_config_timing` (`rockchip_dmc_timing.h`): 61 `u32` parameters, `ca_skew[15]`, `cs0_skew[44]`, `cs1_skew[44]`, `available`. With `available = 0` the firmware keeps the loader's settings; that is what we use (observed to work at every OPP).

## Sequence that works

```
SIP_SHARE_MEM(2, DDR)                → base; zero both pages
params->complt_hwirq = hwirq
DRAM_INIT
GET_RATE                             → 332000000

per switch:
  params->hz = target
  ROUND_RATE                         → x1 = rate (exact for 194/328/450/528/666 MHz)
  params->hz = x1
  (lcdc_type, wait flags, line time left at 0: no display synchronisation)
  SET_RATE                           → x0 = 0, x1 = -6
  wait for the completion interrupt   (6–11 ms end to end)
  GET_RATE                           → x1 == target
```

## What happens without `ROUND_RATE` (observed)

`SET_RATE` returns `-6` as usual, and within ~300 ms the SoC is gone: no further kernel log, USB gadget dead, the panel frozen with a stuck column; only a power cycle recovers. With the timing block filled (`available = 1`) it dies before `SET_RATE` returns. Identical on v1.34 and v1.37, with one or four CPUs online, with or without display sync. See [design.md](design.md#round_rate-before-every-set_rate).

Interpretation: `ROUND_RATE` is where the firmware computes the controller/PHY settings for the target rate; `SET_RATE` applies whatever it last computed (for a different rate, or nothing). Consistent with the data, not proven from the binary.

## Completion

The switch finishes in EL3 and the firmware pends `complt_hwirq` by software. On PX30 that is GIC SPI 105 (hwirq 137), declared level-high. Keep the interrupt enabled permanently; enabling it only around a switch loses completions (see [design.md](design.md#completion-interrupt-always-enabled)). The vendor driver also requests it without `IRQF_NO_AUTOEN`.

## Related open implementation

Upstream TF-A implements this SIP interface for RK3399: `plat/rockchip/rk3399/plat_sip_calls.c`, `drivers/dram/dfs.c` (`ddr_round_rate`, `ddr_set_rate`).
