// Language: SystemVerilog
`ifndef MSG_MACROS_SVH
`define MSG_MACROS_SVH

/// File: msg_macros.svh
/// Macros de utilidad para mensajes de depuración.
/// Incluye códigos de colores ANSI y funciones auxiliares
/// para mejorar la visualización del log en consola.
//------------------------------------------------------
//  CONFIGURACIÓN DE COLOR
//  Usar +define+NO_MSG_ANSI_FORMAT para desactivar colores
//------------------------------------------------------

`ifndef NO_MSG_ANSI_FORMAT
    // Colores habilitados (por defecto)
    `define RESET       "\033[0m"
    `define RED         "\033[31m" // mensajes de error
    `define GREEN       "\033[32m" // pass / éxito
    `define YELLOW      "\033[33m" // mensajes de warning
    `define BLUE        "\033[34m" // hito de fase
    `define MAGENTA     "\033[35m" // scoreboard - checker
    `define CYAN        "\033[36m" // hito de test / env
    `define BOLD        "\033[1m"  // énfasis

    `define BOLD_RED     "\033[1;31m"
    `define BOLD_GREEN   "\033[1;32m"
    `define BOLD_YELLOW  "\033[1;33m"
    `define BOLD_BLUE    "\033[1;34m"
    `define BOLD_MAGENTA "\033[1;35m"
    `define BOLD_CYAN    "\033[1;36m"
`else // Sin color (modo log limpio) - todos vacíos
    `define RESET       ""
    `define RED         ""
    `define GREEN       ""
    `define YELLOW      ""
    `define BLUE        ""
    `define MAGENTA     ""
    `define CYAN        ""
    `define BOLD        ""

    `define BOLD_RED     ""
    `define BOLD_GREEN   ""
    `define BOLD_YELLOW  ""
    `define BOLD_BLUE    ""
    `define BOLD_MAGENTA ""
    `define BOLD_CYAN    ""
`endif

    //------------------------------------------------------
    //  MACROS DE MENSAJE (fuera del ifndef de color)
    //------------------------------------------------------

    /*Dejan un bloque de espacio libre entre el margen y el mensaje*/
    // `define CUSTOM_MSG(msg)     $display({`BOLD,   "[MSG]   ", msg, `RESET});
    // `define CUSTOM_WARN(msg)    $display({`YELLOW, "[WARN]  ", msg, `RESET});
    // `define CUSTOM_ERROR(msg)   $display({`RED,    "[ERROR] ", msg, `RESET});
    `define CUSTOM_MSG(msg)   $display("%s[MSG]   %s%s", `BOLD, msg, `RESET);
    `define CUSTOM_WARN(msg)  $display("%s[WARN]  %s%s", `YELLOW, msg, `RESET);
    `define CUSTOM_ERROR(msg) $display("%s[ERROR] %s%s", `RED, msg, `RESET);

    //------------------------------------------------------
    //  MACROS DE VEREDICTO (lo que importa en el log)
    //------------------------------------------------------

    `define CUSTOM_PASS(msg)    $display({`BOLD_GREEN, "[PASS]  ", msg, `RESET});
    `define CUSTOM_FAIL(msg)    $display({`BOLD_RED,   "[FAIL]  ", msg, `RESET});

    //------------------------------------------------------
    //  MACRO DE BLOQUE FORMATEADO
    //  env_block : nombre del componente, ej. "FPU_ENV"
    //  msg       : mensaje
    //  macro_color : color ANSI, ej. `CYAN
    //  El padding se aplica al texto antes del color para no
    //  desalinear columnas con caracteres ANSI invisibles.
    //------------------------------------------------------

    // `define CUSTOM_INFO(env_block, msg, macro_color) \
    //     begin : custom_info_blk \
    //         string block_s; \
    //         block_s = $sformatf("%-14s", {"[", env_block , "] "}); \
    //         $display({"T=%-6t", macro_color, "%s", `RESET, "%s"}, $time, block_s, msg); \
    //     end
    `define CUSTOM_INFO(env_block, msg, macro_color) \
        $display({"T=%-6t", macro_color, "%s", `RESET, "%s"}, $time, $sformatf("%-14s", {"[", env_block, "]"}), msg);

`endif // MSG_MACROS_SVH