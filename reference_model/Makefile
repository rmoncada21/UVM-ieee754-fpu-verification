####################################################################################
#################### Targets: universales
all: build_all remake

remake: build_testfloat_vectors test_build_berkeleys_libraries \
		all_runner all_driver all_replayer

include make_common.mk
include standalone_tests/runner/make_runner.mk
include standalone_tests/driver/make_driver.mk
include standalone_tests/replayer/make_replayer.mk
include ../scripts/.ansi_code.mk

# revisar solo syntaxis
# make src/nombre_archivo.c_syntax
# make standalone_tests/nombre_archivo.c_syntax
# $(CFILES:=_syntax):
# 	$(CC) $(CFLAGS) $(CFSYNTAX) $(@:_syntax=)

####################################################################################
################### Targets: Herramientas de testfloat por separado
# TODO: Hacer regla con testfloat y probar vectores hechos con tf_ver
_my_TF_SEED  = 5
_my_TF_LEVEL = 1
_my_RM       = -rnear_even
_my_OP       = f32_mulAdd

_testfloat_gen:
	$(TF_GEN)  -level $(_my_TF_LEVEL) -seed $(_my_TF_SEED) \
		$(_my_RM) $(_my_OP)

_testfloat_ver:
	$(TF_VER) $(_my_RM) $(_my_OP)

# pipe tf_gen | tf_ver
_testfloat_test:
	$(TF_GEN) -level $(_my_TF_LEVEL) -seed $(_my_TF_SEED) \
		$(_my_RM) $(_my_OP) \
	| $(TF_VER) $(_my_RM) -checkNaNs -errors 0 $(_my_OP)

####################################################################################
################### N0: Build de librerías (internas, externas) y herramientas
# construye las librerías berkeley y el objeto del modelo de referencia
build_all: build_testfloat_vectors build_berkeley_softfloat build_berkeley_testfloat build_reference_model_obj

#---------------------------- Librerías
# construir la librerias berkeley con especializacion RISC-V, 
# genera softfloat.a como librería estática -> ../third_party/berkeley-softfloat-3/build/Linux-x86_64-GCC/softfloat.a
build_berkeley_softfloat:
	$(MAKE) -C $(SF_BUILD) SPECIALIZE_TYPE=$(ARCH_TARGET)

# Ambas deben coincidir para una correcta integración y compilación
build_berkeley_testfloat:
	$(MAKE) -C $(TF_BUILD) SPECIALIZE_TYPE=$(ARCH_TARGET)

# TODO: mover prerrequisito build_*_testfloat a runner/driver
$(REF_OBJ): build_berkeley_softfloat build_berkeley_testfloat | $(REF_BUILD)
	$(CC) $(CFLAGS) -c $(REF_C) -I$(SF_INCLUDE) -o $@

build_reference_model_obj: $(REF_OBJ)

####################################################################################
################### N1: herramientas de uso testfloat

# Uso de testsoftfloat N1: primer nivel de verificación del modelo
# testear softfloat vs testfloat de berkeley
# opciones: -all2 -all1 f32_add f32_sub ...
# Compara el softfloat.a generado contra slowfloat (FP íntegro de berkeley)
test_build_berkeleys_libraries: | $(TFSOFT_LOGS_F)
	for op in $(TF_OPS_ALL); do \
		for pair in $(ROUND_MODE_PAIR); do \
			echo "";\
			rm=$${pair##*:}; \
			$(TF_SOFTFLOAT) -level 1 $$rm $$op 2>&1 \
			| tee $(TFSOFT_LOGS_F)/tf_soft_$${op}_$${rm/-/}.rpt ; \
		done; \
	done

#--------------------------
# construir vectores.
# TODO: crear mas vectores con otro modo de redondeo
# cambiar nombre con respecto a la operación y modo de redondeo
# $(TF_GEN) -rnear_even $$op > $(REF_VECTORS)/$$op.tf;
# build_testfloat_vectors: | $(REF_VECTORS) $(LOGS_VECTORS)
build_testfloat_vectors: | $(REF_VECTORS)
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
	done; } 2>&1 | tee $(REF_VECTORS)/$@_$(FECHA).log

####################################################################################
################### N2: make_runner.mk

####################################################################################
################### N3: make_driver.mk

####################################################################################
################### N4: make_replayer.mk

