# usar "make -f make_ref_soft.mk" si se encuentra dentro del directorio de golde_model/

SHELL := /bin/bash

#############################################################################
# Folders
REF_BIN       = bin
REF_SRC       = src
REF_INC       = include
REF_LOGS      = logs
REF_BUILD     = build
REF_VECTORS   = vectors
REF_STAND     = standalone_tests
# STAND_BIN = standalone_tests/bin

#----------------------------
# Variables para berkeley SOFTFLOAT
SOFTFLOAT_DIR ?= ../third_party/berkeley-softfloat-3
SF_BUILD      := $(SOFTFLOAT_DIR)/build/Linux-x86_64-GCC
SF_LIBRARY_A  := $(SF_BUILD)/softfloat.a
SF_INCLUDE    := $(SOFTFLOAT_DIR)/source/include

#----------------------------
# Variables para berkeley TESTFLOAT
TESTFLOAT_DIR ?= ../third_party/berkeley-testfloat-3
TF_BUILD      := $(TESTFLOAT_DIR)/build/Linux-x86_64-GCC
TF_TEST       := $(TF_BUILD)/testfloat
TF_GEN        := $(TF_BUILD)/testfloat_gen
TF_VER        := $(TF_BUILD)/testfloat_ver
TF_SOFTFLOAT  := $(TF_BUILD)/testsoftfloat
TF_TIME       := $(TF_BUILD)/timesoftfloat
TF_TOOLS       = $(TF_TEST) $(TF_GEN) $(TF_VER) $(TF_SOFTFLOAT) $(TF_TIME)
TF_OPS        := f32_add f32_sub f32_mul f32_eq f32_lt f32_le
TF_ROUNDS_MODE = -rnear_even -rnear_maxMag -rminMag -rmin -rmax -rodd

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
# runner
# Nombre original tf_runner
RUNNER_FILE ?= runner_testfloat
RUNNER_C    := $(REF_SRC)/$(RUNNER_FILE:=.c)
RUNNER_EXE  := $(REF_BIN)/$(RUNNER_FILE:=_exe)

#----------------------------
# Archivos para inyectar datos desde el mismo archivo "main"
DRIVER_FILE    ?= simple_driver
REF_DRIVER_C   := $(REF_STAND)/$(DRIVER_FILE:=.c)
REF_DRIVER_EXE := $(REF_BIN)/$(DRIVER_FILE:=_exe)

# Variables del testfloat replay
# Archivos para inyectar datos mediante pipe con testfloat tools
# nombre_original tf_replay  
TF_REPLAY      ?= replayer_testfloat
TF_REPLAY_C    := $(REF_STAND)/$(TF_REPLAY:=.c)
TF_REPLAY_EXE  := $(REF_BIN)/$(TF_REPLAY:=_exe)

