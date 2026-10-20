#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Mutation evidence harness: temporary source copies only, manifest-backed.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
: "${VERILATOR:=verilator}"
if ! command -v "$VERILATOR" >/dev/null 2>&1; then
  echo "BLOCKED: mutation test requires Verilator" >&2; exit 2
fi
result_dir=results/latest/mutations
source_dir="$result_dir/sources"
mkdir -p "$source_dir"
manifest="$result_dir/manifest.tsv"
printf 'name\tclassification\tlint_rc\trun_rc\toriginal_sha256\tcompiled_sha256\n' > "$manifest"
original_sha=$(sha256sum rtl/credit_bridge.sv | awk '{print $1}')
detected=0; harness_error=0

run_case() {
  local name source expected lint_log run_log
  name=$1
  source=$2
  expected=$3
  lint_log="$result_dir/${name}.lint.log"
  run_log="$result_dir/${name}.log"
  local source_sha lint_rc run_rc classification
  source_sha=$(sha256sum "$source" | awk '{print $1}')
  set +e
  "$VERILATOR" --lint-only --top-module credit_bridge "$source" > "$lint_log" 2>&1
  lint_rc=$?
  set -e
  if [ "$lint_rc" -ne 0 ]; then
    classification=COMPILE_FAILURE; run_rc=-
  else
    set +e
    timeout 120s env RTL_SRC="$source" TEST=all FIFO_DEPTH=8 RUN_NAME="mutation_${name}" VERILATOR="$VERILATOR" ./scripts/run_directed.sh > "$run_log" 2>&1
    run_rc=$?
    set -e
    if [ "$run_rc" -eq 0 ]; then classification=ACTIVATED_UNDETECTED
    elif [ "$run_rc" -eq 124 ]; then classification=TIMEOUT_INCONCLUSIVE
    elif grep -Eq 'Assertion failed|%Error:|\[FAIL\]|\$fatal' "$run_log"; then classification=DETECTED_FUNCTIONAL
    else classification=RUN_FAILURE_INCONCLUSIVE
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$classification" "$lint_rc" "$run_rc" "$original_sha" "$source_sha" >> "$manifest"
  echo "$name: $classification"
  if [ "$expected" = DETECTED_FUNCTIONAL ] && [ "$classification" = DETECTED_FUNCTIONAL ]; then detected=$((detected+1)); fi
  if [ "$expected" = NEGATIVE_CONTROL ] && [ "$classification" != ACTIVATED_UNDETECTED ]; then harness_error=1; fi
}

cp rtl/credit_bridge.sv "$source_dir/negative_control_original.sv"
run_case negative_control_original "$source_dir/negative_control_original.sv" NEGATIVE_CONTROL
declare -a names=(credit_decrement fifo_order tlast reset_pointer_retention return_increment)
declare -a expressions=(
  "s/credit_count <= credit_count - 1'b1;/credit_count <= credit_count;/"
  's/assign m_link_data = data_mem\[rd_ptr\];/assign m_link_data = data_mem[wr_ptr];/'
  "s/assign m_link_last = last_mem\[rd_ptr\];/assign m_link_last = 1'b0;/"
  "s/rd_ptr       <= '0;/rd_ptr       <= rd_ptr;/"
  "s/credit_count <= credit_count \+ 1'b1;/credit_count <= credit_count - 1'b1;/"
)
for i in "${!names[@]}"; do
  name=${names[$i]}; mutant="$source_dir/${name}.sv"
  cp rtl/credit_bridge.sv "$mutant"; perl -0pi -e "${expressions[$i]}" "$mutant"
  if cmp -s rtl/credit_bridge.sv "$mutant"; then echo "$name: MUTATION_NOT_APPLIED"; harness_error=1; continue; fi
  run_case "$name" "$mutant" DETECTED_FUNCTIONAL
done
echo "Mutation summary: $detected/5 functional detections; negative-control error=$harness_error"
[ "$detected" -eq 5 ] && [ "$harness_error" -eq 0 ]
