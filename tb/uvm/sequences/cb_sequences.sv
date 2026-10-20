class cb_random_packet_sequence extends uvm_sequence #(cb_axis_item);
  `uvm_object_utils(cb_random_packet_sequence)
  rand int unsigned packet_count;
  rand int unsigned max_packet_beats;
  constraint bounds { packet_count inside {[1:32]}; max_packet_beats inside {[1:32]}; }
  function new(string name = "cb_random_packet_sequence"); super.new(name); endfunction
  task body();
    cb_axis_item tr;
    int unsigned packet_len;
    int unsigned beat_index;
    // Tests may constrain packet_count/max_packet_beats before start().  Do
    // not overwrite those values by randomizing the sequence a second time.
    if (packet_count == 0 || max_packet_beats == 0)
      if (randomize() == 0) `uvm_fatal("SEQ_RAND", "Unable to randomize sequence configuration")
    repeat (packet_count) begin
      if ((std::randomize(packet_len) with { packet_len inside {[1:max_packet_beats]}; }) == 0)
        `uvm_fatal("SEQ_RAND", "Unable to randomize packet length")
      for (beat_index = 0; beat_index < packet_len; beat_index++) begin
        tr = cb_axis_item::type_id::create("tr");
        start_item(tr);
        if ((tr.randomize() with { last == (beat_index == packet_len - 1); }) == 0)
          `uvm_fatal("SEQ_RAND", "Unable to randomize packet beat")
        finish_item(tr);
      end
    end
  endtask
endclass

class cb_smoke_sequence extends uvm_sequence #(cb_axis_item);
  `uvm_object_utils(cb_smoke_sequence)
  function new(string name = "cb_smoke_sequence"); super.new(name); endfunction
  task body();
    cb_axis_item tr;
    for (int unsigned i = 0; i < 8; i++) begin
      tr = cb_axis_item::type_id::create("tr");
      start_item(tr);
      if ((tr.randomize() with { gap_cycles inside {[0:2]}; }) == 0) `uvm_fatal("SEQ_RAND", "Item randomization failed");
      tr.last = (i % 3 == 2);
      finish_item(tr);
    end
  endtask
endclass

// Deterministic packets used by reset and credit-accounting closure tests.
class cb_fixed_packet_sequence extends uvm_sequence #(cb_axis_item);
  `uvm_object_utils(cb_fixed_packet_sequence)
  int unsigned packet_count = 1;
  int unsigned beats_per_packet = 1;
  bit [31:0] base_data = 32'h9000_0000;
  int unsigned gap_cycles = 0;
  function new(string name = "cb_fixed_packet_sequence"); super.new(name); endfunction
  task body();
    cb_axis_item tr;
    for (int unsigned p = 0; p < packet_count; p++) begin
      for (int unsigned b = 0; b < beats_per_packet; b++) begin
        tr = cb_axis_item::type_id::create($sformatf("fixed_%0d_%0d", p, b));
        start_item(tr);
        tr.data = base_data + (p * 32'h100) + b;
        tr.keep = 4'hf;
        tr.last = (b == beats_per_packet - 1);
        tr.gap_cycles = gap_cycles;
        finish_item(tr);
      end
    end
  endtask
endclass
