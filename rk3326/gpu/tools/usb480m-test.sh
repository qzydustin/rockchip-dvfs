#!/bin/sh
# GPU pinned at 480 MHz (usb480m) under glmark2 load for 120 s, state logged every second to
# /storage/usb480m.log so it survives the USB link going away. Unplug and replug the cable meanwhile.
# Run detached: setsid sh usb480m-test.sh </dev/null >/dev/null 2>&1 &
C=/sys/kernel/debug/clk; G=/sys/class/devfreq/ff400000.gpu; L=/storage/usb480m.log
export XDG_RUNTIME_DIR=/var/run/0-runtime-dir WAYLAND_DISPLAY=wayland-1
systemctl stop powerstate.service   # it resets the GPU governor on charger unplug
echo userspace > $G/governor; echo 480000000 > $G/userspace/set_freq
: > $L
( while :; do glmark2-es2-wayland --off-screen -b build:duration=2 -b texture:duration=2 >/dev/null 2>&1 || echo "$(date +%T) glmark exit=$?" >> $L; done ) & GL=$!
for i in $(seq 1 120); do
  echo "$(date +%T) clk_gpu=$(cat $C/clk_gpu/clk_rate) src=$(cat $C/clk_gpu_src/clk_parent) usb480m_en=$(cat $C/usb480m/clk_enable_count)" >> $L
  sleep 1
done
kill $GL; pkill -x glmark2-es2-wayland
echo simple_ondemand > $G/governor; systemctl start powerstate.service
echo "$(date +%T) DONE" >> $L
