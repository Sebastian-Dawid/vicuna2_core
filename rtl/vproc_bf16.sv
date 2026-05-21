// Copyright Bielefeld University
// Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

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
    output logic  [BF16_OP_W  -1:0] pipe_out_res_o,
    output logic  [BF16_OP_W/8-1:0] pipe_out_mask_o
);

    import vproc_pkg::*;

    logic state_ready;
    logic state_valid_q, state_valid_d;
    CTRL_T state_q, state_d;

    logic [BF16_OP_W  -1:0] op1_q, op1_d;
    logic [BF16_OP_W  -1:0] op2_q, op2_d;
    logic [BF16_OP_W  -1:0] res_q, res_d;
    logic [BF16_OP_W/8-1:0] mask = {default: '0};

    assign state_valid_d = pipe_in_valid_i;
    assign state_d = pipe_in_ctrl_i;
    assign op1_d = pipe_in_op1_i;
    assign op2_d = pipe_in_op2_i;

    always @(posedge clk_i or negedge async_rst_ni) begin
        if (~async_rst_ni) begin
            state_valid_q <= 1'b0;
        end else if (~sync_rst_ni) begin
            state_valid_q <= 1'b0;
        end else if (state_ready) begin
            state_valid_q <= state_valid_d;
        end
        state_q <= state_d;
        op1_q <= op1_d;
        op2_q <= op2_d;
        res_q <= res_d;
    end
    assign state_ready = ~state_valid_q | pipe_out_ready_i;

    assign pipe_in_ready_o = state_ready;
    assign pipe_out_valid_o = state_valid_q;
    assign pipe_out_ctrl_o = state_q;

    assign pipe_out_res_o = res_q;
    assign pipe_out_mask_o = mask;

    // TODO: Actual unit logic
    // Switch over instructions
    // Differentiate between FP32 and BF16 inputs/outputs

    always_comb begin
        res_d[BF16_OP_W-1:BF16_OP_W/2] = op2_d[BF16_OP_W-1:BF16_OP_W/2];
        res_d[BF16_OP_W/2-1:0] = {default: '0};
        mask = 'b1100;
    end
endmodule
