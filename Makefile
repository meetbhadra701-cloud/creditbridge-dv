# SPDX-License-Identifier: Apache-2.0
SHELL := /usr/bin/env bash
VERILATOR ?= verilator
UVM_HOME ?=
UVM_SEED ?= 1
UVM_SEEDS ?= 1 2 3 4 5 6 7 8 9 10
BUILD_ROOT ?= build

.PHONY: lint test regression uvm-smoke uvm-test uvm-regression uvm-mutation-test coverage mutation-test clean

lint:
	$(VERILATOR) --lint-only --Wall --Werror-WIDTH --top-module credit_bridge rtl/credit_bridge.sv
	$(VERILATOR) --lint-only --Wall --Werror-WIDTH --top-module creditbridge_assertions assertions/creditbridge_assertions.sv

test:
	VERILATOR="$(VERILATOR)" TEST=all FIFO_DEPTH=8 RUN_NAME=directed BUILD_ROOT="$(BUILD_ROOT)" ./scripts/run_directed.sh

regression:
	VERILATOR="$(VERILATOR)" TEST=all FIFO_DEPTH=8 RUN_NAME=regression_default BUILD_ROOT="$(BUILD_ROOT)" ./scripts/run_directed.sh
	VERILATOR="$(VERILATOR)" TEST=fifo_depths FIFO_DEPTH=1 RUN_NAME=regression_depth1 BUILD_ROOT="$(BUILD_ROOT)" ./scripts/run_directed.sh
	VERILATOR="$(VERILATOR)" TEST=fifo_depths FIFO_DEPTH=3 RUN_NAME=regression_depth3 BUILD_ROOT="$(BUILD_ROOT)" ./scripts/run_directed.sh

uvm-smoke:
	VERILATOR="$(VERILATOR)" UVM_HOME="$(UVM_HOME)" UVM_TESTNAME=cb_uvm_smoke_test UVM_SEED="$(UVM_SEED)" RUN_NAME=uvm_smoke BUILD_ROOT="$(BUILD_ROOT)" ./scripts/run_uvm.sh

uvm-test:
	VERILATOR="$(VERILATOR)" UVM_HOME="$(UVM_HOME)" UVM_TESTNAME=cb_uvm_random_test UVM_SEED="$(UVM_SEED)" RUN_NAME=uvm_random_seed$(UVM_SEED) BUILD_ROOT="$(BUILD_ROOT)" ./scripts/run_uvm.sh

uvm-regression:
	VERILATOR="$(VERILATOR)" UVM_HOME="$(UVM_HOME)" UVM_TESTNAME=cb_uvm_random_test UVM_SEEDS="$(UVM_SEEDS)" BUILD_JOBS=6 BUILD_ROOT="$(BUILD_ROOT)" ./scripts/run_uvm_seed_regression.sh

coverage:
	@coverage_dir=results/latest/uvm/uvm_random_seed$(UVM_SEED); if test -f "$$coverage_dir/coverage.dat"; then :; else coverage_dir=results/latest/uvm/uvm_regression_seed$(UVM_SEED); fi; test -f "$$coverage_dir/coverage.dat" || { echo "ERROR: run make uvm-test or make uvm-regression first" >&2; exit 2; }; "$(dir $(VERILATOR))verilator_coverage" --report summary,hier "$$coverage_dir/coverage.dat" > "$$coverage_dir/coverage_report.txt"; echo "PASS: functional coverage report written to $$coverage_dir/coverage_report.txt"

mutation-test:
	VERILATOR="$(VERILATOR)" ./scripts/run_mutation_tests.sh

uvm-mutation-test:
	VERILATOR="$(VERILATOR)" UVM_HOME="$(UVM_HOME)" BUILD_JOBS=6 BUILD_ROOT="$(BUILD_ROOT)" ./scripts/run_uvm_mutation_tests.sh

clean:
	rm -rf build results/latest
