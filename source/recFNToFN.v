
/*============================================================================

This Verilog source file is part of the Berkeley HardFloat IEEE Floating-Point
Arithmetic Package, Release 1, by John R. Hauser.

Copyright 2019 The Regents of the University of California.  All rights
reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions, and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the University nor the names of its contributors may
    be used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=============================================================================*/

/*----------------------------------------------------------------------------
*----------------------------------------------------------------------------*/

module
    recFNToFN#(parameter expWidth = 3, parameter sigWidth = 3) (
        input [(expWidth + sigWidth):0] in,
        output [(expWidth + sigWidth - 1):0] out
    );
`include "HardFloat_localFuncs.vi"

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    localparam [expWidth:0] minNormExp = (1<<(expWidth - 1)) + 2;
    localparam normDistWidth = clog2(sigWidth);
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    wire isNaN, isInf, isZero, sign;
    wire signed [(expWidth + 1):0] sExp;
    wire [sigWidth:0] sig;
    recFNToRawFN#(expWidth, sigWidth)
        recFNToRawFN(in, isNaN, isInf, isZero, sign, sExp, sig);
    wire isSubnormal = (sExp < minNormExp);
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    wire [(normDistWidth - 1):0] denormShiftDist = minNormExp - 1 - sExp;
    wire [(expWidth - 1):0] expOut =
        (isSubnormal ? 0 : sExp - minNormExp + 1)
            | (isNaN || isInf ? {expWidth{1'b1}} : 0);
    wire [(sigWidth - 2):0] fractOut =
        isSubnormal ? (sig>>1)>>denormShiftDist : isInf ? 0 : sig;
    assign out = {sign, expOut, fractOut};

endmodule

// ????????????????????????opa[7]?????????????????????
extbit = opa[7] & signed_mul;
for(i = 0; i < 4; i++)
begin
    benc_sign[i] = bsel[i][M1] | bsel[i][M2];
    E[i] = (extbit == benc_sign[i]);
    header[i][0] = 
      ({(1){bsel[i][P1]}} & extbit)
    | ({(1){bsel[i][P2]}} & opa[7])
    | ({(1){bsel[i][M1]}} & ~extbit)
    | ({(1){bsel[i][M2]}} & ~opa[7]);
    if(i == 0)
        header[i][3:1] = {E[i], ~E[i], ~E[i]};
    else if(i == 3)
        header[i][3:1] = {00, E[i]};
    else
        header[i][3:1] = {01, E[i]};
end

// 1. ??????????????????
// 2. ????????????????????????opb[7] = 0
// ?????????????????????pp[4] = 8'b0, ??????pp[4] = opa??????????????????????????????????????????????????????
pp[4][7:0] = (signed_mul | (opb[7] == 1'b0)) ? 8'b0 : opa[7:0];
for(i = 0; i < 4; i++)
begin
    pp[i][7:0] = 
      ({(8){bsel[i][P1]}} & opa[7:0])
    | ({(8){bsel[i][P2]}} & {opa[6:0], 0})
    | ({(8){bsel[i][M1]}} & ~opa[7:0])
    | ({(8){bsel[i][M2]}} & {~opa[6:0], 1});
end

addend[0] = {0000, {header[0][3:0], pp[0][7:0]}};
addend[1] = {00, {header[1][3:0], pp[1][7:0]}, 0, benc_sign[0]};
addend[2] = {{header[2][3:0], pp[2][7:0]}, 0, benc_sign[1], 00};
addend[3] = {{header[3][1:0], pp[3][7:0]}, 0, benc_sign[2], 0000};
addend[4] = {pp[4][7:0], 0, benc_sign[3], 00_0000}


for(i = 0; i < 8; i++)
begin
    if((i / 4) == 0)
    begin
        // ??????8-bit??????booth?????????, ?????????8-bit???????????????
        pp_mask[i][15:0] = 16'b0000_0000_1111_1111;
        // ???8-bit???pp???lsb?????????
        lsb_mask[i][15:0] = 16'b0000_0000_0000_0001;
    end
    else if((i / 4) == 1)
    begin
        // ??????8-bit??????booth?????????, ?????????8-bit???????????????
        pp_mask[i][15:0] = 16'b1111_1111_0000_0000;
        // ???8-bit???pp???lsb?????????
        lsb_mask[i][15:0] = 16'b0000_0001_0000_0000;
    end

    pp[i] = 
      (({(16){bsel[i][P1]}} & pp_mask[i]) & opa[15:0])
    // i = 0, 1, 2, 3???, ?????????
    // i = 4, 5, 6, 7???, ??????P2 = 1?????????, ?????????????????????{opa[14:8], 1'b0}, ??????lsb_mask[i][15:1] = 000_0000_1000_0000 -> ~lsb_mask[i][15:1] = 111_1111_0111_1111
    // ?????????: opa[14:0] & ~lsb_mask[i][15:1] = {opa[14:8], 0, opa[6:0]}, ?????????8-bit, ???????????????????????????{opa[14:8], 1'b0}
    | (({(16){bsel[i][P2]}} & pp_mask[i]) & {opa[14:0] & ~lsb_mask[i][15:1], 1'b0})
    | (({(16){bsel[i][M1]}} & pp_mask[i]) & ~opa[15:0])
    // i = 0, 1, 2, 3???, ?????????
    // i = 4, 5, 6, 7???, ??????P2 = 1?????????, ?????????????????????{~opa[14:8], 1'b1}, ??????lsb_mask[i][15:1] = 000_0000_1000_0000 
    // ?????????: ~opa[14:0] | lsb_mask[i][15:1] = {~opa[14:8], 1, ~opa[6:0]}, ?????????8-bit, ???????????????????????????{~opa[14:8], 1'b1}
    | (({(16){bsel[i][M2]}} & pp_mask[i]) & {~opa[14:0] | lsb_mask[i][15:1], 1'b1});
end
pp[8][15:0] = 16'b0000_0000_0000_0000;

for(i = 0; i < 9; i++)
begin
    if(i == 4)
        // ??????8-bit??????????????????????????????????????????????????????opa[7] = 1, ???????????????"+1"?????????????????????pp, ???????????????????????????????????????????????????pp[4]???????????????8-bit??????????????????
        unsigned_mask[i][15:0] = (opa[2 * i - 1] & ~signed_mul_lo) ? 16'b0000_0000_1111_1111 : 16'b0000_0000_0000_0000;
    else if(i == 8)
        // ??????8-bit??????????????????????????????????????????????????????opa[15] = 1, ???????????????"+1"?????????????????????pp, ???????????????????????????????????????????????????pp[8]??????????????????8-bit??????????????????
        unsigned_mask[i][15:0] = (opa[2 * i - 1] & ~signed_mul_hi) ? 16'b1111_1111_0000_0000 : 16'b0000_0000_0000_0000;
    else
        unsigned_mask[i][15:0] = 16'b0000_0000_0000_0000;

    if(i == 0)
    begin
        carry_in[i] = '0;
        carry_in_mask[i][15:0] = 16'b0000_0000_0000_0000;
    end
    else
    begin
        carry_in[i] = benc_sign[i-1];
        // ????????????pp????????????????????????pp??????????????????:
        // ?????????8-bit???pp??????(i = 1, 2, 3, 4), carry_in_mask[i]????????????pp???????????????????????????pp???[0]
        // ?????????8-bit???pp??????(i = 5, 6, 7, 8), carry_in_mask[i]????????????pp???????????????????????????pp???[8]
        // ??????????????????addend[i]?????????????????????????????????
        carry_in_mask[i][15:0] = lsb_mask[i-1][15:0];
    end

    addend_pre[i][21:0] = 
      {header[i][3:0], pp[i][15:0], 00}
    | {0000, unsigned_mask[i][15:0] & opa[15:0], 00}
    | ({(22){carry_in[i]}} & {00_0000, carry_in_mask[i][15:0]});
end

logic extbit_lo = signed_mul_lo & opa[7];
for(i = 0; i < 4; i++)
begin
    benc_sign[i] = bsel[i][M1] | bsel[i][M2];
    E[i] = (extbit_lo == benc_sign[i]);
    header[i][0] = 
      ({(1){bsel[i][P1]}} & extbit_lo)
    | ({(1){bsel[i][P2]}} & opa[7])
    | ({(1){bsel[i][M1]}} & ~extbit_lo)
    | ({(1){bsel[i][M2]}} & ~opa[7]);
    if((i % 4) == 0)
        header[i][3:1] = {E[i], ~E[i], ~E[i]};
    else if((i % 4) == 3)
        header[i][3:1] = {00, E[i]};
    else
        header[i][3:1] = {01, E[i]};
end
logic extbit_hi = signed_mul_hi & opa[15];
for(i = 4; i < 8; i++)
begin
    benc_sign[i] = bsel[i][M1] | bsel[i][M2];
    E[i] = (extbit_hi == benc_sign[i]);
    header[i][0] = 
      ({(1){bsel[i][P1]}} & extbit_hi)
    | ({(1){bsel[i][P2]}} & opa[15])
    | ({(1){bsel[i][M1]}} & ~extbit_hi)
    | ({(1){bsel[i][M2]}} & ~opa[15]);
    if((i % 4) == 0)
        header[i][3:1] = {E[i], ~E[i], ~E[i]};
    else if((i % 4) == 3)
        header[i][3:1] = {00, E[i]};
    else
        header[i][3:1] = {01, E[i]};
end
header[8][3:0] = 4'b0000;


addend[0][31:0] = {12'b0, addend_pre[0][21:2],      };
addend[1][31:0] = {10'b0, addend_pre[1][21:0],      };
addend[2][31:0] = { 8'b0, addend_pre[2][21:0],  2'b0};
addend[3][31:0] = { 6'b0, addend_pre[3][21:0],  4'b0};
addend[4][31:0] = { 4'b0, addend_pre[4][21:0],  6'b0};
addend[5][31:0] = { 2'b0, addend_pre[5][21:0],  8'b0};
addend[6][31:0] = {       addend_pre[6][21:0], 10'b0};
addend[7][31:0] = {       addend_pre[7][19:0], 12'b0};
addend[8][31:0] = {       addend_pre[8][17:0], 14'b0};

function automatic logic [31:0] csa_sum (
	input logic [31:0] pp0,
	input logic [31:0] pp1,
	input logic [31:0] pp2
);
csa_sum = pp0 ^ pp1 ^ pp2;
endfunction

function automatic logic [31:0] csa_carry (
	input logic [31:0] pp0,
	input logic [31:0] pp1,
	input logic [31:0] pp2
);
csa_carry = {(pp0[30:0] & pp1[30:0]) | (pp1[30:0] & pp2[30:0]) | (pp2[30:0] & pp0[30:0]), 1'b0};
endfunction

addend_stage1[0][31:0] = csa_sum(addend[0], addend[1], addend[2]);
addend_stage1[1][31:0] = csa_carry(addend[0], addend[1], addend[2]) & carry_mask_ctl;
addend_stage1[2][31:0] = csa_sum(addend[3], addend[4], addend[5]);
addend_stage1[3][31:0] = csa_carry(addend[3], addend[4], addend[5]) & carry_mask_ctl;
addend_stage1[4][31:0] = csa_sum(addend[6], addend[7], addend[8]);
addend_stage1[5][31:0] = csa_carry(addend[6], addend[7], addend[8]) & carry_mask_ctl;

addend_stage2[0][31:0] = csa_sum(addend_stage1[0], addend_stage1[1], addend_stage1[2]);
addend_stage2[1][31:0] = csa_carry(addend_stage1[0], addend_stage1[1], addend_stage1[2]) & carry_mask_ctl;
addend_stage2[2][31:0] = csa_sum(addend_stage1[3], addend_stage1[4], addend_stage1[5]);
addend_stage2[3][31:0] = csa_carry(addend_stage1[3], addend_stage1[4], addend_stage1[5]) & carry_mask_ctl;

addend_stage3[0][31:0] = csa_sum(addend_stage2[0], addend_stage2[1], addend_stage2[2]);
addend_stage3[1][31:0] = csa_carry(addend_stage2[0], addend_stage2[1], addend_stage2[2]) & carry_mask_ctl;
addend_stage3[2][31:0] = addend_stage2[3][31:0];

addend_stage4[0][31:0] = csa_sum(addend_stage3[0], addend_stage3[1], addend_stage3[2]);
addend_stage3[1][31:0] = csa_carry(addend_stage3[0], addend_stage3[1], addend_stage3[2]) & carry_mask_ctl;

mul_pre[32:0] = {addend_stage4[0][31:16], carry_mask_ctl[16], addend_stage4[0][15:0]} + {addend_stage4[1][31:16], 1'b0, addend_stage4[1][15:0]};
mul[31:0] = {mul_pre[32:17], mul_pre[15:0]};