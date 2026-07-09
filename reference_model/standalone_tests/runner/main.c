/****************************************************************************************
 * File:    main.c
 * Project: FPU RV32F - Verificacion funcional UVM, subambiente de validacion
 * Author:
 *
 * Descripcion:
 *   Juez TERMINAL del nivel N2: valida que la base SoftFloat (softfloat.a con
 *   SPECIALIZE_TYPE=RISCV y tininess afterRounding) coincide bit a bit con las
 *   columnas de referencia que produce testfloat_gen. Lee por stdin los
 *   vectores de gen (a, b, resultado_testfloat, banderas_testfloat en hex), recalcula con
 *   las MISMAS llamadas SoftFloat que usa el modelo, y cuenta discrepancias.
 *   El pipe ACABA aqui: nunca encadenar testfloat_ver (este programa no emite
 *   vectores, emite un veredicto).
 *
 *   A PROPOSITO no enlaza reference_model.{h,c}: audita la base sola, con la
 *   misma configuracion global. Si N2 (RUNNER) falla y N4 (REPLAYER) no, el
 *   problema es de build/configuracion de la libreria, no de la logica del 
 *   modelo.
 *
 *   FMADD/FMSUB del DUT son NO fusionadas (mul + add/sub con doble redondeo);
 *   por eso NO se validan aqui contra f32_mulAdd (fusionado): sus primitivas
 *   add/sub/mul ya quedan cubiertas en esta matriz.
 *
 *   Codigos de salida:  0 = sin discrepancias   1 = hubo discrepancias
 *                       2 = uso invalido, stream vacio o linea malformada
 *
 * Uso:
 *   testfloat_gen -level 1 -seed 1 -rnear_even f32_mul | ./runner_testfloat_exe -rnear_even f32_mul
 *   (rmode: -rnear_even|-rminMag|-rmin|-rmax|-rnear_maxMag)
 *   (op:    f32_add|f32_sub|f32_mul|f32_eq|f32_lt|f32_le)
 * 
 ****************************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "softfloat.h"
#include "runner_testfloat.h"   /* operacion_e + mapear_operacion/mapear_modo_redondeo */

// función tipo help de makefile
static void uso(const char *nombre_programa) {
        fprintf(stderr,
        "uso: %s <rmode> <op>\n"
        "     rmode: -rnear_even|-rminMag|-rmin|-rmax|-rnear_maxMag\n"
        "     op: f32_add|f32_sub|f32_mul|f32_eq|f32_lt|f32_le\n",
        nombre_programa);
}

