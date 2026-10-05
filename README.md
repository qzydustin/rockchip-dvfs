# rockchip-dvfs

Design notes and tools for frequency scaling on Rockchip SoCs running the upstream Linux kernel.

## RK3326 / PX30 — DDR frequency scaling

On the upstream kernel the DDR runs at a fixed 333 MHz. This driver lets it scale from 194 MHz at idle to 666 MHz under load, which doubles memory bandwidth, cuts latency by a third and raises the glmark2 score by 38 %. The frequency change itself is done by Rockchip's firmware, which is already on the device; the driver only asks for it. Driver: [ROCKNIX/distribution #3437](https://github.com/ROCKNIX/distribution/pull/3437).

- [design.md](rk3326/dmc/design.md) — how the driver works and why each decision was made
- [firmware-interface.md](rk3326/dmc/firmware-interface.md) — the BL31 SIP interface
- [vendor-kernel.md](rk3326/dmc/vendor-kernel.md) — how the vendor kernel does it, other ports
- [validation.md](rk3326/dmc/validation.md) — performance, stability, display
- [tools/](rk3326/dmc/tools/) — probe module, test scripts, overlays

## RK3326 / PX30 — GPU frequency scaling

ROCKNIX runs the GPU at a fixed 480 MHz and 1.15 V while reporting 560 MHz. With these changes it scales 200–480 MHz as on the vendor kernel, plus 520 MHz on boards whose supply allows it (+6 % in glmark2), and idles at 200 MHz / 0.95 V. The GPU clock is modelled as the vendor's single mux-and-divider clock, which also stops a brief overclock when the clock source changes. Changes: [ROCKNIX/distribution #3438](https://github.com/ROCKNIX/distribution/pull/3438).

- [design.md](rk3326/gpu/design.md) — clock tree, OPPs, the shared `vdd_logic`
- [vendor-kernel.md](rk3326/gpu/vendor-kernel.md) — vendor kernel and other ports
- [validation.md](rk3326/gpu/validation.md) — OPPs, performance, stress, USB
- [tools/](rk3326/gpu/tools/) — test scripts, 520 MHz overlay

## RK3326 / PX30 — CPU frequency scaling

ROCKNIX deletes three of mainline's five CPU OPPs, so the CPU never goes below 1008 MHz and suspend has no low OPP. Restoring them lets the CPU idle at 600–816 MHz with no measurable cost in performance. Changes: [ROCKNIX/distribution #3439](https://github.com/ROCKNIX/distribution/pull/3439).

- [design.md](rk3326/cpu/design.md) — what was deleted, what is restored
- [vendor-kernel.md](rk3326/cpu/vendor-kernel.md) — vendor table and other ports
- [validation.md](rk3326/cpu/validation.md) — OPPs, stress, performance, idle, suspend
- [tools/](rk3326/cpu/tools/) — test scripts

Rockchip's firmware (rkbin) is a binary and is not disassembled here; the interface comes from Rockchip's GPL kernel sources, and what those don't say was established on hardware.

## License

GPL-2.0-only, see [LICENSE](LICENSE).