####################################################################################
################### Targets: de limpieza
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
	@echo ""
	@echo -e '$(CIAN_BRILLANTE)══════════════════════════════════════════════════════════════$(RESET)'
	@echo -e '$(BLANCO_BRILLANTE) Modelo de referencia — SoftFloat/TestFloat   ·   make help$(RESET)'
	@echo -e '$(CIAN_BRILLANTE)══════════════════════════════════════════════════════════════$(RESET)'
	@echo -e '$(NEGRO_BRILLANTE) Ejecutar desde reference_model/  (o  make -C reference_model <target>)$(RESET)'
	@echo ""
	@echo -e '$(CIAN_BRILLANTE)FLUJO COMPLETO$(RESET)'
	@echo -e '$(NEGRO_BRILLANTE)  Librerías + modelo + los tres módulos (runner, driver, replayer)$(RESET)'
	@echo -e '$(VERDE)    make all$(RESET)'
	@echo ""
	@echo -e '$(CIAN_BRILLANTE)1) CONSTRUCCIÓN$(RESET) — librerías y modelo'
	@echo -e '$(NEGRO_BRILLANTE)  Librerías Berkeley (softfloat.a + testfloat) y objeto del modelo$(RESET)'
	@echo -e '$(VERDE)    make build_all$(RESET)'
	@echo -e '$(NEGRO_BRILLANTE)  Solo el objeto del modelo (reference_model.o)$(RESET)'
	@echo -e '$(VERDE)    make build_reference_model_obj$(RESET)'
	@echo ""
	@echo -e '$(CIAN_BRILLANTE)2) VECTORES Y VERIFICACIÓN N1$(RESET)'
	@echo -e '$(NEGRO_BRILLANTE)  softfloat.a vs slowfloat (testsoftfloat)$(RESET)'
	@echo -e '$(VERDE)    make test_build_berkeleys_libraries$(RESET)'
	@echo -e '$(NEGRO_BRILLANTE)  Generar vectores .tf en vectors/$(RESET)'
	@echo -e '$(VERDE)    make build_testfloat_vectors$(NEGRO_BRILLANTE)        # knobs: TF_LEVEL, TF_SEED$(RESET)'
	@echo ""
	@echo -e '$(CIAN_BRILLANTE)3) TESTS$(RESET) — módulos standalone'
	@echo -e '$(AMARILLO_BRILLANTE)  Runner$(RESET) — validación cruzada  (tf_gen | runner):'
	@echo -e '$(VERDE)    make all_runner$(NEGRO_BRILLANTE)          # compile + run_matrix + valgrind + sanitizers$(RESET)'
	@echo -e '$(VERDE)    make runner_run_matrix$(NEGRO_BRILLANTE)   # solo la matriz op×modo$(RESET)'
	@echo -e '$(AMARILLO_BRILLANTE)  Driver$(RESET) — casos dirigidos (autojuez):'
	@echo -e '$(VERDE)    make all_driver$(RESET)'
	@echo -e '$(VERDE)    make driver_run$(RESET)'
	@echo -e '$(AMARILLO_BRILLANTE)  Replayer$(RESET) — auditoría  (tf_gen | replayer | tf_ver):'
	@echo -e '$(VERDE)    make all_replayer$(RESET)'
	@echo -e '$(VERDE)    make replayer_run_matrix$(RESET)'
	@echo -e '$(VERDE)    make replayer_testfloat_sweep$(NEGRO_BRILLANTE)   # genera csv/$(RESET)'
	@echo ""
	@echo -e '$(CIAN_BRILLANTE)LIMPIEZA$(RESET)'
	@echo -e '$(VERDE)    make clean$(NEGRO_BRILLANTE)                  # bin + logs + vectors (locales al modelo)$(RESET)'
	@echo -e '$(VERDE)    make clean_berkeley$(NEGRO_BRILLANTE)         # objetos/.a de softfloat y testfloat$(RESET)'
	@echo -e '$(VERDE)    make clean_build_reference$(NEGRO_BRILLANTE)  # build/ (reference_model.o)$(RESET)'
	@echo -e '$(VERDE)    make clean_all$(NEGRO_BRILLANTE)              # todo lo anterior$(RESET)'
	@echo ""
	@echo -e '$(CIAN_BRILLANTE)Knobs$(RESET)  TF_LEVEL (1|2)   TF_SEED   RUNNER_TRACE (0|N|all)   ARCH_TARGET'
	@echo ""

# TODO: ACTUALIZAR PHONY
.PHONY: \
	all \
	remake \
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