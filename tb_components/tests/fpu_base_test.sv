/*
 * File:    fpu_base_test.sv
 * Project:  FPU RV32F — Verificación funcional UVM
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

	// variables para mover el archivo de salida tr_db.log de raiz a logs
	uvm_text_tr_database base_datos_tr; // base de datos de transaction recording redirigida a logs/
	uvm_coreservice_t    uvm_servicio; // servicio core de UVM, usado para fijar la base de datos por defecto

	// handler/puntero al ambiente
	fpu_env_c fpu_env; // ambiente UVM del test

	// Prototipos de funiones del base test
	extern function new(string name="fpu_base_test_c", uvm_component parent=null); // constructor
	extern virtual function void build_phase(uvm_phase phase); // crea el ambiente y configura el agente como activo
	extern virtual function void end_of_elaboration_phase (uvm_phase phase); // valida topología y estado del agente
	extern virtual function void start_of_simulation_phase(uvm_phase phase); // imprime banner y metadatos de la corrida
	extern virtual task run_phase(uvm_phase phase); // arranca la secuencia sobre el sequencer del agente
	extern virtual function fpu_base_sequence_c crear_secuencia(); // hook de fábrica para la secuencia del test

endclass :  fpu_base_test_c

// Implementacion de los prototipos
// Function: new
// Constructor del test base; delega la inicialización al uvm_test base.
function fpu_base_test_c::new(string name="fpu_base_test_c", uvm_component parent=null);
	super.new(name, parent);
endfunction : new

// build phase
// Function: build_phase
// Fase de construcción UVM: redirige la base de datos de transaction
// recording a logs/tr_db.log, crea el ambiente vía factory, publica la
// semilla inicial para el scoreboard y configura el agente como activo.
function void fpu_base_test_c::build_phase(uvm_phase phase);
	super.build_phase(phase);

	// redirigir la base de datos de transaction recording de UVM
	// (por defecto genera tr_db.log raiz)
	base_datos_tr   = new("base_datos_tr");
	base_datos_tr.set_file_name("logs/tr_db.log");
	uvm_servicio = uvm_coreservice_t::get();
	uvm_servicio.set_default_tr_database(base_datos_tr);

	// creacion del ambiente
	fpu_env = fpu_env_c::type_id::create("fpu_env", this);

	uvm_config_db#(int)::set(this, "fpu_env.fpu_scoreboard",
	                        "semilla", $get_initial_random_seed());

	`uvm_info(this.get_type_name(),
	         "FPU_ENV creado desde fpu_base_test",
	         UVM_LOW);

	// variable para crear el agente activo
	uvm_config_db#(uvm_active_passive_enum)::set(
	  this, "fpu_env.fpu_agent", "is_active", UVM_ACTIVE);

endfunction: build_phase

// EOEP
// Function: end_of_elaboration_phase
// Verifica que el agente haya sido creado y reporta si quedó
// configurado como activo, pasivo o en un estado desconocido (error).
// Imprime además la topología completa del ambiente UVM.
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
// Function: start_of_simulation_phase
// Fase previa al inicio de la simulación: fija el formato de tiempo y
// muestra el banner de la corrida con el nombre del test, la semilla
// inicial y el timeout configurado.
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
// Task: run_phase
// Levanta la objeción, obtiene la secuencia del test (vía
// crear_secuencia(), hook sobreescrito por los tests hijos),
// randomiza sus knobs y la arranca sobre el sequencer del agente.
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
// Function: crear_secuencia
// Hook de fábrica (patrón Template Method): devuelve la instancia de
// secuencia a ejecutar por run_phase. La versión base devuelve la
// secuencia smoke; los tests hijos la sobreescriben para devolver su
// propia secuencia derivada de fpu_base_sequence_c.
function fpu_base_sequence_c fpu_base_test_c::crear_secuencia();
	return fpu_base_sequence_c::type_id::create("base_sequence");
endfunction : crear_secuencia
