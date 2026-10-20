# Bugs and verification findings

- The scoreboard had same-edge and analysis-FIFO delta-order races. It was
  repaired with one raw-posedge observation process and explicit drain checks;
  canonical smoke/random tests now pass.
- The random packet sequence overwrote test-level packet constraints. The
  sequence now preserves nonzero test constraints.
- Directed builds reused objects tied to an ephemeral Verilator installation.
  `BUILD_ROOT` is now configurable and final M1 regression uses a clean root.
- The reset-pointer mutant was initially an escaped verification gap. A
  deterministic reset-epoch test now activates it and produces scoreboard
  mismatches. The credit-return mutant was initially inconclusive; the
  separated compile/run harness and bounded credit scenario now produce an
  executed checker failure. These are verification fixes, not baseline RTL
  defects.

No confirmed original-RTL correctness defect was found in the final baseline.
