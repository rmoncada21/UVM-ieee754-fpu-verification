#ifndef GOLDEN_MODEL_H
#define GOLDEN_MODEL_H

/*--------------------------------------------------------------------------------------
 * dpi_fpu_reference
 *   Modelo de referencia para las 8 operaciones de fp_alu.
 *
 *   Parametros:
 *     op_code : codigo de operacion (0..7, ver tabla arriba)
 *     a_bits  : operando A en formato binary32 crudo (bit-pattern)
 *     b_bits  : operando B en formato binary32 crudo
 *     c_bits  : operando C en formato binary32 crudo (solo FMADD/FMSUB; 0 si no aplica)
 *     rm      : modo de redondeo RISC-V (0..4; ignorado en comparaciones)
 *
 *   Salidas (por puntero):
 *     r_bits  : resultado.
 *                 - Aritmetica : binary32 crudo (bit-pattern del float resultante)
 *                 - Comparacion: entero RISC-V, 0 o 1 en el bit 0 (resto en cero)
 *     flags   : banderas de excepcion segun la semantica operativa del DUT
 *               (NO el fflags IEEE crudo de SoftFloat; ver dpi_fpu_reference.c)
 *--------------------------------------------------------------------------------------*/

 // códigos de operacion
enum OPCODES {
    OP_FADD  = 0,
	OP_FSUB  = 1,
	OP_FMUL  = 2,
	OP_FMADD = 3,
    OP_FMSUB = 4,
	OP_FEQ   = 5,
	OP_FLT   = 6,
	OP_FLE   = 7
};

enum ROUND_MODE {
    OP_RNE  = 0,   /*  round_near_even   */
	OP_RTZ  = 1,   /*  round_minMag      */
	OP_RDN  = 2,   /*  round_min         */
	OP_RUP  = 3,   /*  round_max         */
    OP_RMM  = 4,   /*  round_near_maxMag */
};

 void dpi_fpu_reference(
    // entradas
    unsigned int   op_code,
    unsigned int   fp_a_bits,
    unsigned int   fp_b_bits,
    unsigned int   fp_c_bits,
    unsigned int   round_mode,
    // salidas
    unsigned int  *result_bits,
    unsigned char *flags
);

#endif