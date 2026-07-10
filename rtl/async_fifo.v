module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4   // FIFO depth = 2^ADDR_WIDTH = 16
)(
    // Write domain
    input  wire     clk_src,
    input  wire     rst_src,
    input  wire     wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire     full,

    // Read domain
    input  wire                  clk_dst,
    input  wire                  rst_dst,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    reg [ADDR_WIDTH:0] wptr_bin;  // Binary write pointer
    reg [ADDR_WIDTH:0] wptr_gray; // Gray code write pointer

    wire [ADDR_WIDTH:0] wptr_gray_next;
    wire [ADDR_WIDTH:0] wptr_bin_next;

    assign wptr_bin_next  = wptr_bin + (wr_en & ~full);
    assign wptr_gray_next = wptr_bin_next ^ (wptr_bin_next >> 1);

    always @(posedge clk_src) begin
        if (rst_src) begin
            wptr_bin  <= 0;
            wptr_gray <= 0;
        end else begin
            wptr_bin  <= wptr_bin_next;
            wptr_gray <= wptr_gray_next;
        end
    end

    always @(posedge clk_src) begin
        if (wr_en && !full)
            mem[wptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end

    (* ASYNC_REG = "TRUE" *) reg [ADDR_WIDTH:0] rptr_gray_sync1;
    (* ASYNC_REG = "TRUE" *) reg [ADDR_WIDTH:0] rptr_gray_sync2;

    always @(posedge clk_src) begin
        if (rst_src) begin
            rptr_gray_sync1 <= 0;
            rptr_gray_sync2 <= 0;
        end else begin
            rptr_gray_sync1 <= rptr_gray;  // FF1: may go metastable
            rptr_gray_sync2 <= rptr_gray_sync1; // FF2: stable
        end
    end

    assign full = (wptr_gray[ADDR_WIDTH]   != rptr_gray_sync2[ADDR_WIDTH])   &&
                  (wptr_gray[ADDR_WIDTH-1] != rptr_gray_sync2[ADDR_WIDTH-1]) &&
                  (wptr_gray[ADDR_WIDTH-2:0] == rptr_gray_sync2[ADDR_WIDTH-2:0]);

    reg [ADDR_WIDTH:0] rptr_bin;
    reg [ADDR_WIDTH:0] rptr_gray;

    wire [ADDR_WIDTH:0] rptr_bin_next;
    wire [ADDR_WIDTH:0] rptr_gray_next;

    assign rptr_bin_next  = rptr_bin + (rd_en & ~empty);
    assign rptr_gray_next = rptr_bin_next ^ (rptr_bin_next >> 1);

    always @(posedge clk_dst) begin
        if (rst_dst) begin
            rptr_bin  <= 0;
            rptr_gray <= 0;
        end else begin
            rptr_bin  <= rptr_bin_next;
            rptr_gray <= rptr_gray_next;
        end
    end

    assign rd_data = mem[rptr_bin[ADDR_WIDTH-1:0]];

    (* ASYNC_REG = "TRUE" *) reg [ADDR_WIDTH:0] wptr_gray_sync1;
    (* ASYNC_REG = "TRUE" *) reg [ADDR_WIDTH:0] wptr_gray_sync2;

    always @(posedge clk_dst) begin
        if (rst_dst) begin
            wptr_gray_sync1 <= 0;
            wptr_gray_sync2 <= 0;
        end else begin
            wptr_gray_sync1 <= wptr_gray;
            wptr_gray_sync2 <= wptr_gray_sync1;
        end
    end
    assign empty = (rptr_gray == wptr_gray_sync2);

endmodule