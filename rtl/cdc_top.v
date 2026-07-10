module cdc_top (
    input  wire clk_src,
    input  wire clk_dst,
    input  wire rst_src,
    input  wire rst_dst,

    // 2-Flop Synchronizer ports
    input  wire        data_in,
    output wire        data_out,

    // Pulse Synchronizer ports
    input  wire        pulse_in,
    output wire        pulse_out,

    // Handshake Synchronizer ports
    input  wire [7:0]  hs_data_in,
    input  wire        hs_send,
    output wire [7:0]  hs_data_out,
    output wire        hs_data_valid,
    output wire        hs_ready,

    // Async FIFO ports
    input  wire        wr_en,
    input  wire [7:0]  wr_data,
    input  wire        rd_en,
    output wire [7:0]  rd_data,
    output wire        full,
    output wire        empty
);

    flop_sync_2 u_flop_sync (
        .clk_dst  (clk_dst),
        .rst_dst  (rst_dst),
        .data_in  (data_in),
        .data_out (data_out)
    );

    pulse_sync u_pulse_sync (
        .clk_src  (clk_src),
        .clk_dst  (clk_dst),
        .rst_src  (rst_src),
        .rst_dst  (rst_dst),
        .pulse_in (pulse_in),
        .pulse_out(pulse_out)
    );

    handshake_sync #(
        .DATA_WIDTH(8)
    ) u_handshake (
        .clk_src   (clk_src),
        .clk_dst   (clk_dst),
        .rst_src   (rst_src),
        .rst_dst   (rst_dst),
        .data_in   (hs_data_in),
        .send      (hs_send),
        .data_out  (hs_data_out),
        .data_valid(hs_data_valid),
        .ready     (hs_ready)
    );

    async_fifo #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) u_async_fifo (
        .clk_src(clk_src),
        .rst_src(rst_src),
        .wr_en  (wr_en),
        .wr_data(wr_data),
        .full   (full),
        .clk_dst(clk_dst),
        .rst_dst(rst_dst),
        .rd_en  (rd_en),
        .rd_data(rd_data),
        .empty  (empty)
    );

endmodule