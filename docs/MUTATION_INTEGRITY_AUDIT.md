# Mutation integrity audit

The repaired runners pass an explicit `RTL_SRC`, generate a run-specific
filelist, record SHA-256 hashes, and require evidence from the actual compiled
run. A copied-original negative control is classified
`ACTIVATED_UNDETECTED`, proving that a clean original run is not reported as a
functional detection.

## Directed harness

`results/latest/mutations/manifest.tsv` records five distinct source hashes and
five `DETECTED_FUNCTIONAL` directed mutations. This is valid directed evidence;
it is not UVM evidence.

## UVM-backed matrix (run `closeout_20261019d`)

| Mutation | Classification | compile_rc | run_rc | Evidence |
|---|---|---:|---:|---|
| credit decrement held | DETECTED_FUNCTIONAL | 0 | 1 | `credit_decrement.run.log`; SVA failure at `creditbridge_sva.sv:32` |
| FIFO order corrupted | DETECTED_FUNCTIONAL | 0 | 0 | `fifo_order.run.log`; scoreboard mismatch signature |
| TLAST forced low | DETECTED_FUNCTIONAL | 0 | 0 | `tlast.run.log`; scoreboard mismatch signature |
| reset pointer retained | DETECTED_FUNCTIONAL | 0 | 0 | `reset_pointer_retention.run.log`; deterministic reset scoreboard mismatch |
| credit return decremented | DETECTED_FUNCTIONAL | 0 | 1 | `return_increment.run.log`; bounded credit checker signature |

The unchanged copied-RTL negative control is `ACTIVATED_UNDETECTED` with equal
SHA-256 hashes and `compile_rc=0`, `run_rc=0`; it is not a functional detection.
The unknown-test control is `INFRASTRUCTURE_FAILURE`, also with separate
compile/run statuses. All five final mutant hashes differ from the original
`615e48824733a370c1f995961e513e0df113d873e00a98a7c682cf10197798d9`. Earlier
no-space/terminated builds are retained as historical infrastructure evidence,
not counted as detections.
