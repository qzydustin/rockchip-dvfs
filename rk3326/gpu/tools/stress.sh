#!/bin/sh
# glmark2 looping: a random GPU OPP every 0.3 s for 3 min, then GPU and DDR on simple_ondemand for 2 min.
G=/sys/class/devfreq/ff400000.gpu; D=/sys/class/devfreq/dmc
export XDG_RUNTIME_DIR=/var/run/0-runtime-dir WAYLAND_DISPLAY=wayland-1
errs() { dmesg | grep -ciE 'Failed to set clock|Failed to (in|de)crease voltage|timed out switching'; }
( while :; do glmark2-es2-wayland --off-screen -b build:duration=2 -b texture:duration=2 -b shading:duration=2 >/dev/null 2>&1; done ) & GL=$!
echo userspace > $G/governor
set -- $(cat $G/available_frequencies); n=0; end=$(( $(date +%s) + 180 ))
while [ $(date +%s) -lt $end ]; do
  i=$(( $(od -An -N1 -tu1 /dev/urandom) % $# + 1 )); eval f=\$$i
  echo $f > $G/userspace/set_freq; n=$((n+1)); sleep 0.3
done
echo "random changes=$n errors=$(errs)"
echo simple_ondemand > $G/governor; [ -d $D ] && echo simple_ondemand > $D/governor; sleep 120
echo "ondemand errors=$(errs)"; tail -1 $G/trans_stat; [ -d $D ] && tail -1 $D/trans_stat
kill $GL; pkill -x glmark2-es2-wayland
