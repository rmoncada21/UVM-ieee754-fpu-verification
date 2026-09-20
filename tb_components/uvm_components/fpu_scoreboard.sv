/*
 * File:    fpu_scoreboard_c.sv
 * Project:  FPU RV32F  Verificación funcional UVM
 *
 * Description:
 *   Scoreboard UVM de la FPU RV32F. Recibe transacciones del monitor
 *   por tlm_scb_aimp (conectado en fpu_env_c vía item_collected_port
 *   del agente) y las compara contra el modelo de referencia DPI-C
 *   (fpu_ref_calcular() / fpu_ref_resultado_s, fpu_types_pkg). La comparación
 *   es EXACTA (sin tolerancia de 1 ULP): resultado bit a bit y
 *   banderas derivadas con la semántica OPERATIVA del DUT ?no el NV/OV
 *   IEEE puro? vía flags_esperadas_dut() (comparaciones fuerzan todo a
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
	
	// semilla obtenida del fpu base test
	int semilla; // semilla de aleatoriedad usada en la corrida

	// uvm_tlm_analysis_fifo ¿?
	// proviene del monitor, conectado en el env
	uvm_analysis_imp #(fpu_seq_item_c, fpu_scoreboard_c) tlm_scb_aimp; // puerto TLM de entrada, dispara write()

	// qNaN canónico RISC-V
	localparam logic [31:0] C_QNAN = 32'h7FC0_0000;

	// knobs de chequeo por clase de bandera (knobs por test si hiciera falta)
    bit chequear_overflow  = 1'b1;
    bit chequear_underflow = 1'b1;
    bit chequear_invalid   = 1'b1;   // contra la fórmula del DUT (BUG-003), no el NV de IEEE

	// Volcado CSV de resultados para análisis posterior
	// Plusargs desde terminal:
	//   +SCB_CSV_KNOB=ON|OFF  habilita/deshabilita el volcado (por defecto OFF)
	//   +SCB_CSV=<ruta>       sobreescribe csv_ruta
	//   +SCB_RESUMEN=<ruta>   fila única de contadores para el manifest de regresión
	// Formato: encabezado + una fila por transacción.
	bit csv_habilitado = 1'b1; // habilita/deshabilita el volcado CSV
	string csv_ruta         = "fpu_scoreboard_results.csv"; // ruta del archivo CSV de salida
	string csv_ruta_resumen = ""; // Se habilita con +SCB_RESUMEN=<ruta>; sin plusarg no se escribe nada.
	string csv_knob         = "OFF"; // valor leído del plusarg SCB_CSV_KNOB
	protected int csv_signal_open = 0; // descriptor devuelto por $fopen (0 = fallo)

	// Contadores de clasificación en tres cubos + distribución por opcode.
	// clasificación en tres parametros
    // num_pass / num_bug / num_fail
	int unsigned num_transacciones; // total de transacciones procesadas
	int unsigned num_pass; // transacciones que coinciden con el modelo
	int unsigned num_bug; // transacciones que calzan con un bug ya documentado
	int unsigned num_fail; // transacciones con fallo no documentado
	int unsigned num_fail_1ulp; // subconjunto de num_fail a exactamente 1 ULP (firma del sesgo del sumador)
	int unsigned conteo_por_opcode[fpu_op_code_e]; // distribución de transacciones por opcode

	// Prototipos de funciones del scoreboard
	extern function new(string name="fpu_scoreboard_c", uvm_component parent); // constructor
	extern virtual function void build_phase(uvm_phase phase); // crea tlm_scb_aimp y obtiene la semilla
	extern virtual function void start_of_simulation_phase(uvm_phase phase); // abre el CSV de resultados
	extern protected function void flags_esperadas_dut( // deriva las banderas esperadas por el DUT
		input  fpu_op_code_e       op_code_i,
		input  fpu_ref_resultado_s reference_model_s,
		output logic               dut_overflow_esperado,
		output logic               dut_underflow_esperado,
		output logic               dut_invalid_esperado
	);
	extern protected function bit es_bug_conocido(fpu_seq_item_c item_dut); // reconoce la firma de BUG-001
	extern protected function longint unsigned distancia_ulp( // distancia ordinal DUT vs referencia en ULPs
		input logic [31:0] valor_dut,
		input logic [31:0] valor_referencia
	);
	extern protected function void csv_abrir(); // abre el CSV y escribe el encabezado
	extern protected function void csv_linea( // escribe una fila del CSV
	    input fpu_seq_item_c      item_dut,
	    input fpu_ref_resultado_s reference_model_s,
	    input logic               overflow_esperado,
	    input logic               underflow_esperado,
	    input logic               invalid_esperado,
	    input bit                 coincide_resultado,
	    input bit                 coincide_overflow,
	    input bit                 coincide_underflow,
	    input bit                 coincide_invalid,
	    input string              clasificacion,
	    input longint unsigned    dist_ulp
	);
	extern protected function void csv_resumen();
	extern virtual function void write(fpu_seq_item_c item_dut); // callback TLM, compara DUT vs referencia
	extern virtual function void report_phase(uvm_phase phase); // imprime el resumen final

endclass: fpu_scoreboard_c

// Implementación de las funciones
// Function: new
// Constructor del scoreboard; delega la inicialización al uvm_scoreboard base.
function fpu_scoreboard_c::new(string name="fpu_scoreboard_c", uvm_component parent);
	super.new(name, parent);
endfunction : new

// BP
// Function: build_phase
// Fase de construcción UVM: crea el puerto de análisis tlm_scb_aimp
// (receptor de las transacciones del agente) y obtiene la semilla
// publicada por el test base vía config_db.
function void fpu_scoreboard_c::build_phase(uvm_phase phase);
	super.build_phase(phase);
	tlm_scb_aimp = new("tlm_scb_aimp", this);

	if(!uvm_config_db#(int)::get(this, "", "semilla", semilla))
		`uvm_warning(get_type_name(), "Semilla not FOUND en soreaboard ");

	`uvm_info(this.get_type_name(),
			"TLM - uvm_analysis_imp: tlm_scb_aimp creado",
			UVM_LOW)
endfunction :  build_phase;

// SOSP
// Function: start_of_simulation_phase
// Fase previa al inicio de la simulación: reporta que el modelo de
// referencia DPI-C está cargado y abre el archivo CSV de resultados.
function void fpu_scoreboard_c::start_of_simulation_phase(uvm_phase phase);
	super.start_of_simulation_phase(phase);
	`uvm_info(this.get_type_name(),
		"Scoreboard, modelo de referencia DPI-C cargado",
		UVM_LOW)
	csv_abrir();
endfunction : start_of_simulation_phase

// flags
// Function: flags_esperadas_dut
// Deriva las banderas esperadas con la semántica OPERATIVA del DUT a
// partir del resultado golden (el DUT no tiene fflags IEEE; sus
// banderas son consecuencia del patrón de bits de la salida).
//   - Comparaciones: todo a 0 (BUG-004).
//   - Aritmética: ov = OV de IEEE (coincide); uf = exponente 0
//     (subnormal o cero); inv = qNaN | ov | uf (fórmula del DUT, BUG-003).
function void fpu_scoreboard_c::flags_esperadas_dut(
	input  fpu_op_code_e       op_code_i,
	input  fpu_ref_resultado_s reference_model_s, // respuesta completa (resultado + flag) del modelo
	output logic               dut_overflow_esperado,
	output logic               dut_underflow_esperado,
	output logic               dut_invalid_esperado
);
	bit es_opcode_comparacion; //opcode: FEQ/FLT/FLE
	bit resultado_es_qnan; // resultado golden es qNaN canónico
	bit resultado_es_subnormal; // resultado golden con exponente 0 y mantisa != 0
	bit resultado_es_cero; // resultado golden es ±0

	es_opcode_comparacion  = ( op_code_i == FEQ || op_code_i == FLT || op_code_i == FLE );
	resultado_es_qnan      = ( reference_model_s.resultado == C_QNAN );
	resultado_es_subnormal = ( reference_model_s.resultado[30:23] == 8'h00 ) && ( reference_model_s.resultado[22:0] != '0);
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

// Function: es_bug_conocido
// Reconoce la "firma" de la familia BUG-001: operando subnormal en una
// operación que pasa por fp_mul
function automatic bit fpu_scoreboard_c::es_bug_conocido(fpu_seq_item_c item_dut);
    bit op_usa_multiplicador;   // el datapath del opcode pasa por fp_mul
    bit operando_a_subnormal; // fp_a_i es subnormal (exponente 0, mantisa != 0)
    bit operando_b_subnormal; // fp_b_i es subnormal (exponente 0, mantisa != 0)

    op_usa_multiplicador = (item_dut.op_code_i == FMUL)  ||
                           (item_dut.op_code_i == FMADD) ||
                           (item_dut.op_code_i == FMSUB);
    operando_a_subnormal = (item_dut.fp_a_i[30:23] == 8'h00) && (item_dut.fp_a_i[22:0] != '0);
    operando_b_subnormal = (item_dut.fp_b_i[30:23] == 8'h00) && (item_dut.fp_b_i[22:0] != '0);
    return op_usa_multiplicador && (operando_a_subnormal || operando_b_subnormal);
endfunction : es_bug_conocido

// Function: distancia_ulp
// Distancia entre dos patrones binary32 en pasos de la escala ordinal
// signo-magnitud: negativo -> -(bits[30:0]), positivo -> +(bits[30:0]).
// La escala es monotónica en toda la recta extendida (±0 colapsan en 0,
// ±Inf son los extremos), así que |orden_dut - orden_referencia| cuenta
// los representables entre ambos: la distancia en ULPs. En un FAIL,
// dist_ulp = 0 delata discrepancia solo de signo del cero; con NaN
// mediría distancia de payload y no se interpreta.
function automatic longint unsigned fpu_scoreboard_c::distancia_ulp(
	input logic [31:0] valor_dut,
	input logic [31:0] valor_referencia
);
	longint orden_dut;        // posición ordinal del resultado del DUT
	longint orden_referencia; // posición ordinal del resultado del modelo

	orden_dut        = valor_dut[31]        ? -longint'(valor_dut[30:0])
	                                        :  longint'(valor_dut[30:0]);
	orden_referencia = valor_referencia[31] ? -longint'(valor_referencia[30:0])
	                                        :  longint'(valor_referencia[30:0]);

	return (orden_dut >= orden_referencia) ? unsigned'(orden_dut - orden_referencia)
	                                       : unsigned'(orden_referencia - orden_dut);
endfunction : distancia_ulp

// Function: csv_abrir
// Abre el archivo CSV de resultados y escribe la fila de encabezado.
// Se invoca desde start_of_simulation_phase. Plusargs desde terminal:
//   +SCB_CSV_KNOB=ON|OFF  habilita/deshabilita el volcado (por defecto OFF)
//   +SCB_CSV=<ruta>       sobreescribe csv_ruta
//   +SCB_RESUMEN=<ruta>   ruta del resumen; se lee ANTES del return temprano
//                         para que el resumen sobreviva con el volcado apagado
// Formato: banderas y clasificaión por campo como
// enteros 0/1, patrones de bits en hex de 8 dígitos SIN prefijo 0x
// (leer en Python con int(x, 16)), tiempo en unidades del timescale.
function void fpu_scoreboard_c::csv_abrir();
    void'($value$plusargs("SCB_RESUMEN=%s", csv_ruta_resumen));
    void'($value$plusargs("SCB_CSV_KNOB=%s",csv_knob));
    csv_habilitado = (csv_knob == "ON");

    void'($value$plusargs("SCB_CSV=%s", csv_ruta));
    if (!csv_habilitado)
        return;

    csv_signal_open = $fopen(csv_ruta, "w");

    if (csv_signal_open == 0) begin
        csv_habilitado = 1'b0;
        `uvm_warning(get_type_name(), $sformatf(
            "No se pudo abrir '%s'; volcado CSV desactivado", csv_ruta))
        return;
    end
	// TODO: agregar seed
    $fdisplay(csv_signal_open,
        {"idx,tiempo,op,rm,fp_a,fp_b,fp_c,dut_res,dut_cmp,ref_result,",
		 "dut_ov,dut_uf,dut_inv,ref_ov,ref_uf,ref_inv,",
         "ok_res,ok_ov,ok_uf,ok_inv,clasificacion,dist_ulp"});
    `uvm_info(get_type_name(),
        $sformatf("Volcado CSV de resultados en '%s'", csv_ruta), UVM_LOW)
endfunction : csv_abrir

// Function: csv_linea
// Vuelca una transacción ya clasificada como fila del CSV (una fila
// por write()). Esquema plano y uniforme para las 8 operaciones: en
// comparaciones el bit útil viaja en dut_cmp y en ref_result[0]; en
// aritmética dut_cmp es indiferente. Los coincide_* se exportan con
// las relajaciones ya aplicadas (qNaN/Inf, knobs chequear_*), de modo
// que un script en Python no tenga que re-implementar esa lógica.
function void fpu_scoreboard_c::csv_linea(
    input fpu_seq_item_c      item_dut,
    input fpu_ref_resultado_s reference_model_s,
    input logic               overflow_esperado,
    input logic               underflow_esperado,
    input logic               invalid_esperado,
    input bit                 coincide_resultado,
    input bit                 coincide_overflow,
    input bit                 coincide_underflow,
    input bit                 coincide_invalid,
    input string              clasificacion,
    input longint unsigned    dist_ulp
);
    if (!csv_habilitado || csv_signal_open == 0)
        return;
    $fdisplay(csv_signal_open, $sformatf(
        "%0d,%0d,%s,%s,%08h,%08h,%08h,%08h,%0b,%08h,%0b,%0b,%0b,%0b,%0b,%0b,%0b,%0b,%0b,%0b,%s,%0d",
        num_transacciones, $time,
        item_dut.op_code_i.name(), item_dut.r_mode_i.name(),
        item_dut.fp_a_i, item_dut.fp_b_i, item_dut.fp_c_i,
        item_dut.fp_result_o, item_dut.cmp_result_o, reference_model_s.resultado,
        item_dut.overflow_o, item_dut.underflow_o, item_dut.invalid_o,
        overflow_esperado, underflow_esperado, invalid_esperado,
        coincide_resultado, coincide_overflow, coincide_underflow, coincide_invalid,
        clasificacion, dist_ulp));
endfunction : csv_linea

// Function: csv_resumen
// Escribe UNA fila SIN encabezado con los contadores finales:
// transacciones,num_pass,num_bug,num_fail. El Makefile le antepone
// test y semilla y la anexa al manifest.csv de la regresión.
function void fpu_scoreboard_c::csv_resumen();
    int resumen_signal_open;

	if (csv_ruta_resumen == "")
        return;
    resumen_signal_open = $fopen(csv_ruta_resumen, "w");
    if (resumen_signal_open == 0) begin
        `uvm_warning(get_type_name(), $sformatf(
            "No se pudo abrir '%s'; resumen de regresion no escrito", csv_ruta_resumen))
        return;
    end
    $fdisplay(resumen_signal_open, $sformatf("%0d,%0d,%0d,%0d",
        num_transacciones, num_pass, num_bug, num_fail));
    $fclose(resumen_signal_open);
endfunction : csv_resumen

// Write
// Function: write
// Callback del analysis_imp - monitor; UVM lo invoca por cada transacción que
// publica el monitor. Cinco pasos: reference -> banderas esperadas ->
// comparación EXACTA (sin tolerancia de 1 ULP) -> clasificación -> volcado CSV.
function void fpu_scoreboard_c::write(fpu_seq_item_c item_dut);
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
	string clasificacion; // etiqueta textual final: PASS / BUG / FAIL

	longint unsigned dist_ulp; // distancia DUT vs referencia en ULPs (0 = bit-exacto o solo signo de cero)
	num_transacciones++;

	// deteccion de datos entrantes XXX/ZZZ
	// $display("op_code_i = %b", item_dut.op_code_i);

	// aborta la simulación si el opcode llega con bits X/Z (dato corrupto)
	if ($isunknown(item_dut.op_code_i))
		`uvm_fatal(get_type_name(), $sformatf(
			"Opcode con X/Z en la transaccion %0d", num_transacciones))
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
	resultado_es_qnan     = ( reference_model_s.resultado == C_QNAN );
	resultado_es_infinito = ( reference_model_s.resultado[30:23] == 8'hFF) &&
							( reference_model_s.resultado[22:0]  == '0 ); 

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
		coincide_resultado = (item_dut.fp_result_o  === reference_model_s.resultado);
		
		coincide_overflow  = !chequear_overflow     ||
							 (item_dut.overflow_o   === overflow_esperado);
		
		// Si el resultado es qNaN/Inf, el DUT marca UF/INV
        // espurio (inf-inf, overflow vía fp_mul) no derivable del valor.
		coincide_underflow = !chequear_underflow    ||
							 (item_dut.underflow_o  === underflow_esperado) || resultado_es_qnan || resultado_es_infinito;

		coincide_invalid   = !chequear_invalid      ||
							 (item_dut.invalid_o    === invalid_esperado)   || resultado_es_qnan || resultado_es_infinito;
	end

	// distancia en ULPs del resultado (en comparaciones el resultado es
	// un bit: la métrica no aplica y se registra 0)
	dist_ulp = es_opcode_comparacion ? 0
	         : distancia_ulp(item_dut.fp_result_o, reference_model_s.resultado);

	// --- 4. Clasificacion en tres parametros ---
	if(coincide_resultado && coincide_overflow && coincide_underflow && coincide_invalid)  begin
		num_pass++;
		clasificacion = "PASS";
	end 
	else if (es_bug_conocido(item_dut)) begin
		num_bug++; // documentado (familia BUG-001), no es un fallo nuevo
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
        // subconjunto a exactamente 1 ULP: firma del sesgo del sumador
        if (dist_ulp == 1) num_fail_1ulp++;
        // imprimir mensaje
		`uvm_error("FPU_SCOREBOARD", $sformatf(
            {"MISMATCH opcode=%s rm=%s fp_a=%08h fp_b=%08h fp_c=%08h | DUT=%08h reference=%08h dist_ulp=%0d",
             " | flags DUT overflow=%0b underflow=%0b invalid=%0b esperadas overflow=%0b underflow=%0b invalid=%0b"},
            item_dut.op_code_i.name(), item_dut.r_mode_i.name(),
            item_dut.fp_a_i, item_dut.fp_b_i, item_dut.fp_c_i,
            item_dut.fp_result_o, reference_model_s.resultado, dist_ulp,
            item_dut.overflow_o, item_dut.underflow_o, item_dut.invalid_o,
            overflow_esperado, underflow_esperado, invalid_esperado))
    end

	// --- 5. Volcado CSV para análisis posterior ---
	csv_linea(item_dut, reference_model_s,
              overflow_esperado, underflow_esperado, invalid_esperado,
              coincide_resultado, coincide_overflow, coincide_underflow, coincide_invalid,
              clasificacion, dist_ulp);
endfunction : write

// Function: report_phase
// Resumen final. Todas las líneas con uvm_info: cada fallo ya emitió
// su propio uvm_error en write()
// Cierra además el CSV y reporta su ruta para el estudio posterior.
function void fpu_scoreboard_c::report_phase(uvm_phase phase);
    string separador = "==================================================";
    super.report_phase(phase);
    `uvm_info(get_type_name(), separador, UVM_NONE)
    `uvm_info(get_type_name(), "  FPU Scoreboard (reference SoftFloat) -- Resumen", UVM_NONE)
    `uvm_info(get_type_name(), separador, UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  Transacciones : %0d", num_transacciones), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  PASS          : %0d", num_pass), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  BUG-001       : %0d (documentado)", num_bug), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("  FALLO nuevo   : %0d", num_fail), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("    a 1 ULP     : %0d", num_fail_1ulp), UVM_NONE)

	if (csv_habilitado && csv_signal_open != 0) begin
        $fclose(csv_signal_open);
        csv_signal_open = 0;
        `uvm_info(get_type_name(), $sformatf("  CSV: %s", csv_ruta), UVM_NONE)
    end

    `uvm_info(get_type_name(), "  Distribucion por opcode:", UVM_NONE)
    
    foreach (conteo_por_opcode[opcode])
        `uvm_info(get_type_name(),
                  $sformatf("    %-6s : %0d", opcode.name(), conteo_por_opcode[opcode]), UVM_NONE)
    `uvm_info(get_type_name(), separador, UVM_NONE)
    
    if (num_fail == 0) begin
        `uvm_info(get_type_name(), "  Sin fallos inesperados.", UVM_NONE)
    end else begin
        `uvm_info(get_type_name(),
                  "  Hay fallos inesperados; revisar los UVM_ERROR del log.", UVM_NONE)
    end
	
	csv_resumen();
endfunction : report_phase