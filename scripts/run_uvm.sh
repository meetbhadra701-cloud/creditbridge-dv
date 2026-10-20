#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Build and execute the canonical UVM environment with Verilator 5.052+.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
: "${VERILATOR:=verilator}"
: "${UVM_HOME:?Set UVM_HOME to the root of Accellera UVM 2020-3.2}"
: "${UVM_TESTNAME:=cb_uvm_smoke_test}"
: "${UVM_SEED:=1}"
: "${RUN_NAME:=uvm_smoke}"
: "${BUILD_JOBS:=3}"
: "${BUILD_ROOT:=build}"
: "${RTL_SRC:=rtl/credit_bridge.sv}"
: "${COMPILE_ONLY:=0}"
: "${RUN_ID:=$(date -u +%Y%m%dT%H%M%SZ)}"
: "${UVM_PLUSARGS:=}"

uvm_src="$UVM_HOME/src"
for required in "$uvm_src/uvm_pkg.sv" "$uvm_src/dpi/uvm_dpi.cc"; do
  [[ -f "$required" ]] || { echo "ERROR: missing UVM file: $required" >&2; exit 2; }
done
command -v "$VERILATOR" >/dev/null || { echo "ERROR: Verilator not found: $VERILATOR" >&2; exit 127; }
command -v z3 >/dev/null || { echo "ERROR: constrained randomization requires z3 on PATH" >&2; exit 127; }
rtl_source=$(readlink -f "$RTL_SRC")
[[ -f "$rtl_source" ]] || { echo "ERROR: RTL source not found: $RTL_SRC" >&2; exit 2; }

result_dir="results/latest/uvm/${RUN_NAME}"
object_dir="${BUILD_ROOT%/}/obj_${RUN_NAME}"
if [[ "$object_dir" = /* ]]; then
  binary_path="$object_dir/Vcreditbridge_uvm_top"
else
  binary_path="$root/$object_dir/Vcreditbridge_uvm_top"
fi
mkdir -p "$result_dir" "$object_dir"
command_file="$result_dir/command.txt"
log_file="$result_dir/run.log"
coverage_file="$result_dir/coverage.dat"
filelist="$result_dir/filelist.f"
compile_status="$result_dir/compile.status"
run_status="$result_dir/run.status"
rm -f "$coverage_file" "$compile_status" "$run_status"
sed 's#^rtl/credit_bridge[.]sv$#'"$rtl_source"'#' tb/uvm/filelist.f > "$filelist"

{
  echo "tool: $($VERILATOR --version)"
  echo "uvm_home: $(readlink -f "$UVM_HOME")"
  echo "uvm_revision: $(git -C "$UVM_HOME" rev-parse HEAD 2>/dev/null || echo unavailable)"
  echo "rtl_source: $rtl_source"
  echo "rtl_sha256: $(sha256sum "$rtl_source" | awk '{print $1}')"
  echo "seed: $UVM_SEED"
  echo "test: $UVM_TESTNAME"
  echo "run_id: $RUN_ID"
  echo "plusargs: $UVM_PLUSARGS"
  echo "compile: $VERILATOR --binary --timing --vpi --assert --coverage --coverage-user --build-jobs $BUILD_JOBS ..."
echo "build_root: $BUILD_ROOT"
echo "run: $binary_path +UVM_TESTNAME=$UVM_TESTNAME +ntb_random_seed=$UVM_SEED +verilator+seed+$UVM_SEED"
} > "$command_file"

set +e
"$VERILATOR" --binary --timing --vpi --assert --coverage --coverage-user --build-jobs "$BUILD_JOBS" \
  -Wno-fatal --top-module creditbridge_uvm_top \
  -I"$uvm_src" -I"$uvm_src/macros" -Itb/uvm \
  -CFLAGS "-I$uvm_src/dpi" --Mdir "$object_dir" \
  "$uvm_src/uvm_pkg.sv" -f "$filelist" --exe "$uvm_src/dpi/uvm_dpi.cc" \
  > "$log_file" 2>&1
compile_rc=$?
set -e
printf '%s\n' "$compile_rc" > "$compile_status"
if [[ "$compile_rc" -ne 0 ]]; then
  echo "COMPILE_FAIL rc=$compile_rc evidence=$result_dir" >&2
  exit "$compile_rc"
fi
if [[ "$COMPILE_ONLY" = 1 ]]; then
  echo "COMPILE_PASS evidence=$result_dir"
  exit 0
fi

set +e
read -r -a extra_plusargs <<< "$UVM_PLUSARGS"
( cd "$result_dir" && "$binary_path" \
    "+UVM_TESTNAME=$UVM_TESTNAME" "+ntb_random_seed=$UVM_SEED" "+verilator+seed+$UVM_SEED" "${extra_plusargs[@]}" ) >> "$log_file" 2>&1
run_rc=$?
set -e
printf '%s\n' "$run_rc" > "$run_status"
[[ -f "$coverage_file" ]] || { echo "ERROR: no coverage.dat was produced" >> "$log_file"; exit 1; }
if [[ "$run_rc" -ne 0 ]] || grep -Eq 'UVM_(ERROR|FATAL) :[[:space:]]+[1-9]|UVM_(ERROR|FATAL).*\[|\[UVM_(ERROR|FATAL)\]' "$log_file"; then
  echo "UVM execution failed; see $log_file" >&2
  exit 1
fi
if ! grep -Eq 'Running test [[:alnum:]_]+\.\.\.' "$log_file"; then
  echo "UVM execution failed: test-start evidence missing; see $log_file" >&2
  exit 1
fi
if ! grep -Eq 'SB_ACTIVITY.*accepted_inputs=[1-9][0-9]*.*observed_outputs=[1-9][0-9]*' "$log_file"; then
  echo "UVM execution failed: useful scoreboard activity evidence missing; see $log_file" >&2
  exit 1
fi
echo "PASS: $UVM_TESTNAME seed=$UVM_SEED evidence=$result_dir"
