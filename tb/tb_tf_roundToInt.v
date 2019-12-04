`include "R5FP_inc.vh"

module R5FP_roundToInt_wrap #(
	parameter SIG_W = 23,
	parameter EXP_W = 8) (
		input  [SIG_W + EXP_W:0] a_i,
		input  [2:0] rnd_i,
		output reg [SIG_W + EXP_W:0] z_o,
		output reg [7:0] status_o);

localparam I_SIG_W=SIG_W*2+5;

wire [EXP_W+SIG_W+1:0] ax;

wire [EXP_W:0] zExp,tailZeroCnt;
wire [6-1:0] zStatusMiddle = 6'b0;
wire [I_SIG_W-1:0] zSig;
wire [SIG_W-1:0] axSig;
wire zSign;

assign {zSign, zExp, axSig} = ax;
assign zSig = {2'b01, axSig, {(I_SIG_W-SIG_W-2){1'b0}}};

R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) exp_incr (.a(a_i), .z(ax));

assign tailZeroCnt = SIG_W-(zExp-{EXP_W{1'b1}});

wire [SIG_W + EXP_W+1:0] zxTmp, zxFromHelper;
reg [SIG_W + EXP_W+1:0] zx;
R5FP_postproc #(
	.I_SIG_W(I_SIG_W),
	.SIG_W(SIG_W),
	.EXP_W(EXP_W+1)) pp (
	.tailZeroCnt(tailZeroCnt),
	.aExp(zExp),
	.aStatus(zStatusMiddle),
	.aSig(zSig),
	.rnd(rnd_i),
	.aSign(zSign),
	.zToInf(1'b0),
	.specialTiny(1'b0),
/* verilator lint_off PINCONNECTEMPTY */
	.zStatus(),
/* verilator lint_on PINCONNECTEMPTY */
	.z(zxTmp));

wire usePP, useOrig;
R5FP_roundToInt_helper #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) helper (
	.zSign(zSign), .zExp(zExp), .zSig(axSig),
	.rnd_i(rnd_i),
	.usePP(usePP), .useOrig(useOrig), .zx(zxFromHelper));

R5FP_exp_decr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) exp_decr (.a(zx), .z(z_o));

always @(*) begin
	if(usePP) begin
		zx = zxTmp;
	end
	else if(useOrig) begin
		zx = ax;
	end
	else begin
		zx = zxFromHelper;
	end
	status_o = 8'b00000000;
end

endmodule


///////////////////////////////////////////////////////////////////

module tb_roundToInt(input clk, 
/* verilator lint_off UNUSED */
	input reset, 
/* verilator lint_on UNUSED */
	input [2:0] rnd);

`ifdef FP64
parameter EXP_W=11;
parameter SIG_W=52;
`else
parameter EXP_W=8;
parameter SIG_W=23;
`endif
integer fd, readcount;

logic aSign;
logic ySign;
logic z0Sign;
logic [SIG_W-1:0] aSig;
logic [SIG_W-1:0] ySig;
logic [SIG_W-1:0] z0Sig;
logic [EXP_W-1:0] aExp;
logic [EXP_W-1:0] yExp;
logic [EXP_W-1:0] z0Exp;
logic [7:0] ySpre;
logic [4:0] s0pre,s0,yS;
assign yS=to_tf_flags(ySpre);
logic [EXP_W+SIG_W:0] a,z0;
assign {aSign,aExp,aSig}=a;
assign {z0Sign,z0Exp,z0Sig}=z0;

R5FP_roundToInt_wrap #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) I (
	.a_i(a),
	.rnd_i(rnd),
	.z_o({ySign,yExp,ySig}),
	.status_o(ySpre));


initial begin
	fd=$fopen("/dev/stdin","r");
	$display("fd is %d", fd);
	readcount = $fscanf(fd, "DUMP: %x %x %x", a, z0, s0pre);
	//$display("New data:  %h %h %b", a, z0, s0pre);
	if(readcount != 3) $display("Read Error! %d", readcount);
end
/* verilator lint_off BLKSEQ */
always @(negedge clk) begin
	if($feof(fd)) $finish();
	readcount = $fscanf(fd, "DUMP: %x %x %x", a, z0, s0pre);
	//$display("New data:  %h %h %b", a, z0, s0pre);
	if(readcount != 3) begin
		$display("Read Error! %d", readcount);
		$finish();
	end
end

always @(posedge clk) begin
	//$display("Now a: %b.%b.%b ", aSign,aExp,aSig);
	reg pass;
	pass={z0Sign,z0Exp,z0Sig}=={ySign,yExp,ySig}||{z0Exp,z0Sig,yExp,ySig}==0;

	//special case for NaN
	if((&z0Exp)==1&&(&yExp)==1&&z0Sig!=0&&ySig!=0) pass=1;

	s0=s0pre;
	s0[3]=0; // useless bit
	s0[0]=0; // clear INEXACT, do not compare

	if(s0!=yS) pass=0;
	if(pass) begin
		//$display("Pass");
		//$display("a:  %b.%b.%b  z0: %b.%b.%b", aSign,aExp,aSig, z0Sign,z0Exp,z0Sig);
		//$display("a:  %b.%b.%b  y:  %b.%b.%b", aSign,aExp,aSig, ySign,yExp,ySig);
		//$display("----");
	end
	else begin
		$display("Fail!!");
		$display("a: %08h ",a);
		$display("a:  %b.%b.%b   z0: %b.%b.%b", aSign,aExp,aSig,   z0Sign,z0Exp,z0Sig);
		$display("a:  %b.%b.%b   y:  %b.%b.%b", aSign,aExp,aSig,   ySign,yExp,ySig);
		$display("ax: %b.%b.%b  zx: %b.%b.%b tailZC: %d %d %d", I.ax[EXP_W+SIG_W+1],I.ax[EXP_W+SIG_W:SIG_W],I.ax[SIG_W-1:0], I.zx[EXP_W+SIG_W+1],I.zx[EXP_W+SIG_W:SIG_W],I.zx[SIG_W-1:0], I.tailZeroCnt, I.I_SIG_W, I.zExp);
		$display("statusRef: %b  statusImp: %b", s0, yS);
		$finish();
	end
end
/* verilator lint_on BLKSEQ */

endmodule

