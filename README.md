# rockchip-dvfs

Design notes and tools for frequency scaling on Rockchip SoCs running the upstream Linux kernel.

## RK3326 / PX30 — DDR frequency scaling

On the upstream kernel the DDR runs at a fixed 333 MHz. This driver lets it scale from 194 MHz at idle to 666 MHz under load, which doubles memory bandwidth, cuts latency by a third and raises the glmark2 score by 38 %. The frequency change itself is done by Rockchip's firmware, which is already on the device; the driver only asks for it. Driver: [ROCKNIX/distribution #3437](https://github.com/ROCKNIX/distribution/pull/3437).

- [design.md](rk3326/dmc/design.md) — how the driver works and why each decision was made
- [firmware-interface.md](rk3326/dmc/firmware-interface.md) — the BL31 SIP interface
- [vendor-kernel.md](rk3326/dmc/vendor-kernel.md) — how the vendor kernel does it, other ports
- [validation.md](rk3326/dmc/validation.md) — performance, stability, display
- [tools/](rk3326/dmc/tools/) — probe module, test scripts, overlays

Rockchip's firmware (rkbin) is a binary and is not disassembled here; the interface comes from Rockchip's GPL kernel sources, and what those don't say was established on hardware.

## License

GPL-2.0-only, see [LICENSE](LICENSE).
