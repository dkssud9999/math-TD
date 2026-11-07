#!/usr/bin/env bash
# Difficulty check per mode. For every stage:
#   N  = normal mode, research a normal-only player can afford      → should win
#   HF = hard mode, research of a player who also clears hard        → should win, tight
#   HN = hard mode, research of a normal-only player                  → should mostly lose
# BOT_ARGS="--oldbot" bash tests/modes.sh  plays with the old rule-of-thumb bot
# Usage: STAGES="1-1 1-2" bash tests/modes.sh [JOBS]
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/jihye/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
JOBS="${1:-12}"
TS="${TS:-2}"   # game speed (TS=8 bash tests/modes.sh: faster, check it matches 2 first)
# Research per stage = what a real player owns when the stage starts (tests/sim_insight.gd walks the
# Insight economy: normal-only player for N/HN, a player who also clears hard for HF).
SIM_N=$("$GODOT" --headless --path . -s res://tests/sim_insight.gd -- --quiet 2>/dev/null | grep '^RS ' | tr -d '\r')
SIM_H=$("$GODOT" --headless --path . -s res://tests/sim_insight.gd -- --hard --quiet 2>/dev/null | grep '^RSH ' | tr -d '\r')
if [ -z "$SIM_N" ] || [ -z "$SIM_H" ]; then echo "sim_insight.gd failed"; exit 1; fi
STAGES="${STAGES:-1-1 1-2 1-3 1-4 1-5 1-6 2-1 2-2 2-3 2-4 2-5 2-6 3-1 3-2 3-3 3-4 3-5 3-6 4-1 4-2 4-3 4-4 4-5 4-6 5-1 5-2 5-3 5-4 5-5 5-6 6-1 6-2 6-3 6-4 6-5 6-6}"
CASES=()
for st in $STAGES; do
  n=$(echo "$SIM_N" | awk -v s="$st" '$2==s {print $3}')
  f=$(echo "$SIM_H" | awk -v s="$st" '$2==s {print $3}')
  CASES+=("$st N $n" "$st HF $f" "$st HN $n")
done
run_case() {
  local st="$1" mode="$2" rs="$3"
  local hard=""
  [ "$mode" != "N" ] && hard="--hard"
  local out
  out=$(timeout 900 "$GODOT" --headless --fixed-fps 60 --path . res://scenes/main.tscn -- \
        --autotest --stage="$st" --tag="$RUN_TAG" --budget --research="$rs" --ts=$TS $hard $BOT_ARGS 2>&1)
  local line
  line=$(echo "$out" | grep "\[autotest\] done" | grep -o 'won=[a-z]* wave=[0-9]* integrity=[0-9]*')
  printf "%-5s %-3s %s\n" "$st" "$mode" "${line:-NO RESULT}"
}
export -f run_case
export GODOT BOT_ARGS TS
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
