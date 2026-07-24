/*
 * File:    fpu_types_seq_pkg.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Tipos auxiliares de la capa de estímulo (tests/sequences).
 *   Define los anchos de campo del formato binary32 y la clasificación
 *   IEEE 754 de un operando, usada por fpu_seq_constraints_c y por los
 *   generadores dirigidos de fpu_base_sequence_c.
 *
 * Dependencies:
 *   (ninguna)
 */

`ifndef FPU_TYPES_CONSTRAINTS_PKG
`define FPU_TYPES_CONSTRAINTS_PKG

package fpu_types_constraints_pkg;
    
    // anchos de campo del formato IEEE 754 binary32
    localparam int C_EXP_WIDTH = 8; // exponente
    localparam int C_MANT_WIDTH = 23; // mantissa

    // limites del campo del exponente (sesgo)
    localparam logic [C_EXP_WIDTH-1:0] C_EXP_MIN_NORMAL = 8'd1;   // normal: menor
    localparam logic [C_EXP_WIDTH-1:0] C_EXP_MAX_NORMAL = 8'd254; // normal: mayor
    localparam logic [C_EXP_WIDTH-1:0] C_EXP_ESPECIAL   = 8'd255; // inf / NaN (s, q)
    
    /* rounding test */
    localparam logic int C_EXP_SESGO = 127; // sesgo del exponente en binary 32

    // banda segura para arimética normal (tesplan sec. 2.2.1.1):
    // operandos normales y sin resultados de over/underflow para
	// FADD/FSUB/FMUL/FMADD/FMSUB
	localparam logic [C_EXP_WIDTH-1:0] C_EXP_BANDA_MINIMA = 8'd70;
	localparam logic [C_EXP_WIDTH-1:0] C_EXP_BANDA_MAXIMA = 8'd184;

    // exponentes dirigidos para flag_arith (testplan sec. 2.2.1.2):
    // 191+191-127 = 255 -> el producto de dos operandos con exp >= 191 siempre desborda; 
    // 63+63-127+1 = 0 -> el producto de dos operandos
    // con exp <= 63 siempre es tiny (bajo el minimo normal)
    localparam logic [C_EXP_WIDTH-1:0] C_EXP_OVF_PROD_MIN = 8'd191;
    localparam logic [C_EXP_WIDTH-1:0] C_EXP_UDF_PROD_MAX = 8'd63;

    // clasificacion IEEE 754 de un operando binary32
     typedef enum int {
        CLASE_CERO      = 0,    // ±0
        CLASE_SUBNORMAL = 1,    // exp = 0, mantisa != 0
        CLASE_NORMAL    = 2,    // exp en [1, 254]
        CLASE_INF       = 3,    // ±inf
        CLASE_QNAN      = 4,    // NaN silencioso (mantisa[22] = 1)
        CLASE_SNAN      = 5,    // NaN señalizador (mantisa[22] = 0, payload != 0)
		// bandas  - subconjuntos de valores
		CLASE_NORMAL_BANDA = 6,     // normal en banda segura [70,184]
        CLASE_NORMAL_OVF_SUMA = 7,  // normal con exp = 254 overflow en suma/resta
        CLASE_NORMAL_OVF_PROD = 8,  // normal con exp en [191, 254] - overflow en producto
        CLASE_NORMAL_UDF_PROD = 9,  // normal con exp en [1, 63] underflow en producto
        /*rounding*/
        CLASE_POTENCIA_DOS = 10, // mantisa 0, exponente normal (via exponente_forzado)
        CLASE_NORMAL_EMPATE_MUL = 11 // mantisa impar <= 'h2AAAAA: empate exacto contra 1.5
     } fpu_clase_operando_e;

    /* flag arith */
    typedef enum int{
        FAM_OVERFLOW  = 0, // resultado supera el máxximo finito
        FAM_UNDERFLOW = 1, // resultado tiny con perdida de exactitud 
        FAM_INVALID   = 2  // operación invalida IEEE (0*inf, inf-inf, NaN entrante)
    } fpu_familia_flag_e;

    /* special spec */
    // clases "especiales" del testplan sec. 2.2.2 (cero, inf, NaN; sin
    // subnormales: estos van al test dedicado de subnormales). El orden
    // es fijo: define el recorrido determinista de special_spec y de
    // norm_spec sobre el cross de clases.
    localparam int C_NUM_CLASES_ESP = 4;
    localparam fpu_clase_operando_e C_CLASES_ESP[C_NUM_CLASES_ESP] = '{
        CLASE_CERO, CLASE_INF,
        CLASE_QNAN, CLASE_SNAN
    };

    /* norm spec */
    // posicion del operando especial en el test norm_spec (testplan
    // sec. 2.2.2): exactamente uno de los tres operandos lleva la
    // clase especial; los otros dos van en banda segura
    typedef enum int {
        POS_ESP_A = 0, // especial en fp_a_i
        POS_ESP_B = 1, // especial en fp_b_i
        POS_ESP_C = 2  // especial en fp_c_i (solo FMADD/FMSUB)
    } fpu_posicion_esp_e;
    localparam int C_NUM_POS_ESP = 3;

    /*rounding*/
    // tipos de estimulo del test rounding (testplan sec. 2.2.3)
    typedef enum int {
        RED_ALEATORIO = 0, // operandos banda aleatorios: inexacto generico
        RED_EMPATE    = 1  // empate exacto construido (guard = 1, sticky = 0)
    } fpu_estimulo_red_e;
    localparam int C_NUM_EST_RED = 2;

endpackage

`endif // FPU_TYPES_CONSTRAINTS_PKG
