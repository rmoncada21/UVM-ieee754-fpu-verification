// Language: SystemVerilog
/*
 * File:    fpu_test_subnormal_arith.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Test subnormal_arith (testplan sec. 2.2.5, test nuevo de TFG-##00):
 *   aritmética dirigida con subnormales sobre fp_mul, su reúso en
 *   fp_madd/fp_msub y el sumador. Hereda todas las fases de
 *   fpu_base_test_c y solo sobreescribe crear_secuencia() para devolver
 *   fpu_sequence_subnormal_arith_c.
 *
 * Dependencies:
 *   fpu_base_test.sv, fpu_sequence_subnormal_arith.sv
 */

class fpu_test_subnormal_arith_c extends fpu_base_test_c;
	`uvm_component_utils(fpu_test_subnormal_arith_c)

	function new(string name = "fpu_test_subnormal_arith_c",
	             uvm_component parent = null);
		super.new(name, parent);
	endfunction : new

	/* Function: crear_secuencia
	devuelve la secuencia subnormal_arith; el run_phase heredado de
	fpu_base_test_c se encarga de randomizarla y arrancarla */
	virtual function fpu_base_sequence_c crear_secuencia();
		return fpu_sequence_subnormal_arith_c::type_id::create("subnormal_arith_sequence");
	endfunction : crear_secuencia

endclass : fpu_test_subnormal_arith_c