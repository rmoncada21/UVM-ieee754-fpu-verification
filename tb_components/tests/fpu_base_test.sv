/*
 * File:    fpu_base_test.sv
 * - Project:  FPU RV32F  Verificación funcional UVM
 *
 * Description:
 *   Test base del ambiente. Instancia fpu_env_c y configura el agente
 *   como activo en build_phase; valida la topología y el estado del
 *   agente en end_of_elaboration_phase; imprime banner y metadatos de
 *   corrida (test, semilla, timeout) en start_of_simulation_phase. El
 *   run_phase arranca fpu_base_sequence_c directamente sobre el
 *   secuenciador del agente (smoke: estímulo completamente aleatorio).
 *   Los tests hijos heredan todas las fases y solo agregan su propia
 *   secuencia derivada de fpu_base_sequence_c.
 *
 * Dependencies:
 *   fpu_env.sv, fpu_agent.sv, fpu_base_sequence.sv
 */

class fpu_base_test_c extends uvm_test;
	`uvm_component_utils(fpu_base_test_c)

	// handler/puntero al ambiente
	fpu_env_c fpu_env;

	// Prototipos de funiones del base test
	extern function new(string name="fpu_base_test_c", uvm_component parent=null);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual function void end_of_elaboration_phase (uvm_phase phase);
	extern virtual function void start_of_simulation_phase(uvm_phase phase);
	extern virtual task run_phase(uvm_phase phase);
	extern virtual function fpu_base_sequence_c crear_secuencia();
	// TODO : implementar report_phase

endclass :  fpu_base_test_c

// Implementacion de los prototipos
// constructor
function fpu_base_test_c::new(string name="fpu_base_test_c", uvm_component parent=null);
	super.new(name, parent);
endfunction : new

// build phase
// instanciar los hijos del componente via factory de UVM
function void fpu_base_test_c::build_phase(uvm_phase phase);
	super.build_phase(phase);
		
	// creacion del ambiente
	fpu_env = fpu_env_c::type_id::create("fpu_env", this);
	
	uvm_config_db#(int)::set(this, "fpu_env.fpu_scoreboard", "semilla", $get_initial_random_seed());

	`uvm_info(this.get_type_name(),
			"FPU_ENV creado desde fpu_base_test",
			UVM_LOW);

	// variable para crear el agente activo
	uvm_config_db#(uvm_active_passive_enum)::set(
		this, "fpu_env.fpu_agent", "is_active", UVM_ACTIVE);

endfunction: build_phase

// EOEP
function void fpu_base_test_c::end_of_elaboration_phase (uvm_phase phase);
    super.end_of_elaboration_phase(phase);
        
    `uvm_info(this.get_type_name(),
		$sformatf(" listo. Numeros de Componentes=%0d",uvm_top.get_num_children()),
        UVM_LOW)

    if(fpu_env.fpu_agent == null) begin
        // EO_ERR: End Of Elaboration Error 
        `uvm_fatal("EO_ERR",
        	"El agente no ha sido creado, revisar el build_phase del fpu_agent");	
    end

    if(fpu_env.fpu_agent.get_is_active() == UVM_ACTIVE) begin
        `uvm_info(this.get_type_name(),
        	"el agente esta configurado como activo",
        	UVM_LOW)
    end else if ( fpu_env.fpu_agent.get_is_active() == UVM_PASSIVE ) begin
        `uvm_info(this.get_type_name(),
        	"el agente esta configurado como pasivo",
        	UVM_LOW)
    end else begin
        `uvm_error(this.get_type_name(),
        	"el agente esta configurado como DESCONOCIDO")
    end

    `uvm_info(this.get_type_name(),
    		"Topología del ambiente UVM:",
    		UVM_LOW)
    uvm_top.print_topology();
endfunction : end_of_elaboration_phase

// SOSP
// Imprimir banners, mostrar configuración aplicada al run.
// como por ejemplos, mostrar seed del test 
// configurar verbosity, setear timeouts, activar debug
// ajustes gloables de ejecucion
function void fpu_base_test_c::start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    $timeformat(0, 6, " s", 12);
    // uvm_top.phase_timeout = 10s;
    // Mostrar banner
    `CUSTOM_MSG("============================================================")
    `CUSTOM_MSG("  FPU RV32F  ·  Ambiente UVM de verificación funcional")
	`CUSTOM_MSG("  DUT: fpu_alu  ·  IEEE 754-2008 binary32")
	`CUSTOM_MSG("============================================================")

	`CUSTOM_INFO("FPU_TEST",
				$sformatf("Test     : %s", get_type_name()),
	           `BOLD)
	`CUSTOM_INFO("FPU_TEST",
	            $sformatf("Semilla  : %0h", $get_initial_random_seed()),
	           `BOLD)
	`CUSTOM_INFO("FPU_TEST",
	            $sformatf("Timeout  : %0t", uvm_top.phase_timeout),
	           `BOLD)
	`CUSTOM_MSG("============================================================")

endfunction : start_of_simulation_phase

// RP
// inicio de la simulacion
task fpu_base_test_c::run_phase(uvm_phase phase);
	fpu_base_sequence_c base_sequence;
		
	phase.raise_objection(this, "fpu_base_test_c: estimulo enviado");
		base_sequence = crear_secuencia();
		// randomizar secuencia: resuelve num_items_rand y signo_rand
		if(!base_sequence.randomize()) begin
			`uvm_error(this.get_type_name(),
				"Falló el randomize de la secuencia base")
		end
		base_sequence.start(fpu_env.fpu_agent.fpu_sequencer);
	phase.drop_objection(this, "fpu_base_test_c: estimulo completo");

endtask : run_phase

// crear secuencia
// los test derivados solo sobreescriben esta función para 
// devolver su suencie derivada de fpu_base_sequence_c
function fpu_base_sequence_c fpu_base_test_c::crear_secuencia();
	return fpu_base_sequence_c::type_id::create("base_sequence");
endfunction : crear_secuencia

// RP
// TODO : implementar report_phase
// virtual function void fpu_base_test_c::report_phase(uvm_phase phase);
// 	uvm_report_server report_server;
// 	super.report_phase(phase);
// endfunction: report_phase