# Variables para estudio con valgrind
BIN_EXE    := $(wildcard $(REF_BIN)/*_exe)
VAL_TOOLS  := memcheck helgrind

####################################################################################
#################### Target universales
all:

_mkdir_folders:
	mkdir -p $(REF_BIN) $(REF_BUILD) $(REF_LOGS) $(REF_VECTORS)

# revisar solo syntaxis
# make src/nombre_archivo.c_syntax
# make standalone_tests/nombre_archivo.c_syntax
$(CFILES:=_syntax):
	$(CC) $(CFLAGS) $(CFSYNTAX) $(@:_syntax=)

####################################################################################
#################### Target: build de librerías (internas, externas ) y herramientas
build_all: build_berkeley_softfloat build_berkeley_testfloat $(REF_OBJ)

#---------------------------- Librerías
# construir la librerias berkeley con especializacion RISC-V, 
# genera softfloat.a como librería estática -> ../third_party/berkeley-softfloat-3/build/Linux-x86_64-GCC/softfloat.a
build_berkeley_softfloat:
	$(MAKE) -C $(SF_BUILD) SPECIALIZE_TYPE=RISCV

build_berkeley_testfloat: | $(SF_LIBRARY_A)
	$(MAKE) -C $(TF_BUILD) SPECIALIZE_TYPE=RISCV

# crear objeto reference_model.o
$(REF_OBJ): _mkdir_folders
	$(CC) $(CFLAGS) -c $(REF_C) -I$(SF_INCLUDE) -o $@

#---------------------------- herramientas
# construir vectores. 
# TODO: crear mas vectores con otro modo de redondeo
# cambiar nombre con respecto a la operación y modo de redondeo
# $(TF_GEN) -rnear_even $$op > $(REF_VECTORS)/$$op.tf;
build_testfloat_vectors: _mkdir_folders
	@for op in $(TF_OPS); do \
		echo ">> $(REF_VECTORS)/$$op.tf"; \
		for mode in $(TF_ROUNDS_MODE); do \
			echo "$${op}_$${mode/-/}"; \
			$(TF_GEN) $$mode $$op > $(REF_VECTORS)/$${op}_$${mode/-/}.tf; \
		done \
	done

mostrar_nombres_vectors:
	for op in $(TF_OPS); do \
		echo ">> $(REF_VECTORS)/$$op.tf"; \
			for mode in $(TF_ROUNDS_MODE); do \
				echo "$${op}_$${mode/-/}"; \
			done \
	done

# testear softfloat vs testfloat de berkeley
test_build_berkeleys_libraries:
	$(TF_SOFTFLOAT) -level 1 f32_sub

####################################################################################
#################### Target: compila y ejecutar validación cruzada
all_runner:

$(RUNNER_EXE): $(RUNNER_C) 
	$(CC) $(CFLAGS) $< $(REF_OBJ) $(SF_LIBRARY_A) $(INCLUDES) -o $@

# probar solo con un redonde y operacion por el momento 
run_runner: testfloat_gen_vectors
	$(TF_GEN) -rnear_even f32_mul | ./$(RUNNER_EXE) mul 0 | $(TF_VER) -rnear_even f32_mul

testfloat_gen_vectors:
	for op in $(TF_OPS); do \
		echo ">> $(REF_VECTORS)/$$op.tf"; \
		$(TF_GEN) -rnear_even $$op > $(REF_VECTORS)/$$op.tf; \
	done

####################################################################################
#################### Target: compilación e integración simple driver
all_driver: test_driver test_driver_run 

#----------------------------
# enlaza objeto y compila simple_driver
test_driver: $(REF_DRIVER_C) $(REF_OBJ)
	$(CC) $(CFLAGS) $< $(REF_OBJ) $(SF_LIBRARY_A) $(INCLUDES) -o $(REF_BIN)/$(notdir $(<:.c=_exe))

test_driver_run: $(REF_DRIVER_C)
	./$(REF_BIN)/$(notdir $(<:.c=_exe)) | tee $(REF_LOGS)/$(notdir $(<:.c=_exe))_$(shell date +%d_%H_%M_%S).log

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
		| tee -a $(REF_LOGS)/$(@)_$(shell date +%d_%H_%M_%S).log; \
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
		--log-file=$(REF_LOGS)/$(notdir $@)_$(shell date +%d_%H_%M_%S).log \
		./$(@:_memcheck=) f32_add \
		| $(TF_VER) -rnear_even f32_add
# 		| tee -a $(REF_LOGS)/$(notdir $@)_$(shell date +%d_%H_%M_%S).log

$(TODO:=_massif):
	@echo ""
	valgrind --tool=massif \
		--massif-out-file=$(REF_LOGS)/$(notdir $@)_$(shell date +%d_%H_%M_%S).log \
		./$(@:_massif=) f32_add \
		| $(TF_VER) -rnear_evenf32_add 
# 		| tee -a $(REF_LOGS)/$(notdir $@)_$(shell date +%d_%H_%M_%S).log

$(TODO:=_callgrind):
	@echo ""
	valgrind --tool=callgrind \
		--callgrind-out-file=$(REF_LOGS)/$(notdir $@)_$(shell date +%d_%H_%M_%S).log \
		./$(@:_callgrind=) f32_add \
		| $(TF_VER) -rnear_even f32_add


####################################################################################
#################### Target: de limpieza
clean_all: clean clean_berkeley
# clean local, borra archivo locales al modelo de referencia
clean: clean_bin clean_logs clean_vectors clean_build_reference

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
	TF_TIME      -rf $(REF_timesoftfloat
	rm -rf $(TF_BUILD)/*.o $(TF_BUILD)/*.a
	for tool in $(TF_TOOLS); do \
		rm -rf $(TF_BUILD)/$$tool; \
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