
`include "R5FP_inc.vh"

module R5FP_mac_wrap #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b, c,
	input  [2:0] rnd,
	output reg [7:0] zStatus,
	output [EXP_W+SIG_W:0] z);

localparam I_SIG_W=SIG_W*2+5;
localparam EXP_W_P1=EXP_W+1;

wire [EXP_W+SIG_W+1:0] ax, bx, cx, zx;
wire [EXP_W:0] zExp;
wire [6-1:0] zStatusMiddle;
wire [SIG_W*2+4:0] zSig;
wire zSign;

R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) a_i (.a(a), .z(ax));
R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) b_i (.a(b), .z(bx));
R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) c_i (.a(c), .z(cx));

wire [EXP_W_P1-1:0] dExp;
wire [6-1:0] dStatus;
wire [SIG_W*2+2:0] dSig;
wire dSign;
wire toInf;
R5FP_mul #(
	.EXP_W(EXP_W_P1),
	.SIG_W(SIG_W)) mul (
	.a(ax), .b(bx),
	.zExp(dExp),
	.toInf(toInf),
	.zStatus(dStatus),
	.zSig(dSig),
	.zSign(dSign));

wire zToInf,specialTiny;
R5FP_acc #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W_P1)) acc (
	.dExp(dExp),
	.dStatus(dStatus),
	.dSig(dSig),
	.dSign(dSign),
	.toInf(toInf),
	.c(cx),
	.rnd(rnd),

	.zToInf(zToInf),
	.specialTiny(specialTiny),
	.zExp(zExp), .zStatus(zStatusMiddle),
	.zSig(zSig), .zSign(zSign));

wire [7:0] zStatusPre;
wire specialZRnd;
R5FP_postproc #(
	.I_SIG_W(I_SIG_W),
	.SIG_W(SIG_W),
	.EXP_W(EXP_W_P1)) pp (
	.aExp(zExp),
	.aStatus(zStatusMiddle),
	.aSig(zSig),
	.aSign(zSign),
	.rnd(rnd),
	.z(zx),
	.specialZRnd(specialZRnd),
	.zStatus(zStatusPre));

R5FP_exp_decr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) z_d (.a(zx), .z(z));

always @(*) begin
	//reg specialZ;
	zStatus=zStatusPre;
	if(zToInf) begin
		zStatus[`Z_INEXACT]=1;
		zStatus[`Z_HUGE]=1;
	end
	if(specialTiny&&specialZRnd) zStatus[`Z_TINY]=1; // I don't know why...
end

endmodule

///////////////////////////////////////////////////////////////////
module tb_fp_mac(input clk, 
/* verilator lint_off UNUSED */
	input reset, 
/* verilator lint_on UNUSED */
	input [2:0] rnd);

parameter EXP_W=8;
parameter SIG_W=23;
localparam I_SIG_W=SIG_W*2+5;
integer fd, readcount;

logic aSign;
logic bSign;
logic cSign;
logic ySign;
logic z0Sign;
logic [SIG_W-1:0] aSig;
logic [SIG_W-1:0] bSig;
logic [SIG_W-1:0] cSig;
logic [SIG_W-1:0] ySig;
logic [SIG_W-1:0] z0Sig;
logic [EXP_W-1:0] aExp;
logic [EXP_W-1:0] bExp;
logic [EXP_W-1:0] cExp;
logic [EXP_W-1:0] yExp;
logic [EXP_W-1:0] z0Exp;
logic [7:0] ySpre;
logic [4:0] s0pre,s0,yS;
assign yS=to_tf_flags(ySpre);
logic [EXP_W+SIG_W:0] a,b,c,z0;
assign {aSign,aExp,aSig}=a;
assign {bSign,bExp,bSig}=b;
assign {cSign,cExp,cSig}=c;
assign {z0Sign,z0Exp,z0Sig}=z0;

R5FP_mac_wrap #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) I (
	.a(a), .b(b), .c(c), .rnd(rnd), .z({ySign,yExp,ySig}), .zStatus(ySpre));

