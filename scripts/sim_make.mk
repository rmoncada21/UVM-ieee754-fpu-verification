_test_target:
	echo "$(LOGS_SIM:=.UVM)"

_testbench_sim:
	./testbench_sim \
	-l ../$(LOGS_SIM)/testbench_sim.log \
	| tee ../$(LOGS_TESTS)/testbench_sim_$(shell date +%d_%H_%M_%S).log

# +UVM_TIMEOUT=$(TIMEOUT)
_sim_fpu_base_test:
	./testbench_sim \
	+UVM_TESTNAME=$(@:_sim_%=%)_c \
	+UVM_VERBOSITY=$(VERBOSITY) \
	+ntb_random_seed_automatic \
	-l ../$(LOGS_SIM)/$(@:_sim_%=%).log \
	| tee ../$(LOGS_TESTS)/$(@:_sim_%=%)_$(shell date +%d_%H_%M_%S).log

_sim_fpu_test_arith_normal:
	./testbench_sim \
	+UVM_TESTNAME=$(@:_sim_%=%)_c \
	+UVM_VERBOSITY=$(VERBOSITY) \
	+ntb_random_seed_automatic \
	-l ../$(LOGS_SIM)/$(@:_sim_%=%).log \
	| tee ../$(LOGS_TESTS)/$(@:_sim_%=%)_$(shell date +%d_%H_%M_%S).log


# 	_sim_fpu_NOMBRE_test:
# 	./testbench_sim \
# 	+UVM_TESTNAME=$(@:_sim_%=%)_c \
# 	+UVM_VERBOSITY=$(VERBOSITY) \
# 	+ntb_random_seed_automatic \
# 	-l ../$(LOGS_SIM)/$(@:_sim_%=%).log \
# 	| tee ../$(LOGS_TESTS)/$(@:_sim_%=%)_$(shell date +%d_%H_%M_%S).log