# CreditBridge-DV v1.0.0

## Release summary

This release packages the completed Milestone 2 verification foundation for
CreditBridge-DV: a parameterized SystemVerilog packet bridge with an executable
UVM environment, independent transaction checking, concurrent assertions,
functional coverage, reproducible seeded regressions, and mutation testing.

## Verified results

- Verilator 5.052 with Accellera UVM 2020.3.2 and Z3.
- M1 directed scenarios: 12/12 PASS.
- Parameterized FIFO scenario invocations: 14/14 PASS.
- UVM smoke: PASS, seed 101.
- UVM random regression: 11/11 PASS, seeds 202 and 1–10.
- User-defined functional coverage: 52/52 bins (100.0%) for the documented
  tested configuration.
- Directed RTL mutations: 5/5 detected.
- UVM-backed RTL mutations: 5/5 detected, with source-hash and negative-control
  evidence.

## Scope

The protocol is an independently specified training protocol. This release is
not a PCIe or CXL compliance claim, does not report code-coverage closure, and
does not claim validation on commercial simulators. Results are scoped to the
documented Verilator configuration and tested FIFO/credit parameters.

See [`README.md`](../README.md) for the project overview and
[`M2_CLOSEOUT_SUMMARY.md`](M2_CLOSEOUT_SUMMARY.md) for the detailed evidence
index.
