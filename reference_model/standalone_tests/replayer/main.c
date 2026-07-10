/****************************************************************************************
 * File:    main.c
 * Project: FPU RV32F - Verificacion funcional UVM, subambiente de validacion
 * Author:
 *
 * Descripcion:
 *   Adaptador de E/S del nivel N4 entre testfloat_gen y el modelo de
 *   referencia, con dos modos:
 *
 *   MODO PIPE (default):  testfloat_gen | replayer [rm] <op> | testfloat_ver ...
 *     Lee los vectores de tf_gen, sustituye las columnas de referencia por la
 *     salida del modelo (dpi_fpu_reference) y emite el MISMO formato que
 *     tf_gen, para que tf_ver juzgue. El replayer NO juzga aqui: el juez es
 *     tf_ver.
 *
 *   MODO CSV (--csv):     tf_gen | replayer [rm] <op> --csv > csv/op_rm.csv
 *     El replayer se vuelve juez terminal de caracterizacion: compara el
 *     modelo (r_dut/f_dut) contra la referencia IEEE (r_ref/f_ref) y emite
 *     una fila por vector para consolidate.py. Aqui van las operaciones con
 *     divergencias ESPERADAS (doble redondeo, politica flags=0) que el gate
 *     de tf_ver no debe juzgar.
 *
 *   Esquema CSV (header incluido; rm numerico 0-4; hex sin 0x; c vacio
 *   salvo en FMADD/FMSUB; result_ok/flags_ok en {0,1}):
 *     op,rm,a,b,c,r_dut,f_dut,r_ref,f_ref,result_ok,flags_ok
 *
 *   Pseudo-op f32_mulSub (solo --csv): tf_gen no genera FMSUB, asi que
 *   consume el stream de f32_mulAdd (misma aridad) y despacha OP_FMSUB
 *   (FMSUB = a*b - c) en el modelo. Su referencia IEEE no viene en el stream
 *   (las columnas de tf_gen son del madd FUSIONADO): se calcula localmente
 *   como f32_mulAdd(a, b, -c) con la MISMA libreria SoftFloat que usa tf_gen,
 *   bajo el mismo modo. Es el unico punto donde este arnes toca SoftFloat
 *   directamente; la frontera DPI (reference_model.h) sigue sin exponerla.
 *
 *   Orden de posicionales: [rm] <op>. El rm va PRIMERO y es opcional; la op
 *   va ULTIMA y es obligatoria. Se diferencia por CANTIDAD de posicionales
 *   (1 = solo op con rne por defecto; 2 = rm + op), de modo que el rm
 *   conserva su opcionalidad pese a ir primero, sin defaults silenciosos
 *   para tokens basura.
 *
 *   Guardas (mismas lecciones que el runner):
 *     - op y rm validados antes de tocar stdin (sin default silencioso
 *       para tokens desconocidos; rm ausente = rne, contrato original).
 *     - 0 casos leidos = exit 2 (leccion '0 tests performed').
 *     - linea malformada a mitad de stream = exit 2, no exito parcial.
 *     - f32_mulSub sin --csv = exit 2 (tf_ver no conoce esa funcion).
 *
 *   Codigos de salida:  0 = stream procesado completo
 *                       2 = uso invalido, stream vacio o linea malformada
 *   (No existe exit 1: este programa no juzga PASS/FAIL del modelo; eso es
 *    de tf_ver en modo pipe y de consolidate.py en modo csv.)
 *
 * Uso:
 *   testfloat_gen -level 1 -seed 1 -rnear_even f32_mul \
 *     | ./replayer_testfloat_exe -rnear_even f32_mul \
 *     | testfloat_ver -rnear_even ... f32_mul
 * 
 *   testfloat_gen -level 1 -seed 1 -rnear_even f32_mulAdd \
 *     | ./replayer_testfloat_exe -rnear_even f32_mulSub --csv \
 *     > csv/f32_mulSub_rne.csv
 * 
 *   (rm: -rnear_even|-rminMag|-rmin|-rmax|-rnear_maxMag ; opcional, ANTES de la op)
 *   (op: f32_add|f32_sub|f32_mul|f32_mulAdd|f32_mulSub|f32_eq|f32_lt|f32_le)
 ****************************************************************************************/
#include <stdio.h>
#include <string.h>
#include "reference_model.h"      /* frontera DPI del modelo (resuelto por -Iinclude) */
#include "replayer_testfloat.h"   /* operacion_t + mapear_operacion/mapear_modo_redondeo
                                   * + ref_fusionada_msub                              */

