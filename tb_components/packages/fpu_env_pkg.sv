`ifndef FPU_ENV_PKG
`define FPU_ENV_PKG
	
package fpu_env_pkg;
	`include "uvm_macros.svh"
	import uvm_pkg::*;
	import fpu_types_pkg::*;
	import fpu_types_constraints_pkg::*;

	// macros
	`include "tb_components/packages/msg_macros.svh"

	// seq item
	`include "tb_components/seq_item/fpu_seq_item.sv"
	`include "tb_components/seq_item/fpu_seq_constraints.sv"

	// sequences
	`include "tb_components/sequences/fpu_sequencer.sv"
	`include "tb_components/sequences/fpu_base_sequence.sv"
	// `include "tb_components/sequences/fpu_sequence_arith_normal.sv"

	// uvm component
	`include "tb_components/uvm_components/fpu_driver.sv"
	`include "tb_components/uvm_components/fpu_monitor.sv"
	`include "tb_components/uvm_components/fpu_agent.sv"
	`include "tb_components/uvm_components/fpu_scoreboard.sv"
	`include "tb_components/uvm_components/fpu_env.sv"

	// tests
	`include "tb_components/tests/fpu_base_test.sv"
	// `include "tb_components/tests/fpu_test_arith_normal.sv"


endpackage
import uvm_pkg::*;
import fpu_types_pkg::*;
import fpu_types_constraints_pkg::*;
`endif
