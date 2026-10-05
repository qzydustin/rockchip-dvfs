#!/bin/sh
# All four cores busy (md5sum of /dev/zero): a random CPU OPP every 0.1 s for 3 min,
# then CPU, GPU and DDR on their default governors under the same load for 2 min.
P=/sys/devices/system/cpu/cpufreq/policy0
for i in 1 2 3 4; do md5sum /dev/zero & done
gov=$(cat $P/scaling_governor); echo performance > $P/scaling_governor   # pin with max
hi=$(cat $P/cpuinfo_max_freq)
set -- $(cat $P/scaling_available_frequencies); n=0; end=$(( $(date +%s) + 180 ))
while [ $(date +%s) -lt $end ]; do
  i=$(( $(od -An -N1 -tu1 /dev/urandom) % $# + 1 )); eval f=\$$i
  echo $f > $P/scaling_max_freq; n=$((n+1)); sleep 0.1
done
echo "random changes=$n"
echo $hi > $P/scaling_max_freq; echo $gov > $P/scaling_governor; sleep 120
pkill md5sum
echo "cpu transitions=$(cat $P/stats/total_trans) errors=$(dmesg | grep -ciE 'cpufreq.*(fail|error)|cpu cpu0: failed')"
cat $P/stats/time_in_state
