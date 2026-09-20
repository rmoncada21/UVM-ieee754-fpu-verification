/*
 * File:    fpu_test_rounding.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Test rounding (testplan sec. 2.2.3, versión mejorada): cross
 *   determinista operación × modo de redondeo, con estímulo inexacto
 *   genérico y empates dirigidos (única forma de distinguir RNE de
 *   RMM). Hereda todas las fases de fpu_base_test_c y solo
 *   sobreescribe crear_secuencia() para devolver
 *   fpu_sequence_rounding_c.
 *
 * Dependencies:
 *   fpu_base_test.sv, fpu_sequence_rounding.sv
 */

class fpu_test_rounding_c extends fpu_base_test_c;
	`uvm_component_utils(fpu_test_rounding_c)

	function new(string name = "fpu_test_rounding_c", uvm_component parent = null);
		super.new(name, parent);
	endfunction : new

	// Function: crear_secuencia
	// devuelve la secuencia rounding; el run_phase heredado de
	// fpu_base_test_c se encarga de randomizarla y arrancarla
	virtual function fpu_base_sequence_c crear_secuencia();
		return fpu_sequence_rounding_c::type_id::create("rounding_sequence");
	endfunction : crear_secuencia

endclass : fpu_test_rounding_c