#!/bin/sh
# GPU and DDR raise and lower the shared vdd_logic independently. Needs the dmc.
G=/sys/class/devfreq/ff400000.gpu; D=/sys/class/devfreq/dmc
vl() { for r in /sys/class/regulator/*; do [ "$(cat $r/name)" = vdd_logic ] && cat $r/microvolts; done; }
top() { tr ' ' '\n' < $1/available_frequencies | sort -n | tail -1; }
low() { tr ' ' '\n' < $1/available_frequencies | sort -n | head -1; }
st() { echo "$1: gpu=$(cat $G/cur_freq) ddr=$(cat $D/cur_freq) vdd_logic=$(vl)"; }
echo userspace > $G/governor; echo userspace > $D/governor
low $G > $G/userspace/set_freq; low $D > $D/userspace/set_freq; st start
top $D > $D/userspace/set_freq; st "DDR up"
top $G > $G/userspace/set_freq; st "GPU up"
low $D > $D/userspace/set_freq; st "DDR down"
low $G > $G/userspace/set_freq; st "GPU down"
echo simple_ondemand > $G/governor; echo simple_ondemand > $D/governor
