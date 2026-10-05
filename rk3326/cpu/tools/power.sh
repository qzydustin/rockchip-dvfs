#!/bin/sh
# Battery draw at idle with the CPU floor at the old 1008 MHz and at 600 MHz, logged to /storage/cpu-power.log.
# Unplug USB within 60 s of starting; run detached: setsid sh power.sh </dev/null >/dev/null 2>&1 &
P=/sys/devices/system/cpu/cpufreq/policy0; B=/sys/class/power_supply/battery; L=/storage/cpu-power.log
systemctl stop powerstate.service   # it changes governors on charger unplug
echo ondemand > $P/scaling_governor
: > $L; sleep 60
for floor in 1008000 600000 1008000 600000; do
  echo $floor > $P/scaling_min_freq; sleep 10
  for i in $(seq 1 30); do
    echo "floor=$floor cur=$(cat $P/cpuinfo_cur_freq) online=$(cat /sys/class/power_supply/rk817-charger/online) I=$(cat $B/current_avg) V=$(cat $B/voltage_avg)" >> $L
    sleep 2
  done
done
echo $(cat $P/cpuinfo_min_freq) > $P/scaling_min_freq; systemctl start powerstate.service
echo DONE >> $L
