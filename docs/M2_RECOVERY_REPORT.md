# M2 recovery report

## Verdict

**GO (closeout).** The canonical CreditBridge UVM environment executes with
Verilator 5.052 and Accellera UVM 2020.3.2. The repaired scoreboard, targeted
coverage tests, reset activation, and separated compile/run mutation harness
were executed on clean run IDs.

## Executed evidence

| Check | Result | Evidence |
|---|---|---|
| Verilator lint (RTL + SVA) | PASS, exit 0 | `make lint VERILATOR=.../verilator` |
| M1 directed depth 8 | PASS, 12/12 | `results/latest/direct*` |
| M1 depth regression | PASS, 12 + 1 + 1 scenarios | `results/latest/regression*` |
| Canonical UVM smoke | PASS, seed 101, 8 accepted/8 observed | `results/latest/uvm/uvm_smoke/run.log` |
| UVM random regression | PASS, 11/11 seeds (202, 1..10) | `results/latest/uvm/uvm_regression_seed*/run.log` |
| Functional coverage | PASS, 100.0%, 52/52 user bins | `results/latest/uvm/coverage_closeout_final_report.txt` |
| Directed mutation harness | PASS, 5/5 functional mutants detected | `results/latest/mutations/manifest.tsv` |
| UVM mutation run | PASS, 5/5 functional detections; controls classified separately | `results/latest/uvm_mutations/closeout_20261019d/manifest.tsv` |

## Repaired defects

The scoreboard uses one raw-posedge observation process for accepted input and
output comparison, preventing same-cycle analysis-FIFO scheduling races. Reset
flushing and explicit drain checks are retained. TKEEP coverage is gated by a
real input handshake. The UVM random sequence no longer overwrites test
constraints. The reset-pointer and credit-return scenarios are deterministic
and bounded. `run_uvm_mutation_tests.sh` now records independent compile/run
statuses, source hashes, run IDs, and checker signatures; an unchanged-RTL
control and an invalid-test infrastructure control are both explicit.

## Limitations

No unexplained functional mutation escape remains in the final UVM matrix.
Earlier no-space/terminated build attempts remain historical infrastructure
artifacts and are not counted as detections. No commercial simulator was used;
Verilator's supported UVM flow remains the executed simulator configuration.
