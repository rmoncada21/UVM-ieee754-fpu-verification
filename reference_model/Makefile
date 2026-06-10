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
TF_TOOLS       = $(notdir $(TF_TEST)) $(notdir $(TF_GEN)) $(notdir $(TF_VER)) $(notdir $(TF_SOFTFLOAT)) $(notdir $(TF_TIME))
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

# Variables para estudio con valgrind
BIN_EXE    := $(wildcard $(REF_BIN)/*_exe)
VAL_TOOLS  := memcheck helgrind

####################################################################################
#################### Target universales
all: build_all

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
	$(MAKE) -C $(SF_BUILD) SPECIALIZE_TYPE=$(ARCH_TARGET)

# Ambas deben coincidir para una correcta integración y compilación
build_berkeley_testfloat: | $(SF_LIBRARY_A)
	$(MAKE) -C $(TF_BUILD) SPECIALIZE_TYPE=$(ARCH_TARGET)

# Ambas deben coincidir para una correcta integración y compilación
# crear objeto reference_model.o
$(REF_OBJ): _mkdir_folders
	$(CC) $(CFLAGS) -c $(REF_C) -I$(SF_INCLUDE) -o $@

#---------------------------- herramientas de uso testfloat ----------------------------#

# Uso de testsoftfloat
# testear softfloat vs testfloat de berkeley
# opciones: -all2 -all1 f32_add f32_sub ...
# TODO: hacer fora para probar las operaciones del reference model
# Compara el softfloat.a generado contra slowfloat (FP íntegro de berkeley)
test_build_berkeleys_libraries:
	$(TF_SOFTFLOAT) -level 1 -all1 \
		2>&1 | tee $(REF_LOGS)/$(notdir $(TF_SOFTFLOAT))_$(shell date +%d_%H_%M_%S).log \

# construir vectores.
# TODO: crear mas vectores con otro modo de redondeo
# cambiar nombre con respecto a la operación y modo de redondeo
# $(TF_GEN) -rnear_even $$op > $(REF_VECTORS)/$$op.tf;
build_testfloat_vectors: _mkdir_folders
	@for op in $(TF_OPS); do \
		echo ">> $(REF_VECTORS)/$$op*.tf"; \
		for mode in $(TF_ROUNDS_MODE); do \
			echo "$${op}_$${mode/-/}"; \
			$(TF_GEN) $$mode $$op > $(REF_VECTORS)/$${op}_$${mode/-/}.tf; \
		done \
	done

# mostrar_nombres_vectors:
# 	for op in $(TF_OPS); do \
# 		echo ">> $(REF_VECTORS)/$$op.tf"; \
# 			for mode in $(TF_ROUNDS_MODE); do \
# 				echo "$${op}_$${mode/-/}"; \
# 			done \
# 	done

####################################################################################
#################### Target: compilación e integración simple driver
all_driver: driver_compile driver_run

#----------------------------
# enlaza objeto y compila simple_driver
driver_compile: $(REF_DRIVER_C) $(REF_OBJ)
	$(CC) $(CFLAGS) $< $(REF_OBJ) $(SF_LIBRARY_A) $(INCLUDES) -o $(REF_DRIVER_EXE)

driver_run: $(REF_DRIVER_C)
	./$(REF_DRIVER_EXE) | tee $(REF_LOGS)/$(notdir $(REF_DRIVER_EXE))_$(shell date +%d_%H_%M_%S).log

####################################################################################
#################### Target: compilar y ejecutar validación cruzada
all_runner:

runner_compile: $(RUNNER_C)
	$(CC) $(CFLAGS) $< $(REF_OBJ) $(SF_LIBRARY_A) $(INCLUDES) -o $(RUNNER_EXE)

# probar solo con un redondeo y operacion por el momento
runner_run: testfloat_gen_vectors
	$(TF_GEN) -rnear_even f32_mul | ./$(RUNNER_EXE) mul 0 | $(TF_VER) -rnear_even f32_mul

testfloat_gen_vectors:
	for op in $(TF_OPS); do \
		echo ">> $(REF_VECTORS)/$$op.tf"; \
		$(TF_GEN) -rnear_even $$op > $(REF_VECTORS)/$$op.tf; \
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