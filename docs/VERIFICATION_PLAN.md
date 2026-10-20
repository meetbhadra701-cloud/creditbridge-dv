# Verification plan

## M1 executed directed checks

The deterministic harness observes accepted input beats into a transaction
queue and compares every output beat against the oldest queued transaction.
It does not mirror DUT pointers, FIFO count, or credit-update code. Scenarios:

1. single-beat packet
2. multi-beat packet and `TLAST`/`TKEEP` preservation
3. FIFO empty behavior
4. FIFO-full behavior
5. input backpressure
6. credit exhaustion
7. credit replenishment
8. simultaneous input/output traffic
9. synchronous reset during an active packet
10. long packet sequences
11. FIFO depths 1, 3, and 8
12. ordering and field preservation

Immediate assertions check credit bounds, prohibit output with zero credit, and
flag an illegal credit return. The run script emits a VCD for waveform debug.

## M2 UVM goals (not implemented or claimed executed)

- Active AXI-stream and credit-link agents with monitors and protocol checkers.
- Constrained-random packets, keep patterns, burst gaps, reset injection, and
  variable credit-return latency.
- A transaction-level UVM scoreboard with packet-aware diagnostics.
- Covergroups for occupancy, credits, packet length, backpressure, reset, and
  cross coverage of credit state with packet boundary and FIFO state.
- Concurrent SVA for stability/handshake properties and mutation testing.
- Seeded regression, coverage merge, coverage closure review, and failure
  triage with retained waveforms.
