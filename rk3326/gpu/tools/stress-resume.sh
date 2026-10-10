#!/bin/sh
# GPU frequency transitions on the EE clone (#3438): fast random OPPs, ondemand, and suspend/resume, glmark2 running.
# Run detached: setsid sh stress-resume.sh </dev/null >/dev/null 2>&1 &
G=/sys/class/devfreq/ff400000.gpu; D=/sys/class/devfreq/dmc; A=/sys/class/rtc/rtc0/wakealarm; L=/storage/gpu-stress.log
export XDG_RUNTIME_DIR=/var/run/0-runtime-dir WAYLAND_DISPLAY=$(ls /var/run/0-runtime-dir | grep -m1 "^wayland-[0-9]$")
log() { echo "$(date +%T) $*" >> $L; sync; }
errs() { dmesg | grep -ciE "Failed to set clock|Failed to (in|de)crease voltage|timed out switching|GPU fault|job fault|Oops|BUG:|Unable to handle|Internal error|rcu.*stall"; }
gl_on() { rm -f /tmp/stopgl; ( while [ ! -f /tmp/stopgl ]; do glmark2-es2-wayland --off-screen -b build:duration=2 -b texture:duration=2 -b shading:duration=2 -b terrain:duration=2 >/dev/null 2>&1; done ) & }
gl_off() { touch /tmp/stopgl; while pidof glmark2-es2-wayland >/dev/null; do sleep 1; done; }
rnd() { echo $(( $(od -An -N2 -tu2 /dev/urandom) % $1 )); }
random_gpu() { # seconds
  set -- $(cat $G/available_frequencies); end=$(( $(date +%s) + $RS )); n=0
  echo userspace > $G/governor
  while [ $(date +%s) -lt $end ]; do i=$(( $(rnd $#) + 1 )); eval f=\$$i; echo $f > $G/userspace/set_freq; n=$((n+1)); sleep 0.05; done
  echo simple_ondemand > $G/governor; echo "changes=$n"
}
: > $L; dmesg -c >/dev/null
log "start gpu=$(cat $G/available_frequencies) gov=$(cat $G/governor) dmc=$(cat $D/governor) temp=$(cat /sys/class/thermal/thermal_zone0/temp)"

# G1: glmark2 looping, a random GPU OPP every 0.05 s for 5 min, DDR and CPU on their governors, memtester
gl_on; memtester 64M 1 > /tmp/gpu-mt1.log 2>&1 & MT=$!
RS=300; r=$(random_gpu); wait $MT
log "G1 done: $r memtester_failures=$(grep -c FAILURE /tmp/gpu-mt1.log) errors=$(errs) gpu_trans=$(tail -1 $G/trans_stat) dmc_trans=$(tail -1 $D/trans_stat)"

# G2: GPU and DDR on simple_ondemand, glmark2 started and stopped at random for 5 min
gl_off; g0=$(tail -1 $G/trans_stat | grep -o "[0-9]*$"); end=$(( $(date +%s) + 300 ))
while [ $(date +%s) -lt $end ]; do gl_on; sleep $(( $(rnd 6) + 2 )); gl_off; sleep $(( $(rnd 3) + 1 )); done
log "G2 done: gpu transitions $(( $(tail -1 $G/trans_stat | grep -o "[0-9]*$") - g0 )) errors=$(errs)"

# G3: 10 suspend/resume cycles with glmark2 running into suspend, then 30 s of random GPU OPPs with memtester
for c in $(seq 1 10); do
  gl_on; sleep 3; echo 0 > $A; echo +15 > $A; log "G3 $c suspend"
  systemctl suspend; sleep 5
  while [ "$(cat $A)" ]; do sleep 1; done
  log "G3 $c resumed gpu_gov=$(cat $G/governor) dmc_gov=$(cat $D/governor) cur=$(cat $G/cur_freq)"
  memtester 32M 1 > /tmp/gpu-mt3.log 2>&1 & MT=$!
  RS=30; r=$(random_gpu); wait $MT; gl_off
  log "G3 $c $r memtester_failures=$(grep -c FAILURE /tmp/gpu-mt3.log) errors=$(errs)"
done
echo simple_ondemand > $G/governor
log "DONE gpu_gov=$(cat $G/governor) dmc_gov=$(cat $D/governor) temp=$(cat /sys/class/thermal/thermal_zone0/temp)"
log "gpu time_in_state: $(tail -n +3 $G/trans_stat | awk '{print $1, $NF}' | tr '\n' ' ')"
