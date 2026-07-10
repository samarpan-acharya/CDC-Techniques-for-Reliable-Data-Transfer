module pulse_sync (
    input  wire clk_src,    
    input  wire clk_dst,    
    input  wire rst_src,    
    input  wire rst_dst,    
    input  wire pulse_in,   
    output wire pulse_out   
);

    reg toggle_ff;

    always @(posedge clk_src) begin
        if (rst_src)
            toggle_ff <= 1'b0;
        else if (pulse_in)
            toggle_ff <= ~toggle_ff; 
    end

    (* ASYNC_REG = "TRUE" *) reg sync_ff1;
    (* ASYNC_REG = "TRUE" *) reg sync_ff2;

    always @(posedge clk_dst) begin
        if (rst_dst) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= toggle_ff;  
            sync_ff2 <= sync_ff1;   
        end
    end

    reg sync_ff2_prev;

    always @(posedge clk_dst) begin
        if (rst_dst)
            sync_ff2_prev <= 1'b0;
        else
            sync_ff2_prev <= sync_ff2; 
    end

    assign pulse_out = sync_ff2 ^ sync_ff2_prev;

endmodule