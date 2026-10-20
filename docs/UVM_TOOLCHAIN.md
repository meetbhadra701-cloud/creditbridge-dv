# UVM toolchain

The executable M2 workflow uses Verilator 5.052 and Accellera UVM 2020.3.2.
The source-ordering contract is `tb/uvm/filelist.f`; `scripts/run_uvm.sh`
adds the UVM DPI source, VPI, assertions, user coverage, and a reproducible
seed. Z3 is required by Verilator's constrained-random implementation.

Validated features: factory construction, phasing, objections, TLM analysis,
constrained randomization, covergroup sampling, SVA reporting, and virtual
interfaces/clocking blocks. The runner supplies both the UVM seed and
Verilator's `+verilator+seed+N` so different regression seeds produce distinct
reproducible stimulus. No commercial simulator or license was available.
See `docs/SIMULATOR_COMPATIBILITY.md` and `docs/UVM_EXECUTION_EVIDENCE.md` for
versions, revisions, commands, and logs.
