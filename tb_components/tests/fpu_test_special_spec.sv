/*
 * File:    fpu_test_special_spec.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Test special_spec (testplan sec. 2.2.2): pares de operandos
 *   especiales (±0, ±inf, NaN) y propagación de NaN sobre las cinco
 *   operaciones aritméticas. Hereda todas las fases de fpu_base_test_c
 *   y solo sobreescribe crear_secuencia() para devolver
 *   fpu_sequence_special_spec_c.
 *
 * Dependencies:
 *   fpu_base_test.sv, fpu_sequence_special_spec.sv
 */

class fpu_test_special_spec_c extends fpu_base_test_c;
	`uvm_component_utils(fpu_test_special_spec_c)

	function new(string name = "fpu_test_special_spec_c", uvm_component parent = null);
		super.new(name, parent);
	endfunction : new

	// Function: crear_secuencia
	// devuelve la secuencia special_spec; el run_phase heredado de
	// fpu_base_test_c se encarga de randomizarla y arrancarla
	virtual function fpu_base_sequence_c crear_secuencia();
		return fpu_sequence_special_spec_c::type_id::create("special_spec_sequence");
	endfunction : crear_secuencia

endclass : fpu_test_special_spec_c