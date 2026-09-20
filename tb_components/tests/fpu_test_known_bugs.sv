/*
 * File:    fpu_test_known_bugs.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Test known_bugs (testplan sec. 2.2.6, test nuevo de TFG-##00):
 *   registro ejecutable de las desviaciones documentadas del DUT. Una
 *   pasada por la tabla de vectores canónicos; el scoreboard clasifica
 *   cada uno en num_pass o num_bug (nunca num_fail: ese es el invariante
 *   del test). Hereda todas las fases de fpu_base_test_c y solo
 *   sobreescribe crear_secuencia() para devolver fpu_sequence_known_bugs_c.
 *
 * Dependencies:
 *   fpu_base_test.sv, fpu_sequence_known_bugs.sv
 */

class fpu_test_known_bugs_c extends fpu_base_test_c;
	`uvm_component_utils(fpu_test_known_bugs_c)

	function new(string name = "fpu_test_known_bugs_c", uvm_component parent = null);
		super.new(name, parent);
	endfunction : new

	// Function: crear_secuencia
	// devuelve la secuencia known_bugs; el run_phase heredado de
	// fpu_base_test_c se encarga de randomizarla y arrancarla
	virtual function fpu_base_sequence_c crear_secuencia();
		return fpu_sequence_known_bugs_c::type_id::create("known_bugs_sequence");
	endfunction : crear_secuencia

endclass : fpu_test_known_bugs_c