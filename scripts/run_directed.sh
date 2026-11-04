#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Build and run the deterministic directed suite with Verilator.
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_root"

: "${VERILATOR:=verilator}"
: "${TEST:=all}"
: "${FIFO_DEPTH:=8}"
: "${RUN_NAME:=directed}"
: "${RTL_SRC:=rtl/credit_bridge.sv}"
: "${BUILD_ROOT:=build}"

if ! command -v "$VERILATOR" >/dev/null 2>&1; then
  echo "ERROR: Verilator was not found. Install it (for Ubuntu: sudo apt-get install verilator)." >&2
  exit 127
fi

result_dir="results/latest"
object_dir="${BUILD_ROOT%/}/obj_${RUN_NAME}_d${FIFO_DEPTH}"
mkdir -p "$result_dir" "$object_dir"

command_file="$result_dir/${RUN_NAME}.command.txt"
log_file="$result_dir/${RUN_NAME}.log"
vcd_file="$result_dir/${RUN_NAME}.vcd"
{
  echo "tool: $($VERILATOR --version)"
  echo "rtl_source: $(readlink -f "$RTL_SRC")"
  sha256sum "$RTL_SRC" | sed 's/^/rtl_sha256: /'
  echo "build_root: $BUILD_ROOT"
  echo "build: $VERILATOR --binary --assert --timing --trace --top-module tb_credit_bridge -GFIFO_DEPTH=$FIFO_DEPTH"
  echo "run: $object_dir/Vtb_credit_bridge +TEST=$TEST +VCD=$vcd_file"
} > "$command_file"

{
  "$VERILATOR" --binary --assert --timing --trace --top-module tb_credit_bridge \
    -GFIFO_DEPTH="$FIFO_DEPTH" --Mdir "$object_dir" \
    "$RTL_SRC" assertions/creditbridge_assertions.sv tb/directed/tb_credit_bridge.sv
  "$object_dir/Vtb_credit_bridge" "+TEST=$TEST" "+VCD=$vcd_file"
} 2>&1 | tee "$log_file"
