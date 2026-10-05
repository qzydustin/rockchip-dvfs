#!/bin/sh
# Every CPU OPP up and down, with armclk, the APLL and vdd_arm.
P=/sys/devices/system/cpu/cpufreq/policy0; C=/sys/kernel/debug/clk
va() { for r in /sys/class/regulator/*; do [ "$(cat $r/name)" = vdd_arm ] && cat $r/microvolts; done; }
gov=$(cat $P/scaling_governor); echo performance > $P/scaling_governor   # no userspace governor; pin with max
lo=$(cat $P/cpuinfo_min_freq); hi=$(cat $P/cpuinfo_max_freq)
freqs=$(cat $P/scaling_available_frequencies)
rev=$(echo $freqs | tr ' ' '\n' | sort -rn | tr '\n' ' ')
for f in $freqs $rev; do
  echo $f > $P/scaling_max_freq; sleep 0.2
  echo "req=$f cur=$(cat $P/cpuinfo_cur_freq) armclk=$(cat $C/armclk/clk_rate) apll=$(cat $C/apll/clk_rate) vdd_arm=$(va)"
done
echo $hi > $P/scaling_max_freq; echo $gov > $P/scaling_governor
