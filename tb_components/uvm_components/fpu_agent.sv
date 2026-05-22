class fpu_agent_c extends;
	`uvm_components_utils(fpu_agent_c);

	fpu_driver_c fpu_driver;
	fpu_monitor_c fpu_monitor;
	virtual fpu_if bif;

	// puertos

	// ¿sequencer?

	// constructor
	function new(string name="fpu_agent_c", uvm_component parent);
		super.new(name, parent);
	endfunction : new
	
	// build_phase
	virtual function build_phase(uvm_phase phase);
		super.build_phase(phase);
		fpu_driver = fpu_driver_c::type_id::create::("fpu_driver", this);
		fpu_monitor = fpu_monitor::type_id::create::("fpu_monitor", this);

		// ¿Hacer monitor active/pasive?
	endfunction: build_phase
	
	// connect_phase - conectar puertos
	virtual function connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		// conectar puerto luego

	endfunction: connect_phase


endclass: fpu_agent_c