
interface fpu_if #(
    parameter int P_ADDR_WIDTH = 3
);

    // Entradas al DUT
    logic [P_ADDR_WIDTH-1:0] op_code_i;
    logic [31:0]             fp_a_i;
    logic [31:0]             fp_b_i;
    logic [31:0]             fp_c_i;
    logic [2:0]              r_mode_i;

    // Salidas del DUT
    logic [31:0] fp_result_o;
    logic        overflow_o;
    logic        underflow_o;
    logic        cmp_result_o;
    logic        invalid_o;

    // Task: clock_gen
    // Genera el reloj principal del DUT con periodo fijo en 10 ciclos de reloj.
    logic clk = 1'b0;
    
    initial begin
        clk = 0;
        forever begin
            #10;
            clk = ~clk;
        end
    end

endinterface: fpu_if
