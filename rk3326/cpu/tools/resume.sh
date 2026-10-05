#!/bin/sh
# Suspend/resume cycles with CPU frequency changes right after each wake-up: resume.sh [cycles]
# Each cycle: RTC alarm, systemctl suspend (ROCKNIX sleep hooks run), then 30 s of random CPU OPPs
# with all cores busy and memtester checking 64 MB. Logs to /storage/cpu-resume.log.
# Run detached: setsid sh resume.sh 10 </dev/null >/dev/null 2>&1 &
P=/sys/devices/system/cpu/cpufreq/policy0; A=/sys/class/rtc/rtc0/wakealarm; L=/storage/cpu-resume.log
: > $L
for c in $(seq 1 ${1:-10}); do
  echo 0 > $A; echo +15 > $A
  echo "$(cut -d' ' -f1 /proc/uptime) cycle $c suspend" >> $L; sync
  systemctl suspend; sleep 5          # returns before the system is down
  while [ "$(cat $A)" ]; do sleep 1; done   # alarm consumed: we are back
  echo "$(cut -d' ' -f1 /proc/uptime) cycle $c resumed gov=$(cat $P/scaling_governor) cpus=$(cat /sys/devices/system/cpu/online)" >> $L; sync
  for i in 1 2 3; do md5sum /dev/zero & done
  memtester 64M 1 > /tmp/mt.log 2>&1 & MT=$!
  echo performance > $P/scaling_governor
  set -- $(cat $P/scaling_available_frequencies); end=$(( $(date +%s) + 30 )); n=0
  while [ $(date +%s) -lt $end ]; do
    i=$(( $(od -An -N1 -tu1 /dev/urandom) % $# + 1 )); eval f=\$$i
    echo $f > $P/scaling_max_freq; n=$((n+1)); sleep 0.05
  done
  echo $(cat $P/cpuinfo_max_freq) > $P/scaling_max_freq; echo ondemand > $P/scaling_governor
  wait $MT; pkill md5sum
  echo "$(cut -d' ' -f1 /proc/uptime) cycle $c changes=$n memtester=$(grep -c FAILURE /tmp/mt.log) failures" >> $L; sync
done
echo DONE >> $L
