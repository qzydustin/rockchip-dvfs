#!/bin/sh
# Every GPU OPP up and down, with the clock parent and vdd_logic.
C=/sys/kernel/debug/clk; G=/sys/class/devfreq/ff400000.gpu; D=/sys/class/devfreq/dmc
vl() { for r in /sys/class/regulator/*; do [ "$(cat $r/name)" = vdd_logic ] && cat $r/microvolts; done; }
echo userspace > $G/governor
[ -d $D ] && { echo userspace > $D/governor; tr ' ' '\n' < $D/available_frequencies | sort -n | head -1 > $D/userspace/set_freq; }   # vdd_logic is shared
freqs=$(cat $G/available_frequencies | tr ' ' '\n' | sort -n | tr '\n' ' ')
rev=$(echo $freqs | tr ' ' '\n' | sort -rn | tr '\n' ' ')
for f in $freqs $rev; do
  echo $f > $G/userspace/set_freq; sleep 0.2
  echo "req=$f clk_gpu=$(cat $C/clk_gpu/clk_rate) src=$(cat $C/clk_gpu_src/clk_parent) vdd_logic=$(vl)"
done
echo simple_ondemand > $G/governor; [ -d $D ] && echo simple_ondemand > $D/governor
dmesg | grep -iE 'Failed to set clock|Failed to (in|de)crease voltage' | tail -3
