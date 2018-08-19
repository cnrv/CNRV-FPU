
`include "R5FP_inc.vh"

module R5FP_mac_wrap #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b, c,
	input  [2:0] rnd,
	output reg [7:0] zStatus,
	output [EXP_W+SIG_W:0] z);

wire [EXP_W+SIG_W+1:0] ax, bx, cx, zx;
wire [EXP_W:0] zExp;
wire [5-1:0] zStatusMiddle;
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

wire zToInf;
R5FP_mac #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W+1)) mac (
	.a(ax), .b(bx), .c(cx),
	.rnd(rnd),
	.zToInf(zToInf),
	.zExp(zExp), .zStatus(zStatusMiddle),
	.zSig(zSig), .zSign(zSign));

wire [7:0] zStatusPre;
R5FP_postproc #(
	.I_SIG_W(SIG_W*2+5),
	.SIG_W(SIG_W),
	.EXP_W(EXP_W+1)) pp (
	.aExp(zExp),
	.aStatus(zStatusMiddle),
	.aSig(zSig),
	.aSign(zSign),
	.rnd(rnd),
	.z(zx),
	.zStatus(zStatusPre));

always @(*) begin
	zStatus=zStatusPre;
	if(zToInf) begin
		zStatus[`Z_INEXACT]=1;
		zStatus[`Z_HUGE]=1;
	end
end

R5FP_exp_decr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) z_d (.a(zx), .z(z));

endmodule

///////////////////////////////////////////////////////////////////
module tb_fp_mac(input clk, 
/* verilator lint_off UNUSED */
	input reset, 
/* verilator lint_on UNUSED */
	input [2:0] rnd);

parameter EXP_W=8;
parameter SIG_W=23;
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
	//$display("Now a: %b.%b.%b  b: %b.%b.%b", aSign,aExp,aSig,  bSign,bExp,bSig);
	reg pass, z0IsNaN;
	pass={z0Sign,z0Exp,z0Sig}=={ySign,yExp,ySig}||{z0Exp,z0Sig,yExp,ySig}==0;

	//special case for NaN
	if((&z0Exp)==1&&(&yExp)==1&&z0Sig!=0&&ySig!=0) pass=1;

	z0IsNaN=(&z0Exp==1 && z0Sig!=0);
	s0=s0pre;
	s0[3]=0; //useless bit
	if(z0Exp!=0) s0[1]=1'b0; // fix an underflow bug of testfloat?
	if(s0!=yS && !z0IsNaN) pass=0;

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
			I.mac.dSign,I.mac.dExp,I.mac.dSig,I.mac.dStatus,I.mac.toInf,
			I.mac.d_m_all_zero, I.mac.d_e_all_zero, I.mac.d_e_all_one);
		$display("isNaN:%d isINF:%d useA:%b useB:%b isZero0:%b signalNaN:%b",
			I.mac.add.isNaN, I.mac.add.isINF, I.mac.add.useA, I.mac.add.useB, 
			I.mac.add.isZero0, I.mac.add.signalNaN);
		$display("ax: %b.%b.%b bx: %b.%b.%b cx: %b.%b.%b", 
			I.ax[EXP_W+SIG_W+1],I.ax[EXP_W+SIG_W:SIG_W],I.ax[SIG_W-1:0], 
			I.bx[EXP_W+SIG_W+1],I.bx[EXP_W+SIG_W:SIG_W],I.bx[SIG_W-1:0], 
			I.cx[EXP_W+SIG_W+1],I.cx[EXP_W+SIG_W:SIG_W],I.cx[SIG_W-1:0]);
		$display("zx: %b.%b.%b", 
			I.zx[EXP_W+SIG_W+1],I.zx[EXP_W+SIG_W:SIG_W],I.zx[SIG_W-1:0]);
		$display("s0: %b  yS:%b", s0, yS);
		$finish();
	end
end
/* verilator lint_on BLKSEQ */

endmodule

