class cb_axis_item extends uvm_sequence_item;
  rand bit [31:0] data;
  rand bit [3:0]  keep;
  rand bit        last;
  rand int unsigned gap_cycles;
  // Populated by the passive monitor; never randomized by a sequence.
  time sample_time;
  constraint legal_keep { keep != 0; gap_cycles inside {[0:8]}; }

  `uvm_object_utils_begin(cb_axis_item)
    `uvm_field_int(data, UVM_DEFAULT)
    `uvm_field_int(keep, UVM_DEFAULT)
    `uvm_field_int(last, UVM_DEFAULT)
    `uvm_field_int(gap_cycles, UVM_DEFAULT)
    `uvm_field_int(sample_time, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "cb_axis_item");
    super.new(name);
  endfunction
endclass
