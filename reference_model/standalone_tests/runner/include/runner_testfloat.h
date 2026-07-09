#ifndef RUNNER_TESTFLOAT_H
#define RUNNER_TESTFLOAT_H

#include <stdint.h>   /* uint_fast8_t (codigos de redondeo SoftFloat) */

/* Operacion resuelta a enum: el lazo caliente despacha con switch, no con
 * cadenas; y una op invalida se rechaza ANTES de consumir stdin.            */
typedef enum { 
    SOFT_ADD, 
    SOFT_SUB, 
    SOFT_MUL, 
    SOFT_EQ, 
    SOFT_LT, 
    SOFT_LE, 
    SOFT_DESCONOCIDA 
} operacion_e;

/* rmode validado: un token desconocido es error de uso (exit 2), 
no un
 * default silencioso a RNE que auditaria el modo equivocado. Devuelve 0 en
 * exito (modo_redondeo <- codigo SoftFloat), -1 si el token no se reconoce. */
int mapear_modo_redondeo(const char *token_rmode, uint_fast8_t *modo_redondeo);

/* Nombre estilo TestFloat -> enum; OP_DESCONOCIDA si no esta soportada. */
operacion_e mapear_operacion(const char *nombre_operacion);

#endif /* RUNNER_TESTFLOAT_H */