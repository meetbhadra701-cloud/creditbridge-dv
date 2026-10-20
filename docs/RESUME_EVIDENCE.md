# Resume evidence

- Built and verified a parameterized SystemVerilog packet bridge with a
  self-checking directed environment; Verilator 5.052 passed 12/12 directed
  scenarios plus FIFO-depth runs at depths 1 and 3.
- Integrated Accellera UVM 2020.3.2 with active AXI and credit-link agents,
  constrained-random sequences, an independent transaction-level scoreboard,
  concurrent SVA, and reproducible 11-seed regression (11/11 PASS).
- Measured 52/52 user-defined functional coverage bins and detected 5/5
  directed plus 5/5 UVM RTL mutations using source-hash-checked, separate
  compile/run mutation evidence.

Scope: Verilator/UVM open-source flow; no commercial-simulator, PCIe/CXL
compliance, formal-completeness, or code-coverage claim.
