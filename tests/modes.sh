#!/usr/bin/env bash
# Difficulty check per mode. For every stage:
#   N  = normal mode, research a normal-only player can afford      → should win
#   HF = hard mode, (almost) every research of the chapter            → should win, tight
#   HN = hard mode, only the normal-affordable research               → should mostly lose
# Usage: STAGES="1-1 1-2" bash tests/modes.sh [JOBS]
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/jihye/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
JOBS="${1:-12}"
N1="zeno,sqrt,log2,mult,sub_range,start_rho"
F1="$N1,accel,spring,drill,div3"
N2="$N1,divx,psqrt,diff,int,d2,divx_fast"
F2="$F1,divx,psqrt,diff,int,int2,d2,d3,divx_fast,diff_range"
N3="$N2,ln,merge,log_fast"
F3="$F2,ln,merge,log_fast,merge_range"
N4="$N3,think_cheap,diff_fast"
F4="$F3,think_cheap,diff_fast,merge_fast"
N5="$N4,dtl,wave,dtl_fast"
F5="$F4,dtl,dtl2,wave,dtl_fast,wave_fast"
N6="$N5,damp,damp_range,core_up"
F6="$F5,damp,damp2,damp_range,core_up"
STAGES="${STAGES:-1-1 1-2 1-3 1-4 1-5 1-6 2-1 2-2 2-3 2-4 2-5 2-6 3-1 3-2 3-3 3-4 3-5 3-6 4-1 4-2 4-3 4-4 4-5 4-6 5-1 5-2 5-3 5-4 5-5 5-6 6-1 6-2 6-3 6-4 6-5 6-6}"
CASES=()
for st in $STAGES; do
  ch="${st%%-*}"
  eval "n=\$N$ch"; eval "f=\$F$ch"
  CASES+=("$st N $n" "$st HF $f" "$st HN $n")
done
run_case() {
  local st="$1" mode="$2" rs="$3"
  local hard=""
  [ "$mode" != "N" ] && hard="--hard"
  local out
  out=$(timeout 900 "$GODOT" --headless --fixed-fps 60 --path . res://scenes/main.tscn -- \
        --autotest --stage="$st" --tag="$RUN_TAG" --budget --research="$rs" --ts=1 $hard 2>&1)
  local line
  line=$(echo "$out" | grep "\[autotest\] done" | grep -o 'won=[a-z]* wave=[0-9]* integrity=[0-9]*')
  printf "%-5s %-3s %s\n" "$st" "$mode" "${line:-NO RESULT}"
}
export -f run_case
export GODOT
# Stopping the script (Ctrl+C, closed shell, killed task) must also stop every Godot it started:
# the run is a child process group; on exit its whole Windows process tree is killed.
export RUN_TAG="lbt$$x$RANDOM"   # every Godot this run starts carries --tag=$RUN_TAG
cleanup() {
  [ -n "$RUN_PID" ] && kill -- -"$RUN_PID" 2>/dev/null
  # the loop (xargs, run_case shells) and every Godot carry the tag; two passes catch anything spawned in between
  for pass in 1 2; do
    powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -match '$RUN_TAG' -and \$_.CommandLine -notmatch 'Get-CimInstance' } | ForEach-Object { try { Stop-Process -Id \$_.ProcessId -Force -ErrorAction Stop } catch {} }" > /dev/null 2>&1
  done
}
trap cleanup INT TERM HUP EXIT
start=$(date +%s)
set -m
(
for c in "${CASES[@]}"; do echo "$c"; done | xargs -P "$JOBS" -L 1 bash -c "run_case \"\$0\" \"\$1\" \"\$2\"  # $RUN_TAG" | sort -t- -k1,1n -k2,2n
) &
RUN_PID=$!
wait "$RUN_PID"
RUN_PID=""
echo "총 소요: $(( $(date +%s) - start ))초"
