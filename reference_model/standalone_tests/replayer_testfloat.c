/* 
Este archivo actúa como un puente que adapta los vectores de prueba del
software externo (testfloat_gen) al formato del modelo de referencia.

- tf_replay.c funciona como un traductor y formateador de flujos de datos en 
tiempo real. Su objetivo es alimentar a el modelo de referencia (dpi_fpu_reference) y 
formatear la salida exactamente como lo espera el ecosistema de Berkeley TestFloat.
*/

#include <stdio.h>
#include <stdlib.h>
#include <../include/reference_model.h>

int main(){
   
    return 0;
}