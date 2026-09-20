#ifndef REPLAYER_TESTFLOAT_H
#define REPLAYER_TESTFLOAT_H

/* Homonimo deliberado de runner_testfloat.h (mismos nombres de funcion,
 * contratos distintos): son ejecutables separados; nunca incluir ambos
 * encabezados en la misma unidad de traduccion.                             */

/* Operacion resuelta a fila de tabla: a diferencia del runner (enum: solo
 * identidad, para despachar con switch), aqui cada operacion porta atributos
 * que main consulta en varios puntos (op_code del contrato DPI, aridad del
 * stream, salida booleana, restriccion csv). La fila ES el objeto de dominio
 * y NULL es el centinela (rol de SOFT_DESCONOCIDA); una op invalida se
 * rechaza ANTES de consumir stdin.                                          */
typedef struct {
    const char  *nombre;       /* nombre estilo TestFloat (argumento CLI)    */
    unsigned int op_code;      /* codigo de operacion del DUT (contrato DPI) */
    int          aridad;       /* 2 o 3 operandos en el stream               */
    int          es_booleana;  /* 1 si la salida es 1 bit (comparaciones)    */
    int          solo_csv;     /* 1 si no puede ir en modo pipe (sin ver)    */
} operacion_t;

/* rm validado: un token desconocido es error de uso (exit 2), no un
 * default silencioso a RNE. NULL = rm ausente = rne (contrato original del
 * pipe; en el runner el rmode es obligatorio y esta rama no existe).
 * Devuelve 0 en exito (modo_redondeo <- codigo rm del DUT, enum ROUND_MODE
 * de reference_model.h: 0=RNE 1=RTZ 2=RDN 3=RUP 4=RMM), -1 si el token no
 * se reconoce. Ignorado en comparaciones.                                   */
int mapear_modo_redondeo(const char *token_rmode, unsigned int *modo_redondeo);

/* Nombre estilo TestFloat -> fila de la tabla; NULL si no esta soportada.   */
const operacion_t *mapear_operacion(const char *nombre_operacion);

/* Referencia IEEE fusionada para f32_mulSub: FMSUB(a,b,c) = mulAdd(a,b,-c)
 * con UN solo redondeo, misma configuracion que usa testfloat_gen.
 * Equivale al "gen de mulSub" que Berkeley no trae. Firma estilo DPI
 * (salidas por puntero, mismos tipos que dpi_fpu_reference) a proposito.    */
void ref_fusionada_msub(unsigned int fp_a_bits, unsigned int fp_b_bits,
                        unsigned int fp_c_bits, unsigned int modo_redondeo,
                        unsigned int *resultado, unsigned char *banderas);

#endif /* REPLAYER_TESTFLOAT_H */