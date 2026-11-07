#!/usr/bin/env bash
# Parallel balance sweep. Every stage × research set × RUNS seeds, in parallel, unthrottled (--fixed-fps 60).
# Usage: bash tests/balance.sh [RUNS] [JOBS]
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/jihye/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
RUNS="${1:-2}"
JOBS="${2:-12}"
CH1_ALL="zeno,sqrt,log2,mult,drill,div3"
CH2A="$CH1_ALL,divx,psqrt"
CH2_ALL="$CH2A,diff,int,int2,d2,d3"
CH3_ALL="$CH2_ALL,ln,merge"
CH4_ALL="$CH3_ALL"
CH5_ALL="$CH4_ALL,dtl,dtl2,wave"
CH6_ALL="$CH5_ALL,damp,damp2"
CH7_ALL="$CH6_ALL,dm1,ann,dbl,harm,harm2,omega2,merge2"
CH8_ALL="$CH7_ALL,lpf"
CH9_ALL="$CH8_ALL,newton,bisect"
CH10_ALL="$CH9_ALL,ax_g,ax_choice,ax_inf,ax_ind"
CASES=()
STAGES="${STAGES:-1-1 1-2 1-3 1-4 1-5 1-6 2-1 2-2 2-3 2-4 2-5 2-6 3-1 3-2 3-3 3-4 3-5 3-6 4-1 4-2 4-3 4-4 4-5 4-6 5-1 5-2 5-3 5-4 5-5 5-6 6-1 6-2 6-3 6-4 6-5 6-6 7-1 7-2 7-3 7-4 7-5 7-6 8-1 8-2 8-3 8-4 8-5 8-6 9-1 9-2 9-3 9-4 9-5 9-6 10-1 10-2 10-3 10-4 10-5}"
for st in $STAGES; do
  case "$st" in
    1-*) CASES+=("$st none" "$st $CH1_ALL") ;;
    2-1) CASES+=("$st $CH1_ALL" "$st $CH1_ALL,divx") ;;
    2-2|2-3) CASES+=("$st $CH1_ALL,divx" "$st $CH2A") ;;    # before calculus: algebra only
    2-4) CASES+=("$st $CH1_ALL,divx" "$st $CH2A") ;;
    2-6) CASES+=("$st $CH2_ALL" "$st $CH3_ALL") ;;      # without D-1 the counterexample must win
    2-*) CASES+=("$st $CH2A,diff" "$st $CH2_ALL") ;;
    3-6) CASES+=("$st $CH3_ALL" "$st $CH4_ALL") ;;      # sin x must win: nothing kills it alone
    3-*) CASES+=("$st $CH2_ALL,ln" "$st $CH3_ALL") ;;
    4-6) CASES+=("$st $CH4_ALL" "$st $CH5_ALL") ;;      # eˣ sin x · eᵗ must win
    4-*) CASES+=("$st $CH4_ALL" "$st $CH4_ALL") ;;
    5-6) CASES+=("$st $CH5_ALL" "$st $CH6_ALL") ;;      # eˣ sin x must win until the damping field
    5-1) CASES+=("$st $CH4_ALL,dtl" "$st $CH5_ALL") ;;
    5-*) CASES+=("$st $CH5_ALL" "$st $CH5_ALL") ;;
    6-6) CASES+=("$st $CH6_ALL" "$st $CH7_ALL") ;;      # the square wave must win
    6-*) CASES+=("$st $CH6_ALL" "$st $CH6_ALL") ;;
    7-6) CASES+=("$st $CH7_ALL" "$st $CH8_ALL") ;;      # without the filter the signal must win
    7-*) CASES+=("$st $CH6_ALL,dtl" "$st $CH7_ALL") ;;
    8-6) CASES+=("$st $CH8_ALL" "$st $CH9_ALL") ;;      # without Newton the quintic must win
    8-*) CASES+=("$st $CH7_ALL" "$st $CH8_ALL") ;;
    9-6) CASES+=("$st $CH9_ALL" "$st $CH10_ALL") ;;     # G must win until axioms exist
    9-*) CASES+=("$st $CH8_ALL,newton" "$st $CH9_ALL") ;;
    10-*) CASES+=("$st $CH9_ALL" "$st $CH10_ALL") ;;
  esac
done

run_case() {
  local st="$1" rs="$2" i="$3"
  local out
  out=$(timeout 600 "$GODOT" --headless --fixed-fps 60 --path . res://scenes/main.tscn -- \
        --autotest --stage="$st" --budget --research="$rs" --ts=1 2>&1)
  local line
  line=$(echo "$out" | grep "\[autotest\] done" | sed 's/\[autotest\] done: //')
  local err
  err=$(echo "$out" | grep -E "SCRIPT ERROR|^ERROR" | head -1)
  local tag="연구없음"
  [ "$rs" != "none" ] && tag="+${rs##*,}"
  if [ -z "$line" ]; then   # keep the whole log of a run that produced no result
    mkdir -p "${TMPDIR:-/tmp}/limit_break_fail"
    local logf="${TMPDIR:-/tmp}/limit_break_fail/${st}_${i}_$$.log"
    echo "$out" > "$logf"
    err="$err (log: $logf)"
  fi
  printf "%-4s %-10s #%s  %s %s\n" "$st" "$tag" "$i" "${line:-NO RESULT}" "$err"
}
export -f run_case
export GODOT

start=$(date +%s)
for c in "${CASES[@]}"; do
  for i in $(seq 1 "$RUNS"); do
    echo "$c $i"
  done
done | xargs -P "$JOBS" -L 1 bash -c 'run_case "$0" "$1" "$2"' | sort
echo "총 소요: $(( $(date +%s) - start ))초"