int main(int argc, char **argv) {
    // datos que se muestran en la terminal
    unsigned int  fp_a_testfloat;
    unsigned int  fp_b_testfloat;
    unsigned int  resultado_testfloat;
    unsigned int  banderas_testfloat;
    // variables internas de procesamiento
    unsigned long casos_procesados = 0; 
    unsigned long discrepancias_total = 0; 
    unsigned long discrepancias_valor = 0;
    unsigned long discrepancias_banderas = 0; 
    unsigned long limite_traza = 0;
    // variables de uso con softfloat
    uint_fast8_t  modo_redondeo_soft;
    operacion_e   operacion_soft;
    int           campos_leidos;

    if (argc < 3) { uso(argv[0]); return 2; }

    if (mapear_modo_redondeo(argv[1], &modo_redondeo_soft) != 0) {
        fprintf(stderr, "runner_testfloat: rmode desconocido: %s\n", argv[1]);
        uso(argv[0]); 
        return 2;
    }

    operacion_soft = mapear_operacion(argv[2]);
    if (operacion_soft == SOFT_DESCONOCIDA) {
        fprintf(stderr, "runner_testfloat: operacion desconocida: %s\n", argv[2]);
        uso(argv[0]); return 2;
    }

    /* Configuracion global IDENTICA a la del modelo: tininess RISC-V despues
     * de redondear, y modo fijo para toda la corrida (nadie lo toca dentro). */
    softfloat_detectTininess = softfloat_tininess_afterRounding;
    softfloat_roundingMode   = modo_redondeo_soft;

    /* Scope opcional: RUNNER_TRACE 
     * Traza opcional para inspeccion: RUNNER_TRACE=N imprime a stderr los
     * primeros N casos AUNQUE pasen; "all"/"todos" imprime todos. Sin la
     * variable, salida limpia: solo discrepancias y resumen (contrato CI).
     * Se activa desde el make_runner.mk: RUNNER_TRACE ?= 0
     * */
    {
        const char *env_runner_trace = getenv("RUNNER_TRACE");
        if (env_runner_trace && *env_runner_trace) {
            if (!strcmp(env_runner_trace, "all") || !strcmp(env_runner_trace, "todos"))
                limite_traza = (unsigned long)-1;                 /* sin tope practico     */
            else
                limite_traza = strtoul(env_runner_trace, NULL, 10); /* token invalido -> 0 */
        }
    }

    while ((campos_leidos = scanf("%x %x %x %x", 
                                  &fp_a_testfloat, &fp_b_testfloat,
                                  &resultado_testfloat, &banderas_testfloat)) == 4) {

        float32_t    fp_a, fp_b, fp_resultado;
        unsigned int resultado_softfloat; // valor del softfloat - slowfloat
        uint_fast8_t banderas_softfloat;
        
        int          valor_distinto;
        int          banderas_distintas;

        fp_a.v = (uint32_t)fp_a_testfloat;
        fp_b.v = (uint32_t)fp_b_testfloat;

        /* Las banderas se ACUMULAN en SoftFloat: limpiar por vector, o el
         * NX de un caso contaminaria todos los siguientes.                  */
        softfloat_exceptionFlags = 0;

        switch (operacion_soft) {
            case SOFT_ADD:
                fp_resultado = f32_add(fp_a, fp_b); 
                resultado_softfloat = fp_resultado.v;
                break;
            case SOFT_SUB:
                fp_resultado = f32_sub(fp_a, fp_b); 
                resultado_softfloat = fp_resultado.v;
                break;
            case SOFT_MUL:
                fp_resultado = f32_mul(fp_a, fp_b); 
                resultado_softfloat = fp_resultado.v;
                break;
            case SOFT_EQ:
                resultado_softfloat = f32_eq(fp_a, fp_b) ? 1u : 0u;
                break;
            case SOFT_LT:
                resultado_softfloat = f32_lt(fp_a, fp_b) ? 1u : 0u;
                break;
            case SOFT_LE:
                resultado_softfloat = f32_le(fp_a, fp_b) ? 1u : 0u;
                break;
            default:      
                return 2; /* inalcanzable: op validada arriba */
        }
        
        banderas_softfloat = (uint_fast8_t)(softfloat_exceptionFlags & 0x1F);
        casos_procesados++;

        /* Valor y banderas se juzgan por separado para diagnostico:
         * tormenta de [FLG] con valores bien = tininess/especializacion mal;
         * [VAL] = problema mas profundo de build o de version.
         * Banderas TAMBIEN en comparaciones: gen las emite (NV con sNaN en
         * lt/le) y aqui se auditan; la politica flags=0 es del modelo (N4). */
        valor_distinto     = (resultado_softfloat != resultado_testfloat);
        banderas_distintas = ((unsigned)banderas_softfloat != (banderas_testfloat & 0x1Fu));

        /* Traza de casos correctos dentro del rango: deja ver el flujo real
         * de vectores y confirma que el runner SI esta procesando (no un
         * pipe vacio). Los casos con discrepancia los reporta el bloque de
         * abajo con su etiqueta, asi que aqui solo se emiten los OK.        */
        if (!valor_distinto && !banderas_distintas && casos_procesados <= limite_traza)
            fprintf(stderr,
                    "[OK] #%06lu a=%08X b=%08X | ref z=%08X f=%02X | sf z=%08X f=%02X\n",
                    casos_procesados, fp_a_testfloat, fp_b_testfloat, resultado_testfloat,
                    banderas_testfloat & 0x1Fu, resultado_softfloat, (unsigned)banderas_softfloat);

        if (valor_distinto || banderas_distintas) {
            discrepancias_total++;
            discrepancias_valor    += (unsigned long)valor_distinto;
            discrepancias_banderas += (unsigned long)banderas_distintas;
            // TODO: cambir el limite de las discrepancias
            if (discrepancias_total <= 20)
                fprintf(stderr,
                        "[%s] a=%08X b=%08X | ref z=%08X f=%02X | softfloat z=%08X f=%02X\n",
                        valor_distinto && banderas_distintas ? "V+F" : (valor_distinto ? "VAL" : "FLG"),
                        fp_a_testfloat, fp_b_testfloat, resultado_testfloat, banderas_testfloat & 0x1Fu,
                        resultado_softfloat, (unsigned)banderas_softfloat);
            else if (discrepancias_total == 21)
                fprintf(stderr, "... (solo se muestran las primeras 20 discrepancias)\n");
        }
    }

    /* scanf devolvio algo distinto de 4 y de EOF: linea malformada o
     * truncada a mitad de stream. Reportar exito parcial seria mentir.      */
    if (campos_leidos != EOF) {
        fprintf(stderr,
                "runner_testfloat: entrada malformada tras %lu casos (scanf=%d)\n",
                casos_procesados, campos_leidos);
        return 2;
    }

    /* Guarda de '0 tests performed': un pipe vacio (gen fallo, ruta mala,
     * op equivocada en gen) NO es un PASS, es una corrida que no ocurrio.   */
    if (casos_procesados == 0) {
        fprintf(stderr,
                "runner_testfloat: 0 casos leidos; pipe vacio o gen mal invocado\n");
        return 2;
    }

    printf("runner_testfloat[%s,%s]: %lu casos, %lu discrepancias (valor=%lu, banderas=%lu)\n",
           argv[2], argv[1], casos_procesados, discrepancias_total,
           discrepancias_valor, discrepancias_banderas);
    return discrepancias_total ? 1 : 0;
}