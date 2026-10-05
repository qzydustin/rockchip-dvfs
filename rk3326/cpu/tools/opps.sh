#!/bin/sh
# CPU OPPs as cpufreq sees them, the governor, time in each state and vdd_arm.
P=/sys/devices/system/cpu/cpufreq/policy0
echo "gov=$(cat $P/scaling_governor) cur=$(cat $P/cpuinfo_cur_freq) min=$(cat $P/scaling_min_freq) max=$(cat $P/scaling_max_freq)"
echo "available: $(cat $P/scaling_available_frequencies) boost=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null)"
cat $P/stats/time_in_state
for r in /sys/class/regulator/*; do [ "$(cat $r/name)" = vdd_arm ] && echo "vdd_arm $(cat $r/microvolts) uV, limits $(cat $r/min_microvolts)-$(cat $r/max_microvolts)"; done
