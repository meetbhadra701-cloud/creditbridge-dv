# UVM architecture

The executable environment is under `tb/uvm/` and is compiled in the order
specified by `tb/uvm/filelist.f`.

## Components

- `cb_axis_if` and `cb_credit_if` provide clocking blocks for race-resistant
  signal access.
- `cb_axis_agent` contains an active sequencer/driver and an input monitor. The
  monitor publishes only accepted `TVALID && TREADY` beats.
- `cb_credit_agent` contains the credit-link monitor and a sequencer/driver for
  explicit credit-return transactions.
- `cb_credit_responder` models a legal receiver: it returns credits only for
  observed output transfers, with configurable delay.
- `cb_scoreboard` observes both monitors through analysis FIFOs but performs the
  end-to-end comparison in one clocked observation process. It queues expected
  beats from accepted input, flushes on reset, detects extra/missing/reordered
  or corrupted output, and requires a bounded drain.
- `cb_coverage` samples legal handshake-derived packet length, TKEEP, credit,
  occupancy, reset, backpressure, and cross bins.
- `creditbridge_sva` is bound to the DUT for input stability, output credit
  eligibility, illegal idle returns, reset credit restoration, and credit-range
  checks.
- `cb_virtual_sequencer` provides a reusable coordination point for future
  synchronized source/link scenarios.

## Test classes

`cb_uvm_smoke_test` and `cb_uvm_random_test` are the canonical smoke and
constrained-random tests. Deterministic closure tests cover reset-pointer
activation, bounded credit return, long packets, credit-state crosses, and
one-cycle backpressure. The mutation runner invokes these tests against
temporary RTL copies and records separate compile/run status and source hashes.

## Independence and scheduling

The reference model is transaction-level and external-observation based; it
does not mirror internal FIFO pointers or memory. Same-cycle input/output
events are ordered from raw clock observations, reset flushes expected state at
the protocol boundary, and end-of-test checks verify accepted/observed counts
and zero pending transactions.
