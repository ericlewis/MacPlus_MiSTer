`default_nettype none

module mac_scsi_mpu_bridge (
    input  wire        clk,
    input  wire        reset_n,

    input  wire        io_fpga,
    input  wire        io_strobe,
    input  wire [15:0] io_dout,
    output reg  [15:0] io_din,
    output wire        io_wait,

    input  wire        img_mounted,
    input  wire [31:0] img_blocks,
    input  wire [31:0] io_lba,
    input  wire        io_rd,
    input  wire        io_wr,
    output reg         io_ack,

    output reg  [7:0]  sd_buff_addr,
    output reg  [15:0] sd_buff_dout,
    input  wire [15:0] sd_buff_din,
    output reg         sd_buff_wr
);

localparam [15:0] CMD_STATUS      = 16'hA000;
localparam [15:0] CMD_LBA_HI      = 16'hA001;
localparam [15:0] CMD_LBA_LO      = 16'hA002;
localparam [15:0] CMD_BLOCKS_HI   = 16'hA003;
localparam [15:0] CMD_BLOCKS_LO   = 16'hA004;
localparam [15:0] CMD_BUF_READ    = 16'hA200;
localparam [15:0] CMD_REQ_ACK     = 16'hA400;
localparam [7:0]  CMD_BUF_ADDR_OP = 8'hA1;
localparam [7:0]  CMD_BUF_WRITE_OP = 8'hA3;

assign io_wait = 1'b0;

reg        req_pending = 1'b0;
reg        req_write = 1'b0;
reg [31:0] req_lba = 32'd0;
reg        ack_active = 1'b0;
reg        buf_write_pending = 1'b0;
reg [7:0]  buf_write_addr = 8'd0;
reg [15:0] sd_buff_din_latched = 16'd0;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        io_din <= 16'd0;
        io_ack <= 1'b0;
        sd_buff_addr <= 8'd0;
        sd_buff_dout <= 16'd0;
        sd_buff_wr <= 1'b0;
        req_pending <= 1'b0;
        req_write <= 1'b0;
        req_lba <= 32'd0;
        ack_active <= 1'b0;
        buf_write_pending <= 1'b0;
        buf_write_addr <= 8'd0;
        sd_buff_din_latched <= 16'd0;
    end else begin
        io_ack <= ack_active;
        sd_buff_wr <= 1'b0;
        sd_buff_din_latched <= sd_buff_din;

        if (ack_active && !io_rd && !io_wr) begin
            ack_active <= 1'b0;
            io_ack <= 1'b0;
        end

        if (!req_pending && !ack_active) begin
            if (io_rd) begin
                req_pending <= 1'b1;
                req_write <= 1'b0;
                req_lba <= io_lba;
            end else if (io_wr) begin
                req_pending <= 1'b1;
                req_write <= 1'b1;
                req_lba <= io_lba;
            end
        end

        if (io_fpga && io_strobe) begin
            if (buf_write_pending) begin
                sd_buff_addr <= buf_write_addr;
                sd_buff_dout <= io_dout;
                sd_buff_wr <= 1'b1;
                io_din <= 16'h0000;
                buf_write_pending <= 1'b0;
            end else begin
                case (io_dout)
                    CMD_STATUS: begin
                        io_din <= {13'd0, img_mounted, req_write, req_pending};
                    end
                    CMD_LBA_HI: begin
                        io_din <= req_lba[31:16];
                    end
                    CMD_LBA_LO: begin
                        io_din <= req_lba[15:0];
                    end
                    CMD_BLOCKS_HI: begin
                        io_din <= img_blocks[31:16];
                    end
                    CMD_BLOCKS_LO: begin
                        io_din <= img_blocks[15:0];
                    end
                    CMD_BUF_READ: begin
                        io_din <= sd_buff_din_latched;
                    end
                    CMD_REQ_ACK: begin
                        ack_active <= 1'b1;
                        io_ack <= 1'b1;
                        req_pending <= 1'b0;
                        io_din <= 16'h0000;
                    end
                    default: begin
                        if (io_dout[15:8] == CMD_BUF_ADDR_OP) begin
                            sd_buff_addr <= io_dout[7:0];
                            io_din <= 16'h0000;
                        end else if (io_dout[15:8] == CMD_BUF_WRITE_OP) begin
                            buf_write_addr <= io_dout[7:0];
                            buf_write_pending <= 1'b1;
                            io_din <= 16'h0000;
                        end else begin
                            io_din <= 16'h0000;
                        end
                    end
                endcase
            end
        end
    end
end

endmodule

`default_nettype wire
