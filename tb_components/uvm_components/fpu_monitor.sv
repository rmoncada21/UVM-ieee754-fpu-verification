/*
 * File:    fpu_monitor.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Monitor UVM del agente. En build_phase obtiene la interfaz virtual
 *   (bif) vía uvm_config_db y crea el puerto de análisis tlm_mon_ap. El
 *   run_phase corre un lazo forever que, en cada flanco de subida de
 *   clk, muestrea entradas (opcode, modo de redondeo, operandos) y
 *   salidas (resultado, bit de comparación, banderas) del DUT hacia un
 *   único item reutilizado, y lo publica por tlm_mon_ap.
 *
 * Dependencies:
 *   fpu_if.sv, fpu_seq_item.sv
 */

class fpu_monitor_c extends uvm_monitor;
	`uvm_component_utils(fpu_monitor_c)
	virtual fpu_if bif;

	// uvm TLM emisor 
	uvm_analysis_port #(fpu_seq_item_c) tlm_mon_ap; // monitor analysis port = mon_ap

	// Prototipos de funciones del monitor
	extern function new(string name="fpu_monitor_c", uvm_component parent);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual task run_phase(uvm_phase phase);

endclass: fpu_monitor_c

// Implementación de funciones
// constructor
function fpu_monitor_c::new(string name="fpu_monitor_c", uvm_component parent);
	super.new(name, parent);
	// tlm_mon_ap = new("tlm_mon_ap", this);
endfunction : new

// BP
function void fpu_monitor_c::build_phase(uvm_phase phase);
	super.build_phase(phase);

	if( !uvm_config_db#(virtual fpu_if)::get(this, "", "vif", bif) ) begin
		`uvm_fatal(this.get_type_name(), 
			"FPU_MONITOR: No pudo obtener vif desde uvm_config_db" )
	end

	// crear el puerto tlm
	tlm_mon_ap = new("tlm_mon_ap",this);

	`uvm_info(this.get_type_name(),
		"tlm_mon_ap creado",
		UVM_LOW)

endfunction

// RP
task fpu_monitor_c::run_phase(uvm_phase phase);
	fpu_seq_item_c item;

	item = fpu_seq_item_c::type_id::create("item", this);

	forever begin : forever_loop
		@(posedge bif.clk);
			// rastrear las entradas
			item.op_code_i = fpu_op_code_e'(bif.op_code_i);
			item.r_mode_i = fpu_r_mode_e'(bif.r_mode_i);
			item.fp_a_i = bif.fp_a_i;
			item.fp_b_i = bif.fp_b_i;
			item.fp_c_i = bif.fp_c_i;
			// rastrear las salidas
			item.fp_result_o = bif.fp_result_o;
			item.cmp_result_o = bif.cmp_result_o;
			item.overflow_o = bif.overflow_o;
			item.underflow_o = bif.underflow_o;
			item.invalid_o = bif.invalid_o;
			tlm_mon_ap.write(item);
			// agregar funcin para mostrar los resultados
	end: forever_loop

endtask: run_phase
