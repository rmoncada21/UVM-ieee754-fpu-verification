# Convención de Código SystemVerilog

**Proyecto:** Verificación Funcional FPU RV32F
**Estándar base:** IEEE 1800-2017 (SystemVerilog)  
**Metodología:** UVM 1.2

> Este documento es normativo. Todo código `.sv` producido en el marco de este proyecto debe cumplir las reglas aquí descritas. En caso de conflicto entre este documento y un ejemplo externo, prevalece este documento.

---

## Tabla de contenidos

1. [Reglas generales](#1-reglas-generales)
2. [Enumeraciones (`enum`)](#2-enumeraciones-enum)
3. [Definiciones de tipo (`typedef`)](#3-definiciones-de-tipo-typedef)
4. [Mailboxes](#4-mailboxes)
5. [Restricciones (`constraint`)](#5-restricciones-constraint)
6. [Clases](#6-clases)
7. [Colas (`queue`)](#7-colas-queue)
8. [Pilas (`stack`)](#8-pilas-stack)
9. [Arreglos (`array`)](#9-arreglos-array)
10. [Interfaces](#10-interfaces)
11. [Interfaces virtuales](#11-interfaces-virtuales)
12. [Parámetros y constantes](#12-parámetros-y-constantes)
13. [Tareas y funciones](#13-tareas-y-funciones)
14. [Señales por dirección](#14-señales-por-dirección)
15. [Semáforos](#15-semáforos)
16. [Eventos](#16-eventos)
17. [Variables aleatorias](#17-variables-aleatorias)
18. [Paquetes (`package`)](#18-paquetes-package)
19. [Grupos de cobertura (`covergroup`)](#19-grupos-de-cobertura-covergroup)
20. [Aserciones (SVA)](#20-aserciones-sva)
21. [DPI-C](#21-dpi-c)
22. [Nombres de instancias](#22-nombres-de-instancias)
23. [Encabezado de archivo (NaturalDocs)](#23-encabezado-de-archivo-naturaldocs)
24. [Referencia rápida](#24-referencia-rápida)

---

## 1. Reglas generales

Las siguientes reglas aplican a todo el código del proyecto sin excepción.

| Regla | Descripción |
|---|---|
| Estilo de escritura | `snake_case` para identificadores; `PascalCase` **nunca** se usa |
| Tipos | Siempre con **sufijo de tipo** (ver sección 3) |
| Constantes y valores `enum` | En **MAYÚSCULAS** |
| Claridad de nombres | Un concepto = un nombre. Se prohíben abreviaciones ambiguas |

```verilog
// Language: SystemVerilog
logic        valid_i;      // puerto de entrada
logic [7:0]  data_o;       // puerto de salida
int          packet_count; // variable interna
```

---

## 2. Enumeraciones (`enum`)

### Reglas

- Los valores del `enum` van en **MAYÚSCULAS**.
- El tipo resultante lleva el sufijo `_e`.
- Se usa `typedef` **siempre**; nunca `enum` anónimo.

### Ejemplo

```verilog
// Language: SystemVerilog
typedef enum logic [2:0] {
    FADD  = 3'd0,
    FSUB  = 3'd1,
    FMUL  = 3'd2,
    FMADD = 3'd3,
    FMSUB = 3'd4,
    FEQ   = 3'd5,
    FLT   = 3'd6,
    FLE   = 3'd7
} fp_op_code_e;
```

> ✔ Correcto: `fp_op_code_e`, valores en mayúsculas  
> ✘ Evitar: `enum {fadd, Fsub, fmul}`

---

## 3. Definiciones de tipo (`typedef`)

### Reglas

- Todo `typedef` lleva **sufijo de tipo**.
- No se usan `typedef` anónimos.

### Tabla de sufijos

| Construcción     | Sufijo  |
|------------------|---------|
| `enum`           | `_e`    |
| `struct`         | `_s`    |
| `union`          | `_u`    |
| `class`          | `_c`    |
| `interface`      | `_if`   |
| virtual interface| `_vif`  |
| tipo de función  | `_ft`   |
| `package`        | `_pkg`  |

### Ejemplo — `struct`

```verilog
// Language: SystemVerilog
typedef struct packed {
    logic [31:0] addr;
    logic [31:0] data;
    logic        we;
} bus_transaction_s;
```

### Ejemplo — tipo de función (`_ft`)

Usado en el scoreboard de la FPU para despachar cada `op_code` a su
función de referencia correspondiente:

```verilog
// Language: SystemVerilog
typedef function automatic logic [31:0] fp_op_func_ft (
    input logic [31:0] fp_a_i,
    input logic [31:0] fp_b_i,
    input logic [2:0]  r_mode_i
);
```

---

## 4. Mailboxes

### Reglas

- Siempre tipados con `#(tipo)`.
- Sufijo `_mbx`.
- El nombre indica la dirección o el propósito del canal.

### Ejemplo

```verilog
// Language: SystemVerilog
mailbox #(bus_transaction_s) mbx_req;
mailbox #(bus_transaction_s) mbx_rsp;
```

> ✔ Correcto: nombre descriptivo, tipado explícito  
> ✘ Evitar: `mailbox m;`

---

## 5. Restricciones (`constraint`)

### Reglas

- El nombre comienza con el prefijo `cn_`.
- El nombre describe la **intención semántica**, no la expresión lógica.
- Las restricciones relacionadas se agrupan en un mismo bloque.

### Ejemplo

```verilog
// Language: SystemVerilog
constraint cn_alineacion_addr {
    addr[1:0] == 2'b00;
}

constraint cn_rango_valido {
    size inside {[1:1024]};
}
```

> ✔ Correcto: `cn_modo_redondeo_valido`, `cn_operandos_normales`  
> ✘ Evitar: `c_rng`, `constraint1`

---

## 6. Clases

### Reglas

- El nombre de la clase lleva el sufijo `_c`.
- Un archivo por clase (regla ideal; no romper salvo justificación documentada).
- Las variables de instancia son `protected` por defecto; `local` cuando no se hereda.

### Ejemplo

```verilog
// Language: SystemVerilog
class fpu_driver_c extends uvm_driver #(fpu_seq_item_c);

    protected virtual fpu_if fpu_vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
```

---

## 7. Colas (`queue`)

### Reglas

- Se declara con la sintaxis `[$]` explícita.
- Sufijo `_q`.

### Ejemplo

```verilog
// Language: SystemVerilog
fpu_seq_item_c pending_q[$];
int            retry_count_q[$];
```

---

## 8. Pilas (`stack`)

Las pilas son conceptualmente colas con acceso LIFO. Se diferencian por
nombre y comentario para que la intención sea explícita.

### Reglas

- Sufijo `_stk`.
- Siempre acompañar de un comentario `// LIFO`.

### Ejemplo

```verilog
// Language: SystemVerilog
int call_stack_stk[$]; // LIFO
```

---

## 9. Arreglos (`array`)

### Tabla de sufijos

| Tipo de arreglo | Sufijo |
|-----------------|--------|
| Estático        | `_a`   |
| Dinámico        | `_da`  |
| Asociativo      | `_aa`  |

### Ejemplo

```verilog
// Language: SystemVerilog
int    error_count_a [8];
int    payload_da    [];
string reg_map_aa    [string];
```

---

## 10. Interfaces

### Reglas

- Sufijo `_if`.
- Las señales se agrupan por dirección mediante `modport`.

### Ejemplo

```verilog
// Language: SystemVerilog
interface fpu_if #(
    parameter int P_ADDR_WIDTH = 3
)(
    input logic clk
);

    logic [31:0]         fp_a_i;
    logic [31:0]         fp_b_i;
    logic [31:0]         fp_result_o;
    logic [P_ADDR_WIDTH-1:0] op_code_i;

    modport driver_mp  (output fp_a_i, output fp_b_i, output op_code_i,
                        input  fp_result_o);
    modport monitor_mp (input  fp_a_i, input  fp_b_i, input  op_code_i,
                        input  fp_result_o);

endinterface : fpu_if
```

---

## 11. Interfaces virtuales

### Regla

- Sufijo `_vif`.

### Ejemplo

```verilog
// Language: SystemVerilog
virtual fpu_if fpu_vif;
```

---

## 12. Parámetros y constantes

### Reglas

| Construcción  | Ámbito                                  | Prefijo | Estilo     |
|---------------|-----------------------------------------|---------|------------|
| `parameter`   | Puertos de módulos e interfaces (configurable desde fuera) | `P_` | MAYÚSCULAS |
| `localparam`  | Constantes internas (no configurables)  | `C_`    | MAYÚSCULAS |

### Ejemplo

```verilog
// Language: SystemVerilog
// En el módulo o interfaz — configurable desde el testbench
module fpu_tb_top #(
    parameter int P_ADDR_WIDTH = 3,
    parameter int P_DATA_WIDTH = 32
);

// Constantes internas del ambiente — no configurables desde fuera
localparam int C_NUM_OPERACIONES = 8;
localparam int C_BITS_FP         = 32;
localparam int C_BITS_EXPONENTE  = 8;
localparam int C_BITS_MANTISSA   = 23;
```

> ✔ Correcto: `P_ADDR_WIDTH`, `C_NUM_OPERACIONES`  
> ✘ Evitar: `localparam addr_width = 3` (minúsculas, sin prefijo)

---

## 13. Tareas y funciones

### Reglas

- Nombres en `snake_case`.
- Comenzar con un **verbo** que describa la acción.
- Las funciones `automatic` son preferidas en contextos de verificación.

### Ejemplo

```verilog
// Language: SystemVerilog
task automatic enviar_transaccion(fpu_seq_item_c item);
    // ...
endtask

function automatic bit es_resultado_nan(logic [31:0] fp_result_i);
    return (fp_result_i[30:23] == 8'hFF) && (fp_result_i[22:0] != 0);
endfunction
```

---

## 14. Señales por dirección

### Tabla de sufijos

| Dirección                    | Sufijo |
|------------------------------|--------|
| Puerto de entrada (`input`)  | `_i`   |
| Puerto de salida (`output`)  | `_o`   |
| Puerto bidireccional         | `_io`  |
| Señal interna combinacional  | `_w`   |
| Registro (flip-flop)         | `_r`   |

> **Nota importante:** El sufijo `_r` está **reservado exclusivamente** para
> registros secuenciales (flip-flops). Las señales internas combinacionales
> usan `_w` para eliminar ambigüedad. En el DUT `fp_alu`, que es puramente
> combinacional, **todas** las señales internas son `_w`.

### Ejemplo

```verilog
// Language: SystemVerilog
// Puertos del módulo
logic [31:0] fp_a_i;        // entrada
logic [31:0] fp_result_o;   // salida

// Señales internas
logic [31:0] fp_resultado_w;  // combinacional — wire interno
logic [7:0]  estado_r;        // flip-flop — solo en lógica secuencial
```

> ✔ Correcto: `result_sign_w`, `carry_out_w`, `mantissa_sum_w`  
> ✘ Evitar: `result_sign_r` para una señal combinacional

---

## 15. Semáforos

### Reglas

- Sufijo `_sem`.
- Inicialización explícita en la declaración.

### Ejemplo

```verilog
// Language: SystemVerilog
semaphore bus_acceso_sem = new(1);
```

> ✔ Correcto: nombre descriptivo, recurso inicializado  
> ✘ Evitar: `semaphore sem;`

---

## 16. Eventos

### Reglas

- Sufijo `_evt`.
- El nombre describe **qué ocurrió**, no qué lo causó.
- Usados exclusivamente para sincronización; nunca para transportar datos.

### Ejemplo

```verilog
// Language: SystemVerilog
event transaccion_lista_evt;

// Disparar
-> transaccion_lista_evt;

// Esperar
@(transaccion_lista_evt);
```

---

## 17. Variables aleatorias

### Reglas

- El calificador `rand` o `randc` es **siempre explícito** en la declaración.
- Sufijo `_rand` para variables `rand`.
- Sufijo `_randc` para variables `randc`.

La razón de este sufijo es que la aleatoriedad de una variable debe ser
visible al leer el nombre en cualquier punto del código, sin necesidad
de regresar a la declaración.

### Ejemplo

```verilog
// Language: SystemVerilog
rand  logic [31:0] fp_a_rand;
rand  logic [2:0]  r_mode_rand;
randc logic [2:0]  op_code_randc;
```

> ✔ Correcto: aleatoriedad visible en el nombre  
> ✘ Evitar: `rand logic [31:0] a;` (ambiguo al referenciar `a` más adelante)

---

## 18. Paquetes (`package`)

### Reglas

- Sufijo `_pkg`.
- Contienen únicamente: tipos, parámetros, funciones de utilidad.
- **No** contienen lógica activa ni instancias de módulos.

### Ejemplo

```verilog
// Language: SystemVerilog
package fpu_tipos_pkg;

    typedef enum logic [2:0] {
        FADD  = 3'd0,
        FSUB  = 3'd1,
        FMUL  = 3'd2,
        FMADD = 3'd3,
        FMSUB = 3'd4,
        FEQ   = 3'd5,
        FLT   = 3'd6,
        FLE   = 3'd7
    } fp_op_code_e;

    typedef enum logic [2:0] {
        RNE = 3'b000,
        RTZ = 3'b001,
        RDN = 3'b010,
        RUP = 3'b011,
        RMM = 3'b100
    } fp_r_mode_e;

endpackage : fpu_tipos_pkg
```

---

## 19. Grupos de cobertura (`covergroup`)

### Reglas

| Elemento     | Convención           |
|--------------|----------------------|
| Grupo        | Prefijo `cg_`        |
| Coverpoint   | Prefijo `cp_`        |
| Bin          | Prefijo `b_`         |
| Cross        | Prefijo `x_`         |
| Instancia    | Nombre base del grupo sin `cg_`, con sufijo de instancia según sección 22 |

### Ejemplo

```verilog
// Language: SystemVerilog
covergroup cg_fpu_operacion @(posedge clk);

    cp_op_code : coverpoint op_code_i {
        bins b_fadd  = {FADD};
        bins b_fsub  = {FSUB};
        bins b_fmul  = {FMUL};
        bins b_fmadd = {FMADD};
        bins b_fmsub = {FMSUB};
        bins b_feq   = {FEQ};
        bins b_flt   = {FLT};
        bins b_fle   = {FLE};
    }

    cp_r_mode : coverpoint r_mode_i {
        bins b_rne = {RNE};
        bins b_rtz = {RTZ};
        bins b_rdn = {RDN};
        bins b_rup = {RUP};
        bins b_rmm = {RMM};
    }

    x_op_modo : cross cp_op_code, cp_r_mode;

endgroup : cg_fpu_operacion

// Instanciación
cg_fpu_operacion cg_fpu_op;
```

---

## 20. Aserciones (SVA)

### Tabla de prefijos

| Construcción SVA | Prefijo |
|------------------|---------|
| `assert property`| `a_`    |
| `property`       | `p_`    |
| `sequence`       | `s_`    |

### Ejemplo

```verilog
// Language: SystemVerilog
sequence s_entrada_estable;
    ##1 $stable(fp_a_i) && $stable(fp_b_i);
endsequence

property p_resultado_valido;
    @(posedge clk) s_entrada_estable |-> ##1 !$isunknown(fp_result_o);
endproperty

a_resultado_valido : assert property (p_resultado_valido)
    else `uvm_error("SVA", "Resultado contiene X/Z tras entrada estable");
```

---

## 21. DPI-C

### Reglas

- Funciones importadas llevan el prefijo `dpi_`.
- Las firmas se mantienen simples: tipos escalares o arreglos de tipos básicos.
- Las declaraciones `import` se agrupan en un `package` dedicado.

### Ejemplo

```verilog
// Language: SystemVerilog
package fpu_dpi_pkg;

    import "DPI-C" function int unsigned dpi_softfloat_fadd(
        input int unsigned fp_a_i,
        input int unsigned fp_b_i,
        input byte unsigned r_mode_i
    );

    import "DPI-C" function int unsigned dpi_softfloat_fmul(
        input int unsigned fp_x_i,
        input int unsigned fp_y_i,
        input byte unsigned r_mode_i
    );

endpackage : fpu_dpi_pkg
```

---

## 22. Nombres de instancias

Se distinguen dos contextos con convenciones distintas:

### RTL / DUT

Prefijo `u_` seguido del nombre descriptivo del bloque en `snake_case`:

```verilog
// Language: SystemVerilog
// En fp_adder.sv
fp_unpack         u_desempaquetado_a ( .* );
fp_unpack         u_desempaquetado_b ( .* );
align_exponents   u_alineacion       ( .* );
add_sub_mantissas u_suma_mantissas   ( .* );
normalize_result  u_normalizacion    ( .* );
round             u_redondeo         ( .* );
fp_pack           u_empaquetado      ( .* );
```

### Ambiente UVM

Nombre completo en `snake_case`, consistente con el nombre de la clase
UVM (sin el sufijo `_c`):

```verilog
// Language: SystemVerilog
// En fpu_env_c
fpu_agente_c     fpu_agnt;
fpu_scoreboard_c fpu_scb;
fpu_coverage_c   fpu_cov;
```

> ✔ Correcto: `u_redondeo`, `fpu_agnt`  
> ✘ Evitar: nombres abreviados arbitrarios como `agnt2`, `scb_1`, `mon`

---

## 23. Encabezado de archivo (NaturalDocs)

### Reglas

- Todo archivo `.sv` lleva encabezado en formato **NaturalDocs**.
- Campos obligatorios: `File`, `Project`, `Author`, `Date`, `Description`.
- `Instantiated by` es obligatorio en módulos RTL; se omite en clases UVM.
- `Dependencies` es obligatorio en clases UVM; se omite si no aplica.

### Ejemplo — módulo RTL

```verilog
// Language: SystemVerilog
/*
 * File:    fp_adder.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 * - Author:   Nombre Apellido
 * - Date:     2025-S1
 *
 * Description:
 *   Implementa la suma en punto flotante IEEE 754 simple precisión.
 *   Internamente realiza desempaquetado, alineación de exponentes,
 *   suma/resta de mantisas, normalización, redondeo y detección
 *   de condiciones especiales (NaN, ±Inf, ±0).
 *
 * Instantiated by:
 *   fp_alu, fp_sub, fp_madd, fp_msub
 */
```

### Ejemplo — clase UVM

```verilog
// Language: SystemVerilog
/*
 * File:    fpu_scoreboard_c.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 * - Author:   Nombre Apellido
 * - Date:     2025-S1
 *
 * Description:
 *   Scoreboard UVM para la FPU RV32F. Recibe transacciones del monitor,
 *   calcula el resultado esperado vía el modelo de referencia DPI-C
 *   (Berkeley SoftFloat) y compara bit a bit contra la salida del DUT.
 *
 * Dependencies:
 *   fpu_seq_item_c.sv, fpu_tipos_pkg.sv, fpu_dpi_pkg.sv
 */
```

---

## 24. Referencia rápida

```
TIPOS
─────────────────────────────────────
enum            →  _e
struct          →  _s
union           →  _u
class           →  _c
interface       →  _if
virtual if      →  _vif
tipo de función →  _ft
package         →  _pkg

ESTRUCTURAS DE DATOS
─────────────────────────────────────
mailbox         →  _mbx
queue           →  _q
stack (LIFO)    →  _stk
array estático  →  _a
array dinámico  →  _da
array asociativo→  _aa
semáforo        →  _sem
evento          →  _evt

SEÑALES
─────────────────────────────────────
puerto entrada  →  _i
puerto salida   →  _o
puerto inout    →  _io
wire interno    →  _w       (combinacional)
flip-flop       →  _r       (secuencial)
rand            →  _rand
randc           →  _randc

PREFIJOS
─────────────────────────────────────
constraint      →  cn_
parameter       →  P_
localparam      →  C_
instancia RTL   →  u_
covergroup      →  cg_
coverpoint      →  cp_
bins            →  b_
cross           →  x_
assertion       →  a_
property SVA    →  p_
sequence SVA    →  s_
DPI-C           →  dpi_
```

---

*Documento bajo control de versiones. Modificaciones deben ser aprobadas
y registradas con un commit descriptivo que justifique el cambio.*
