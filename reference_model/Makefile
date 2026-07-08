####################################################################################
#################### Targets: universales
all: build_all all_runner all_driver all_replayer

include make_common.mk
include standalone_tests/runner/make_runner.mk
include standalone_tests/driver/make_driver.mk
include standalone_tests/replayer/make_replayer.mk

# _mkdir_folders:
# 	mkdir -p $(REF_BIN) $(REF_BUILD) $(REF_LOGS) $(REF_VECTORS)

# revisar solo syntaxis
# make src/nombre_archivo.c_syntax
# make standalone_tests/nombre_archivo.c_syntax
# $(CFILES:=_syntax):
# 	$(CC) $(CFLAGS) $(CFSYNTAX) $(@:_syntax=)

####################################################################################
#################### Targets: TESTFLOAT test tools
_my_TF_SEED  = 5
_my_TF_LEVEL = 1
_my_RM       = -rnear_even
_my_OP       = f32_add

_testfloat_gen:
	$(TF_GEN) -level $(_my_TF_LEVEL) -seed $(_my_TF_SEED) \
		$(_my_RM) $(_my_OP)

_testfloat_ver:
	$(TF_VER) $(_my_RM) $(_my_OP)

_testfloat_test:
	$(TF_GEN) -level $(_my_TF_LEVEL) -seed $(_my_TF_SEED) \
		$(_my_RM) $(_my_OP) \
	| $(TF_VER) $(_my_RM) -checkNaNs -errors 0 $(_my_OP)
####################################################################################
#################### Targets: Build de librerías (internas, externas ) y herramientas
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
#################### Targets: herramientas de uso testfloat

# Uso de testsoftfloat
# testear softfloat vs testfloat de berkeley
# opciones: -all2 -all1 f32_add f32_sub ...
# TODO: hacer for para probar las operaciones del reference model
# Compara el softfloat.a generado contra slowfloat (FP íntegro de berkeley)
test_build_berkeleys_libraries:
	for op in $(TF_OPS_ALL); do \
		for pair in $(ROUND_MODE_PAIR); do \
			echo "";\
			rm=$${pair##*:}; \
			$(TF_SOFTFLOAT) -level 1 $$rm $$op; \
		done; \
	done

# 	for op in $(TF_OPS_ALL); do \
# 		echo -e "\n== testsoftfloat $$op =="; \
# 		$(TF_SOFTFLOAT) -level 1 $$op ;\
# 	done

# TODO: Hacer regla con testfloat y probar vectores hechos con tf_ver

#--------------------------
# construir vectores.
# TODO: crear mas vectores con otro modo de redondeo
# cambiar nombre con respecto a la operación y modo de redondeo
# $(TF_GEN) -rnear_even $$op > $(REF_VECTORS)/$$op.tf;
build_testfloat_vectors: | $(REF_VECTORS) $(LOGS_VECTORS)
	{ echo -e "\n== vectores level=$(TF_LEVEL) seed=$(TF_SEED) fecha=$(FECHA) =="; \
	for op in $(OPS_ARITH) f32_mulAdd; do \
	  for par in $(ROUND_MODE_PAIR); do \
		ref_r=$${par%%:*}; tf_r=$${par##*:}; \
	    out_file=$(REF_VECTORS)/$${op}_$${ref_r}_l$(TF_LEVEL)_s$(TF_SEED).tf; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$tf_r $$op > $$out_file || exit 1; \
		echo "$$out_file ($$(wc -l < $$out_file) vectores)"; \
	  done; \
	done; \
	for op in $(OPS_CMP); do \
	  out_file=$(REF_VECTORS)/$${op}_l$(TF_LEVEL)_s$(TF_SEED).tf; \
	  $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$op > $$out_file || exit 1; \
	  echo "$$out_file ($$(wc -l < $$out_file) vectores)"; \
	done; } 2>&1 | tee $(LOGS_VECTORS)/$@_$(FECHA).log

####################################################################################
################### Targets: N1 - compilación y ejecución con gcc
# gcc & ./exe

####################################################################################
################### N2- Targets: Reglas de análisis dinámico de código: 
# valgrind  : memcheck, massif, callgrind

####################################################################################
#################### N3 Clang Sanitizers
# sanitizers: addres, memory, undefined
# 		clang -g -Wall -Wextra -fsanitize=address $(APPNAME).c -o $(APPNAME)_asan

# ####################################################################################
# #################### Targets: de limpieza
clean_all: clean clean_berkeley clean_build_reference
# clean local, borra archivo locales al modelo de referencia
clean: clean_bin clean_logs clean_vectors

clean_bin:
	rm -rf $(DIRS)
# 	rm -rf  $(RUN_BIN) $(DRV_BIN) $(REP_BIN)
clean_logs:
	rm -rf $(LOGS_DIRS)
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

# TODO: ACTUALIZAR PHONY
.PHONY: \
	all \
	build_all \
	build_berkeley_softfloat \
	build_berkeley_testfloat \
	test_build_berkeleys_libraries \
	build_testfloat_vectors \
	valgrind_all \
	sanitizers_all \
	clean_all \
	clean \
	clean_bin \
	clean_logs \
	clean_vectors \
	clean_build_reference \
	clean_berkeley \
	clean_berkeley_softfloat \
	clean_berkeley_testfloat \
	help