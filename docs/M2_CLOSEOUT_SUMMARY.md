# CreditBridge-DV M2 closeout summary

## Verdict

**GO.** Final acceptance was executed on 2026-10-19 with Verilator 5.052 and
Accellera UVM 2020.3.2. The original RTL was restored before the final clean
regression.

## Executed matrix

| Area | Result | Evidence |
|---|---:|---|
| Verilator lint | PASS | `make lint` |
| M1 directed | 12/12 PASS | `make test` |
| FIFO depths | 14/14 total PASS (12 + depth 1 + depth 3) | `make regression` |
| UVM smoke | 1/1 PASS, seed 101 | `results/latest/uvm/uvm_smoke/run.log` |
| UVM random | 11/11 PASS, seeds 202 and 1–10 | `results/latest/uvm/uvm_regression_seed*/run.log` |
| Functional coverage | 52/52 = 100.0% | `results/latest/uvm/coverage_closeout_final_report.txt` |
| Directed mutations | 5/5 detected | `results/latest/mutations/manifest.tsv` |
| UVM mutations | 5/5 detected | `results/latest/uvm_mutations/closeout_20261019d/manifest.tsv` |

The final random regression uses seeds `202 1 2 3 4 5 6 7 8 9 10`. A separate
seed audit confirmed distinct accepted-data hashes for seeds 1 and 2; see
`results/latest/uvm/seed_debug_summary.txt`.

## Coverage closure

The original workload measured 42/52 bins (80.8%). A deterministic target test
closed delayed-return and packet-length bins (46/52), a credit/packet cross test
closed legal state crosses (51/52), and the one-cycle backpressure test closed
the final bin. The final denominator remains 52; no bins were excluded.

## Mutation integrity

The final audit records independent compile and simulation statuses, SHA-256
source hashes, seeds, run IDs, and checker signatures. The unchanged-RTL
negative control was `ACTIVATED_UNDETECTED`; the unknown-test control was
`INFRASTRUCTURE_FAILURE`. These controls prevent infrastructure failures from
being counted as DUT detections. The reset-pointer mutant was activated by a
reset after the read pointer advanced and failed with scoreboard mismatches.
The credit-return mutant passed compilation and failed during simulation via an
executed credit checker signature; the clean bounded credit-return test passed
first.

The final mutation matrix had no compile failures or timeouts (`compile_rc=0`
for all five mutants). Historical no-space/terminated attempts are preserved
under earlier run IDs and are classified as infrastructure/inconclusive, never
as functional detections. The final clean original-DUT regression was rerun
after the mutation audit.

## Limitations

The executed UVM configuration is Verilator 5.052 + UVM 2020.3.2 with the
32-bit, depth-8, eight-credit configuration. No commercial simulator was
available or used; no PCIe/CXL compliance or code-coverage closure is claimed.
