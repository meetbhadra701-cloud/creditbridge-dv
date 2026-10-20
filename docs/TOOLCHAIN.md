# Toolchain inventory

Inventory and final validation were performed on 2026-10-16 in WSL2.

| Component | Actual finding | Status |
|---|---|---|
| OS / shell | Windows host with Ubuntu WSL2 / Bash | available |
| Verilator | 5.052 (2026-09-05), commit `ea338be98e1e838d3518809ce8899f85a009963c` | executed |
| Accellera UVM | 2020.3.2, commit `1eab10a7995c7846dcad7305b995ddb265880433` | executed |
| Icarus Verilog | not used for UVM; no suitable UVM workflow claimed | not required |
| Python | 3.14.4 | available |
| C++ | GCC 15.2.0 | available |
| Make / CMake | GNU Make 4.4.1 / CMake 4.2.3 | available |
| Git | 2.53.0 | available |
| Z3 | user-local 5.3.1 | executed for randomization |

No Questa, Riviera-PRO, VCS, Xcelium, or commercial license was available or
used. The validated tools were installed in a user-local cache for the closeout
run. Exact paths, seeds, source hashes, and commands are recorded in each
result directory's `command.txt`; they are intentionally not hard-coded here.

The open-source Verilator/UVM workflow is now the validated M2 execution plan;
`tb/uvm/filelist.f` remains the canonical source-order contract.
