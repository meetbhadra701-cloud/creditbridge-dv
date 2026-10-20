# Milestone 1 engineering report

## Implementation

The M1 RTL is `rtl/credit_bridge.sv`. It implements a parameterized circular
beat FIFO, legal full-FIFO simultaneous send/receive, synchronous reset,
credit accounting, and output gating. `assertions/creditbridge_assertions.sv`
contains executable immediate safety assertions. The directed testbench has an
independent accepted-transaction queue checker and writes VCD waveforms.

## Executed evidence

The following were run in this workspace with user-locally extracted Verilator
5.032 because it was not globally installed. Exact commands and complete logs
from the project commands are retained under `results/latest/` when generated;
that directory is intentionally ignored by Git because it is reproducible.

| Check | Exact project command | Result | Exit code | Measured count |
|---|---|---:|---:|---:|
| RTL/assertion lint | `make lint` | PASS | 0 | 2 source files / 2 lint invocations |
| Directed suite | `make test` | PASS | 0 | 12/12 scenarios |
| Regression | `make regression` | PASS | 0 | 14 scenario invocations: 12/12 default, 1/1 at depth 1, 1/1 at depth 3 |

The final automated directed suite completed `+TEST=all` with **12/12
directed scenarios PASSED**. Runtime assertions were enabled through
Verilator's `--assert`; no assertion or checker failures occurred. Regression
generated VCD files for all three invocations (the default trace is 81 KiB).

## Defects found during M1

1. A testbench receiver had two competing drivers for manual and automatic
   credit returns. It could suppress a requested credit return. Replaced with a
   single arbitration process and explicit pending-return counters.
2. The first credit-replenishment scenario did not retain a beat after
   consuming all credits, so it could not demonstrate re-enable behavior.
   It now queues one additional beat and observes a post-return transfer.
3. RTL comparisons initially emitted width warnings under Verilator. Sized
   localparams now make parameterized comparisons lint-clean.

No RTL data-integrity defect was observed in the executed directed suite.

## Limits and honest status

- UVM agents, scoreboards, covergroups, constrained-random tests, mutation
  testing, and advanced concurrent SVA are not implemented in M1.
- No functional-coverage percentage is claimed.
- Icarus and an actual UVM-capable simulator were unavailable locally.
- GitHub Actions is configured but has not been remotely executed from this
  workspace; local equivalent commands are the M1 evidence.

## Reproduction

Install Verilator 5.032 or compatible, then run `make lint`, `make test`, and
`make regression` from repository root. Inspect `results/latest/*.command.txt`,
`*.log`, and `*.vcd`. Individual scenarios can be rerun with, for example:

```bash
TEST=credit_exhaustion FIFO_DEPTH=8 RUN_NAME=repro_credit ./scripts/run_directed.sh
```
