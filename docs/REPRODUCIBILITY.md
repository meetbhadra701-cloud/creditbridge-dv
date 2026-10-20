# Reproducibility

The project is designed to run from a Linux shell (native Linux, WSL, or a
Linux CI runner). Do not copy the temporary paths from the closeout host; set
the variables to local installations.

## Required tools

- Verilator 5.052 (`Verilator 5.052 2026-09-05`, source revision
  `ea338be98e1e838d3518809ce8899f85a009963c`)
- Accellera UVM 2020.3.2, revision
  `1eab10a7995c7846dcad7305b995ddb265880433`
- Z3 available on `PATH` for Verilator constrained randomization
- GCC/C++17-capable compiler, GNU make, Bash, and standard Unix utilities

Example environment setup:

```bash
export VERILATOR=/opt/verilator-5.052/bin/verilator
export UVM_HOME=/opt/uvm-verilator-2020-3.2
export PATH=/opt/z3/bin:$PATH
```

The UVM source must contain `src/uvm_pkg.sv`, `src/dpi/uvm_dpi.cc`, and the
Verilator support files. The runner validates these paths before compiling.

## Commands

```bash
make lint
make test
make regression
make uvm-smoke UVM_SEED=101 BUILD_ROOT=/tmp/cb-uvm-smoke
make uvm-test UVM_SEED=202 BUILD_ROOT=/tmp/cb-uvm-test
make uvm-regression \
  UVM_SEEDS="202 1 2 3 4 5 6 7 8 9 10" \
  BUILD_ROOT=/tmp/cb-uvm-regression
make coverage UVM_SEED=1
make uvm-mutation-test BUILD_ROOT=/tmp/cb-uvm-mutants
```

Every UVM run records the tool version, UVM revision, RTL SHA-256, test, seed,
run ID, command, compile status, simulation status, log, and coverage database.
The runners pass both `+ntb_random_seed=N` and `+verilator+seed+N` so the
constrained-random stream is reproducible and changes with the seed.

## CI scope

The GitHub Actions workflow runs the open-source lint and directed regression.
The UVM job is intentionally not claimed in CI because UVM 2020.3.2 and the
Verilator 5.052 toolchain are not installed by the default runner image.
