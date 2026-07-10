module flop_sync_2 (
    input  wire clk_dst,   // Destination domain clock
    input  wire rst_dst,   // Synchronous reset (destination domain)
    input  wire data_in,   // Single-bit input from source domain
    output wire data_out   // Synchronized output (destination domain)
);

    
    (* ASYNC_REG = "TRUE" *) reg ff1;
    (* ASYNC_REG = "TRUE" *) reg ff2;
    always @(posedge clk_dst) begin
        if (rst_dst) begin
            ff1 <= 1'b0;   // Reset FF1 to 0
            ff2 <= 1'b0;   // Reset FF2 to 0
        end else begin
            ff1 <= data_in; // FF1 samples source-domain signal
            ff2 <= ff1;     // FF2 samples FF1 output
        end
    end
    assign data_out = ff2;

endmodule