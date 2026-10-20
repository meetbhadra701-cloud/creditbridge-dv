class cb_credit_sequencer extends uvm_sequencer #(cb_link_item);
  `uvm_component_utils(cb_credit_sequencer)
  function new(string name = "cb_credit_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class cb_credit_return_driver extends uvm_driver #(cb_link_item);
  `uvm_component_utils(cb_credit_return_driver)
  virtual cb_credit_if vif;
  function new(string name = "cb_credit_return_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual cb_credit_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "cb_credit_if was not configured")
  endfunction
  task run_phase(uvm_phase phase);
    cb_link_item tr;
    vif.return_drv_cb.credit_return <= 0;
    forever begin
      seq_item_port.get_next_item(tr);
      repeat (tr.return_delay) @(vif.return_drv_cb);
      if (!vif.return_drv_cb.rst) begin
        vif.return_drv_cb.credit_return <= 1;
        @(vif.return_drv_cb);
        vif.return_drv_cb.credit_return <= 0;
      end
      seq_item_port.item_done();
    end
  endtask
endclass

class cb_credit_monitor extends uvm_component;
  `uvm_component_utils(cb_credit_monitor)
  virtual cb_credit_if vif;
  uvm_analysis_port #(cb_link_item) ap;
  function new(string name = "cb_credit_monitor", uvm_component parent = null);
    super.new(name, parent); ap = new("ap", this);
  endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual cb_credit_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "cb_credit_if was not configured")
  endfunction
  task run_phase(uvm_phase phase);
    cb_link_item tr;
    forever begin
      @(posedge vif.clk);
      if (!vif.rst && vif.valid) begin
        tr = cb_link_item::type_id::create("observed_output");
        tr.data = vif.data;
        tr.keep = vif.keep;
        tr.last = vif.last;
        tr.sample_time = $time;
        ap.write(tr);
      end
    end
  endtask
endclass

// This responder is intentionally driven only by observed output transfers;
// it cannot manufacture a return for a credit that was never consumed.
class cb_credit_responder extends uvm_component;
  `uvm_component_utils(cb_credit_responder)
  virtual cb_credit_if vif;
  uvm_tlm_analysis_fifo #(cb_link_item) observed_fifo;
  int unsigned fixed_delay = 1;
  function new(string name = "cb_credit_responder", uvm_component parent = null);
    super.new(name, parent); observed_fifo = new("observed_fifo", this);
  endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual cb_credit_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "cb_credit_if was not configured")
  endfunction
  task run_phase(uvm_phase phase);
    cb_link_item observed;
    vif.return_drv_cb.credit_return <= 0;
    forever begin
      observed_fifo.get(observed);
      repeat (fixed_delay) @(vif.return_drv_cb);
      if (!vif.return_drv_cb.rst) begin
        vif.return_drv_cb.credit_return <= 1;
        @(vif.return_drv_cb);
        vif.return_drv_cb.credit_return <= 0;
      end
    end
  endtask
endclass

class cb_credit_agent extends uvm_agent;
  `uvm_component_utils(cb_credit_agent)
  cb_credit_sequencer sequencer;
  cb_credit_return_driver driver;
  cb_credit_monitor monitor;
  function new(string name = "cb_credit_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = cb_credit_monitor::type_id::create("monitor", this);
    if (is_active == UVM_ACTIVE) begin
      sequencer = cb_credit_sequencer::type_id::create("sequencer", this);
      driver = cb_credit_return_driver::type_id::create("driver", this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (is_active == UVM_ACTIVE) driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
