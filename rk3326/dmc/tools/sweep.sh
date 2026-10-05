#!/bin/sh
# Every OPP up and down, read back from the firmware.
D=/sys/class/devfreq/dmc
echo userspace > $D/governor
freqs=$(cat $D/available_frequencies)
rev=$(echo $freqs | tr ' ' '\n' | sort -rn | tr '\n' ' ')
for f in $freqs $rev; do
  echo $f > $D/userspace/set_freq; sleep 0.3
  echo "req=$f cur=$(cat $D/cur_freq)"
done
echo "timeouts=$(dmesg | grep -c 'timed out switching')"
tail -1 $D/trans_stat