initial begin
	fd=$fopen("/dev/stdin","r");
	$display("fd is %d", fd);
	readcount = $fscanf(fd, "DUMP: %x %x %x %x %x", a, b, c, z0, s0pre);
	$display("New data:  %h %h %h %h %b", a, b, c, z0, s0pre);
	if(readcount != 5) $display("Read Error! %d", readcount);
end
/* verilator lint_off BLKSEQ */
always @(negedge clk) begin
	if($feof(fd)) $finish();
	readcount = $fscanf(fd, "DUMP: %x %x %x %x %x", a, b, c, z0, s0pre);
	//$display("New data:  %h %h %h %h %b", a, b, c, z0, s0pre);
	if(readcount != 5) begin
		$display("Read Error! %d", readcount);
		$finish();
	end
end

always @(posedge clk) begin
	reg pass;
	reg [2:0] grt;
	grt={I.pp.core.guard_bit, I.pp.core.round_bit, I.pp.core.sticky};
	pass={z0Sign,z0Exp,z0Sig}=={ySign,yExp,ySig}||{z0Exp,z0Sig,yExp,ySig}==0;

	//special case for NaN
	if((&z0Exp)==1&&(&yExp)==1&&z0Sig!=0&&ySig!=0) pass=1;

	s0=s0pre;
	s0[3]=0; //useless bit

	if(s0!=yS) pass=0;

	if(pass) begin
		//$display("Pass");
	end
	else begin
		$display("Fail!!");
		$display("a b c: %08h %08h %08h",a,b,c);
		$display("a:  %b.%b.%b  b:  %b.%b.%b  c:  %b.%b.%b", aSign,aExp,aSig,  bSign,bExp,bSig, cSign,cExp,cSig);
		$display("z0: %b.%b.%b", z0Sign,z0Exp,z0Sig);
		$display("y:  %b.%b.%b", ySign,yExp,ySig);
		$display("d:  %b.%b.%b %b toInf:%b m0:%b e0:%b e1:%b",
			I.acc.dSign,I.acc.dExp,I.acc.dSig,I.acc.dStatus,I.acc.toInf,
			I.acc.d_m_all_zero, I.acc.d_e_all_zero, I.acc.d_e_all_one);
		$display("add isNaN:%d isINF:%d useA:%b useB:%b isZero0:%b signalNaN:%b",
			I.acc.add.isNaN, I.acc.add.isINF, I.acc.add.useA, I.acc.add.useB, 
			I.acc.add.isZero0, I.acc.add.signalNaN);
		$display("mul isZero:%d isNaN:%d isINF:%d toInfPre:%b toInf:%b",
			I.mul.isZero, I.mul.isNaN, I.mul.isINF, 
			I.mul.toInfPre, I.mul.toInf);
		$display("ax: %b.%b.%b bx: %b.%b.%b cx: %b.%b.%b", 
			I.ax[EXP_W+SIG_W+1],I.ax[EXP_W+SIG_W:SIG_W],I.ax[SIG_W-1:0], 
			I.bx[EXP_W+SIG_W+1],I.bx[EXP_W+SIG_W:SIG_W],I.bx[SIG_W-1:0], 
			I.cx[EXP_W+SIG_W+1],I.cx[EXP_W+SIG_W:SIG_W],I.cx[SIG_W-1:0]);
		$display("zx: %b.%b.%b grt:%b pp.aSig:%b", 
			I.zx[EXP_W+SIG_W+1],I.zx[EXP_W+SIG_W:SIG_W],I.zx[SIG_W-1:0],grt,
			I.pp.core.aSig);
		$display("I.zSig: %b-%b", I.zSig[SIG_W*2+2:SIG_W],I.zSig[SIG_W-1:0]);
		$display("s0: %b  yS:%b", s0, yS);
		//$finish();
	end
end
/* verilator lint_on BLKSEQ */

endmodule

