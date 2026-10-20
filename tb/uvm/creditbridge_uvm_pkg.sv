// SPDX-License-Identifier: Apache-2.0
package creditbridge_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `include "transactions/cb_axis_item.sv"
  `include "transactions/cb_link_item.sv"
  `include "agents/cb_axis_agent.sv"
  `include "agents/cb_credit_agent.sv"
  `include "scoreboard/cb_scoreboard.sv"
  `include "coverage/cb_coverage.sv"
  `include "sequences/cb_sequences.sv"
  `include "tests/cb_env_and_tests.sv"
endpackage
