class cb_axis_sequencer extends uvm_sequencer #(cb_axis_item);
  `uvm_component_utils(cb_axis_sequencer)
  function new(string name = "cb_axis_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class cb_axis_driver extends uvm_driver #(cb_axis_item);
  `uvm_component_utils(cb_axis_driver)
  virtual cb_axis_if vif;

  function new(string name = "cb_axis_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cb_axis_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "cb_axis_if was not configured")
  endfunction
  task run_phase(uvm_phase phase);
    cb_axis_item tr;
    vif.drv_cb.tvalid <= 0;
    forever begin
      seq_item_port.get_next_item(tr);
      repeat (tr.gap_cycles) @(vif.drv_cb);
      vif.drv_cb.tdata <= tr.data;
      vif.drv_cb.tkeep <= tr.keep;
      vif.drv_cb.tlast <= tr.last;
      vif.drv_cb.tvalid <= 1;
      do @(vif.drv_cb); while (!vif.drv_cb.tready || vif.drv_cb.rst);
      vif.drv_cb.tvalid <= 0;
      seq_item_port.item_done();
    end
  endtask
endclass

class cb_axis_monitor extends uvm_component;
  `uvm_component_utils(cb_axis_monitor)
  virtual cb_axis_if vif;
  uvm_analysis_port #(cb_axis_item) ap;

  function new(string name = "cb_axis_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual cb_axis_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "cb_axis_if was not configured")
  endfunction
  task run_phase(uvm_phase phase);
    cb_axis_item tr;
    forever begin
      @(posedge vif.clk);
      if (!vif.rst && vif.tvalid && vif.tready) begin
        tr = cb_axis_item::type_id::create("accepted_input");
        tr.data = vif.tdata;
        tr.keep = vif.tkeep;
        tr.last = vif.tlast;
        tr.sample_time = $time;
        ap.write(tr);
      end
    end
  endtask
endclass

class cb_axis_agent extends uvm_agent;
  `uvm_component_utils(cb_axis_agent)
  cb_axis_sequencer sequencer;
  cb_axis_driver driver;
  cb_axis_monitor monitor;
  function new(string name = "cb_axis_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = cb_axis_monitor::type_id::create("monitor", this);
    if (is_active == UVM_ACTIVE) begin
      sequencer = cb_axis_sequencer::type_id::create("sequencer", this);
      driver = cb_axis_driver::type_id::create("driver", this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (is_active == UVM_ACTIVE) driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
