# Interview preparation

These questions are grounded in the implemented CreditBridge-DV environment.

1. **What constitutes an accepted input beat?**  A beat is accepted only on a
   rising edge with `s_axis_tvalid && s_axis_tready`. The scoreboard and
   coverage collector use that external handshake, not merely `TVALID`.

2. **Why does the output have no ready signal?**  The simplified link models a
   receiver that consumes every beat when `m_link_valid` is high. Eligibility
   therefore depends on FIFO occupancy and available send credits.

3. **How are credits conserved?**  An output transfer decrements the count and
   a legal return increments it. A simultaneous transfer and return leaves the
   count unchanged. Assertions flag idle over-returns and out-of-range state.

4. **How does the scoreboard remain independent?**  It queues transactions
   observed at the AXI handshake and compares them with output monitor events.
   It never reads FIFO pointers, memory, or internal occupancy.

5. **How did you handle same-cycle input and output?**  A single raw-clock
   observation process applies reset, accepted input, and output events in a
   deterministic order. This avoids analysis-FIFO delta-cycle races.

6. **What happens on reset during a packet?**  Synchronous reset discards all
   buffered state and restores credits. The scoreboard flushes its expected
   queue at the same observed reset boundary; post-reset traffic is checked as
   a new epoch.

7. **What does the coverage percentage mean?**  It is 52/52 bins in the
   user-defined covergroup for the depth-8/eight-credit configuration. It is not
   line coverage, formal completeness, or coverage for all parameter values.

8. **How did you validate mutation sensitivity?**  Temporary RTL copies are
   hash-checked, compiled through an explicit `RTL_SRC`, and run with separate
   compile/run statuses. Only executed SVA, scoreboard, or protocol signatures
   count as functional detections.

9. **Why can a mutation have `run_rc=0` and still be detected?**  The UVM
   report server can log `UVM_ERROR` without making the Verilator process return
   nonzero. The mutation harness therefore requires a specific checker
   signature; it does not treat a nonzero exit alone as a detection.

10. **What would you do before signoff in a larger product?**  I would add
    broader parameter/configuration coverage, formalize protocol assumptions,
    run the same environment in an authorized commercial simulator, and review
    coverage exclusions with the design team. This project deliberately stops
    short of PCIe/CXL compliance claims.
