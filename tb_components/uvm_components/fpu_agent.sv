class fpu_agent_c extends uvm_agent;
	`uvm_component_utils(fpu_agent_c)

	fpu_driver_c fpu_driver;
	fpu_monitor_c fpu_monitor;
	virtual fpu_if bif;

	// puertos

	// ¿sequencer?
	// uvm_sequencer#(fpu_seq_item_c) agent_seq;

	// constructor
	function new(string name="fpu_agent_c", uvm_component parent);
		super.new(name, parent);
	endfunction : new
	
	// build_phase
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		fpu_driver = fpu_driver_c::type_id::create("fpu_driver", this);
		fpu_monitor = fpu_monitor_c::type_id::create("fpu_monitor", this);
		// agent_seq = uvm_sequencer#(fpu_seq_item_c)::type_id::create("agent_seq", this);
		
		// ¿Hacer monitor active/pasive?
		// Crear/ instanciar el sequencer

		`uvm_info("FPU_AGENT",
				"FPU_DRIVER & FPU_MONITOR creados desde fpu_agent",
				UVM_LOW);

	endfunction: build_phase
	
	// connect_phase - conectar puertos
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		// conectar puertos luego

	endfunction: connect_phase


endclass: fpu_agent_c