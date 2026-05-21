`ifndef FPU_ENV_PKG
`define FPU_ENV_PKG
	package fpu_env_pkg;
	    `include "uvm_macros.svh"
	    import uvm_pkg::*;
	    import fpu_types_pkg::*;

	    `include "tb_components/packages/msg_macros.svh"

	    `include "tb_components/seq_item/fpu_seq_item.sv"
	    `include "tb_components/uvm_components/fpu_driver.sv"

	endpackage
	import fpu_env_pkg::*;
	import uvm_pkg::*;
`endif
