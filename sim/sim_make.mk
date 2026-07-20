# 1. FUNCIÓN MODULAR (Macro)
# $(1): Nombre del test extraído del target
# los test se guardan directos en sim

define run_uvm_test
	./$(EXE_SIM) \
		+UVM_TESTNAME=$(strip $(1))_c \
		+UVM_VERBOSITY=$(VERBOSITY) \
		+ntb_random_seed_automatic \
		-l ../$(LOGS_SIM)/$(strip $(1)).log \
		| tee ../$(LOGS_TESTS)/$(strip $(1))_$(FECHA).log
endef

all_test: run_fpu_base_test run_fpu_test_arith_normal run_fpu_test_cmp \
		  run_fpu_test_rounding run_fpu_test_special_spec run_fpu_test_norm_spec \
		  run_fpu_test_subnormal_arith
####################################################################################
################### Ejecutar los tests

testbench_sim:
	./$(EXE_SIM) \
		-l ../$(LOGS_SIM)/testbench_sim.log \
		| tee ../$(LOGS_TESTS)/testbench_sim_$(shell date +%d_%H_%M_%S).log

run_fpu_base_test:
	echo "$@"
	@$(call run_uvm_test, $(@:run_%=%))

run_fpu_test_arith_normal:
	@$(call run_uvm_test, $(@:run_%=%))

# run_fpu_test_cmp:
# 	@$(call run_uvm_test, $(@:run_%=%))

# run_fpu_test_rounding:
# 	@$(call run_uvm_test, $(@:run_%=%))

# run_fpu_test_special_spec:
# 	@$(call run_uvm_test, $(@:run_%=%))

# run_fpu_test_norm_spec:
# 	@$(call run_uvm_test, $(@:run_%=%))

# run_fpu_test_subnormal_arith:
# 	@$(call run_uvm_test, $(@:run_%=%))

.PHONY: \
	testbench_sim \
	run_fpu_base_test \
	run_fpu_test_arith_normal \
	run_fpu_test_cmp \
	run_fpu_test_rounding \
	run_fpu_test_special_spec \
	run_fpu_test_norm_spec \
	run_fpu_test_subnormal_arith
