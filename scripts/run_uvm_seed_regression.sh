#!/usr/bin/env bash
# Build the canonical UVM testbench once, then execute reproducible seeds
# against the same compiled DUT.  Each seed has an independent log and
# coverage.dat so failures cannot be overwritten by later runs.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
: "${VERILATOR:=verilator}"
: "${UVM_HOME:?Set UVM_HOME to Accellera UVM 2020.3.2}"
: "${BUILD_JOBS:=6}"
: "${BUILD_ROOT:=/tmp/cb-regression-build}"
: "${UVM_SEEDS:=1 2 3 4 5 6 7 8 9 10}"
: "${UVM_TESTNAME:=cb_uvm_random_test}"

first_seed=""
for seed in $UVM_SEEDS; do first_seed="$seed"; break; done
[[ -n "$first_seed" ]] || { echo "ERROR: UVM_SEEDS is empty" >&2; exit 2; }

first_run="uvm_regression_seed${first_seed}"
VERILATOR="$VERILATOR" UVM_HOME="$UVM_HOME" UVM_TESTNAME="$UVM_TESTNAME" \
  UVM_SEED="$first_seed" RUN_NAME="$first_run" BUILD_JOBS="$BUILD_JOBS" \
  BUILD_ROOT="$BUILD_ROOT" ./scripts/run_uvm.sh

binary="$BUILD_ROOT/obj_${first_run}/Vcreditbridge_uvm_top"
[[ -x "$binary" ]] || { echo "ERROR: compiled UVM binary missing: $binary" >&2; exit 1; }

pass_count=0
fail_count=0
for seed in $UVM_SEEDS; do
  run_name="uvm_regression_seed${seed}"
  result_dir="results/latest/uvm/$run_name"
  mkdir -p "$result_dir"
  if [[ "$seed" = "$first_seed" ]]; then
    # The first invocation already produced this evidence and was checked by
    # run_uvm.sh.
    pass_count=$((pass_count + 1))
    continue
  fi
  log_file="$result_dir/run.log"
  coverage_file="$result_dir/coverage.dat"
  {
    echo "tool: $($VERILATOR --version)"
    echo "uvm_home: $(readlink -f "$UVM_HOME")"
    echo "uvm_revision: $(git -C "$UVM_HOME" rev-parse HEAD 2>/dev/null || echo unavailable)"
    echo "rtl_sha256: $(sha256sum rtl/credit_bridge.sv | awk '{print $1}')"
    echo "seed: $seed"
    echo "test: $UVM_TESTNAME"
    echo "binary: $binary"
    echo "run: $binary +UVM_TESTNAME=$UVM_TESTNAME +ntb_random_seed=$seed +verilator+seed+$seed"
  } > "$result_dir/command.txt"
  set +e
  ( cd "$result_dir" && "$binary" "+UVM_TESTNAME=$UVM_TESTNAME" "+ntb_random_seed=$seed" "+verilator+seed+$seed" ) > "$log_file" 2>&1
  run_rc=$?
  set -e
  [[ -f "$coverage_file" ]]
  if [[ "$run_rc" -eq 0 ]] && \
     ! grep -Eq 'UVM_(ERROR|FATAL) :[[:space:]]+[1-9]|UVM_(ERROR|FATAL).*\[|\[UVM_(ERROR|FATAL)\]' "$log_file" && \
     grep -Eq 'Running test [[:alnum:]_]+\.\.\.' "$log_file" && \
     grep -Eq 'SB_ACTIVITY.*accepted_inputs=[1-9][0-9]*.*observed_outputs=[1-9][0-9]*' "$log_file"; then
    echo "PASS seed=$seed evidence=$result_dir"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL seed=$seed rc=$run_rc evidence=$result_dir" >&2
    fail_count=$((fail_count + 1))
  fi
done

echo "SUMMARY: $pass_count PASS, $fail_count FAIL, seeds=$UVM_SEEDS"
[[ "$fail_count" -eq 0 ]]
