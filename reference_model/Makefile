# usar "make -f make_ref_soft.mk" si se encuentra dentro del directorio de golde_model/

SHELL := /bin/bash
FECHA := $(shell date +%d_%H_%M_%S)
#############################################################################
# Folders del ambiente
REF_BIN       = bin
REF_SRC       = src
REF_INC       = include
REF_LOGS      = logs
REF_BUILD     = build
REF_VECTORS   = vectors
# REF_CSV       = csv
REF_STAND     = standalone_tests
# STAND_BIN = standalone_tests/bin

# Folders logs
LOGS_BUILD    := $(REF_LOGS)/build
LOGS_TFSOFT   := $(REF_LOGS)/testsoftfloat
LOGS_VECTORS  := $(REF_LOGS)/vectores
LOGS_DRIVER   := $(REF_LOGS)/driver
LOGS_REPLAY   := $(REF_LOGS)/replayer
LOGS_RUNNER   := $(REF_LOGS)/runner
LOGS_VALGRIND := $(REF_LOGS)/valgrind
LOGS_SAN      := $(REF_LOGS)/sanitizers

LOG_DIRS      := $(LOGS_BUILD) $(LOGS_TFSOFT) $(LOGS_VECTORS) $(LOGS_DRIVER) \
                 $(LOGS_REPLAY) $(LOGS_RUNNER) $(LOGS_VALGRIND) $(LOGS_SAN)
DIRS          := $(REF_BIN) $(REF_BUILD) $(REF_VECTORS) $(REF_CSV) $(LOG_DIRS)

$(DIRS):
	mkdir -p $@
#----------------------------
# variables generales para soft/testfloat
ARCH_TARGET       = RISCV
# Opciones: Linux-ARM-VFPv2-GCC Linux-386-GCC Linux-x86_64-GCC Win32-MinGW
# Ambas deben coincidir para una correcta integración y compilación
PLATFORM_SOFT     = Linux-x86_64-GCC
PLATFORM_TEST     = Linux-x86_64-GCC
#----------------------------
# Variables para berkeley SOFTFLOAT
SOFTFLOAT_DIR ?= ../third_party/berkeley-softfloat-3
SF_BUILD      := $(SOFTFLOAT_DIR)/build/$(PLATFORM_SOFT)
SF_LIBRARY_A  := $(SF_BUILD)/softfloat.a
SF_INCLUDE    := $(SOFTFLOAT_DIR)/source/include

#----------------------------
# Variables para berkeley TESTFLOAT
TESTFLOAT_DIR ?= ../third_party/berkeley-testfloat-3
TF_BUILD      := $(TESTFLOAT_DIR)/build/$(PLATFORM_TEST)
TF_TEST       := $(TF_BUILD)/testfloat
TF_GEN        := $(TF_BUILD)/testfloat_gen
TF_VER        := $(TF_BUILD)/testfloat_ver
TF_SOFTFLOAT  := $(TF_BUILD)/testsoftfloat
TF_TIME       := $(TF_BUILD)/timesoftfloat
TF_TOOLS_PATHS = $(TF_TEST) $(TF_GEN) $(TF_VER) $(TF_SOFTFLOAT) $(TF_TIME)
TF_TOOLS       = $(notdir $(TF_TOOLS_PATHS))


#----------------------------
# TF_LEVEL: 1 = ~46.5 K vectores por (op,modo); 2 = millones (barrido nocturno)
# TF_SEED : reproducibilidad total del flujo (default de testfloat_gen: 1)
# VAL_N   : vectores bajo valgrind (es ~20-50x mas lento que nativo)
TF_LEVEL ?= 1
TF_SEED  ?= 1
VAL_N    ?= 500

#----------------------------
# Matrices de cobertura: 5 modos de redondeo RISC-V x operaciones del DUT
# token:flag  ->  rne=RNE  rtz=RTZ  rdn=RDN  rup=RUP  rmm=RMM
ROUND_MODE_PAIR := rne:-rnear_even rtz:-rminMag rdn:-rmin rup:-rmax rmm:-rnear_maxMag
TF_OPS          := f32_add f32_sub f32_mul f32_eq f32_lt f32_le
RUNNER_ARITH := add sub mul
RUNNER_CMP   := eq lt le
TF_ARITH_OPS    := f32_add f32_sub f32_mul
TF_OPS_CMP   := f32_eq f32_lt f32_le
SWEEP_OPS    := f32_add f32_sub f32_mul f32_mulAdd f32_mulSub
# TF_OPS   : N1, las 6 funciones SoftFloat que el modelo llama
# RUNNER_*  : N3, 3 ops aritmeticas x 5 modos + 3 comparaciones x RNE = 18
# TF_ARITH_OPS : N4, set auditable por ver (madd/msub y cmp quedan fuera del gate)
# SWEEP_OPS : barrido CSV; f32_mulSub consume vectores de f32_mulAdd (parte 2)


