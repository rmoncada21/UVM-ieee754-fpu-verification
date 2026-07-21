/*
 * File:    fpu_scoreboard_c.sv
 * - Project:  FPU RV32F Verificación funcional UVM
 *
 * Description:
 *   Scoreboard UVM de la FPU RV32F. Recibe transacciones del monitor
 *   por tlm_scb_aimp (conectado en fpu_env_c vía item_collected_port
 *   del agente) y las compara contra el modelo de referencia DPI-C
 *   (fpu_ref_calcular() / fpu_ref_resultado_s, fpu_types_pkg). La comparación
 *   es EXACTA (sin tolerancia de 1 ULP): resultado bit a bit y
 *   banderas derivadas con la semántica OPERATIVA del DUT no el NV/OV
 *   IEEE puro vía flags_esperadas_dut() (comparaciones fuerzan todo a
 *   0 por BUG-004; aritmética deriva uf de exponente 0 e inv como
 *   qNaN|ov|uf por BUG-003). Cada transacción se clasifica en tres
 *   cubos: num_pass, num_bug (firma BUG-001 reconocida por
 *   es_bug_conocido(), documentada y no cuenta como fallo nuevo) y
 *   num_fail (meta: 0). report_phase imprime el resumen final y la
 *   distribución por opcode.
 *
 * Dependencies:
 *   fpu_seq_item.sv, fpu_types_pkg.sv, fpu_dpic_ref_model_pkg.sv (dpi_fpu_reference,
 *   fpu_ref_resultado_s, fpu_ref_calcular()), reference_model.c (DPI-C)
 */

class fpu_scoreboard_c extends uvm_scoreboard;
	`uvm_component_utils(fpu_scoreboard_c)
	
	// uvm_tlm_analysis_fifo ¿?
	// proviene del monitor, conectado en el env
	uvm_analysis_imp #(fpu_seq_item_c, fpu_scoreboard_c) tlm_scb_aimp;

	// qNaN canónico RISC-V
	localparam logic [31:0] C_QNAN = 32'h7FC0_0000;


	// Contadores de clasificación en tres cubos + distribución por opcode.
	// clasificación en tres parametros
    // num_pass / num_bug / num_fail
	int unsigned num_transacciones;
	int unsigned num_pass;
	int unsigned num_bug;
	int unsigned num_fail;
	int unsigned conteo_por_opcode[fpu_op_code_e];

	// Prototipos de funciones del scoreboard
	extern function new(string name="fpu_scoreboard_c", uvm_component parent);
	extern virtual function void build_phase(uvm_phase phase);
	extern virtual function void start_of_simulation_phase(uvm_phase phase);
	// TODO: flags esperadas, bug_conocido, archivo CSV de salida
	extern protected function void flags_esperadas_dut(
		input  fpu_op_code_e       op_code_i,
		input  fpu_ref_resultado_s reference_model_s,
		output logic               dut_overflow_esperado,
		output logic               dut_underflow_esperado,
		output logic               dut_invalid_esperado
	);
	extern protected function bit es_bug_conocido(fpu_seq_item_c item);
	extern virtual task write(fpu_seq_item_c item_dut);
	extern virtual function void report_phase(uvm_phase phase);

endclass: fpu_scoreboard_c

// Implementación de las funciones
// Constructor de la clase
function fpu_scoreboard_c::new(string name="fpu_scoreboard_c", uvm_component parent);
	super.new(name, parent);
endfunction : new

// BP
function void fpu_scoreboard_c::build_phase(uvm_phase phase);
	super.build_phase(phase);
	tlm_scb_aimp = new("tlm_scb_aimp", this);

	`uvm_info(this.get_type_name(),
			"TLM - uvm_analysis_imp: tlm_scb_aimp creado",
			UVM_LOW)
endfunction :  build_phase;

