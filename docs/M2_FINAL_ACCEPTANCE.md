# M2 final acceptance

| Gate | Evidence | Status |
|---|---|---|
| Genuine UVM simulation | Verilator 5.052 + UVM 2020.3.2 smoke/random logs | PASS |
| Source/credit agents and independent scoreboard | `SB_ACTIVITY`, accepted/observed counts, zero pending | PASS |
| Constrained-random regression | 11/11 seeds, nonzero traffic | PASS |
| Concurrent SVA execution | intentional negative probe and credit mutant failure | PASS |
| Functional coverage measured | 52/52 user bins = 100.0% | PASS |
| Mutation sensitivity | directed 5/5 and UVM 5/5 functional detections | PASS |
| M1 preserved | lint PASS; directed 12/12 plus depths 1 and 3 | PASS |

**Final verdict: GO.** All required M2 gates were executed on the original RTL
after the repaired scoreboard, coverage targets, reset scenario, and mutation
harness were rerun. No commercial simulator or PCIe/CXL compliance is claimed.

Primary evidence: `results/latest/uvm/coverage_closeout_final_report.txt`,
`results/latest/uvm_mutations/closeout_20261019d/manifest.tsv`, and
`results/latest/uvm_mutations/closeout_20261019d/control_manifest.tsv`.
