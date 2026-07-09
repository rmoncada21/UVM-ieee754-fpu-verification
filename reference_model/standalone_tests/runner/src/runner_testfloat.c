/****************************************************************************************
 * File:    runner_testfloat.c
 * Project: FPU RV32F - Verificacion funcional UVM, subambiente de validacion
 * Author:
 *
 * Modulo de dominio del runner N3: mapeo de nombre de operacion a enum y de
 * token de redondeo del CLI a codigo SoftFloat. Ambos validan ANTES de tocar
 * stdin (op/rmode invalido = error de uso). La orquestacion (CLI, lazo de
 * auditoria contra SoftFloat, guardas y codigos de salida) vive en main.c.
 ****************************************************************************************/
#include <string.h>
#include <stdint.h>
#include "softfloat.h"
#include "runner_testfloat.h"

operacion_e mapear_operacion(const char *nombre_operacion) {
    if (!strcmp(nombre_operacion, "f32_add")) return SOFT_ADD;
    if (!strcmp(nombre_operacion, "f32_sub")) return SOFT_SUB;
    if (!strcmp(nombre_operacion, "f32_mul")) return SOFT_MUL;
    if (!strcmp(nombre_operacion, "f32_eq"))  return SOFT_EQ;
    if (!strcmp(nombre_operacion, "f32_lt"))  return SOFT_LT;
    if (!strcmp(nombre_operacion, "f32_le"))  return SOFT_LE;
    return SOFT_DESCONOCIDA;
}

// -rnear_even   rne
// -rminMag      rtz // -rmin         rdn
// -rmax         rup // -rnear_maxMag rmm

/* rmode validado: un token desconocido es error de uso (exit 2), no un
 * default silencioso a RNE que auditaria el modo equivocado.                */
int mapear_modo_redondeo(const char *token_rmode, uint_fast8_t *modo_redondeo) {
    if      (!strcmp(token_rmode, "-rnear_even"))   *modo_redondeo = softfloat_round_near_even;
    else if (!strcmp(token_rmode, "-rminMag"))      *modo_redondeo = softfloat_round_minMag;
    else if (!strcmp(token_rmode, "-rmin"))         *modo_redondeo = softfloat_round_min;
    else if (!strcmp(token_rmode, "-rmax"))         *modo_redondeo = softfloat_round_max;
    else if (!strcmp(token_rmode, "-rnear_maxMag")) *modo_redondeo = softfloat_round_near_maxMag;
    else return -1;
    return 0;
}