module vproc_bf16 #(
    parameter int unsigned BF16_OP_W = 64,    // ALU operand width in bits
    parameter type CTRL_T            = logic,
    // parameter bit BUF_OPERANDS       = 1'b1,  // insert pipeline stage after operand extraction
    // parameter bit BUF_INTERMEDIATE   = 1'b1,  // insert pipeline stage for intermediate results
    // parameter bit BUF_RESULTS        = 1'b1,  // insert pipeline stage after computing result
    parameter bit DONT_CARE_ZERO     = 1'b0   // initialize don't care values to zero
) (
    input logic clk_i,
    input logic async_rst_ni,
    input logic sync_rst_ni,

    input  logic                    pipe_in_valid_i,
    output logic                    pipe_in_ready_o,
    input  CTRL_T                   pipe_in_ctrl_i,
    input  logic  [BF16_OP_W  -1:0] pipe_in_op1_i,
    input  logic  [BF16_OP_W  -1:0] pipe_in_op2_i,
    input  logic  [BF16_OP_W/8-1:0] pipe_in_mask_i,

    output logic                    pipe_out_valid_o,
    input  logic                    pipe_out_ready_i,
    output CTRL_T                   pipe_out_ctrl_o,
    output logic  [BF16_OP_W  -1:0] pipe_out_res_alu_o,
    output logic  [BF16_OP_W/8-1:0] pipe_out_res_cmp_o,
    output logic  [BF16_OP_W/8-1:0] pipe_out_mask_o
);

  import vproc_pkg::*;

  assign pipe_out_valid_o = 1;
  assign pipe_in_ready_o = 1;

endmodule
