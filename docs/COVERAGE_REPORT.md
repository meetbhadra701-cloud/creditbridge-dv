# Functional coverage report

## Executed result

Current-source UVM coverage databases from the seeded regression and targeted
legal tests were merged with Verilator 5.052. The final report is
`results/latest/uvm/coverage_closeout_final_report.txt` and the database is
`results/latest/uvm/coverage_closeout_final.dat`.
The exact merge/report command is preserved in
`results/latest/uvm/coverage_closeout_final_command.txt`.

The user-defined functional covergroup is **100.0% (52/52 bins)**. This is not
code coverage. Simulator line/toggle metrics in the same report are not used as
the functional-coverage claim.

## Bin status

The original merged workload reached 42/52 bins. The ten previously unhit bins
were all feasible and were closed by deterministic legal tests:

`backpressure_cp.one`, `backpressure_cp.short`, `packet_length_cp.long`,
`packet_length_x_credit.long_x_available`, `long_x_exhausted`, `long_x_full`,
`long_x_low`, `short_x_available`, `single_x_available`, and
`single_x_low`.

- `cb_uvm_coverage_target_test` closed short/long packet and delayed-return
  bins (46/52 intermediate result).
- `cb_uvm_coverage_cross_test` closed packet-length x credit-state and
  occupancy combinations (51/52 intermediate result).
- `cb_uvm_backpressure_one_test` produced measured one-cycle stalls and closed
  `backpressure_cp.one` (final 52/52).

The final report shows every coverpoint and cross at 100% with no exclusions or
unhit legal bins. TKEEP is sampled only on accepted AXI input handshakes;
packet length is sampled only for completed accepted packets; occupancy and
credits are derived from external handshakes. The merged result is meaningful
coverage closure for the configured 32-bit, depth-8, eight-credit environment,
not a claim for every parameter value.

The 4/4 covergroup result in the feasibility probe is a separate tiny probe and
must not be confused with this 52/52 project result.
