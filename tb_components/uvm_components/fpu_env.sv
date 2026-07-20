/*
 * File:    fpu_env.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Ambiente UVM del proyecto. En build_phase instancia el agente
 *   (fpu_agent_c) y el scoreboard (fpu_scoreboard_c); en connect_phase
 *   conecta item_collected_port del agente al analysis_imp del
 *   scoreboard. La conexión con el coverage queda pendiente (TODO).
 *
 * Dependencies:
 *   fpu_agent.sv, fpu_scoreboard.sv, fpu_if.sv
 */

class fpu_env_c  extends uvm_env;
	`uvm_component_utils(fpu_env_c)
	
	fpu_agent_c fpu_agent;
	fpu_scoreboard_c fpu_scoreboard;

	// QUITAR / aun sin uso
	virtual fpu_if bif;

	// Prototipos de funciones del ambiente
	extern function new(string name="fpu_env_c", uvm_component parent);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual function void connect_phase(uvm_phase phase);
	extern virtual function void start_of_simulation_phase(uvm_phase phase);

endclass: fpu_env_c

// Implementación de funciones
// constructor
function fpu_env_c::new(string name="fpu_env_c", uvm_component parent);
	super.new(name, parent);
endfunction: new

// BP
// ------------------------------------------------------------
// Function: build_phase
// Instancia: agente, configura el vif y crea el scoreboard.
// ------------------------------------------------------------
function void fpu_env_c::build_phase(uvm_phase phase);
	super.build_phase(phase);
	fpu_agent = fpu_agent_c::type_id::create("fpu_agent", this);
	// scoreboard
	fpu_scoreboard = fpu_scoreboard_c::type_id::create("fpu_scoreboard", this);
	// coverage

	`uvm_info(this.get_type_name(),
			"Agent & Scoreboard creados",
			UVM_LOW)

endfunction: build_phase

// CP
// connect phase, agent, driver, monitor 
function void fpu_env_c::connect_phase(uvm_phase phase);
	super.connect_phase(phase);
	// conexion por medio del puerto del agente al exterior
	fpu_agent.item_collected_port.connect(fpu_scoreboard.tlm_scb_aimp);
	// conexion directa del monitor al agente - mala pratica
	// fpu_agent.fpu_monitor.tlm_mon_ap.connect(fpu_scoreboard.tlm_scb_aimp);
	
	// TODO: agregar conexion con el coverage
	// fpu_agent.item_collected_port.connect(fpu_cov."NOMBRE_PUERTO");
endfunction: connect_phase

// SOSP
function void fpu_env_c::start_of_simulation_phase(uvm_phase phase);
	super.start_of_simulation_phase(phase);
	`uvm_info(this.get_type_name(),
		"Enviroment listo, puertos TLM cableados",
		UVM_LOW)

endfunction: start_of_simulation_phase
