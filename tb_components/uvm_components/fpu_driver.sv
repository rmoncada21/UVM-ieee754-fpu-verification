/*
 * File:    fpu_driver.sv
 * Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Driver UVM del agente. En build_phase obtiene la interfaz virtual
 *   (bif) vía uvm_config_db. El run_phase corre un lazo forever que
 *   espera items del sequencer, descarta ítems nulos con uvm_error, y
 *   delega el manejo de señales a drive_item(): en cada flanco de
 *   subida de clk, conduce opcode, modo de redondeo y los tres
 *   operandos hacia el DUT.
 *
 * Dependencies:
 *   fpu_if.sv, fpu_seq_item.sv
 */

class fpu_driver_c extends uvm_driver #(fpu_seq_item_c);
	`uvm_component_utils(fpu_driver_c)

	// handler de la interfas con Dut
	virtual fpu_if bif; // bus interface

	// Prototipos de funciones del driver
	extern function new(string name="fpu_driver_c", uvm_component parent); // constructor
	extern virtual function void build_phase(uvm_phase phase); // obtiene vif desde config_db
	extern virtual function void start_of_simulation_phase(uvm_phase phase); // aviso de driver listo
	extern virtual task run_phase(uvm_phase phase); // lazo principal de conducción
	extern task drive_item(fpu_seq_item_c item); // conduce señales del item al DUT

endclass: fpu_driver_c

// Implementación de funciones
// Function: new
// Constructor del driver; delega la inicialización al uvm_driver base.
function fpu_driver_c::new(string name="fpu_driver_c", uvm_component parent);
	super.new(name, parent);
endfunction

// BP
// Function: build_phase
// Fase de construcción UVM: obtiene la interfaz virtual (vif) publicada
// en la config_db y la asigna a bif. Si no está disponible, aborta la
// simulación con uvm_fatal.
function void fpu_driver_c::build_phase(uvm_phase phase);
	super.build_phase(phase);

	if( !uvm_config_db#(virtual fpu_if)::get(this, "", "vif", bif) ) begin
		`uvm_fatal(this.get_type_name(), 
			"FPU_DRIVER: No pudo obtener vif desde uvm_config_db")
	end

endfunction: build_phase

//SOSP
// Function: start_of_simulation_phase
// Fase previa al inicio de la simulación: reporta que el driver está
// listo para recibir items del sequencer.
function void fpu_driver_c::start_of_simulation_phase(uvm_phase phase);
	super.start_of_simulation_phase(phase);
	`uvm_info(this.get_type_name(),
		"Driver esperando items del sequencer",
		UVM_LOW)
endfunction: start_of_simulation_phase

// RP
// Task: run_phase
// Lazo principal del driver:
// 1. Espera un item del sequencer.
// 2. Llama drive_item().
// 3. Publica la transacción al scoreboard por drv_ap.
task fpu_driver_c::run_phase(uvm_phase phase);
	fpu_seq_item_c item;
	
	forever begin
		seq_item_port.get_next_item(item);
			// revisar integridad del paquete
			if(item == null) begin
				`uvm_error(this.get_type_name(), "Se recibio un item nulo") 
				seq_item_port.item_done();
				continue;
			end
			drive_item(item);
		seq_item_port.item_done();
	end

endtask: run_phase

// Task: drive_item
// Conduce hacia el DUT los campos del item (opcode, modo de redondeo y
// los tres operandos) en el flanco de subida de clk.
task fpu_driver_c::drive_item(fpu_seq_item_c item);
	@(posedge bif.clk);
		bif.op_code_i <= item.op_code_i;
		bif.r_mode_i  <= item.r_mode_i;
		bif.fp_a_i    <= item.fp_a_i;
		bif.fp_b_i    <= item.fp_b_i;
		bif.fp_c_i    <= item.fp_c_i;
endtask: drive_item