#!/bin/sh
# What the GPU really runs at: devfreq's view, the clock tree, the PLLs, vdd_logic.
C=/sys/kernel/debug/clk; G=/sys/class/devfreq/ff400000.gpu
echo "devfreq gov=$(cat $G/governor) cur=$(cat $G/cur_freq) avail=$(cat $G/available_frequencies)"
for c in clk_gpu clk_gpu_div clk_gpu_np5 clk_gpu_src aclk_gpu gpll cpll npll usb480m; do
  [ -d $C/$c ] && echo "$c rate=$(cat $C/$c/clk_rate) parent=$(cat $C/$c/clk_parent 2>/dev/null)"
done
kids=$(for d in $C/*/; do [ "$(cat $d/clk_parent 2>/dev/null)" = npll ] && basename $d; done | tr '\n' ' ')
echo "npll children: ${kids:-none}"
for r in /sys/class/regulator/*; do [ "$(cat $r/name)" = vdd_logic ] && echo "vdd_logic $(cat $r/microvolts) uV, limits $(cat $r/min_microvolts)-$(cat $r/max_microvolts)"; done
