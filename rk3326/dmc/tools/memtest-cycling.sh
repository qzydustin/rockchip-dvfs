#!/bin/sh
# memtester while the DDR rate changes every 0.3 s, then under simple_ondemand.
# memtest-cycling.sh [size]: default 300M, "max" = free RAM minus 120 MB
D=/sys/class/devfreq/dmc
size=${1:-300M}
if [ "$size" = max ]; then
  sync; echo 3 > /proc/sys/vm/drop_caches
  size=$(( $(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo) - 120 ))M
fi
echo userspace > $D/governor; rm -f /tmp/stopcycle
( while [ ! -f /tmp/stopcycle ]; do for f in $(cat $D/available_frequencies); do echo $f > $D/userspace/set_freq 2>/dev/null; sleep 0.3; done; done ) &
before=$(tail -1 $D/trans_stat); s=$(date +%s)
echo "memtester $size with cycling"
memtester $size 1 2>&1 | tr -s ' ' | grep -E ': (ok|FAIL)|FAILURE' | sed -E 's/(setting [0-9]+|testing [0-9]+|[\\|\/-]{3,})//g'
touch /tmp/stopcycle; sleep 1
echo "took $(( $(date +%s) - s )) s; $before -> $(tail -1 $D/trans_stat); timeouts=$(dmesg | grep -c 'timed out switching')"
echo simple_ondemand > $D/governor
echo "memtester $size under simple_ondemand"
memtester $size 1 2>&1 | grep -c FAILURE | sed 's/^/failures=/'
tail -1 $D/trans_stat
