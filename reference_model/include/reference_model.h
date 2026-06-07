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
void dpi_fpu_reference(
    unsigned int   op_code,
    unsigned int   a_bits,
    unsigned int   b_bits,
    unsigned int   c_bits,
    unsigned int   rm,
    unsigned int  *r_bits,
    unsigned char *flags
);

#endif