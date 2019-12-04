`include "R5FP_inc.vh"

module R5FP_intToFloat_wrap #(
	parameter INT_W = 64,
	parameter SIG_W = 23,
	parameter EXP_W = 8) (
		input [INT_W-1:0] a_i,
		input isSigned,
		input [2:0] rnd_i,
		output  [SIG_W + EXP_W:0] z_o);

localparam I_SIG_W=SIG_W*2+5;
wire [EXP_W:0] tailZeroCnt;
wire [EXP_W:0] aExp;
wire [6-1:0] aStatus;
wire [I_SIG_W-1:0] aSig;
wire aSign;
wire [SIG_W+EXP_W+1:0] zx,zxTmp;

R5FP_intToFloat_helper #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W),
	.INT_W(INT_W)) intToFloat (
	.isSigned(isSigned), .a(a_i), 
	.tailZeroCnt(tailZeroCnt),
	.aExp(aExp),
	.aStatus(aStatus),
	.aSig(aSig),
	.aSign(aSign));

R5FP_postproc #(
	.I_SIG_W(I_SIG_W),
	.SIG_W(SIG_W),
	.EXP_W(EXP_W+1)) pp (
	.tailZeroCnt(tailZeroCnt),
	.aExp(aExp),
	.aStatus(aStatus),
	.aSig(aSig),
	.rnd(rnd_i),
	.aSign(aSign),
	.zToInf(1'b0),
	.specialTiny(1'b0),
/* verilator lint_off PINCONNECTEMPTY */
	.zStatus(),
/* verilator lint_on PINCONNECTEMPTY */
	.z(zxTmp));

assign zx = (a_i==0)? 0 : zxTmp;

R5FP_exp_decr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) exp_decr (.a(zx), .z(z_o));

endmodule


///////////////////////////////////////////////////////////////////

module tb_intToFloat(input clk, 
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

logic [63:0] a, a_i;
logic ySign;
logic z0Sign;
logic [SIG_W-1:0] ySig;
logic [SIG_W-1:0] z0Sig;
logic [EXP_W-1:0] yExp;
logic [EXP_W-1:0] z0Exp;
logic [EXP_W+SIG_W:0] y,z0;
assign {ySign,yExp,ySig}=y;
assign {z0Sign,z0Exp,z0Sig}=z0;
logic isSigned, halfWidth;
/* verilator lint_off UNUSED */
logic [4:0] s0pre;
/* verilator lint_on UNUSED */

always @(*) begin
	case({isSigned,halfWidth})
	2'b00: a_i = a;
	2'b01: a_i = {32'b0, a[31:0]};
	2'b10: a_i = a;
	2'b11: a_i = {{32{a[31]}}, a[31:0]};
	endcase
end

R5FP_intToFloat_wrap #(
	.INT_W(64),
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) I (
		.a_i(a_i),
		.rnd_i(rnd),
		.isSigned(isSigned),
		.z_o(y));

initial begin
	fd=$fopen("/dev/stdin","r");
	$display("fd is %d", fd);
	readcount = $fscanf(fd, "DUMP: %x %x %x %x %x", isSigned, halfWidth, a, z0, s0pre);
	//$display("New data:  %h %h %b", a, z0, s0pre);
	if(readcount != 5) $display("Read Error! %d", readcount);
end
/* verilator lint_off BLKSEQ */
always @(negedge clk) begin
	if($feof(fd)) $finish();
	readcount = $fscanf(fd, "DUMP: %x %x %x %x %x", isSigned, halfWidth, a, z0, s0pre);
	//$display("New data:  %h %h %b", a, z0, s0pre);
	if(readcount != 5) begin
		$display("Read Error! %d", readcount);
		$finish();
	end
end

always @(posedge clk) begin
	//$display("Now a: %b.%b.%b ", aSign,aExp,aSig);
	reg pass;
	pass = (y==z0);

	if(pass) begin
		//$display("Pass");
	end
	else begin
		$display("Fail!!");
		$display("a: %08h ",a);
		$display("a:  %b   z0: %b.%b.%b", a_i, z0Sign,z0Exp,z0Sig);
		$display("a:  %b    y: %b.%b.%b", a_i,  ySign, yExp, ySig);
		$display("aLZC %d aExp %b aAbs %b  aShifted %b aSig %b zTmp %b", I.intToFloat.aLZC, I.intToFloat.aExp, 
			I.intToFloat.aAbs, I.intToFloat.aShifted, I.intToFloat.aSig, I.zxTmp);
		$finish();
	end
end
/* verilator lint_on BLKSEQ */

endmodule

