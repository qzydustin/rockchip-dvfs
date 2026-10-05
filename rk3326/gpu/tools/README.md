# Tools

| file | runs on | what |
|---|---|---|
| `clocks.sh` | device | what the GPU really runs at: devfreq, clock tree, PLLs, NPLL's children, `vdd_logic` and its limits |
| `sweep.sh` | device | every OPP up and down, with clock parent and `vdd_logic` |
| `bench.sh` | device | glmark2-es2 off-screen at pinned GPU rates, DDR at its top OPP |
| `stress.sh` | device | random OPP every 0.3 s under glmark2 for 3 min, then GPU + DDR `simple_ondemand` for 2 min |
| `rail.sh` | device | GPU and DDR raise and lower the shared `vdd_logic` independently |
| `usb480m-test.sh` | device | GPU at 480 MHz (usb480m) under load while the USB cable is unplugged; logs to `/storage` |
| `overlays/gpu-opp-520.dts` | device | NPLL 1040 MHz and the 520 MHz OPP, for boards whose `vdd_logic` allows 1175 mV |

All need debugfs (`/sys/kernel/debug/clk`); the glmark2 ones need sway running. Overlays: `dtc -@ -I dts -O dtb -o x.dtbo x.dts`, copy to `/flash/overlays/`, append to `FDTOVERLAYS` in `extlinux.conf`.
