# Compile with UVM library first, then use this exact ordering.
tb/uvm/interfaces/creditbridge_interfaces.sv
tb/uvm/creditbridge_uvm_pkg.sv
rtl/credit_bridge.sv
assertions/creditbridge_sva.sv
tb/uvm/creditbridge_uvm_top.sv
