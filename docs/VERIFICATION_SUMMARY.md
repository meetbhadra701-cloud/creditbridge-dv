# Verification summary

## Measured final result

| Area | Executed result |
|---|---:|
| Lint | PASS |
| M1 directed | 12/12 scenarios |
| FIFO-depth regression | 14/14 invocations |
| UVM smoke | PASS, seed 101 |
| UVM random regression | 11/11, seeds 202 and 1–10 |
| User-defined functional coverage | 52/52 bins (100.0%) |
| Directed mutations | 5/5 detected |
| UVM mutations | 5/5 detected |

## What was checked

The tests exercise single- and multi-beat packets, legal TKEEP patterns, source
gaps, FIFO empty/full transitions, input backpressure, credit exhaustion and
return, simultaneous send/return, reset during traffic, FIFO depths 1/3/8,
ordering preservation, and long packet sequences. The UVM scoreboard checks
beat data, TKEEP, TLAST, ordering, reset flushing, extra output, missing output,
and bounded end-of-test drain.

## Evidence boundaries

The results are from Verilator 5.052 with Accellera UVM 2020.3.2 and Z3. The
coverage percentage is a user-defined functional covergroup result for the
documented depth-8/eight-credit configuration. It is not code coverage, formal
completeness, or a commercial-simulator cross-check. The protocol is simplified
and independently specified; no PCIe/CXL compliance is implied.

Run-specific logs, source hashes, coverage databases, and mutation manifests
are generated under `results/latest/` when the commands are executed locally.
