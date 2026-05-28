class fpu_env_c  extends uvm_env;
	`uvm_component_utils(fpu_env_c)
	
	fpu_agent_c fpu_agent;
	fpu_scoreboard_c fpu_scoreboard;

	// QUITAR / aun sin uso
	virtual fpu_if bif;

	// constructor
	function new(string name="fpu_env_c", uvm_component parent);
		super.new(name, parent);
	endfunction: new
	
	// ------------------------------------------------------------
	// Function: build_phase
	// Instancia: agente, configura el vif y crea el scoreboard.
	// ------------------------------------------------------------
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		fpu_agent = fpu_agent_c::type_id::create("fpu_agent", this);
		// scoreboard
		fpu_scoreboard = fpu_scoreboard_c::type_id::create("fpu_scoreboard", this);
		// coverage

		`uvm_info("FPU_ENV",
				"FPU_AGENT & FPU_SCOREBOARD creados desde fpu_env",
				UVM_LOW);

	endfunction: build_phase

	// connect phase, agent, driver, monitor 
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		fpu_agent.fpu_monitor.tlm_mon_ap.connect(fpu_scoreboard.tlm_mon_aimp);
	endfunction: connect_phase



endclass: fpu_env_c