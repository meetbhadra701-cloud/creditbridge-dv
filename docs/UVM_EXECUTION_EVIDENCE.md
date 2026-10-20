# UVM execution evidence

## Toolchain

Verilator 5.052 (`ea338be98e1e838d3518809ce8899f85a009963c`) executed
Accellera UVM 2020.3.2 (`1eab10a7995c7846dcad7305b995ddb265880433`) with the
UVM DPI source and Verilator VPI enabled. Z3 was present on `PATH` for
constraint solving.

## Canonical tests

| Test | Seed(s) | Result |
|---|---:|---|
| `cb_uvm_smoke_test` | 101 | PASS; 8 accepted, 8 observed, pending 0 |
| `cb_uvm_random_test` | 202, 1..10 | PASS; 11/11 runs, each with nonzero scoreboard activity |
| `cb_uvm_coverage_stress_test` | 404 | PASS; 36 accepted, 36 observed, pending 0 |
| `cb_uvm_reset_test` | 710 | PASS on clean RTL; reset mutant produced deterministic scoreboard mismatches |
| `cb_uvm_credit_return_test` | 711 | PASS on clean RTL; return mutant produced an executed checker failure |
| targeted coverage tests | 712–715 | PASS; coverage merged to 52/52 |

Every passing run has `Running test`, `SB_ACTIVITY`, zero UVM_ERROR/FATAL, a
zero simulator exit, and a local `coverage.dat`.

The final 11-seed command returned `SUMMARY: 11 PASS, 0 FAIL` for seeds
`202 1 2 3 4 5 6 7 8 9 10`.
The runners pass both `+ntb_random_seed=<N>` and Verilator's
`+verilator+seed+<N>`. A two-seed debug audit produced different accepted-input
SHA-256 streams: seed 1
`1000dd2d10fba06329bfb74c03a0826dc90c557a3db2211b0288cab5d0c929ee`, seed 2
`c6a86ae602a171049111eaffdafe5edff7c54b969de469efa3e0680c54d905e5`.
The exact commands and logs are in `results/latest/uvm/seed_debug_summary.txt`
and `results/latest/uvm/seed_debug{1,2}/`.

## Independent checking

`cb_scoreboard` derives expected output only from externally accepted AXI
transfers and observed reset events. It does not read DUT FIFO state. The
FIFO-order mutant produces `SB_MISMATCH` errors and the credit-decrement mutant
triggers `creditbridge_sva.sv` assertion failure, demonstrating active checker
sensitivity.

## Feature probes

Factory/phasing/TLM, constrained randomization, covergroups (4/4 probe bins),
virtual-interface clocking, and an intentional concurrent-SVA failure were
executed separately under `results/latest/recovery/feasibility/`. The SVA
negative-control exit code is intentionally nonzero because the assertion was
required to fire.
