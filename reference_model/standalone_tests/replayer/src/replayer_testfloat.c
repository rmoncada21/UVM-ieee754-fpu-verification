/****************************************************************************************
 * File:    replayer_testfloat.c
 * Project: FPU RV32F - Verificacion funcional UVM, subambiente de validacion
 * Author:
 *
 * Modulo de dominio del replayer N4: tabla de operaciones y su resolucion a
 * fila (op_code DPI, aridad, booleana, solo_csv), mapeo del token de
 * redondeo del CLI al codigo rm del DUT, y referencia IEEE fusionada para la
 * pseudo-op f32_mulSub. Ambos mapeos validan ANTES de tocar stdin (op/rm
 * invalido = error de uso). La orquestacion (CLI, pipe/CSV, guardas y
 * codigos de salida) vive en main.c.
 ****************************************************************************************/
#include <string.h>
#include <stdint.h>
#include "reference_model.h"      /* constantes del contrato DPI: OP_F* y OP_RNE..OP_RMM */
/* SOLO para la referencia fusionada de f32_mulSub: unico punto del arnes que
 * toca SoftFloat directamente; la frontera DPI sigue sin exponerla.         */
#include "softfloat.h"
#include "replayer_testfloat.h"

/* Tabla de operaciones: nombre TestFloat -> op_code del DUT (enum OPCODES
 * de reference_model.h). solo_csv marca a f32_mulSub: existe solo como
 * pseudo-op de analisis.
 *   nombre        op_code   aridad  booleana  solo_csv                     */
static const operacion_t OPERACIONES[] = {
    {"f32_add",    OP_FADD,  2, 0, 0},
    {"f32_sub",    OP_FSUB,  2, 0, 0},
    {"f32_mul",    OP_FMUL,  2, 0, 0},
    {"f32_mulAdd", OP_FMADD, 3, 0, 0},  /* FMADD: doble redondeo esperado vs ver   */
    {"f32_mulSub", OP_FMSUB, 3, 0, 1},  /* FMSUB: pseudo-op, consume stream mulAdd */
    {"f32_eq",     OP_FEQ,   2, 1, 0},
    {"f32_lt",     OP_FLT,   2, 1, 0},
    {"f32_le",     OP_FLE,   2, 1, 0},
    {NULL,         0u,       0, 0, 0}   /* centinela de fin de tabla               */
};

const operacion_t *mapear_operacion(const char *nombre_operacion) {
    for (int i = 0; OPERACIONES[i].nombre; i++)
        if (!strcmp(nombre_operacion, OPERACIONES[i].nombre)) {
            return &OPERACIONES[i];
        }
    return NULL;
}

// -rnear_even   OP_RNE
// -rminMag      OP_RTZ // -rmin         OP_RDN
// -rmax         OP_RUP // -rnear_maxMag OP_RMM

/* rm validado: un token desconocido es error de uso (exit 2), no un default
 * silencioso a RNE. NULL = rm ausente = rne (contrato original del pipe).
 * Sale el codigo rm del DUT (enum ROUND_MODE), NO el codigo SoftFloat: esa
 * traduccion es del runner, que si habla con SoftFloat directamente.        */
int mapear_modo_redondeo(const char *token_rmode, unsigned int *modo_redondeo) {
    if      (!token_rmode)                          *modo_redondeo = OP_RNE;  /* ausente = rne */
    else if (!strcmp(token_rmode, "-rnear_even"))   *modo_redondeo = OP_RNE;
    else if (!strcmp(token_rmode, "-rminMag"))      *modo_redondeo = OP_RTZ;
    else if (!strcmp(token_rmode, "-rmin"))         *modo_redondeo = OP_RDN;
    else if (!strcmp(token_rmode, "-rmax"))         *modo_redondeo = OP_RUP;
    else if (!strcmp(token_rmode, "-rnear_maxMag")) *modo_redondeo = OP_RMM;
    else return -1;
    return 0;
}

/* Referencia IEEE fusionada para f32_mulSub: FMSUB(a,b,c) = mulAdd(a,b,-c)
 * con UN solo redondeo, misma configuracion que usa testfloat_gen.
 * Equivale al "gen de mulSub" que Berkeley no trae.                         */
void ref_fusionada_msub(unsigned int fp_a_bits, unsigned int fp_b_bits,
                        unsigned int fp_c_bits, unsigned int modo_redondeo,
                        unsigned int *resultado, unsigned char *banderas) {
    /* indice = codigo rm del DUT (OP_RNE..OP_RMM, ya validado en el CLI)
     * -> codigo de la API SoftFloat                                         */
    static const uint_fast8_t MODOS_REDONDEO_SOFT[5] = {
        softfloat_round_near_even, softfloat_round_minMag, softfloat_round_min,
        softfloat_round_max,       softfloat_round_near_maxMag
    };
    
    float32_t fp_a;
    float32_t fp_b;
    float32_t fp_c_negado;
    float32_t fp_resultado;

    fp_a.v = (uint32_t)fp_a_bits;
    fp_b.v = (uint32_t)fp_b_bits;
    fp_c_negado.v = (uint32_t)fp_c_bits ^ 0x80000000u;  /* -c: flip de signo */

    /* Configuracion global IDENTICA a la de gen: tininess RISC-V despues de
     * redondear. Las banderas se ACUMULAN en SoftFloat: limpiar por vector. */
    softfloat_detectTininess = softfloat_tininess_afterRounding;
    softfloat_roundingMode   = MODOS_REDONDEO_SOFT[modo_redondeo];
    softfloat_exceptionFlags = 0;

    fp_resultado = f32_mulAdd(fp_a, fp_b, fp_c_negado);
    *resultado = fp_resultado.v;
    *banderas  = (unsigned char)(softfloat_exceptionFlags & 0x1F);
}