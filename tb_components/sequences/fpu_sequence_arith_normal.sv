class fpu_sequence_arith_normal_c extends fpu_base_sequence_c;
    `uvm_object_utils(fpu_sequence_arith_normal_c)

    function new(string name="fpu_sequence_arith_normal_c");
        super.new(name);
        num_items = 200;
    endfunction : new

    task body();
        `uvm_info(this.get_type_name(),
            "w",
            UVM_LOW)
        
        repeat(num_items) begin
            req = fpu_seq_item_c::type_id::create("req");
            this.start_item(req);
            // TODO: pasar constraints a fpu_seq_item
            if(!req.randomize() with {  
                op_code_i inside {FADD, FSUB, FMUL, FMADD, FMSUB};
                fp_a_i[30:23] inside {[8'd70 : 8'd184]};
                fp_b_i[30:23] inside {[8'd70 : 8'd184]};
                fp_c_i[30:23] inside {[8'd70 : 8'd184]}; }
            ) begin
                `uvm_error(this.get_type_name(), "falló la aleatorización")
            end
            this.finish_item(req);
        end
    endtask : body

endclass