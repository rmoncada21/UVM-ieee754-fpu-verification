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
        `define GREEN       "\033[32m" // driver - monitor
        `define YELLOW      "\033[33m" // mensajes de warning
        `define BLUE        "\033[34m" // agente
        `define MAGENTA     "\033[35m" // scoreboard - checker 
        `define CYAN        "\033[36m" // env
        `define BOLD        "\033[1m"  // test
    
        // Colores bold
        `define BOLD_RED     "\033[1;31m"
        `define BOLD_GREEN   "\033[1;32m"
        `define BOLD_YELLOW  "\033[1;33m"
        `define BOLD_BLUE    "\033[1;34m"
        `define BOLD_MAGENTA "\033[1;35m"
        `define BOLD_CYAN    "\033[1;36m"
    `else // Sin color (modo log limpio) - pone todos en reset
        `define RESET       "\033[0m"
        `define RED         "\033[0m"
        `define GREEN       "\033[0m"
        `define YELLOW      "\033[0m"
        `define BLUE        "\033[0m"
        `define MAGENTA     "\033[0m"
        `define CYAN        "\033[0m"
        `define BOLD        "\033[0m"

        `define BOLD_RED     "\033[0m"
        `define BOLD_GREEN   "\033[0m"
        `define BOLD_YELLOW  "\033[0m"
        `define BOLD_BLUE    "\033[0m"
        `define BOLD_MAGENTA "\033[0m"
        `define BOLD_CYAN    "\033[0m"
    `endif
    
    //------------------------------------------------------
    //  MACROS DE MENSAJE
    //------------------------------------------------------
    
    // `define INFO(msg)    $display({`CYAN,   "[INFO]  ", msg, `RESET});
    `define CUSTOM_MSG(msg)    $display({`BOLD,    "[MSG]  ", msg, `RESET});
    `define CUSTOM_WARN(msg)    $display({`YELLOW, "[WARN]  ", msg, `RESET});
    `define CUSTOM_ERROR(msg)   $display({`RED,    "[ERROR] ", msg, `RESET});
    
    //------------------------------------------------------
    //  MACRO DE BLOQUE FORMATEADO
    //------------------------------------------------------

    `define CUSTOM_INFO(env_block, msg, macro_color) \
        begin \
          string block; \
          block = {"[", env_block, "]"}; \
          $display({"T=%-6t", macro_color, "%-14s", `RESET, "%s"}, $time, block, msg); \
        end 
`endif // MSG_MACROS_SVH
