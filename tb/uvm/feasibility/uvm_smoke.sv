// SPDX-License-Identifier: Apache-2.0
// Feature gate: run only with a simulator and an Accellera UVM library.
`include "uvm_macros.svh"
import uvm_pkg::*;

class uvm_smoke_item extends uvm_sequence_item;
  rand bit [7:0] payload;
  constraint nonzero_payload { payload inside {[8'h01:8'hfe]}; }
  `uvm_object_utils(uvm_smoke_item)

  function new(string name = "uvm_smoke_item");
    super.new(name);
  endfunction
endclass

class uvm_smoke_producer extends uvm_component;
  `uvm_component_utils(uvm_smoke_producer)
  uvm_analysis_port #(uvm_smoke_item) ap;
  function new(string name = "uvm_smoke_producer", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction
endclass

class uvm_smoke_subscriber extends uvm_subscriber #(uvm_smoke_item);
  `uvm_component_utils(uvm_smoke_subscriber)
  int unsigned write_count;
  bit [7:0] observed_payload;
  function new(string name = "uvm_smoke_subscriber", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void write(uvm_smoke_item t);
    write_count++;
    observed_payload = t.payload;
  endfunction
endclass

class uvm_smoke_test extends uvm_test;
  `uvm_component_utils(uvm_smoke_test)
  uvm_smoke_item item;
  uvm_smoke_producer producer;
  uvm_smoke_subscriber subscriber;

  function new(string name = "uvm_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    producer = uvm_smoke_producer::type_id::create("producer", this);
    subscriber = uvm_smoke_subscriber::type_id::create("subscriber", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    producer.ap.connect(subscriber.analysis_export);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    item = uvm_smoke_item::type_id::create("item");
    if (!item.randomize())
      `uvm_fatal("SMOKE_RAND", "Constrained randomization failed")
    producer.ap.write(item);
    if ((subscriber.write_count != 1) || (subscriber.observed_payload != item.payload))
      `uvm_fatal("SMOKE_TLM", "Analysis-port transaction was not delivered")
    `uvm_info("SMOKE", $sformatf("factory/randomized payload=%0h", item.payload), UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

module uvm_smoke_top;
  initial run_test("uvm_smoke_test");
endmodule
