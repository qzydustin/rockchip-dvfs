#!/bin/sh
# CPU transitions with boost (the 1416 MHz turbo OPP) on, low OPPs present.
# Run detached: setsid sh boost.sh </dev/null >/dev/null 2>&1 &  Log: /storage/cpu-boost.log
P=/sys/devices/system/cpu/cpufreq/policy0; B=/sys/devices/system/cpu/cpufreq/boost
A=/sys/class/rtc/rtc0/wakealarm; L=/storage/cpu-boost.log
log() { echo "$(date +%T) $*" >> $L; sync; }
load_on() { rm -f /tmp/stopload; i=0; while [ $i -lt $1 ]; do (while [ ! -f /tmp/stopload ]; do :; done) & i=$((i+1)); done; }
load_off() { touch /tmp/stopload; sleep 0.3; }
errs() { dmesg | grep -ciE "cpufreq.*(fail|error)|cpu cpu0: failed|Oops|Unable to handle|BUG:|rcu.*stall|Internal error"; }
rnd() { echo $(( $(od -An -N2 -tu2 /dev/urandom) % $1 )); }
random_opps() { # $1 seconds; performance governor + scaling_max_freq, every 0.05 s
  set -- $1 $(cat $P/scaling_available_frequencies) $(cat $P/scaling_boost_frequencies); s=$1; shift
  end=$(( $(date +%s) + s )); n=0; top=0; echo performance > $P/scaling_governor
  while [ $(date +%s) -lt $end ]; do
    i=$(( $(rnd $#) + 1 )); eval f=\$$i; echo $f > $P/scaling_max_freq; n=$((n+1))
    [ $f = 1416000 ] && top=$((top+1)); sleep 0.05
  done
  echo ondemand > $P/scaling_governor; echo $(cat $P/cpuinfo_max_freq) > $P/scaling_max_freq
  echo "changes=$n to1416=$top"
}
: > $L; dmesg -c >/dev/null; echo ondemand > $P/scaling_governor; echo 0 > $B
log "start freqs=$(cat $P/scaling_available_frequencies) boost=$(cat $P/scaling_boost_frequencies)"

# 1: idle under ondemand, then boost on and all cores loaded at once
reached=0
for c in $(seq 1 100); do
  echo 0 > $B; load_off; sleep 1.5
  echo 1 > $B; load_on 4; sleep 1; [ $(cat $P/scaling_cur_freq) = 1416000 ] && reached=$((reached+1))
done
load_off; log "1: 1416 reached in $reached/100, errors=$(errs)"

# 2: from 600 MHz straight to 1416 MHz under ondemand
lows=0; reached=0
for c in $(seq 1 200); do
  load_off; echo 0 > $B; echo 600000 > $P/scaling_max_freq; sleep 1; [ $(cat $P/scaling_cur_freq) = 600000 ] && lows=$((lows+1))
  echo 1 > $B; load_on 4; echo 1416000 > $P/scaling_max_freq; sleep 0.5; [ $(cat $P/scaling_cur_freq) = 1416000 ] && reached=$((reached+1))
done
load_off; log "2: at 600 before $lows/200, 1416 after $reached/200, errors=$(errs)"

# 3: random OPPs including 1416, three cores busy, memtester
echo 1 > $B; load_on 3; memtester 64M 1 > /tmp/boost-mt.log 2>&1 & MT=$!
r=$(random_opps 180); wait $MT; load_off
log "3: $r memtester_failures=$(grep -c FAILURE /tmp/boost-mt.log) errors=$(errs)"

# 4: ondemand with bursty load, memtester
t0=$(cat $P/stats/total_trans); memtester 64M 1 > /tmp/boost-mt.log 2>&1 & MT=$!; end=$(( $(date +%s) + 180 ))
while [ $(date +%s) -lt $end ]; do load_on 3; sleep 0.$(( $(rnd 6) + 1 )); load_off; sleep 0.$(( $(rnd 6) + 1 )); done
wait $MT; log "4: transitions $(( $(cat $P/stats/total_trans) - t0 )) memtester_failures=$(grep -c FAILURE /tmp/boost-mt.log) errors=$(errs)"

# 5: suspend/resume, then random OPPs including 1416 with memtester
for c in $(seq 1 10); do
  echo 0 > $A; echo +15 > $A; systemctl suspend; sleep 5
  while [ "$(cat $A)" ]; do sleep 1; done
  echo 1 > $B; load_on 3; memtester 32M 1 > /tmp/boost-mt.log 2>&1 & MT=$!
  r=$(random_opps 30); wait $MT; load_off
  log "5.$c: $r memtester_failures=$(grep -c FAILURE /tmp/boost-mt.log) errors=$(errs)"
done
echo 0 > $B; echo ondemand > $P/scaling_governor; echo 1296000 > $P/scaling_max_freq
log "DONE"
