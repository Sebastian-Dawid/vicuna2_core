// Copyright Bielefeld University
// Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module vproc_bf16 #(
    parameter int unsigned BF16_OP_W = 32,    // ALU operand width in bits
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
    input  logic  [BF16_OP_W  -1:0] pipe_in_op3_i,
    input  logic  [BF16_OP_W/8-1:0] pipe_in_mask_i,

    output logic                    pipe_out_valid_o,
    input  logic                    pipe_out_ready_i,
    output CTRL_T                   pipe_out_ctrl_o,
    output logic  [BF16_OP_W  -1:0] pipe_out_res_o,
    output logic  [BF16_OP_W/8-1:0] pipe_out_mask_o
);

    import vproc_pkg::*;

    logic state_ready;
    logic state_valid0_q, state_valid0_d;
    logic state_valid1_q, state_valid1_d;
    logic state_valid2_q, state_valid2_d;

    CTRL_T state0_q, state0_d;
    CTRL_T state1_q, state1_d;
    CTRL_T state2_q, state2_d;

    logic [BF16_OP_W  -1:0] op1_q, op1_d;
    logic [BF16_OP_W  -1:0] op2_q, op2_d;
    logic [BF16_OP_W  -1:0] op3_q, op3_d;
    logic [BF16_OP_W  -1:0] res_q, res_d;
    logic [BF16_OP_W/8-1:0] mask = {default: '0};

    localparam COUNT = BF16_OP_W/16;
    logic [31:0] intermediate0_q [COUNT-1:0], intermediate0_d [COUNT-1:0];
    logic [16:0] intermediate1_q [COUNT-1:0], intermediate1_d [COUNT-1:0];

    assign state_valid0_d = pipe_in_valid_i;
    assign state_valid1_d = state_valid0_q;
    assign state_valid2_d = state_valid1_q;

    assign state0_d = pipe_in_ctrl_i;
    assign state1_d = state0_q;
    assign state2_d = state1_q;

    assign op1_d = pipe_in_op1_i;
    assign op2_d = pipe_in_op2_i;
    assign op3_d = pipe_in_op3_i;

    always_ff @(posedge clk_i or negedge async_rst_ni) begin
        if (~async_rst_ni) begin
            state_valid2_q <= 1'b0;
        end else if (~sync_rst_ni) begin
            state_valid2_q <= 1'b0;
        end else if (state_ready) begin
            state_valid2_q <= state_valid2_d;
        end

        state_valid0_q <= state_valid0_d;
        state_valid1_q <= state_valid1_d;

        state0_q <= state0_d;
        state1_q <= state1_d;
        state2_q <= state2_d;

        op1_q <= op1_d;
        op2_q <= op2_d;
        op3_q <= op3_d;
        intermediate0_q <= intermediate0_d;
        intermediate1_q <= intermediate1_d;
        res_q <= res_d;
    end
    assign state_ready = ~state_valid2_q | pipe_out_ready_i;

    assign pipe_in_ready_o = state_ready;
    assign pipe_out_valid_o = state_valid2_q;
    assign pipe_out_ctrl_o = state2_q;

    assign pipe_out_res_o = res_q;
    assign pipe_out_mask_o = mask;

    always_comb begin
        intermediate0_d[0] = signed'(op2_d[BF16_OP_W/2-1:0]) * signed'(op1_d[BF16_OP_W/2-1:0]);
        intermediate0_d[1] = signed'(op2_d[BF16_OP_W-1:BF16_OP_W/2]) * signed'(op1_d[BF16_OP_W-1:BF16_OP_W/2]);

        intermediate1_d[0] = signed'(intermediate0_q[0][15:0]) + signed'(op3_q[BF16_OP_W/2-1:0]);
        intermediate1_d[1] = signed'(intermediate0_q[1][15:0]) + signed'(op3_q[BF16_OP_W-1:BF16_OP_W/2]);

        res_d = { intermediate1_q[1][15:0], intermediate1_q[0][15:0] };
        mask = 'b1111;
    end
endmodule
