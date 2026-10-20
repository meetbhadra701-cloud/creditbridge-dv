class cb_link_item extends uvm_sequence_item;
  bit [31:0] data;
  bit [3:0]  keep;
  bit        last;
  rand int unsigned return_delay;
  // Populated by the passive monitor; never randomized by a sequence.
  time sample_time;
  constraint legal_return_delay { return_delay inside {[0:8]}; }

  `uvm_object_utils_begin(cb_link_item)
    `uvm_field_int(data, UVM_DEFAULT)
    `uvm_field_int(keep, UVM_DEFAULT)
    `uvm_field_int(last, UVM_DEFAULT)
    `uvm_field_int(return_delay, UVM_DEFAULT)
    `uvm_field_int(sample_time, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "cb_link_item");
    super.new(name);
  endfunction
endclass
