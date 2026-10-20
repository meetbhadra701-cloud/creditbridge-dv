#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# UVM mutation audit with independent compile/run status and run-specific evidence.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
: "${VERILATOR:=verilator}"
: "${UVM_HOME:?Set UVM_HOME to Accellera UVM 2020.3.2}"
: "${BUILD_JOBS:=6}"
: "${BUILD_ROOT:=/tmp/cb-uvm-mutants-closeout}"
: "${UVM_SEED:=909}"
: "${MUTATION_RUN_ID:=$(date -u +%Y%m%dT%H%M%SZ)}"
: "${COMPILE_TIMEOUT:=600}"
: "${SIM_TIMEOUT:=60}"

command -v "$VERILATOR" >/dev/null || { echo "BLOCKED: Verilator not found" >&2; exit 2; }
command -v z3 >/dev/null || { echo "BLOCKED: z3 not found" >&2; exit 2; }

audit_dir="results/latest/uvm_mutations/$MUTATION_RUN_ID"
source_dir="$audit_dir/sources"
uvm_result_root=results/latest/uvm
mkdir -p "$source_dir"
manifest="$audit_dir/manifest.tsv"
control_manifest="$audit_dir/control_manifest.tsv"
printf 'name\tclassification\tcompile_rc\trun_rc\toriginal_sha256\tmutant_sha256\tseed\tcompile_log\trun_log\tsignature\n' > "$manifest"
printf 'control\tclassification\tcompile_rc\trun_rc\tlog\n' > "$control_manifest"
original_sha=$(sha256sum rtl/credit_bridge.sv | awk '{print $1}')
detected=0
harness_error=0

classify_run() {
  local name=$1 mutant=$2 expected_signature=$3 testname=$4
  local mutant_sha run_name result_dir compile_console run_log binary plusargs
  local compile_wrapper_rc compile_rc run_rc classification signature
  mutant_sha=$(sha256sum "$mutant" | awk '{print $1}')
  run_name="uvm_mutation_${MUTATION_RUN_ID}_${name}"
  result_dir="$uvm_result_root/$run_name"
  compile_console="$audit_dir/${name}.compile.console.log"
  run_log="$audit_dir/${name}.run.log"
  plusargs=""
  if [[ "$testname" = cb_uvm_reset_test ]]; then plusargs="+CB_RESET_AFTER=5 +CB_RESET_CYCLES=3"; fi

  set +e
  timeout "$COMPILE_TIMEOUT" env VERILATOR="$VERILATOR" UVM_HOME="$UVM_HOME" \
    UVM_TESTNAME="$testname" UVM_SEED="$UVM_SEED" RUN_NAME="$run_name" \
    BUILD_JOBS="$BUILD_JOBS" BUILD_ROOT="$BUILD_ROOT" RTL_SRC="$mutant" \
    COMPILE_ONLY=1 RUN_ID="$MUTATION_RUN_ID" UVM_PLUSARGS="$plusargs" ./scripts/run_uvm.sh > "$compile_console" 2>&1
  compile_wrapper_rc=$?
  set -e

  if [[ -f "$result_dir/compile.status" ]]; then
    compile_rc=$(tr -d '[:space:]' < "$result_dir/compile.status")
  else
    compile_rc="$compile_wrapper_rc"
  fi

  if [[ "$compile_wrapper_rc" -eq 124 ]]; then
    classification=TIMEOUT_INCONCLUSIVE; run_rc=-; signature=compile_timeout
  elif [[ "$compile_rc" -ne 0 ]]; then
    classification=COMPILE_FAILURE; run_rc=-; signature=compile_failure
    rm -rf "$BUILD_ROOT/obj_${run_name}"
  else
    binary="$BUILD_ROOT/obj_${run_name}/Vcreditbridge_uvm_top"
    set +e
    timeout "$SIM_TIMEOUT" bash -c 'cd "$1" && "$2" "+UVM_TESTNAME=$3" "+ntb_random_seed=$4" "+verilator+seed+$4" $5' \
      _ "$result_dir" "$binary" "$testname" "$UVM_SEED" "$plusargs" > "$run_log" 2>&1
    run_rc=$?
    set -e
    if [[ "$run_rc" -eq 124 ]]; then
      classification=TIMEOUT_INCONCLUSIVE; signature=simulation_timeout
    elif [[ -n "$expected_signature" ]] && grep -Eq "$expected_signature" "$run_log"; then
      classification=DETECTED_FUNCTIONAL; signature="$expected_signature"
    elif [[ "$run_rc" -eq 0 ]]; then
      classification=ACTIVATED_UNDETECTED; signature=none
    else
      classification=RUN_FAILURE_INCONCLUSIVE; signature=unmatched_failure
    fi
    # The compiled model is no longer needed after this bounded simulation;
    # remove only this run's generated object directory so six UVM mutants do
    # not exhaust the WSL tmpfs. Logs, hashes, and statuses remain in results.
    rm -rf "$BUILD_ROOT/obj_${run_name}"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$name" "$classification" "$compile_rc" "$run_rc" "$original_sha" "$mutant_sha" \
    "$UVM_SEED" "$compile_console" "$run_log" "$signature" >> "$manifest"
  echo "$name: $classification compile_rc=$compile_rc run_rc=$run_rc"
  if [[ "$classification" = DETECTED_FUNCTIONAL ]]; then detected=$((detected + 1)); fi
}