// SOSP
function void fpu_scoreboard_c::start_of_simulation_phase(uvm_phase phase);
	super.start_of_simulation_phase(phase);
	`uvm_info(this.get_type_name(),
		"Scoreboard, modelo de referencia DPI-C cargado",
		UVM_LOW)
endfunction : start_of_simulation_phase

// flags
// Function: flags_esperadas_dut
// Deriva las banderas esperadas con la semántica OPERATIVA del DUT a
// partir del resultado golden (el DUT no tiene fflags IEEE; sus
// banderas son consecuencia del patrón de bits de la salida).
//   - Comparaciones: todo a 0 (BUG-004).
//   - Aritmética: ov = OV de IEEE (coincide); uf = exponente 0
//     (subnormal o cero); inv = qNaN | ov | uf (fórmula del DUT, BUG-003).
function void fpu_soreboard_c::flags_esperadas_dut(
	input  fpu_op_code_e       op_code_i,
	input  fpu_ref_resultado_s reference_model_s, // respuesta completa (resultado + flag) del modelo
	output logic               dut_overflow_esperado,
	output logic               dut_underflow_esperado,
	output logic               dut_invalid_esperado
);
	bit es_opcode_comparacion; //opcode: FEQ/FLT/FLE
	bit resultado_es_qnan;
	bit resultado_es_subnormal;
	bit resultado_es_cero;

	es_opcode_comparacion  = ( op_code_i == FEQ || op_code_i == FLT || op_code_i == FLE );
	resultado_es_qnan      = ( reference_model_s.resultado == C_QNAN );
	resultado_es_subnormal = ( reference_model_s.resultado[30:23] == 8'h00 ) && ( referene_model.resultado[22:0] != '0);
	resultado_es_cero      = ( reference_model_s.resultado[30:0] == '0 );

	if (es_opcode_comparacion) begin
		// El DUT fuerza overflow/underflow/invalid a 0 en comparaciones (BUG-004)
		dut_overflow_esperado  = 1'b0;
		dut_underflow_esperado = 1'b0;
		dut_invalid_esperado   = 1'b0;
	end else begin
		dut_overflow_esperado  = reference_model_s.flags.ov;                        // OV de IEEE coincide
		dut_underflow_esperado = ( resultado_es_subnormal || resultado_es_cero ); // campo exponente == 0
		dut_invalid_esperado   = ( resultado_es_qnan || dut_overflow_esperado || dut_underflow_esperado );
	end

endfunction : flags_esperadas_dut

// Bug del ambiente
// function bit fpu_soreboard_c::es_bug_conocido(fpu_seq_item_c item);
// endfunction : es_bug_conocido

// Write
// TODO: implementar funcion write
// Function: write
// Callback del analysis_imp - monitor; UVM lo invoca por cada transacción que
// publica el monitor. Cinco pasos: reference -> banderas esperadas ->
// comparación EXACTA (sin tolerancia de 1 ULP) -> veredicto -> volcado CSV.
task fpu_scoreboard_c::write(fpu_seq_item_c item_dut);
	fpu_ref_resultado_s reference_model_s; // respuesta completa (resultado + flag) del modelo

	bit es_opcode_comparacion; // opcode: FEQ/FLT/FLE
	bit resultado_es_qnan;     // resultado reference == qNaN canónico
	bit resultado_es_infinito; // resultado golden == ±Inf

	// clasificación por campo: resultado observado del dut coincide con los esperado?
	bit coincide_resultado;
	bit coincide_overflow;
	bit coincide_underflow;
	bit coincide_invalid;

	// banderas que el dur debería marcar, las llena flags_esperadas_dut
	logic  overflow_esperado;
	logic  underflow_esperado;
	logic  invalid_esperado;
	string clasificacion;

	numm_trasacciones++;
	conteo_por_opcode[item_dut.op_code_i]++;
	es_opcode_comparacion = ( item_dut.op_code_i == FEQ ) || 
							( item_dut.op_code_i == FLT ) || 
							( item_dut.op_code_i == FLE); 


	// --- 1. Modelo de referencia (SoftFloat vía DPI-C) ---
	// salida de la función fpu_ref se guarda en reference_model_s
	reference_model_s = fpu_ref_calcular( // entradas a la función
										  item_dut.op_code_i,
										  item_dut.fp_a_i,
										  item_dut.fp_b_i,
										  item_dut.fp_c_i,
										  item_dut.r_mode_i );
	// clasificar/ovservar el resultado
	resultado_es_qnan     = ( reference_model_s.resultado == CQNAN );
	resultado_es_infinito = ( reference_model_s.resultado[30:23] == 8'hFF) &&
							( reference_model_s.resultado [22:0] == '0 ); 

	// --- 2. Banderas esperadas según la semántica del DUT ---
	flags_esperadas_dut( // entradas a la función
						 item_dut.op_code_i,
						 reference_model_s,
						 //  salidas de la función hacia los punteros
						 overflow_esperado,
						 underflow_esperado,
						 invalid_esperado );

	// --- 3. Comparación EXACTA (sin tolerancia de 1 ULP) ---
	if (es_opcode_comparacion) begin
		// El dut entrega el bit en cmp_result_o y pone fp_result_o y banderas a 0.
		// el modelo entrga todo en resultado[31:0]
		coincide_resultado = (item_dut.cmp_result_o === reference_model_s.resultado[0]) &&
							 (item_dut.fp_result_o  === 32'h0000_0000);
		coincide_overflow  = (item_dut.overflow_o   === 1'b0); 
		coincide_underflow = (item_dut.underflow_o  === 1'b0); 
		coincide_invalid   = (item_dut.invalid_o    === 1'b0); 
	end else begin // si no es de comparación sucedió alguna operación arimética
		coincide_resultado = (item_dut.fp_result_o  === reference_model_s.resultado)
		
		coincide_overflow  = (item_dut.overflow_o === overflow_esperado)
		
		coincide_underflow = (item_dut.underflow_o === underflow_esperado) || resultado_es_qnan || resultado_es_infinito;

		coincide_invalid   = (item_dut.invalid_o === invalid_esperado) || resultado_es_qnan || resultado_es_infinito;
	end

	// --- 4. Clasificacion en tres parametros ---
	if(coincide_resultado && coincide_overflow && coincide_underflow && coincide_invalid)  begin
		num_pass++;
		clasificacion = "PASS";
	end 
	else if (es_bug_conocido(item_dut)) begin
		num_bag++; // documentado (familia BUG-001), no es un fallo nuevo
		clasificacion = "BUG";
		// imprimir mensaje
		`uvm_warning(get_type_name(), $sformatf(
            "BUG-001 opcode=%s rm=%s fp_a=%08h fp_b=%08h fp_c=%08h | DUT=%08h reference=%08h",
            item_dut.op_code_i.name(), item_dut.r_mode_i.name(),
            item_dut.fp_a_i, item_dut.fp_b_i, item_dut.fp_c_i,
            item_dut.fp_result_o, reference_model_s.resultado))
	end 
	else begin
        num_fail++;      // fallo inesperado: debería quedar en 0
        clasificacion = "FAIL";
        // imprimir mensaje
		`uvm_error(get_type_name(), $sformatf(
            {"MISMATCH opcode=%s rm=%s fp_a=%08h fp_b=%08h fp_c=%08h | DUT=%08h reference=%08h",
             " | flags DUT overflow=%0b underflow=%0b invalid=%0b esperadas overflow=%0b underflow=%0b invalid=%0b"},
            item_dut.op_code_i.name(), item_dut.r_mode_i.name(),
            item_dut.fp_a_i, item_dut.fp_b_i, item_dut.fp_c_i,
            item_dut.fp_result_o, reference_model_s.resultado,
            item_dut.overflow_o, item_dut.underflow_o, item_dut.invalid_o,
            overflow_esperado, underflow_esperado, invalid_esperado))
    end

	// --- 5. Volcado CSV para análisis posterior ---

endtask

// Function: report_phase
// Resumen final. Todas las líneas con uvm_info: cada fallo ya emitió
// su propio uvm_error en write()
// Cierra además el CSV y reporta su ruta para el estudio posterior.
// ------------------------------------------------------------------
function void fpu_scoreboard_c::report_phase(uvm_phase phase);
    string separador = "==================================================";
    super.report_phase(phase);
    `uvm_info(get_type_name(), separador, UVM_NONE)
    `uvm_info(get_type_name(), "  FPU Scoreboard (golden SoftFloat) -- Resumen", UVM_NONE)
    `uvm_info(get_type_name(), separador, UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  Transacciones : %0d", num_transacciones), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  PASS          : %0d", num_pass), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  BUG-001       : %0d (documentado)", num_bug), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  FALLO nuevo   : %0d", num_fail), UVM_NONE)
    // TODO: hacer salida hacia archivo CSV

    `uvm_info(get_type_name(), "  Distribucion por opcode:", UVM_NONE)
    
    foreach (conteo_por_opcode[opcode])
        `uvm_info(get_type_name(),
                  $sformatf("    %-6s : %0d", opcode.name(), conteo_por_opcode[opcode]), UVM_NONE)
    `uvm_info(get_type_name(), separador, UVM_NONE)
    
    if (num_fail == 0)
        `uvm_info(get_type_name(), "  Sin fallos inesperados.", UVM_NONE)
    else
        `uvm_info(get_type_name(),
                  "  Hay fallos inesperados; revisar los UVM_ERROR del log.", UVM_NONE)
endfunction : report_phase