// funcion tipo help de makefile
static void uso(const char *nombre_programa) {
    fprintf(stderr,
        "uso: %s [<rm>] <op> [--csv]   (lee la salida de testfloat_gen por stdin)\n"
        "     rm: -rnear_even|-rminMag|-rmin|-rmax|-rnear_maxMag\n"
        "         (opcional, va ANTES de op; ausente = rne; ignorado en comparaciones)\n"
        "     op: f32_add|f32_sub|f32_mul|f32_mulAdd|f32_mulSub|f32_eq|f32_lt|f32_le\n"
        "     --csv: opcional, va AL FINAL; activa el modo CSV de caracterizacion\n"
        "     f32_mulSub: solo con --csv, consumiendo vectores de f32_mulAdd\n",
        nombre_programa);
}

int main(int argc, char **argv) {
    // datos que llegan por stdin (stream de testfloat_gen)
    unsigned int  fp_a_testfloat;
    unsigned int  fp_b_testfloat;
    unsigned int  fp_c_testfloat;      /* solo operaciones de aridad 3 */
    unsigned int  resultado_testfloat;
    unsigned int  banderas_testfloat;
    // variables internas de procesamiento
    unsigned long casos_procesados = 0;
    int           campos_leidos;
    // variables del CLI ([<rm>] <op> [--csv])
    int           modo_csv = 0;
    int           num_posicionales;
    const char   *token_rmode;
    const char   *token_operacion;
    // variables de despacho hacia el modelo (frontera DPI)
    const operacion_t *operacion;
    unsigned int       modo_redondeo;

    /* Scope opcional para incluir salida en CSV
     * --csv es opcional y, si esta, debe ser el ULTIMO argumento (contrato
     * [<rm>] <op> [--csv]). En cualquier otra posicion es error de uso, no
     * un default silencioso ni un --csv "perdido" en medio.                 */
    {
        int indice_ultimo = argc - 1;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--csv")) {
                if (i != indice_ultimo) {
                    fprintf(stderr,
                        "replayer_testfloat: --csv debe ir al final ([<rm>] <op> [--csv])\n");
                    uso(argv[0]); return 2;
                }
                modo_csv = 1;
            }
        }
    }

    /* Posicionales = argv[1 .. ultimo], excluyendo el --csv final si existe.
     * La op SIEMPRE es obligatoria y va ULTIMA (antes de --csv); el rm es
     * opcional y, si esta, va PRIMERO. Desambiguacion por CANTIDAD:
     *   1 posicional   -> solo op (rm por defecto rne)
     *   2 posicionales -> rm, luego op
     * mapear_modo_redondeo/mapear_operacion siguen rechazando tokens basura
     * (sin default mudo).                                                   */
    num_posicionales = argc - 1 - modo_csv;
    if (num_posicionales == 1) {
        token_rmode     = NULL;
        token_operacion = argv[1];
    } else if (num_posicionales >= 2) {
        token_rmode     = argv[1];
        token_operacion = argv[2];
    } else {
        uso(argv[0]); return 2;
    }

    /* rm y op validados ANTES de tocar stdin, en el mismo orden de chequeo
     * que el runner: rm primero, op despues (token desconocido = uso).      */
    if (mapear_modo_redondeo(token_rmode, &modo_redondeo) != 0) {
        fprintf(stderr, "replayer_testfloat: rm desconocido: %s\n", token_rmode);
        uso(argv[0]); return 2;
    }
    operacion = mapear_operacion(token_operacion);
    if (!operacion) {
        fprintf(stderr, "replayer_testfloat: op no soportada: %s\n", token_operacion);
        uso(argv[0]); return 2;
    }
    /* f32_mulSub emite resultados de a*b-c: encadenarlo a ver (que juzgaria
     * contra mulAdd fusionado) seria basura con apariencia de corrida.      */
    if (operacion->solo_csv && !modo_csv) {
        fprintf(stderr,
            "replayer_testfloat: %s solo tiene sentido con --csv (ver no la conoce)\n",
            operacion->nombre);
        return 2;
    }

    if (modo_csv)
        printf("op,rm,a,b,c,r_dut,f_dut,r_ref,f_ref,result_ok,flags_ok\n");

    if (operacion->aridad == 2) {
        while ((campos_leidos = scanf("%x %x %x %x",
                                      &fp_a_testfloat, &fp_b_testfloat,
                                      &resultado_testfloat, &banderas_testfloat)) == 4) {
            unsigned int  resultado_modelo;   /* salida del modelo via DPI  */
            unsigned char banderas_modelo;

            dpi_fpu_reference(operacion->op_code, fp_a_testfloat, fp_b_testfloat, 0u,
                              modo_redondeo, &resultado_modelo, &banderas_modelo);
            casos_procesados++;

            if (modo_csv) {
                /* Referencia de la fila = columnas de gen (en 2-op no hay
                 * recalculo local); c vacio (esquema de consolidate.py).
                 * result_ok/flags_ok registran COINCIDENCIA con la
                 * referencia, no veredicto: flags_ok=0 en lt/le con sNaN
                 * documenta la politica flags=0 del modelo (divergencia
                 * esperada, no bug).                                        */
                unsigned int csv_resultado_referencia = resultado_testfloat;
                unsigned int csv_banderas_referencia  = banderas_testfloat & 0x1Fu;
                unsigned int csv_resultado_coincide;
                unsigned int csv_banderas_coinciden;

                csv_resultado_coincide = (resultado_modelo == csv_resultado_referencia) ? 1u : 0u;
                csv_banderas_coinciden = ((unsigned)banderas_modelo == csv_banderas_referencia) ? 1u : 0u;
                printf("%s,%u,%08X,%08X,,%08X,%02X,%08X,%02X,%u,%u\n",
                       operacion->nombre, modo_redondeo, fp_a_testfloat, fp_b_testfloat,
                       resultado_modelo, banderas_modelo,
                       csv_resultado_referencia, csv_banderas_referencia,
                       csv_resultado_coincide, csv_banderas_coinciden);
            } else if (operacion->es_booleana) {
                printf("%08X %08X %X %02X\n",
                       fp_a_testfloat, fp_b_testfloat, resultado_modelo & 1u, banderas_modelo);
            } else {
                printf("%08X %08X %08X %02X\n",
                       fp_a_testfloat, fp_b_testfloat, resultado_modelo, banderas_modelo);
            }
        }
    } else { /* 3-op: f32_mulAdd y la pseudo-op f32_mulSub (mismo stream)    */
        while ((campos_leidos = scanf("%x %x %x %x %x",
                                      &fp_a_testfloat, &fp_b_testfloat, &fp_c_testfloat,
                                      &resultado_testfloat, &banderas_testfloat)) == 5) {
            unsigned int  resultado_modelo;
            unsigned char banderas_modelo;

            dpi_fpu_reference(operacion->op_code, fp_a_testfloat, fp_b_testfloat,
                              fp_c_testfloat, modo_redondeo,
                              &resultado_modelo, &banderas_modelo);
            casos_procesados++;

            if (modo_csv) {
                unsigned int csv_resultado_referencia = resultado_testfloat;
                unsigned int csv_banderas_referencia  = banderas_testfloat & 0x1Fu;
                unsigned int csv_resultado_coincide;
                unsigned int csv_banderas_coinciden;

                if (operacion->op_code == OP_FMSUB) {
                    /* mulSub: las columnas del stream son del madd fusionado;
                     * la referencia correcta se recalcula local (ver arriba).
                     * banderas_msub puentea el unsigned char de la firma
                     * estilo DPI hacia el unsigned int del CSV.             */
                    unsigned char banderas_msub;
                    ref_fusionada_msub(fp_a_testfloat, fp_b_testfloat, fp_c_testfloat,
                                       modo_redondeo, &csv_resultado_referencia, &banderas_msub);
                    csv_banderas_referencia = banderas_msub;
                }
                /* result_ok=0 aqui caracteriza BUG-002: doble redondeo del
                 * modelo (fiel al DUT) vs fusionado IEEE de referencia.     */
                csv_resultado_coincide = (resultado_modelo == csv_resultado_referencia) ? 1u : 0u;
                csv_banderas_coinciden = ((unsigned)banderas_modelo == csv_banderas_referencia) ? 1u : 0u;
                printf("%s,%u,%08X,%08X,%08X,%08X,%02X,%08X,%02X,%u,%u\n",
                       operacion->nombre, modo_redondeo,
                       fp_a_testfloat, fp_b_testfloat, fp_c_testfloat,
                       resultado_modelo, banderas_modelo,
                       csv_resultado_referencia, csv_banderas_referencia,
                       csv_resultado_coincide, csv_banderas_coinciden);
            } else {
                printf("%08X %08X %08X %08X %02X\n",
                       fp_a_testfloat, fp_b_testfloat, fp_c_testfloat,
                       resultado_modelo, banderas_modelo);
            }
        }
    }

    /* Mismas guardas que el runner.
     * scanf devolvio algo distinto de la aridad esperada y de EOF: linea
     * malformada o truncada a mitad de stream. Exito parcial seria mentir.  */
    if (campos_leidos != EOF) {
        fprintf(stderr,
            "replayer_testfloat: entrada malformada tras %lu casos (scanf=%d)\n",
            casos_procesados, campos_leidos);
        return 2;
    }
    /* Guarda de '0 tests performed': un pipe vacio (gen fallo, ruta mala,
     * op equivocada en gen) NO es un exito, es una corrida que no ocurrio.  */
    if (casos_procesados == 0) {
        fprintf(stderr,
            "replayer_testfloat: 0 casos leidos; pipe vacio o gen mal invocado\n");
        return 2;
    }
    return 0;
}