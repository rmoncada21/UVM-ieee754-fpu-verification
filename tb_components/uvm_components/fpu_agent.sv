/* 
 * File:    fpu_agent.sv
 * Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Agente UVM del ambiente. Instancia siempre el monitor (activo o
 *   pasivo) y expone su salida al exterior por item_collected_port;
 *   si is_active == UVM_ACTIVE (valor por defecto), instancia además
 *   sequencer y driver y los conecta entre sí en connect_phase. La
 *   condición de activo/pasivo se configura desde el test vía
 *   uvm_config_db (ver fpu_base_test_c::build_phase).
 *
 * Dependencies:
 *   fpu_monitor.sv, fpu_sequencer.sv, fpu_driver.sv, fpu_seq_item.sv,
 *   fpu_if.sv
 */

class fpu_agent_c extends uvm_agent;
	`uvm_component_utils(fpu_agent_c)

	fpu_monitor_c   fpu_monitor;   // monitor del agente
	fpu_sequencer_c fpu_sequencer; // sequencer del agente (solo activo)
	fpu_driver_c    fpu_driver;    // driver del agente (solo activo)

	virtual fpu_if bif; // interfaz con el DUT

	// puertos
	uvm_analysis_port #(fpu_seq_item_c) item_collected_port; // salida del agente al ambiente

	// Prototipos de funciones del agente
	extern function new(string name="fpu_agent_c", uvm_component parent); // constructor
	extern virtual function void build_phase(uvm_phase phase); // crea sub-componentes según is_active
	extern virtual function void connect_phase(uvm_phase phase); // conecta puertos internos y externos

endclass: fpu_agent_c

// Implementación de funciones
// Function: new
// Constructor del agente; delega la inicialización al uvm_agent base.
function fpu_agent_c::new(string name="fpu_agent_c", uvm_component parent);
	super.new(name, parent);
endfunction : new

// BP
// Function: build_phase
// Fase de construcción UVM: crea el monitor incondicionalmente y expone
// item_collected_port. Si el agente es activo (get_is_active() ==
// UVM_ACTIVE, valor por defecto), crea además sequencer y driver.
function void fpu_agent_c::build_phase(uvm_phase phase);
	super.build_phase(phase);
	
	// monitor siempre se crea ya sea el agente activo o pasivo		
	fpu_monitor = fpu_monitor_c::type_id::create("fpu_monitor", this);

	// puerto del agente
	item_collected_port = new("item_collected_port", this);

	// get_is_active() es por defecto UVM_ACTIVE
	if(this.get_is_active() == UVM_ACTIVE) begin
			fpu_sequencer = fpu_sequencer_c::type_id::create("fpu_sequencer", this);
			fpu_driver = fpu_driver_c::type_id::create("fpu_driver", this);
	end

	`uvm_info(this.get_type_name(),
			"Sequencer, Driver & Monitor creados",
			UVM_LOW);

endfunction: build_phase

// CP
// Function: connect_phase
// Fase de conexión UVM: enlaza la salida del monitor con el puerto
// externo del agente y, si el agente es activo, conecta el driver con
// el sequencer.
function void fpu_agent_c::connect_phase(uvm_phase phase);
	super.connect_phase(phase);

	// suscribers
	// exponer el puerto del agente al ambiente
	fpu_monitor.tlm_mon_ap.connect(item_collected_port);

	// conectar sequencer con el driver
	if(this.get_is_active() == UVM_ACTIVE) begin
		fpu_driver.seq_item_port.connect(fpu_sequencer.seq_item_export);
	end

endfunction: connect_phase