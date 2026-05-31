class fpu_agent_c extends uvm_agent;
	`uvm_component_utils(fpu_agent_c)

	fpu_monitor_c fpu_monitor;
	fpu_sequencer_c fpu_sequencer;
	fpu_driver_c fpu_driver;

	virtual fpu_if bif;

	// puertos
	uvm_analysis_port #(fpu_seq_item_c) item_collected_port;

	// ¿sequencer?
	// uvm_sequencer#(fpu_seq_item_c) agent_seq;

	// constructor
	function new(string name="fpu_agent_c", uvm_component parent);
		super.new(name, parent);
	endfunction : new
	
	// build_phase
	virtual function void build_phase(uvm_phase phase);
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

		// agent_seq = uvm_sequencer#(fpu_seq_item_c)::type_id::create("agent_seq", this);

		`uvm_info(this.get_type_name(),
				"FPU_SEQUENCER, FPU_DRIVER & FPU_MONITOR creados desde fpu_agent",
				UVM_LOW);

	endfunction: build_phase
	
	// connect_phase - conectar puertos
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		// suscribers
		// exponer el puerto del agente al ambiente
		fpu_monitor.tlm_mon_ap.connect(item_collected_port);

		// conectar sequencer con el driver
		if(this.get_is_active() == UVM_ACTIVE) begin
			fpu_driver.seq_item_port.connect(fpu_sequencer.seq_item_export);
		end

	endfunction: connect_phase


endclass: fpu_agent_c