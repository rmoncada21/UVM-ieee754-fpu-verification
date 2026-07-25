# sim/sim_make.mk
# Incluido desde el Makefile raíz => el cwd de make es la RAÍZ del repo.
# Jerarquía de salidas (la unidad de organización es la CORRIDA):
#   salidas/regresiones/<REG_ID>/<test_name>/s<SEED>/
#       											 cmd.txt
# 													 sim.log
# 													 consola.log
# 													 scoreboard.csv
# 													 resumen.csv
# 													 cov.vdb/
#   salidas/regresiones/<REG_ID>/manifest.csv  -> 1 fila por corrida (índice p/ Python)
#   salidas/ultima -> regresiones/<REG_ID>     -> symlink a la más reciente
#

EXE_ABS := $(abspath $(EXE_SIM))
MOSTRAR_EXE_ABS:
	echo "$(EXE_ABS)"

# tests activos; agregar aquí conforme se integren los del testplan
TESTS_ACTIVOS := fpu_base_test fpu_test_arith_normal fpu_test_flag_arith \
				 fpu_test_special_spec fpu_test_norm_spec fpu_test_rounding \
				 fpu_test_cmp fpu_test_subnormal_arith run_fpu_test_known_bugs

# knobs de regresión multi-semilla
NUM_SEEDS ?= 1
TEST      ?= fpu_base_test fpu_test_arith_normal fpu_test_flag_arith \
        	 fpu_test_special_spec fpu_test_norm_spec fpu_test_rounding \
        	 fpu_test_cmp fpu_test_subnormal_arith run_fpu_test_known_bugs
SEEDS     ?= 

# run_fpu_base_test run_fpu_test_arith_normal run_fpu_test_flag_arith 
# run_fpu_test_cmp run_fpu_test_rounding run_fpu_test_special_spec
# run_fpu_test_norm_spec run_fpu_test_subnormal_arith

####################################################################################
################### #1. FUNCIÓN MODULAR (Macro)
# $(1): Nombre del test extraído del target

define run_uvm_test
	@set -o pipefail; \
	run_dir=$(REG_DIR)/$(strip $(1))/s$(SEED); \
	mkdir -p $$run_dir; \
	if [ ! -f $(MANIFEST) ]; then \
		echo "test,semilla,transacciones,num_pass,num_bug,num_fail,ruta" > $(MANIFEST); \
		{ echo "regresion  : $(REG_ID)"; \
		  echo "fecha      : $$(date -Iseconds)"; \
		  echo "commit UVM : $$(git rev-parse --short HEAD 2>/dev/null || echo NA)"; \
		  echo "commit DUT : $$(git -C dut/ALU-FPU-ieee754 rev-parse --short HEAD 2>/dev/null || echo NA)"; \
		} > $(REG_DIR)/info_regresion.txt; \
	fi; \
	echo "cd $$run_dir && $(EXE_ABS) +UVM_TESTNAME=$(strip $(1))_c +UVM_VERBOSITY=$(VERBOSITY) +ntb_random_seed=$(SEED) +SCB_CSV_KNOB=$(CSV_KNOB) +SCB_CSV=scoreboard.csv +SCB_RESUMEN=resumen.csv -cm $(COVERAGE) -cm_dir cov.vdb -cm_name $(strip $(1))_s$(SEED) -l sim.log" > $$run_dir/cmd.txt; \
	( $(EXE_ABS) \
		+UVM_TESTNAME=$(strip $(1))_c \
		+UVM_VERBOSITY=$(VERBOSITY) \
		+ntb_random_seed=$(SEED) \
		+SCB_CSV_KNOB=$(CSV_KNOB) \
		+SCB_CSV=$$run_dir/scoreboard.csv \
		+SCB_RESUMEN=$$run_dir/resumen.csv \
		-cm $(COVERAGE) -cm_dir $$run_dir/cov.vdb -cm_name $(strip $(1))_s$(SEED) \
		-l $$run_dir/sim.log ) \
		| tee $$run_dir/consola.log; \
	echo "$(strip $(1)),$(SEED),$$(cat $$run_dir/resumen.csv 2>/dev/null || echo NA,NA,NA,NA),$$run_dir" >> $(MANIFEST); \
	mkdir -p $(REPORTES); ln -sfn regresiones/$(REG_ID) $(ULTIMA_REG)
endef

####################################################################################
################### Ejecutar los tests

all_test: run_fpu_base_test run_fpu_test_arith_normal run_fpu_test_flag_arith \
		  run_fpu_test_special_spec run_fpu_test_norm_spec run_fpu_test_rounding \
		  run_fpu_test_cmp run_fpu_test_subnormal_arith

# testbench_sim:
# 	./$(EXE_SIM) \
# 		-l ../$(SIM)/$(EXE_SIM) \
# 		| tee ../$(SIM)/$(EXE_SIM)$(shell date +%d_%H_%M_%S).log

# run_fpu_base_test:
# 	echo "$@"
# 	@$(call run_uvm_test, $(@:run_%=%))

run_fpu_test_arith_normal:
	@$(call run_uvm_test, $(@:run_%=%))

run_fpu_test_flag_arith:
	@$(call run_uvm_test, $(@:run_%=%))

run_fpu_test_special_spec:
	@$(call run_uvm_test, $(@:run_%=%))

run_fpu_test_norm_spec:
	@$(call run_uvm_test, $(@:run_%=%))

run_fpu_test_rounding:
	@$(call run_uvm_test, $(@:run_%=%))

run_fpu_test_cmp:
	@$(call run_uvm_test, $(@:run_%=%))

run_fpu_test_subnormal_arith:
	@$(call run_uvm_test, $(@:run_%=%))

run_fpu_test_known_bugs:
	@$(call run_uvm_test, $(@:run_%=%))

####################################################################################
################### Regresión multi-semilla
# make regresion TEST=fpu_test_arith_normal NUM_SEEDS=10 [REG_ID=etiqueta]
# make regresion TEST=fpu_test_cmp SEEDS="1734829105 998877"   (reproducir exactas)
regresion:
	@sem="$(SEEDS)"; \
	if [ -z "$$sem" ]; then \
		for i in $$(seq $(NUM_SEEDS)); do \
			sem="$$sem $$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')"; \
		done; \
	fi; \
	for s in $$sem; do \
		$(MAKE) run_$(TEST) SEED=$$s REG_ID=$(REG_ID); \
	done

# todos los TESTS_ACTIVOS x NUM_SEEDS bajo el MISMO id de regresión
regresion_todos:
	@for t in $(TESTS_ACTIVOS); do \
		$(MAKE) regresion TEST=$$t NUM_SEEDS=$(NUM_SEEDS) REG_ID=$(REG_ID) SEEDS="$(SEEDS)"; \
	done

####################################################################################
################### Regresión multi-semilla
# make regresion TEST=fpu_test_arith_normal NUM_SEEDS=10 [REG_ID=etiqueta]
# make regresion TEST=fpu_test_cmp SEEDS="1734829105 998877"   (reproducir exactas)
# TODO: regresions target
cobertura:
	urg -full64 -dir $(DIR_ANALISIS)/*/s*/cov.vdb \
		-dbname $(DIR_ANALISIS)/cobertura_fusionada \
		-report $(DIR_ANALISIS)/cobertura_reporte

.PHONY: \
	testbench_sim \
	run_fpu_base_test \
	run_fpu_test_arith_normal \
	run_fpu_test_cmp \
	run_fpu_test_rounding \
	run_fpu_test_special_spec \
	run_fpu_test_norm_spec \
	run_fpu_test_subnormal_arith \
	regresion regresion_todos
