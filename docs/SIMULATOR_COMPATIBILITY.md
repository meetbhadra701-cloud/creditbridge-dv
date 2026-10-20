# Simulator compatibility

| Component | Version / revision | Status |
|---|---|---|
| Verilator | 5.052, 2026-09-05, `ea338be98e1e838d3518809ce8899f85a009963c` | executed |
| Accellera UVM | 2020.3.2, `1eab10a7995c7846dcad7305b995ddb265880433` | executed |
| Z3 | user-local 5.3.1 | constraint solver, executed |
| GCC | 15.2.0 | generated C++ compiler |

The project uses UVM DPI (`src/dpi/uvm_dpi.cc`), `--vpi`, `--assert`,
`--coverage`, and `--coverage-user`. Feature probes demonstrated factory,
phasing, objections, TLM, randomization, covergroups, SVA reporting, and
virtual interfaces. No Riviera-PRO, Questa, VCS, Xcelium, or other commercial
license was available or used.

The validated toolchain was kept in a user-local cache during the closeout
runs. Reproduction documentation uses a generic cache root; exact paths are
captured in each run's `command.txt` and should not be treated as portable
installation locations.
