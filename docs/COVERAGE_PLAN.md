# Functional coverage plan

The project covergroup is defined in `tb/uvm/coverage/cb_coverage.sv` and is
measured with Verilator user coverage. The final configured denominator is 52
legal bins:

- 15 legal nonzero TKEEP patterns, sampled only on accepted input beats;
- packet length, credit availability, occupancy, reset, and backpressure bins;
- packet-length × credit-state crosses;
- packet-boundary and simultaneous-event behavior.

Packet length samples only completed accepted packets. Occupancy and credits are
tracked from interface handshakes rather than DUT internals. Zero TKEEP and
other illegal protocol situations are not credited as legal traffic.

The closeout report measured **52/52 bins (100.0%)** for the documented
32-bit/depth-8/eight-credit configuration. Intermediate closure runs are
preserved in `results/latest/uvm/`; the final report and merge command are
documented in [`COVERAGE_REPORT.md`](COVERAGE_REPORT.md).

This is user-defined functional coverage. Verilator line, toggle, branch, and
expression numbers are reported separately and are not substituted for
functional coverage.
