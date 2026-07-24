/*
 * File:    fpu_test_cmp.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Test cmp (testplan sec. 2.2.4, test nuevo de TFG-##00): verificación
 *   de las operaciones de comparación feq.s / flt.s / fle.s y de la
 *   salida dedicada cmp_result_o. Hereda todas las fases de
 *   fpu_base_test_c y solo sobreescribe crear_secuencia() para devolver
 *   fpu_sequence_cmp_c.
 *
 * Dependencies:
 *   fpu_base_test.sv, fpu_sequence_cmp.sv
 */

class fpu_test_cmp_c extends fpu_base_test_c;
	`uvm_component_utils(fpu_test_cmp_c)

	function new(string name = "fpu_test_cmp_c", uvm_component parent = null);
		super.new(name, parent);
	endfunction : new

	// Function: crear_secuencia
	// devuelve la secuencia cmp; el run_phase heredado de fpu_base_test_c
	// se encarga de randomizarla y arrancarla
	virtual function fpu_base_sequence_c crear_secuencia();
		return fpu_sequence_cmp_c::type_id::create("cmp_sequence");
	endfunction : crear_secuencia

endclass : fpu_test_cmp_c