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

# variable que contiene la dirección absoluta de testbench_sim
EXE_ABS := $(abspath $(EXE_SIM))
MOSTRAR_EXE_ABS:
	echo "$(EXE_ABS)"

# tests activos; agregar aquí conforme se integren los del testplan
TESTS_ACTIVOS := fpu_base_test fpu_test_arith_normal fpu_test_flag_arith \
				 fpu_test_special_spec fpu_test_norm_spec fpu_test_rounding \
				 fpu_test_cmp fpu_test_subnormal_arith fpu_test_known_bugs

# knobs de targets de regresión
# se sobreesciben desde el cli
NUM_SEEDS ?= 1
TEST      ?= fpu_base_test
SEEDS     ?= 

# knobs de targets de cobertura
COV_DIR   ?=

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

# run_all_test: run_fpu_base_test run_fpu_test_arith_normal run_fpu_test_flag_arith \
# 		  run_fpu_test_special_spec run_fpu_test_norm_spec run_fpu_test_rounding \
# 		  run_fpu_test_cmp run_fpu_test_subnormal_arith run_fpu_test_known_bugs

run_fpu_base_test:
	@$(call run_uvm_test, $(@:run_%=%))

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
# make regresion TEST=fpu_test_cmp SEEDS="469078601 1238983584 4170956088"   (reproducir exactas)
regresion:
	@local_seeds="$(SEEDS)"; \
	if [ -z "$$local_seeds" ]; then \
		for i in $$(seq $(NUM_SEEDS)); do \
			local_seeds="$$local_seeds $$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')"; \
		done; \
	fi; \
	for seed in $$local_seeds; do \
		$(MAKE) run_$(TEST) SEED=$$seed REG_ID=$(REG_ID); \
	done

# todos los TESTS_ACTIVOS x NUM_SEEDS bajo el MISMO id de regresión
# make regresion_all NUM_SEEDS=3
# seeds usadas para analisis de datos
# make regresion_all SEEDS="469078601 1238983584 4170956088"
regresion_all:
	@for test in $(TESTS_ACTIVOS); do \
		$(MAKE) regresion TEST=$$test NUM_SEEDS=$(NUM_SEEDS) REG_ID=$(REG_ID) SEEDS="$(SEEDS)"; \
	done

####################################################################################
################### Cobertura de código con verdi
# make verdi COV_DIR=./reportes/regresionas/FECHA/TEST/seed/cov.vdb # para cobertura individual
# make verdi COV_DIR=./reportes/regresionas/FECHA/cobertura_fusionada.vdb
ifeq ($(findstring cobertura_fusionada.vdb,$(COV_DIR)),)
	VERDI_DEPS := cobertura_urg_simple
else
	VERDI_DEPS :=
endif

verdi: $(VERDI_DEPS)
	(cd verdi_logs && verdi -cov \
		-covdir ../$(EXE_VDB) \
		-covdir ../$(COV_DIR))

# make cobertura_urg_simple COV_DIR=./reportes/regresionas/FECHA/cobertura_fusionada.vdb
cobertura_urg_simple:
	urg -full64 \
    	-dir $(EXE_VDB) \
    	-dir $(COV_DIR) \
		-report $(COV_DIR:/cov.vdb/=)/cov_reporte_tml

# cobertura fusionada por fecha. Toma la carpeta llamda ultima/ como entrada
# cobertura_fusionada.vdb     : consumida por verdi
# cobertura_fusionada_reporte : salida principal - un html de lectura con nevagador
cobertura_urg_fusionada:
	urg -full64 \
		-dir $(EXE_VDB) $(DIR_ANALISIS)/*/s*/cov.vdb \
		-dbname $(DIR_ANALISIS)/cobertura_fusionada.vdb \
		-report $(DIR_ANALISIS)/cobertura_fusionada_reporte_html



.PHONY: \
	run_all_test \
	run_fpu_base_test \
	run_fpu_test_arith_normal \
	run_fpu_test_cmp \
	run_fpu_test_rounding \
	run_fpu_test_special_spec \
	run_fpu_test_norm_spec \
	run_fpu_test_subnormal_arith \
	regresion regresion_all \
	verdi \
	cobertura_urg_simple \
	cobertura_urg_fusionada


# análsis de cobertura con verdi gui
# verdi -cov -covdir sim/testbench_sim.vdb
# verdi -cov -covdir sim/testbench_sim.vdb/ -covdir reportes/ultima.vdb