`ifndef FPU_ENV_PKG
`define FPU_ENV_PKG
	package fpu_env_pkg;
	    `include "uvm_macros.svh"
	    import uvm_pkg::*;
	    import fpu_types_pkg::*;

	    // packages
	    `include "tb_components/packages/msg_macros.svh"

	    // sequences
	    // `include "tb_components/sequences/fpu_base_sequences.sv"

	    // uvm component
	    `include "tb_components/seq_item/fpu_seq_item.sv"
	    `include "tb_components/uvm_components/fpu_driver.sv"
	    `include "tb_components/uvm_components/fpu_monitor.sv"
	    `include "tb_components/uvm_components/fpu_agent.sv"
	    `include "tb_components/uvm_components/fpu_scoreboard.sv"
	    `include "tb_components/uvm_components/fpu_env.sv"

	    // tests
	    `include "tb_components/tests/fpu_base_test.sv"


	endpackage
	import fpu_env_pkg::*;
	import uvm_pkg::*;
`endif
