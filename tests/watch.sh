#!/usr/bin/env bash
# Opens one bot run in a window so a person can watch it play.
# Usage: bash tests/watch.sh <stage> [N|HF|HN] [speed]
#   bash tests/watch.sh 1-6            # normal, 8x
#   bash tests/watch.sh 6-2 HF 2       # hard with the research of a player who also clears hard, 2x
# Research = what a real player owns when the stage starts (tests/sim_insight.gd), same as tests/modes.sh.
# The bot's log (purchases, savings, expected damage, leaks) goes to build/watch_logs/<stage>-<mode>.log.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/jihye/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
ST="${1:?stage, e.g. 1-6}"
MODE="${2:-N}"
TS="${3:-8}"
case "$MODE" in
  N|HN) RS=$("$GODOT" --headless --path . -s res://tests/sim_insight.gd -- --quiet 2>/dev/null | tr -d '\r' | awk -v s="$ST" '$1=="RS" && $2==s {print $3}') ;;
  HF)   RS=$("$GODOT" --headless --path . -s res://tests/sim_insight.gd -- --hard --quiet 2>/dev/null | tr -d '\r' | awk -v s="$ST" '$1=="RSH" && $2==s {print $3}') ;;
  *) echo "mode must be N, HF or HN"; exit 1 ;;
esac
if [ -z "$RS" ]; then echo "unknown stage $ST (1-1 … 6-6)"; exit 1; fi
HARD=""
[ "$MODE" != "N" ] && HARD="--hard"
mkdir -p build/watch_logs
LOG="build/watch_logs/$ST-$MODE.log"
echo "stage $ST  mode $MODE  speed ${TS}x"
echo "research: $RS"
echo "log: $LOG"
"$GODOT" --path . res://scenes/main.tscn -- --autotest --stage="$ST" --tag=lbtwatch --budget \
  --research="$RS" --ts="$TS" $HARD --botlog --leaks > "$LOG" 2>&1
grep "\[autotest\] done" "$LOG" | grep -o 'won=[a-z]* wave=[0-9]* integrity=[0-9]*'
