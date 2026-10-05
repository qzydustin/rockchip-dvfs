#!/bin/sh
# Does a lower CPU floor cost performance under ondemand? For each floor: one sustained run
# (md5sum of 64 MB in RAM) and 20 short bursts with idle gaps (the governor drops back between them).
P=/sys/devices/system/cpu/cpufreq/policy0
dd if=/dev/urandom of=/tmp/burst.bin bs=1M count=8 2>/dev/null
dd if=/dev/urandom of=/tmp/long.bin bs=1M count=64 2>/dev/null
echo ondemand > $P/scaling_governor
for floor in 1008000 600000; do
  echo $floor > $P/scaling_min_freq; sleep 2
  echo "=== floor $floor"
  s=$(date +%s%N); md5sum /tmp/long.bin >/dev/null; e=$(date +%s%N); echo "sustained $(( (e-s)/1000000 )) ms"
  t=0; for i in $(seq 1 20); do
    sleep 1; s=$(date +%s%N); md5sum /tmp/burst.bin >/dev/null; e=$(date +%s%N); t=$(( t + (e-s)/1000 ))
  done
  echo "burst avg $(( t / 20 )) us"
done
echo $(cat $P/cpuinfo_min_freq) > $P/scaling_min_freq; rm -f /tmp/burst.bin /tmp/long.bin