cp rtl/credit_bridge.sv "$source_dir/negative_control_original.sv"
classify_run negative_control_original "$source_dir/negative_control_original.sv" '' cb_uvm_random_test

# Deliberate infrastructure control: a clean binary with an unknown test name
# must fail as infrastructure, never be counted as a DUT detection.
infra_name="uvm_infra_control_${MUTATION_RUN_ID}"
infra_dir="$uvm_result_root/$infra_name"
set +e
timeout "$COMPILE_TIMEOUT" env VERILATOR="$VERILATOR" UVM_HOME="$UVM_HOME" \
  UVM_TESTNAME=cb_uvm_random_test UVM_SEED="$UVM_SEED" RUN_NAME="$infra_name" \
  BUILD_JOBS="$BUILD_JOBS" BUILD_ROOT="$BUILD_ROOT" RTL_SRC=rtl/credit_bridge.sv \
  COMPILE_ONLY=1 RUN_ID="$MUTATION_RUN_ID" ./scripts/run_uvm.sh > "$audit_dir/infrastructure.compile.log" 2>&1
infra_compile_wrapper_rc=$?
set -e
infra_compile_rc=$(tr -d '[:space:]' < "$infra_dir/compile.status" 2>/dev/null || echo "$infra_compile_wrapper_rc")
infra_binary="$BUILD_ROOT/obj_${infra_name}/Vcreditbridge_uvm_top"
set +e
timeout "$SIM_TIMEOUT" bash -c 'cd "$1" && "$2" +UVM_TESTNAME=cb_nonexistent_test +ntb_random_seed=1 +verilator+seed+1' \
  _ "$infra_dir" "$infra_binary" > "$audit_dir/infrastructure.run.log" 2>&1
infra_run_rc=$?
set -e
rm -rf "$BUILD_ROOT/obj_${infra_name}"
if [[ "$infra_compile_rc" -eq 0 ]] && grep -Eq 'NOT FOUND|cannot find|UVM_FATAL|INVTST|NOCOMP' "$audit_dir/infrastructure.run.log"; then
  infra_classification=INFRASTRUCTURE_FAILURE
else
  infra_classification=CONTROL_HARNESS_FAILURE
  harness_error=1
fi
printf 'unknown_test\t%s\t%s\t%s\t%s\n' "$infra_classification" "$infra_compile_rc" "$infra_run_rc" "$audit_dir/infrastructure.run.log" >> "$control_manifest"

declare -a names=(credit_decrement fifo_order tlast reset_pointer_retention return_increment)
declare -a expressions=(
  "s/credit_count <= credit_count - 1'b1;/credit_count <= credit_count;/"
  's/assign m_link_data = data_mem\[rd_ptr\];/assign m_link_data = data_mem[wr_ptr];/'
  "s/assign m_link_last = last_mem\[rd_ptr\];/assign m_link_last = 1'b0;/"
  "s/rd_ptr       <= '0;/rd_ptr       <= rd_ptr;/"
  "s/credit_count <= credit_count \+ 1'b1;/credit_count <= credit_count - 1'b1;/"
)
declare -a signatures=(
  'Assertion failed|creditbridge_sva[.]sv:32'
  'SB_MISMATCH|SB_UNEXPECTED|SB_TIMEOUT'
  'SB_MISMATCH|SB_UNEXPECTED|SB_TIMEOUT'
  'SB_MISMATCH|SB_UNEXPECTED|SB_TIMEOUT'
  'SB_TIMEOUT|creditbridge_sva[.]sv:[0-9]+: Assertion failed|SB_MISMATCH'
)
declare -a tests=(cb_uvm_random_test cb_uvm_random_test cb_uvm_random_test cb_uvm_reset_test cb_uvm_credit_return_test)
for i in "${!names[@]}"; do
  name=${names[$i]}
  mutant="$source_dir/${name}.sv"
  cp rtl/credit_bridge.sv "$mutant"
  perl -0pi -e "${expressions[$i]}" "$mutant"
  if cmp -s rtl/credit_bridge.sv "$mutant"; then
    printf '%s\tMUTATION_NOT_APPLIED\t-\t-\t%s\t%s\t%s\t-\t-\tno_source_change\n' \
      "$name" "$original_sha" "$original_sha" "$UVM_SEED" >> "$manifest"
    harness_error=1
  else
    classify_run "$name" "$mutant" "${signatures[$i]}" "${tests[$i]}"
  fi
done

echo "UVM mutation summary: $detected/5 functional detections; control=$infra_classification"
printf 'summary\tdetected_functional\t%s\n' "$detected" > "$audit_dir/summary.txt"
printf 'audit_dir=%s\nmanifest=%s\ncontrol_manifest=%s\n' "$audit_dir" "$manifest" "$control_manifest" >> "$audit_dir/summary.txt"
[[ "$infra_classification" = INFRASTRUCTURE_FAILURE && "$harness_error" -eq 0 ]]
