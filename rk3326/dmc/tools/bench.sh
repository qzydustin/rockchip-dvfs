#!/bin/sh
# tinymembench and glmark2-es2 at pinned DDR rates: bench.sh 328000000 666000000
# Run with EmulationStation stopped and sway running; needs /storage/tinymembench.
D=/sys/class/devfreq/dmc
mkdir -p /storage/bench
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do echo performance > $c; done
echo userspace > $D/governor
export XDG_RUNTIME_DIR=/var/run/0-runtime-dir WAYLAND_DISPLAY=wayland-1
for F in "$@"; do
  echo $F > $D/userspace/set_freq; sleep 1; echo "=== DMC $(cat $D/cur_freq) ==="
  [ -x /storage/tinymembench ] && { /storage/tinymembench > /storage/bench/tmb-$F.txt 2>&1; grep -E '^ (standard memcpy|standard memset|NEON LDP/STP copy  )' /storage/bench/tmb-$F.txt; }
  glmark2-es2-wayland --off-screen -b build:use-vbo=true -b texture:texture-filter=linear -b shading:shading=phong \
    -b bump:bump-render=normals -b effect2d:kernel=0,1,0\;1,-4,1\;0,1,0\; -b desktop:effect=blur -b terrain -b refract \
    > /storage/bench/glmark-$F.txt 2>&1
  grep -E 'FPS|Score' /storage/bench/glmark-$F.txt | tr -s ' '
done
echo simple_ondemand > $D/governor
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do echo ondemand > $c; done
