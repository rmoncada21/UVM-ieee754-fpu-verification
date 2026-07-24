/*
 * File:    fpu_seq_constraints.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Contenedor de constraints para la generación de operandos binary32.
 *   Extiende fpu_seq_item_c con campos auxiliares de generación (signo,
 *   exponente, mantisa) y una constraint por clase IEEE 754. Todas las
 *   constraints de clase nacen desactivadas; activar_clase() deja activa
 *   exactamente una antes de cada randomize(), siguiendo el patrón de
 *   encendido/apagado del proyecto de referencia mult_ieee754.
 *
 * Dependencies:
 *   fpu_seq_item.sv, fpu_types_constraints_pkg.sv
 */

class fpu_seq_constraints_c extends fpu_seq_item_c;
	`uvm_object_utils(fpu_seq_constraints_c)

	// campos auxiliares exclusivos de generacion (un operando por llamada)
	rand bit                      signo_rand;
	rand logic [C_EXP_WIDTH-1:0]  exponente_rand;
	rand logic [C_MANT_WIDTH-1:0] mantisa_rand;

	// knob de estado: -1 = signo aleatorio, 0 = positivo, 1 = negativo
	int signo_forzado = -1;

	// knob de estado: -1 = exponente aleatorio, >= 0 = valor exacto del
	// campo exponente (sesgado); lo usan los generadores dirigidos que
	// necesitan una potencia de dos con exponente calculado (rounding)
	int exponente_forzado = -1;

	// signo forzado: siempre activa; solo restringe cuando signo_forzado >= 0
	constraint cn_signo_forzado {
		if (signo_forzado >= 0) signo_rand == signo_forzado[0];
	}
	
	/*rounding*/
	// exponente forzado: siempre activa; solo restringe cuando
	// exponente_forzado >= 0. Si el valor pedido contradice la clase
	// activa, el randomize falla ruidosamente (mejor que degradar)
	constraint cn_exponente_forzado {
		if (exponente_forzado >= 0)
			exponente_rand == exponente_forzado[C_EXP_WIDTH-1:0];
	}

	/*Arith normal*/
	// Constraints por clase IEEE 754 (desactivadas por defecto)
	// ±0 : exponente 0, mantisa 0
	constraint cn_cero {
		exponente_rand == '0;
		mantisa_rand   == '0;
	}

	// subnormal : exponente 0, mantisa != 0
	constraint cn_subnormal {
		exponente_rand == '0;
		mantisa_rand   != '0;
	}

	// normal : exponente en [1, 254]; mantisa y signo libres
	constraint cn_normal {
		exponente_rand inside {
            [C_EXP_MIN_NORMAL : C_EXP_MAX_NORMAL]
        };
	}

	// normal en banda segura [70,184]: operandos y resultados normales
	// sin overflow ni underflow en arith normal (testplan sec)
	constraint cn_normal_banda {
		exponente_rand inside {
			[C_EXP_BANDA_MINIMA : C_EXP_BANDA_MAXIMA]
		};
	}

	/* FLAG ARITH NORMAL TEST */
	// normal con exponente maximo (254): la suam efectiva de dos de estos
	// siempre excede al máximo finito -> overflow
	constraint cn_normal_ovf_suma {
		exponente_rand == C_EXP_MAX_NORMAL;
	}

	// normal alto [191, 254]: el producto de dos de estos siempre desborda
	// (exp_a + exp_b - 127 >= 255 ) -> overflow
	constraint cn_normal_ovf_prod {
		exponente_rand inside {
			[C_EXP_OVF_PROD_MIN : C_EXP_MAX_NORMAL]
		};
	}
   
	// normal bajo [1, 63]: el producto de dos de estos siempre es tiny
    // (exp_a + exp_b - 127 + 1 <=0 ) -> underflow
    constraint cn_normal_udf_prod {
		exponente_rand inside {
			[C_EXP_MIN_NORMAL : C_EXP_UDF_PROD_MAX]
		};
    }

	/* rounding */

	// potencia de dos: mantisa 0, exponente normal; combinada con
	// exponente_forzado produce el ±medio ULP exacto de los empates
	// dirigidos del test rounding (testplan sec. 2.2.3)
	constraint cn_potencia_dos {
		exponente_rand inside {[C_EXP_MIN_NORMAL : C_EXP_MAX_NORMAL]};
		mantisa_rand   == '0;
	}

	// empate en FMUL contra +1.5: mantisa impar y acotada tal que
	// 3*sig cabe en 25 bits (sig = 2^23 + m < 2^25/3  <=>  m <= 'h2AAAAA);
	// el unico bit descartado tras normalizar es el LSB de 3*sig = 1
	// -> guard = 1, sticky = 0: empate exacto (testplan sec. 2.2.3)
	constraint cn_normal_empate_mul {
		exponente_rand inside {[C_EXP_BANDA_MINIMA : C_EXP_BANDA_MAXIMA]};
		mantisa_rand[0] == 1'b1;
		mantisa_rand    <= 23'h2AAAAA;
	}

	/* subnormal */
	// normal con mantisa impar: el producto de dos mantisas impares es impar,
	// asi que al caer en rango subnormal siempre se descarta al menos el LSB
	// -> inexactitud garantizada, no probable (testplan sec. 2.2.5)
	constraint cn_normal_impar {
		exponente_rand inside {[C_EXP_MIN_NORMAL : C_EXP_MAX_NORMAL]};
		mantisa_rand[0] == 1'b1;
	}

   /* OTROS */
	// ±inf : exponente 255, mantisa 0
	constraint cn_inf {
		exponente_rand == C_EXP_ESPECIAL;
		mantisa_rand   == '0;
	}

	// qNaN : exponente 255, MSB de mantisa en 1 (payload libre)
	constraint cn_qnan {
		exponente_rand == C_EXP_ESPECIAL;       
		mantisa_rand[C_MANT_WIDTH-1] == 1'b1;  // MSB
		// mantisa_rand[C_MANT_WIDTH-2:0]      // payload libre
	}

	// sNaN : exponente 255, MSB de mantisa en 0, payload != 0
	constraint cn_snan {
		exponente_rand == C_EXP_ESPECIAL;
		mantisa_rand[C_MANT_WIDTH-1]   == 1'b0; // MSB
		mantisa_rand[C_MANT_WIDTH-2:0] != '0;   // payload
	}

	

	// constructor: todas las clases apagadas, control desde afuera
	function new(string name = "fpu_seq_constraints_c");
		super.new(name);
		desactivar_clases();
	endfunction : new

	// Function: desactivar_clases
	// Apaga todas las constraints de clase; deja el objeto en estado neutro.
	function void desactivar_clases();
		cn_cero.constraint_mode(0);
		cn_subnormal.constraint_mode(0);
		cn_normal.constraint_mode(0);
		cn_inf.constraint_mode(0);
		cn_qnan.constraint_mode(0);
		cn_snan.constraint_mode(0);
		// subconjuntos - bandas
		cn_normal_banda.constraint_mode(0);
		cn_normal_ovf_suma.constraint_mode(0);
		cn_normal_ovf_prod.constraint_mode(0);
		cn_normal_udf_prod.constraint_mode(0);
		cn_potencia_dos.constraint_mode(0);
		cn_normal_empate_mul.constraint_mode(0);
		cn_normal_impar.constraint_mode(0);
	endfunction : desactivar_clases

	// Function: activar_clase
	// Apaga todo y enciende exactamente la constraint de la clase pedida.
	// Al apagar siempre primero, el estado nunca se filtra entre llamadas.
	function void activar_clase(fpu_clase_operando_e clase);
		desactivar_clases();
		case (clase)
			CLASE_CERO         : cn_cero.constraint_mode(1);
			CLASE_SUBNORMAL    : cn_subnormal.constraint_mode(1);
			CLASE_NORMAL       : cn_normal.constraint_mode(1);
			CLASE_INF          : cn_inf.constraint_mode(1);
			CLASE_QNAN         : cn_qnan.constraint_mode(1);
			CLASE_SNAN         : cn_snan.constraint_mode(1);
			// subconjutos - banda segura
			CLASE_NORMAL_BANDA : cn_normal_banda.constraint_mode(1);
			CLASE_NORMAL_OVF_SUMA : cn_normal_ovf_suma.constraint_mode(1);
			CLASE_NORMAL_OVF_PROD : cn_normal_ovf_prod.constraint_mode(1);
			CLASE_NORMAL_UDF_PROD : cn_normal_udf_prod.constraint_mode(1);
			/*rounding*/
			CLASE_POTENCIA_DOS    : cn_potencia_dos.constraint_mode(1);
			CLASE_NORMAL_EMPATE_MUL : cn_normal_empate_mul.constraint_mode(1);
			/* subnormal */
			CLASE_NORMAL_IMPAR      : cn_normal_impar.constraint_mode(1);
			default : `uvm_warning(get_type_name(),
				$sformatf("Clase de operando desconocida: %0d", clase))
		endcase
	endfunction : activar_clase

	// Function: operando
	// Empaqueta el ultimo operando generado: {signo, exponente, mantisa}.
	function logic [C_FP_WIDTH-1:0] operando();
		return {signo_rand, exponente_rand, mantisa_rand};
	endfunction : operando

endclass : fpu_seq_constraints_c