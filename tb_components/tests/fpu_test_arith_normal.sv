// Language: SystemVerilog
/*
 * File:    fpu_test_arith_normal.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Test arith_normal (testplan sec. 2.2.1.1): funcionalidad aritmética
 *   general con operandos normales en banda segura. Hereda todas las
 *   fases de fpu_base_test_c y solo sobreescribe crear_secuencia() para
 *   devolver fpu_arith_normal_sequence_c.
 *
 * Dependencies:
 *   fpu_base_test.sv, fpu_arith_normal_sequence.sv
 */

class fpu_test_arith_normal_c extends fpu_base_test_c;
	`uvm_component_utils(fpu_test_arith_normal_c)

	function new(string name = "fpu_test_arith_normal_c", uvm_component parent = null);
		super.new(name, parent);
	endfunction : new

	// Function: crear_secuencia
	// devuelve la secuencia arith_normal; el run_phase heredado de
	// fpu_base_test_c se encarga de randomizarla y arrancarla
	virtual function fpu_base_sequence_c crear_secuencia();
		return fpu_sequence_arith_normal_c::type_id::create("arith_normal_sequence");
	endfunction : crear_secuencia

endclass : fpu_test_arith_normal_c