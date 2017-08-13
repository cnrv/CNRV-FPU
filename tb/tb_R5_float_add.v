
`include "R5FP_inc.vh"

module R5FP_add_wrap #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
    input  [2:0] rnd,
    output reg [7:0] status,
	output [EXP_W+SIG_W:0] z);

wire [EXP_W+SIG_W+1:0] ax, bx, zx;

R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) a_i (.a(a), .z(ax));
R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) b_i (.a(b), .z(bx));

R5FP_add #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W+1)) add (.a(ax), .b(bx), .rnd(rnd), .status(status), .z(zx));

R5FP_exp_decr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) z_d (.a(zx), .z(z));

endmodule

///////////////////////////////////////////////////////////////////
module tb_fp_add;

parameter ClockPeriod=2000;
reg clk,reset;
initial begin
	clk=0;
	forever begin
		#(ClockPeriod/2)
		clk=~clk;
	end
end


parameter EXP_W=5;
parameter SIG_W=6;
parameter [2:0] ROUND=`RM;

logic aSign;
logic bSign;
logic ySign;
logic z0Sign;
logic [SIG_W-1:0] aSig;
logic [SIG_W-1:0] bSig;
logic [SIG_W-1:0] ySig;
logic [SIG_W-1:0] z0Sig;
logic [EXP_W-1:0] aExp;
logic [EXP_W-1:0] bExp;
logic [EXP_W-1:0] yExp;
logic [EXP_W-1:0] z0Exp;
wire [7:0] s0,yS;
wire [EXP_W+SIG_W:0] a={aSign,aExp,aSig};
wire [EXP_W+SIG_W:0] b={bSign,bExp,bSig};

DW_fp_add #(
	.sig_width(SIG_W),
	.exp_width(EXP_W),
	.ieee_compliance(1)) R (.a(a), .b(b), .rnd(ROUND), .z({z0Sign,z0Exp,z0Sig}), .status(s0));

R5FP_add_wrap #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) I (
	.a(a), .b(b), .rnd(ROUND), .z({ySign,yExp,ySig}), .status(yS));

reg stop;
initial begin
	stop=1'b0;
	{aSign,aExp,aSig}=32'b0;
	{bSign,bExp,bSig}=32'b0;
end
always @(negedge clk) begin
	if(stop) begin
		$display("All Done");
		$finish();
	end
	if((&a)==1 && (&b)==1) stop<=1'b1;
	if((&a)==1) begin
		{aExp,aSign,aSig}=0;
		{bExp,bSign,bSig}={bExp,bSign,bSig}+1;
		$display("Now b: %b.%b.%b",bExp,bSign,bSig);
	end
	else begin
		{aExp,aSign,aSig}={aExp,aSign,aSig}+1;
	end
	//$display("Now a: %b.%b.%b (b: %b.%b.%b)",aExp,aSign,aSig, bExp,bSign,bSig);
end

always @(posedge clk) begin
	//$display("Now a: %b.%b.%b  b: %b.%b.%b", aSign,aExp,aSig,  bSign,bExp,bSig);
	reg pass;
	pass={z0Sign,z0Exp,z0Sig}=={ySign,yExp,ySig}||{z0Exp,z0Sig,yExp,ySig}==0;
	if((&z0Exp)==1&&(&yExp)==1&&z0Sig!=0&&ySig!=0) pass=1;
	if(s0!=yS) pass=0;
	if(pass) begin
		//$display("Pass");
		//$display("Pass a: %b.%b.%b  b: %b.%b.%b  z0:%b.%b.%b y:%b.%b.%b", aSign,aExp,aSig,  bSign,bExp,bSig,  z0Sign,z0Exp,z0Sig, ySign,yExp,ySig);
		//$display("Pass ax: %b.%b.%b bx: %b.%b.%b zx: %b.%b.%b", I.ax[EXP_W+SIG_W+1],I.ax[EXP_W+SIG_W:SIG_W],I.ax[SIG_W-1:0], I.bx[EXP_W+SIG_W+1],I.bx[EXP_W+SIG_W:SIG_W],I.bx[SIG_W-1:0], I.zx[EXP_W+SIG_W+1],I.zx[EXP_W+SIG_W:SIG_W],I.zx[SIG_W-1:0]);
		//$display("Pass s0: %b  yS:%b", s0, yS);
	end
	else begin
		$display("a: %b.%b.%b  b: %b.%b.%b  z0:%b.%b.%b y:%b.%b.%b", aSign,aExp,aSig,  bSign,bExp,bSig,  z0Sign,z0Exp,z0Sig, ySign,yExp,ySig);
		$display("ax: %b.%b.%b bx: %b.%b.%b zx: %b.%b.%b", I.ax[EXP_W+SIG_W+1],I.ax[EXP_W+SIG_W:SIG_W],I.ax[SIG_W-1:0], I.bx[EXP_W+SIG_W+1],I.bx[EXP_W+SIG_W:SIG_W],I.bx[SIG_W-1:0], I.zx[EXP_W+SIG_W+1],I.zx[EXP_W+SIG_W:SIG_W],I.zx[SIG_W-1:0]);
		$display("s0: %b  yS:%b", s0, yS);
		$finish();
	end
end

endmodule

