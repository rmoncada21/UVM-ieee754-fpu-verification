/*
 * File:    fpu_scoreboard_c.sv
 * - Project:  FPU RV32F Verificación funcional UVM
 *
 * Description:
 *   Scoreboard UVM de la FPU RV32F. Recibe transacciones del monitor
 *   por tlm_scb_aimp (conectado en fpu_env_c vía item_collected_port
 *   del agente) y las compara contra el modelo de referencia DPI-C
 *   (golden_calcular / golden_result_s, fpu_types_pkg). La comparación
 *   es EXACTA (sin tolerancia de 1 ULP): resultado bit a bit y
 *   banderas derivadas con la semántica OPERATIVA del DUT no el NV/OV
 *   IEEE puro vía flags_esperadas_dut() (comparaciones fuerzan todo a
 *   0 por BUG-004; aritmética deriva uf de exponente 0 e inv como
 *   qNaN|ov|uf por BUG-003). Cada transacción se clasifica en tres
 *   cubos: num_pass, num_bug (firma BUG-001 reconocida por
 *   es_bug_conocido(), documentada y no cuenta como fallo nuevo) y
 *   num_fail (meta: 0). report_phase imprime el resumen final y la
 *   distribución por opcode.
 *
 * Dependencies:
 *   fpu_seq_item.sv, fpu_types_pkg.sv, fpu_dpic_ref_model_pkg.sv (dpi_fpu_reference,
 *   golden_result_s, golden_calcular), reference_model.c (DPI-C)
 */

class fpu_scoreboard_c extends uvm_scoreboard;
	`uvm_component_utils(fpu_scoreboard_c)
	
	// uvm_tlm_analysis_fifo ¿?
	// proviene del monitor, conectado en el env
	uvm_analysis_imp #(fpu_seq_item_c, fpu_scoreboard_c) tlm_scb_aimp;

	// Prototipos de funciones del scoreboard
	extern function new(string name="fpu_scoreboard_c", uvm_component parent);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual function void start_of_simulation_phase(uvm_phase phase);
	extern virtual task write(fpu_seq_item_c item);
	extern virtual function void report_phase(uvm_phase phase);

endclass: fpu_scoreboard_c

// Implementación de las funciones
// Constructor de la clase
function fpu_scoreboard_c::new(string name="fpu_scoreboard_c", uvm_component parent);
	super.new(name, parent);
endfunction : new

// BP
function void fpu_scoreboard_c::build_phase(uvm_phase phase);
	super.build_phase(phase);
	tlm_scb_aimp = new("tlm_scb_aimp", this);

	`uvm_info(this.get_type_name(),
			"TLM - uvm_analysis_imp: tlm_scb_aimp creado",
			UVM_LOW)
endfunction :  build_phase;

// SOSP
function void fpu_scoreboard_c::start_of_simulation_phase(uvm_phase phase);
	super.start_of_simulation_phase(phase);
	`uvm_info(this.get_type_name(),
		"Scoreboard, modelo de referencia DPI-C cargado",
		UVM_LOW)
endfunction : start_of_simulation_phase

// Write
// TODO: implementar funcion write
task fpu_scoreboard_c::write(fpu_seq_item_c item);
	`uvm_info(this.get_type_name(),
		" - ",
		UVM_LOW);
endtask

// RP
// TODO: hacer report phase
function void fpu_scoreboard_c::report_phase(uvm_phase phase);
	super.report_phase(phase);
endfunction : report_phase