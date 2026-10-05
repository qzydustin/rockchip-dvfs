# Design

One devfreq driver, `drivers/devfreq/px30_dmc.c` (~340 lines), plus the `dfi`, `dmc` and OPP nodes in the dts and a one-line PX30 entry in `rockchip-dfi`. The driver asks Rockchip's BL31 firmware to change the DDR frequency; the firmware does the actual work ([firmware-interface.md](firmware-interface.md)).

## Flow

```
probe   GET_VERSION ≥ 0x103 → SHARE_MEM (2 pages, zeroed) → complt_hwirq → DRAM_INIT → GET_RATE
switch  raise vdd_logic if going up
        rockchip_pmu_block()
        hz = target; ROUND_RATE → hz = rounded
        SET_RATE → −6: wait for the completion interrupt (≤ 85 ms, CPU latency QoS 0)
        GET_RATE must equal the target
        rockchip_pmu_unblock()
        lower vdd_logic if going down; restore it if the switch failed
```

## Decisions

### `ROUND_RATE` before every `SET_RATE`

Without it the SoC dies within ~300 ms of `SET_RATE` returning: DDR unusable, USB gone, the panel frozen with a stuck column of pixels (which looks like a display bug and isn't). Same on BL31 v1.34 and v1.37, with one or four CPUs online, with or without display synchronisation, whether or not the kernel waits or calls `GET_RATE` afterwards.

```
without:  SET_RATE 332000000 -> 450000000
          SET_RATE smc a0=0 a1=fffffffa
          (nothing more)

with:     ROUND_RATE 450000000: a0=0 a1=1ad27480
          SET_RATE smc a0=0 a1=fffffffa
          completion irq
          GET_RATE a0=0 rate=450000000
```

Most likely `ROUND_RATE` is where the firmware prepares the settings for the new frequency, and `SET_RATE` only applies them. The vendor kernel never hits this because it goes through `clk_set_rate()`, which always rounds first.

### Completion interrupt always enabled

When the firmware finishes a switch it raises GIC SPI 105. If the driver enables that interrupt only around each switch, some completions get lost, because Linux does not replay a level interrupt that arrived while it was disabled. So the interrupt is requested once and stays enabled, as in the vendor driver; no completion has been lost since.

`SET_RATE` usually returns −6, meaning "switch pending, wait for the interrupt". Occasionally it finishes the switch inside the call and returns the new rate instead (6 of 317 switches), and no interrupt follows. The driver therefore waits only when it gets −6.

### No display synchronisation

The firmware can wait until the display is between frames before switching, so the screen never reads memory mid-switch. Using that on the upstream kernel needs a patch to the display driver (VOP). We wrote it and then removed it: without it, switching every 0.65 s while scrolling the menu or running glmark2 full screen shows no glitches, performance is unchanged, and a switch takes 6–11 ms instead of 15–26. The 640×480 panel reads only ~74 MB/s, so the display's buffer easily covers the short pause. Bigger panels or HDMI have not been tried.

### DDR timing page left empty

The vendor kernel fills the second shared page with drive strength, ODT and de-skew values from a `ddr_timing` DT node. Left zeroed (`available = 0`), BL31 keeps what the loader trained; every OPP works. No board-specific data in the kernel.

### `vdd_logic` is shared with the GPU

Only a minimum voltage is requested (`regulator_set_voltage(vdd, volt, INT_MAX)`), raised before going up and lowered after going down.

### Load and governor

Load comes from the DFI counters (`rockchip-dfi`; PX30's PMUGRF layout matches RK3568, so the existing `rk3568_dfi_init` is reused). `simple_ondemand`, up threshold 40 %, down differential 20 %, 50 ms polling — the vendor's values. The menu sits at 194 MHz, load goes to 666 MHz.

### OPPs: 194 / 328 / 450 / 528 / 666 MHz

Voltages from the vendor dts (950 mV up to 450, 975 mV at 528, 1050 mV at 666). The vendor table also has 786 MHz at 1.10 V; that is in spec for LPDDR3-1600 and DDR3-1600 but not DDR3-1333, which some of these boards carry, so 666 is the top until more boards are tested. An overlay adding 786 is in [tools/overlays/](tools/overlays/).

### Firmware

The images tested boot rkbin `rk3326_ddr_333MHz_v2.11` (DDR init, fixed at 333 MHz), `miniloader_v1.40` and `bl31_v1.34` (DRAM interface 0x106). v1.34 is enough; v1.37 (`stop CPUs when pd_vo is powered down`) behaved identically.