# para build_testfloat_vectors
TF_ROUNDS_MODE = -rnear_even -rminMag -rmin -rmax -rnear_maxMag

#----------------------------
# Compilador local
CC         := gcc
CFLAGS     := -O2 -frounding-math -fno-unsafe-math-optimizations
CFSYNTAX   := -fsyntax-only
INCLUDES   := -Iinclude -I$(SF_INCLUDE)
# para revisar sintaxis
CSOURCES    = $(wildcard $(REF_SRC)/*.c)
CTEST       = $(wildcard $(REF_STAND)/*.c)
HFILES      = $(wildcard $(REF_INC)/*.h)
CFILES      = $(CSOURCES) $(CTEST) $(HFILES)

# AGREGAR SANITIZERS con clang

#----------------------------
# Variables del modelo de referencia con softfloat
REF_MODEL ?= reference_model
REF_C     := $(REF_SRC)/$(REF_MODEL:=.c)
REF_OBJ   := $(REF_BUILD)/$(REF_MODEL:=.o)
REF_EXE   := $(REF_BIN)/$(REF_MODEL:=_exe)

#----------------------------
# Archivos para inyectar datos desde el mismo archivo "main"
DRIVER_FILE    ?= simple_driver
REF_DRIVER_C   := $(REF_STAND)/$(DRIVER_FILE:=.c)
REF_DRIVER_EXE := $(REF_BIN)/$(DRIVER_FILE:=_exe)

#----------------------------
# runner
# Nombre original tf_runner
RUNNER_FILE ?= runner_testfloat
RUNNER_C    := $(REF_STAND)/$(RUNNER_FILE:=.c)
RUNNER_EXE  := $(REF_BIN)/$(RUNNER_FILE:=_exe)

#----------------------------
# Variables del testfloat replay
# Archivos para inyectar datos mediante pipe con testfloat tools
# nombre_original tf_replay  
TF_REPLAY      ?= replayer_testfloat
TF_REPLAY_C    := $(REF_STAND)/$(TF_REPLAY:=.c)
TF_REPLAY_EXE  := $(REF_BIN)/$(TF_REPLAY:=_exe)

#----------------------------
# Variables para estudio con valgrind
BIN_EXE    := $(wildcard $(REF_BIN)/*_exe)
VAL_TOOLS  := memcheck helgrind

####################################################################################
#################### Target universales
all: build_all

# _mkdir_folders:
# 	mkdir -p $(REF_BIN) $(REF_BUILD) $(REF_LOGS) $(REF_VECTORS)

# revisar solo syntaxis
# make src/nombre_archivo.c_syntax
# make standalone_tests/nombre_archivo.c_syntax
$(CFILES:=_syntax):
	$(CC) $(CFLAGS) $(CFSYNTAX) $(@:_syntax=)

####################################################################################
#################### Target: N0 build de librerías (internas, externas ) y herramientas
build_all: build_berkeley_softfloat build_berkeley_testfloat $(REF_OBJ)

#---------------------------- Librerías
# construir la librerias berkeley con especializacion RISC-V, 
# genera softfloat.a como librería estática -> ../third_party/berkeley-softfloat-3/build/Linux-x86_64-GCC/softfloat.a
build_berkeley_softfloat:
	$(MAKE) -C $(SF_BUILD) SPECIALIZE_TYPE=$(ARCH_TARGET)

# Ambas deben coincidir para una correcta integración y compilación
build_berkeley_testfloat:
	$(MAKE) -C $(TF_BUILD) SPECIALIZE_TYPE=$(ARCH_TARGET)

# Ambas deben coincidir para una correcta integración y compilación
# crear objeto reference_model.o
$(REF_OBJ): | $(REF_BUILD)
	$(CC) $(CFLAGS) -c $(REF_C) -I$(SF_INCLUDE) -o $@

# N1 ###################################################################################
#################### Target:  Nivel N1
#-------------------------- herramientas de uso testfloat --------------------------#

# Uso de testsoftfloat
# testear softfloat vs testfloat de berkeley
# opciones: -all2 -all1 f32_add f32_sub ...
# TODO: hacer fora para probar las operaciones del reference model
# Compara el softfloat.a generado contra slowfloat (FP íntegro de berkeley)
test_build_berkeleys_libraries:
	@for op in $(TF_OPS); do \
		echo -e "\n== testsoftfloat $$op =="; \
		$(TF_SOFTFLOAT) -level 1 $$op ;\
	done

#--------------------------
# construir vectores.
# TODO: crear mas vectores con otro modo de redondeo
# cambiar nombre con respecto a la operación y modo de redondeo
# $(TF_GEN) -rnear_even $$op > $(REF_VECTORS)/$$op.tf;
build_testfloat_vectors: | $(REF_VECTORS) $(LOGS_VECTORS)
	{ echo -e "\n== vectores level=$(TF_LEVEL) seed=$(TF_SEED) fecha=$(FECHA) =="; \
	for op in $(TF_ARITH_OPS) f32_mulAdd; do \
	  for par in $(ROUND_MODE_PAIR); do \
	    ref_r=$${par%%:*}; tf_r=$${par##*:}; \
	    out=$(REF_VECTORS)/$${op}_$${ref_r}_l$(TF_LEVEL)_s$(TF_SEED).tf; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$tf_r $$op > $$out || exit 1; \
	    echo "$$out ($$(wc -l < $$out) vectores)"; \
	  done; \
	done; \
	for op in $(TF_OPS_CMP); do \
	  out=$(REF_VECTORS)/$${op}_rne_l$(TF_LEVEL)_s$(TF_SEED).tf; \
	  $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$op > $$out || exit 1; \
	  echo "$$out ($$(wc -l < $$out) vectores)"; \
	done; } 2>&1 | tee $(LOGS_VECTORS)/$@_$(FECHA).log

#--------------------------
# mostrar_nombres_vectors:
# 	for op in $(TF_OPS); do \
# 		echo ">> $(REF_VECTORS)/$$op.tf"; \
# 			for mode in $(TF_ROUNDS_MODE); do \
# 				echo "$${op}_$${mode/-/}"; \
# 			done \
# 	done

# N2 ###################################################################################
#################### Target: compilación e integración simple driver
all_driver: driver_compile driver_run

#----------------------------
# enlaza objeto y compila simple_driver
$(REF_DRIVER_EXE): $(REF_DRIVER_C) $(REF_OBJ) | $(REF_BIN)
	$(CC) $(CFLAGS) $(REF_DRIVER_C) $(REF_OBJ) $(SF_LIBRARY_A) $(INCLUDES) -o $@

driver_compile: $(REF_DRIVER_EXE)

#--------------------------
driver_run: $(REF_DRIVER_EXE) | $(LOGS_DRIVER)
	./$(REF_DRIVER_EXE) | tee $(LOGS_DRIVER)_$(FECHA).log

####################################################################################
#################### Target: compilar y ejecutar validación cruzada
all_runner: runner_compile runner_matrix

#--------------------------

$(RUNNER_EXE): $(RUNNER_C) | $(REF_BIN)
	$(CC) $(CFLAGS) $(RUNNER_C) $(SF_LIBRARY_A) -I$(SF_INCLUDE) -o $@

runner_compile: $(RUNNER_EXE)

# probar solo con un redondeo y operacion por el momento
runner_run: $(RUNNER_EXE) | $(LOGS_RUNNER)
	$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) -rnear_even f32_mul \
	  | ./$(RUNNER_EXE) mul rne 2>&1 \
	  | tee $(LOGS_RUNNER)/runner_mul_rne_$(FECHA).log

runner_matrix: $(RUNNER_EXE) | $(LOGS_RUNNER)
	for op in $(RUNNER_ARITH); do \
	  for par in $(RM_PAIRS); do \
	    ref_r=$${par%%:*}; tf_r=$${par##*:}; \
	    echo "== runner $$op $$ref_r =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$tf_r f32_$$op \
	      | ./$(RUNNER_EXE) $$op $$ref_r 2>&1 \
	      | tee $(LOGS_RUNNER)/runner_$${op}_$${ref_r}_$(FECHA).log || exit 1; \
	  done; \
	done; \
	for op in $(RUNNER_CMP); do \
	  echo "== runner $$op rne =="; \
	  $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) f32_$$op \
	    | ./$(RUNNER_EXE) $$op rne 2>&1 \
	    | tee $(LOGS_RUNNER)/runner_$${op}_rne_$(FECHA).log || exit 1; \
	done


####################################################################################
#################### Target: compilación e integración tf_replay
all_replayer: testfloat_gen testfloat_replay_compile testfloat_check

#----------------------------
# Generar vectores con tf_gen en vectors/, uno por op
# gen_vectors/ guardar/respaldar vectores
# TODO: BORRAR/CAMBIAR
testfloat_gen:
	for op in $(TF_OPS); do \
		echo ">> $(REF_VECTORS)/$$op.tf"; \
		$(TF_GEN) -rnear_even $$op > $(REF_VECTORS)/$$op.tf; \
	done

#----------------------------
# Compilar tf_replayer (usa reference_model.o ya producido antes)
# produce el ejecutable standalone_tests/bin/tf_replay
testfloat_replay_compile: $(REF_OBJ)
	$(CC) $(CFLAGS) $(TF_REPLAY_C) $(REF_OBJ) $(SF_LIBRARY_A) \
		$(INCLUDES) -o $(TF_REPLAY_EXE)

#----------------------------
# Auditar reference_model contra testfloat mediante un piep
# usa tf_gen | tf_ver
testfloat_check: $(TF_REPLAY_EXE)
	for op in $(TF_OPS); do \
		echo "auditando $$op "; \
		$(TF_GEN) -rnear_even $$op | $(TF_REPLAY_EXE) $$op \
		| $(TF_VER) -rnear_even $$op \
		| tee -a $(REF_LOGS)/$(@)_$(FECHA).log; \
	done


####################################################################################
# Reglas de análisis dinámico de código: 
# valgrind  : memcheck, helgrind
# sanitizers: addres, memory, thread, undefined
# 		clang -g -Wall -Wextra -fsanitize=address $(APPNAME).c -o $(APPNAME)_asan
####################################################################################
#################### Target: Análisis estático de código con linter
all_valgrind: $(TODO:=_memcheck) $(TODO:=_massif) $(TODO:=_callgrind)

$(TODO:=_memcheck):
	@echo ""
	valgrind --tool=memcheck \
		--log-file=$(REF_LOGS)/$(notdir $@)_$(FECHA).log \
		./$(@:_memcheck=) f32_add \
		| $(TF_VER) -rnear_even f32_add
# 		| tee -a $(REF_LOGS)/$(notdir $@)_$(FECHA).log

$(TODO:=_massif):
	@echo ""
	valgrind --tool=massif \
		--massif-out-file=$(REF_LOGS)/$(notdir $@)_$(FECHA).log \
		./$(@:_massif=) f32_add \
		| $(TF_VER) -rnear_evenf32_add 
# 		| tee -a $(REF_LOGS)/$(notdir $@)_$(FECHA).log

$(TODO:=_callgrind):
	@echo ""
	valgrind --tool=callgrind \
		--callgrind-out-file=$(REF_LOGS)/$(notdir $@)_$(FECHA).log \
		./$(@:_callgrind=) f32_add \
		| $(TF_VER) -rnear_even f32_add


####################################################################################
#################### Target: de limpieza
clean_all: clean clean_berkeley clean_build_reference
# clean local, borra archivo locales al modelo de referencia
clean: clean_bin clean_logs clean_vectors

clean_bin:
	rm -rf $(REF_BIN) 
clean_logs:
	rm -rf $(REF_LOGS)
clean_vectors:
	rm -rf $(REF_VECTORS)
clean_build_reference:
	rm -rf $(REF_BUILD)

clean_berkeley: clean_berkeley_softfloat clean_berkeley_testfloat
clean_berkeley_softfloat:
	rm -rf $(SF_BUILD)/*.o $(SF_BUILD)/*.a
clean_berkeley_testfloat:
	rm -rf $(REF_VECTORS)/*.tf
	rm -rf $(TF_BUILD)/*.o $(TF_BUILD)/*.a
	@for tool in $(TF_TOOLS); do \
		rm -rf $(TF_BUILD)/$$tool; \
		echo "rm -rf $(TF_BUILD)/$$tool"; \
	done

####################################################################################
help:
	echo "TODO HELP FUNCTION"

.PHONY: all _mkdir_folders _echo_vars \
		build_all \
		build_berkeley_testfloat \
		build_berkeley_softfloat \
		testd_river \
		$(REF_OBJ) \
		$(CFILES:=_syntax) \
		$(CTEST:=_compile) \
		$(BIN_EXE:=_run) \
		testfloat_gen testfloat_replay testfloat_check \
		clean clean_bin  clean_logs clean_build clean_build_reference \
		clean_berkeley_softfloat clean_berkeley_testfloat clean_all \
		help