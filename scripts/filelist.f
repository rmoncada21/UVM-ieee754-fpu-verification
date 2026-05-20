# Incluir componentes del testbench
+incdir+tb_components
+incdir+tb_components/interface
+incdir+tb_components/packages

# Incluir DUT
dut/ALU-FPU-ieee754/ALU_FP/fp_alu.sv

# Incluir packages
tb_components/packages/fpu_pkg.sv
tb_components/packages/fpu_env_pkg.sv
tb_components/interface/fpu_if.sv

# Incluir top testbench
testbench.sv
