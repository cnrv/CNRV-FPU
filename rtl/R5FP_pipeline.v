module R5FP_mul_blk #(
	parameter EXP_W=11,
	parameter SIG_W=53) (
	input [EXP_W+SIG_W:0] a, b,

	output [EXP_W-1:0] zExp,tailZeroCnt,
	output reg [6-1:0] zStatus,
	output [SIG_W*2+2:0] zSig,
	output toInf,
	output zSign);

R5FP_mul_blk #(.EXP_W(EXP_W), .SIG_W(SIG_W)) inst (.*);

endmodule

module R5FP_acc_blk #(
	parameter EXP_W=11,
	parameter SIG_W=53) (
	input [EXP_W-1:0] dExp,
	input [6-1:0] dStatus,
	input [SIG_W*2+2:0] dSig,
	input dSign,
	input toInf,
	input [EXP_W+SIG_W:0] c,
	input [2:0] rnd,

	output zToInf,
	output reg specialTiny,
	output [EXP_W-1:0] zExp,
	output reg [EXP_W-1:0] tailZeroCnt,
	output reg [6-1:0] zStatus,
	output [SIG_W*2+4:0] zSig,
	output zSign);

R5FP_acc_blk #(.EXP_W(EXP_W), .SIG_W(SIG_W)) inst (.*);

endmodule

module R5FP_postproc_blk #(
	parameter I_SIG_W=109,
	parameter SIG_W=52,
	parameter EXP_W=11) (
	input [EXP_W-1:0] aExp,
	input [6-1:0] aStatus,
	input [I_SIG_W-1:0] aSig,
	input aSign, specialTiny, zToInf,
	input  [2:0] rnd,
	input [EXP_W-1:0] tailZeroCnt,
	output [SIG_W+EXP_W:0] z,
	output [7:0] zStatus);

wire sticky, round_bit, guard_bit;
reg sticky_r, round_bit_r, guard_bit_r;
R5FP_postproc_prepare #(
		.I_SIG_W(I_SIG_W),
		.SIG_W(SIG_W),
		.EXP_W(EXP_W)) prepare (
		.tailZeroCnt(tailZeroCnt),
		.aSig(aSig),
		.sticky(sticky), .round_bit(round_bit), .guard_bit(guard_bit));

reg [EXP_W-1:0] aExp_r;
reg [6-1:0] aStatus_r;
reg [I_SIG_W-1:0] aSig_r;
reg  [2:0] rnd_r;
reg aSign_r, specialTiny_r, zToInf_r;
reg [EXP_W-1:0] tailZeroCnt_r;
always @(posedge clk) begin
	aExp_r<=aExp;
	aStatus_r<=aStatus;
	aSig_r<=aSig;
	rnd_r<=rnd;
	aSign_r<=aSign;
	specialTiny_r<=specialTiny;
	zToInf_r<=zToInf;
	tailZeroCnt_r<=tailZeroCnt;
	sticky_r<=sticky;
	round_bit_r<=round_bit;
	guard_bit_r<=guard_bit;
end

R5FP_postproc_core #(
		.I_SIG_W(I_SIG_W),
		.SIG_W(SIG_W),
		.EXP_W(EXP_W)) core (
	.sticky_in(sticky_r), .round_bit(round_bit_r), .guard_bit(guard_bit_r),
	.aExp(aExp_r),
	.aStatus(aStatus_r),
	.aSig(aSig_r),
	.rnd(rnd_r),
	.aSign(aSign_r),
	.specialTiny(specialTiny_r), 
	.zToInf(zToInf_r),
	.tailZeroCnt(tailZeroCnt_r),
	.z(z),
	.zStatus(zStatus));
	
endmodule

