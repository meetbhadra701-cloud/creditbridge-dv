class cb_virtual_sequencer extends uvm_sequencer #(uvm_sequence_item);
  `uvm_component_utils(cb_virtual_sequencer)
  cb_axis_sequencer axis_seqr;
  cb_credit_sequencer credit_seqr;
  function new(string name = "cb_virtual_sequencer", uvm_component parent = null); super.new(name, parent); endfunction
endclass

class cb_env extends uvm_env;
  `uvm_component_utils(cb_env)
  cb_axis_agent axis_agent;
  cb_credit_agent credit_agent;
  cb_credit_responder credit_responder;
  cb_scoreboard scoreboard;
  cb_coverage coverage;
  cb_virtual_sequencer vseqr;
  function new(string name = "cb_env", uvm_component parent = null); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axis_agent = cb_axis_agent::type_id::create("axis_agent", this);
    credit_agent = cb_credit_agent::type_id::create("credit_agent", this);
    credit_responder = cb_credit_responder::type_id::create("credit_responder", this);
    scoreboard = cb_scoreboard::type_id::create("scoreboard", this);
    coverage = cb_coverage::type_id::create("coverage", this);
    vseqr = cb_virtual_sequencer::type_id::create("vseqr", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    axis_agent.monitor.ap.connect(scoreboard.input_fifo.analysis_export);
    axis_agent.monitor.ap.connect(coverage.analysis_export);
    credit_agent.monitor.ap.connect(scoreboard.output_fifo.analysis_export);
    credit_agent.monitor.ap.connect(credit_responder.observed_fifo.analysis_export);
    vseqr.axis_seqr = axis_agent.sequencer;
    vseqr.credit_seqr = credit_agent.sequencer;
  endfunction
endclass

class cb_base_test extends uvm_test;
  `uvm_component_utils(cb_base_test)
  cb_env env;
  function new(string name = "cb_base_test", uvm_component parent = null); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); env = cb_env::type_id::create("env", this);
  endfunction
endclass

class cb_uvm_smoke_test extends cb_base_test;
  `uvm_component_utils(cb_uvm_smoke_test)
  function new(string name = "cb_uvm_smoke_test", uvm_component parent = null); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    cb_smoke_sequence seq;
    phase.raise_objection(this);
    seq = cb_smoke_sequence::type_id::create("seq");
    seq.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(200);
    phase.drop_objection(this);
  endtask
endclass

class cb_uvm_random_test extends cb_base_test;
  `uvm_component_utils(cb_uvm_random_test)
  function new(string name = "cb_uvm_random_test", uvm_component parent = null); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    cb_random_packet_sequence seq;
    phase.raise_objection(this);
    seq = cb_random_packet_sequence::type_id::create("seq");
    if ((seq.randomize() with { packet_count == 16; max_packet_beats == 8; }) == 0) `uvm_fatal("TEST_RAND", "Sequence randomization failed");
    seq.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(2000);
    phase.drop_objection(this);
  endtask
endclass

// Legal stress profile used to exercise credit exhaustion, FIFO occupancy
// boundaries, and source backpressure without manufacturing illegal returns.
class cb_uvm_coverage_stress_test extends cb_base_test;
  `uvm_component_utils(cb_uvm_coverage_stress_test)
  function new(string name = "cb_uvm_coverage_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    cb_random_packet_sequence seq;
    phase.raise_objection(this);
    env.credit_responder.fixed_delay = 20;
    seq = cb_random_packet_sequence::type_id::create("seq");
    if ((seq.randomize() with { packet_count == 8; max_packet_beats == 8; }) == 0)
      `uvm_fatal("TEST_RAND", "Coverage stress sequence randomization failed");
    seq.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(5000);
    phase.drop_objection(this);
  endtask
endclass

class cb_uvm_reset_test extends cb_base_test;
  `uvm_component_utils(cb_uvm_reset_test)
  function new(string name = "cb_uvm_reset_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    cb_fixed_packet_sequence pre_reset, post_reset;
    phase.raise_objection(this);
    env.credit_responder.fixed_delay = 1;
    pre_reset = cb_fixed_packet_sequence::type_id::create("pre_reset");
    pre_reset.packet_count = 1; pre_reset.beats_per_packet = 4;
    pre_reset.base_data = 32'hA000_0000; pre_reset.gap_cycles = 0;
    pre_reset.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(100);
    repeat (8) @(posedge env.scoreboard.axis_vif.clk);
    post_reset = cb_fixed_packet_sequence::type_id::create("post_reset");
    post_reset.packet_count = 1; post_reset.beats_per_packet = 8;
    post_reset.base_data = 32'hB000_0000; post_reset.gap_cycles = 0;
    post_reset.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(200);
    phase.drop_objection(this);
  endtask
endclass

class cb_uvm_credit_return_test extends cb_base_test;
  `uvm_component_utils(cb_uvm_credit_return_test)
  function new(string name = "cb_uvm_credit_return_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    cb_fixed_packet_sequence simultaneous, depletion;
    phase.raise_objection(this);
    env.credit_responder.fixed_delay = 1;
    simultaneous = cb_fixed_packet_sequence::type_id::create("simultaneous");
    simultaneous.packet_count = 1; simultaneous.beats_per_packet = 4;
    simultaneous.base_data = 32'hC000_0000; simultaneous.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(100);
    repeat (8) @(posedge env.scoreboard.axis_vif.clk);
    env.credit_responder.fixed_delay = 20;
    depletion = cb_fixed_packet_sequence::type_id::create("depletion");
    depletion.packet_count = 2; depletion.beats_per_packet = 4;
    depletion.base_data = 32'hD000_0000; depletion.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(500);
    repeat (30) @(posedge env.scoreboard.axis_vif.clk);
    phase.drop_objection(this);
  endtask
endclass

class cb_uvm_coverage_target_test extends cb_base_test;
  `uvm_component_utils(cb_uvm_coverage_target_test)
  function new(string name = "cb_uvm_coverage_target_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    cb_fixed_packet_sequence singles, long_packet;
    phase.raise_objection(this);
    // Delayed returns deliberately create legal low/exhausted credit states
    // and source backpressure; no illegal return is generated.
    env.credit_responder.fixed_delay = 20;
    singles = cb_fixed_packet_sequence::type_id::create("singles");
    singles.packet_count = 8; singles.beats_per_packet = 1;
    singles.base_data = 32'hE000_0000; singles.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(500);
    repeat (40) @(posedge env.scoreboard.axis_vif.clk);
    env.credit_responder.fixed_delay = 2;
    long_packet = cb_fixed_packet_sequence::type_id::create("long_packet");
    long_packet.packet_count = 1; long_packet.beats_per_packet = 12;
    long_packet.base_data = 32'hF000_0000; long_packet.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(1000);
    repeat (40) @(posedge env.scoreboard.axis_vif.clk);
    phase.drop_objection(this);
  endtask
endclass

class cb_uvm_coverage_cross_test extends cb_base_test;
  `uvm_component_utils(cb_uvm_coverage_cross_test)
  function new(string name = "cb_uvm_coverage_cross_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    cb_fixed_packet_sequence long_full, short_pre, short_available, long_available, long_exhausted, one_stall;
    phase.raise_objection(this);
    // A paced long packet keeps the initial credit state visible at packet
    // completion and targets long_x_full.
    env.credit_responder.fixed_delay = 1;
    long_full = cb_fixed_packet_sequence::type_id::create("long_full");
    long_full.packet_count = 1; long_full.beats_per_packet = 12;
    long_full.base_data = 32'h1100_0000; long_full.gap_cycles = 2;
    long_full.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(500);
    repeat (20) @(posedge env.scoreboard.axis_vif.clk);

    // Consume a controlled number of credits without allowing returns, then
    // complete a short packet in the available range.
    env.credit_responder.fixed_delay = 20;
    short_pre = cb_fixed_packet_sequence::type_id::create("short_pre");
    short_pre.packet_count = 3; short_pre.beats_per_packet = 1;
    short_pre.base_data = 32'h1200_0000; short_pre.start(env.axis_agent.sequencer);
    short_available = cb_fixed_packet_sequence::type_id::create("short_available");
    short_available.packet_count = 1; short_available.beats_per_packet = 2;
    short_available.base_data = 32'h1210_0000; short_available.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(300);
    env.credit_responder.fixed_delay = 4;
    long_available = cb_fixed_packet_sequence::type_id::create("long_available");
    long_available.packet_count = 1; long_available.beats_per_packet = 12;
    long_available.base_data = 32'h1300_0000; long_available.gap_cycles = 5;
    long_available.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(700);
    repeat (50) @(posedge env.scoreboard.axis_vif.clk);

    // Delayed legal returns make the FIFO accept buffered beats while credits
    // are exhausted, targeting long_x_exhausted.
    env.credit_responder.fixed_delay = 20;
    long_exhausted = cb_fixed_packet_sequence::type_id::create("long_exhausted");
    long_exhausted.packet_count = 1; long_exhausted.beats_per_packet = 12;
    long_exhausted.base_data = 32'h1400_0000; long_exhausted.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(1000);
    repeat (50) @(posedge env.scoreboard.axis_vif.clk);
    env.credit_responder.fixed_delay = 2;
    one_stall = cb_fixed_packet_sequence::type_id::create("one_stall");
    one_stall.packet_count = 1; one_stall.beats_per_packet = 16;
    one_stall.base_data = 32'h1500_0000; one_stall.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(1000);
    repeat (50) @(posedge env.scoreboard.axis_vif.clk);
    phase.drop_objection(this);
  endtask
endclass

class cb_uvm_backpressure_one_test extends cb_base_test;
  `uvm_component_utils(cb_uvm_backpressure_one_test)
  function new(string name = "cb_uvm_backpressure_one_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    cb_fixed_packet_sequence preload, one_cycle;
    phase.raise_objection(this);
    env.credit_responder.fixed_delay = 20;
    preload = cb_fixed_packet_sequence::type_id::create("preload");
    preload.packet_count = 8; preload.beats_per_packet = 1;
    preload.base_data = 32'h1600_0000; preload.start(env.axis_agent.sequencer);
    // Change the legal return latency before the next output burst. This
    // creates a single credit-recovery edge after depletion.
    env.credit_responder.fixed_delay = 1;
    one_cycle = cb_fixed_packet_sequence::type_id::create("one_cycle");
    one_cycle.packet_count = 1; one_cycle.beats_per_packet = 16;
    one_cycle.base_data = 32'h1700_0000; one_cycle.start(env.axis_agent.sequencer);
    env.scoreboard.wait_for_drain(1000);
    repeat (60) @(posedge env.scoreboard.axis_vif.clk);
    phase.drop_objection(this);
  endtask
endclass
