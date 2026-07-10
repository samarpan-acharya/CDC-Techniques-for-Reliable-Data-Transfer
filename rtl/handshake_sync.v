module handshake_sync #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  clk_src,    // Source domain clock
    input  wire                  clk_dst,    // Destination domain clock
    input  wire                  rst_src,    // Synchronous reset, source
    input  wire                  rst_dst,    // Synchronous reset, destination
    input  wire [DATA_WIDTH-1:0] data_in,    // Data to send (source domain)
    input  wire                  send,       // Initiate transfer (source domain)
    output wire [DATA_WIDTH-1:0] data_out,   // Received data (destination domain)
    output wire                  data_valid, // Data captured (destination domain)
    output wire                  ready       // Ready for next send (source domain)
);

    reg [DATA_WIDTH-1:0] data_reg;
    reg req;

    localparam IDLE     = 1'b0;
    localparam WAIT_ACK = 1'b1;
    reg sender_state;

    (* ASYNC_REG = "TRUE" *) reg ack_sync1;
    (* ASYNC_REG = "TRUE" *) reg ack_sync2;

    
    (* ASYNC_REG = "TRUE" *) reg req_sync1;
    (* ASYNC_REG = "TRUE" *) reg req_sync2;

    reg req_sync2_prev;

    reg ack;

    reg [DATA_WIDTH-1:0] data_out_reg;
    reg data_valid_reg;

    always @(posedge clk_src) begin
        if (rst_src) begin
            ack_sync1 <= 1'b0;
            ack_sync2 <= 1'b0;
        end else begin
            ack_sync1 <= ack;      // FF1: may go metastable
            ack_sync2 <= ack_sync1; // FF2: stable in src domain
        end
    end

    always @(posedge clk_src) begin
        if (rst_src) begin
            sender_state <= IDLE;
            req          <= 1'b0;
            data_reg     <= {DATA_WIDTH{1'b0}};
        end else begin
            case (sender_state)

                IDLE: begin
                    if (send && !req) begin
                        // Latch data — holds stable during entire transfer
                        data_reg     <= data_in;
                        req          <= 1'b1; // Phase 1: assert request
                        sender_state <= WAIT_ACK;
                    end
                end

                WAIT_ACK: begin
                    if (ack_sync2) begin
                        // Phase 3: ack received — deassert req
                        req <= 1'b0;
                    end
                    // Wait for ack to go low (Phase 4 complete)
                    // before returning to IDLE
                    if (!ack_sync2 && !req) begin
                        sender_state <= IDLE;
                    end
                end

            endcase
        end
    end

    always @(posedge clk_dst) begin
        if (rst_dst) begin
            req_sync1     <= 1'b0;
            req_sync2     <= 1'b0;
            req_sync2_prev <= 1'b0;
        end else begin
            req_sync1      <= req;       // FF1: may go metastable
            req_sync2      <= req_sync1; // FF2: stable in dst domain
            req_sync2_prev <= req_sync2; // Delayed for edge detection
        end
    end

    always @(posedge clk_dst) begin
        if (rst_dst) begin
            ack          <= 1'b0;
            data_out_reg <= {DATA_WIDTH{1'b0}};
            data_valid_reg <= 1'b0;
        end else begin
            data_valid_reg <= 1'b0; // Default: not valid

            // Rising edge of req_sync2: new data arriving
            if (req_sync2 && !req_sync2_prev) begin
                // Phase 2: capture data and assert ack
                data_out_reg   <= data_reg;  // Capture stable data
                ack            <= 1'b1;      // Assert acknowledge
                data_valid_reg <= 1'b1;      // Signal valid data
            end

            // Falling edge of req_sync2: sender got ack, deasserted req
            if (!req_sync2 && req_sync2_prev) begin
                // Phase 4: deassert ack
                ack <= 1'b0;
            end
        end
    end
    assign data_out   = data_out_reg;
    assign data_valid = data_valid_reg;
    assign ready      = (sender_state == IDLE) && !req;

endmodule