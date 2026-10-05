#!/bin/sh
# glmark2-es2 off-screen at pinned GPU rates: bench.sh 480000000 520000000
# DDR pinned at its top OPP if the dmc exists. Run with EmulationStation stopped and sway running.
G=/sys/class/devfreq/ff400000.gpu; D=/sys/class/devfreq/dmc
mkdir -p /storage/bench
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do echo performance > $c; done
[ -d $D ] && { echo userspace > $D/governor; tr ' ' '\n' < $D/available_frequencies | sort -n | tail -1 > $D/userspace/set_freq; }
echo userspace > $G/governor
export XDG_RUNTIME_DIR=/var/run/0-runtime-dir WAYLAND_DISPLAY=wayland-1
for F in "$@"; do
  echo $F > $G/userspace/set_freq; sleep 1
  echo "=== GPU $(cat /sys/kernel/debug/clk/clk_gpu/clk_rate) DDR $(cat $D/cur_freq 2>/dev/null) ==="
  glmark2-es2-wayland --off-screen > /storage/bench/glmark-gpu$F.txt 2>&1
  grep -E 'Score' /storage/bench/glmark-gpu$F.txt | tr -s ' '
done
echo simple_ondemand > $G/governor; [ -d $D ] && echo simple_ondemand > $D/governor
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do echo ondemand > $c; done
