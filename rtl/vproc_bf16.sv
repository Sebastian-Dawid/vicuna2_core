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
    input  logic  [BF16_OP_W  -1:0] pipe_in_op3_i,
    input  logic  [BF16_OP_W/8-1:0] pipe_in_mask_i,

    output logic                    pipe_out_valid_o,
    input  logic                    pipe_out_ready_i,
    output CTRL_T                   pipe_out_ctrl_o,
    output logic  [BF16_OP_W  -1:0] pipe_out_res_o,
    output logic  [BF16_OP_W/8-1:0] pipe_out_mask_o
);
    localparam FMA_INSTANCES = BF16_OP_W/16;
    import vproc_pkg::*;

    logic state_ready;
    logic state_valid_q, state_valid_d;
    CTRL_T state_q, state_d;

    logic [BF16_OP_W  -1:0] vs1_d;
    logic [BF16_OP_W  -1:0] vs2_d;
    logic [BF16_OP_W  -1:0] vd_d;
    logic [BF16_OP_W  -1:0] res_q, res_d;
    logic [BF16_OP_W/8-1:0] mask;

    assign state_valid_d = pipe_in_valid_i;
    assign state_d = pipe_in_ctrl_i;

    assign vs1_d = pipe_in_op2_i;
    assign vs2_d = pipe_in_op1_i;
    assign vd_d = pipe_in_op3_i;

    always_ff @(posedge clk_i, negedge async_rst_ni) begin
        if (~async_rst_ni) begin
            state_valid_q <= 1'b0;
        end else if (~sync_rst_ni) begin
            state_valid_q <= 1'b0;
        end else begin
            state_valid_q <= state_ready & state_valid_d;
        end
    end

    always_ff @(posedge clk_i) begin
        state_q <= state_d;
        res_q <= res_d;
    end
    assign state_ready = ~state_valid_q | pipe_out_ready_i;

    assign pipe_in_ready_o = state_ready;
    assign pipe_out_valid_o = state_valid_q;
    assign pipe_out_ctrl_o = state_q;

    assign pipe_out_res_o = res_q;
    assign pipe_out_mask_o = mask;

    logic ivalid, oready, flush;
    // outermost index runs from high operand bits to low
    logic [FMA_INSTANCES-1:0][2:0][31:0] ops;
    logic [FMA_INSTANCES-1:0][31:0] results;

    assign ivalid = 1;
    assign oready = 1;
    assign flush = 0;

    genvar i;
    generate
        for (i=0; i < FMA_INSTANCES; i++) begin
            localparam MASK_BIT_LO = i * 2;
            localparam MASK_BIT_HI = i * 2 + 1;
            localparam RES_BIT_LO = i * 16;
            localparam RES_BIT_HI = i * 16 + 15;

            assign ops[i][0] = { vs1_d[RES_BIT_HI:RES_BIT_LO], 16'b0 };
            assign ops[i][1] = { vs2_d[RES_BIT_HI:RES_BIT_LO], 16'b0 };
            assign ops[i][2] = { vd_d[RES_BIT_HI:RES_BIT_LO], 16'b0 };

            logic iready, ovalid;
            fpnew_fma #() fma (
                  .clk_i           ( clk_i            )
                , .rst_ni          ( async_rst_ni     )
                // input
                , .operands_i      ( ops[i]           )
                , .is_boxed_i      ( 3'b111           )
                , .rnd_mode_i      ( fpnew_pkg::RNE   )
                , .op_i            ( fpnew_pkg::FMADD )
                , .op_mod_i        ( 1'b0             )
                , .tag_i           ( 1'b0             )
                , .mask_i          ( 1'b0             )
                , .aux_i           ( 1'b0             )
                // handshake input
                , .in_valid_i      ( ivalid           )
                , .in_ready_o      ( iready           )
                , .flush_i         ( flush            )
                // output
                , .result_o        ( results[i]       )
                , .status_o        (                  )
                , .extension_bit_o (                  )
                , .tag_o           (                  )
                , .mask_o          (                  )
                , .aux_o           (                  )
                // handshake output
                , .out_valid_o     ( ovalid           )
                , .out_ready_i     ( oready           )
                // misc
                , .busy_o          (                  )
                , .reg_ena_i       (                  )
            );

            assign res_d[RES_BIT_HI:RES_BIT_LO] = results[i][31:16];
            assign mask[MASK_BIT_HI:MASK_BIT_LO] = 'b11;
        end
    endgenerate
endmodule
