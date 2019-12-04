`include "R5FP_inc.vh"

module R5FP_floatToInt_wrap #(
	parameter INT_W = 64,
	parameter SIG_W = 23,
	parameter EXP_W = 8) (
		input  [SIG_W + EXP_W:0] a_i,
		input toSigned, halfWidth,
		output [INT_W-1:0] z_o);

wire [EXP_W+SIG_W+1:0] ax;
wire aSign;
wire [EXP_W:0] aExp;
wire [SIG_W-1:0] aSig;
assign {aSign, aExp, aSig} = ax;

R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) exp_incr (.a(a_i), .z(ax));

R5FP_floatToInt #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W),
	.INT_W(INT_W)) floatToInt (
	.toSigned(toSigned), .halfWidth(halfWidth),
	.aSign(aSign), .aExp(aExp), .aSig(aSig),
	.z(z_o));

endmodule


///////////////////////////////////////////////////////////////////

module tb_floatToInt(input clk, 
/* verilator lint_off UNUSED */
	input reset, 
	input [2:0] rnd);
/* verilator lint_on UNUSED */

`ifdef FP64
parameter EXP_W=11;
parameter SIG_W=52;
`else
parameter EXP_W=8;
parameter SIG_W=23;
`endif
integer fd, readcount;

logic aSign;
logic [SIG_W-1:0] aSig;
logic [EXP_W-1:0] aExp;
logic [EXP_W+SIG_W:0] a;
assign {aSign,aExp,aSig}=a;
logic [63:0] y, z0;
logic toSigned, halfWidth;
/* verilator lint_off UNUSED */
logic [4:0] s0pre;
/* verilator lint_on UNUSED */

R5FP_floatToInt_wrap #(
	.INT_W(64),
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) I (
		.a_i(a),
		.toSigned(toSigned), .halfWidth(halfWidth),
		.z_o(y));

initial begin
	fd=$fopen("/dev/stdin","r");
	$display("fd is %d", fd);
	readcount = $fscanf(fd, "DUMP: %x %x %x %x %x", toSigned, halfWidth, a, z0, s0pre);
	//$display("New data:  %h %h %b", a, z0, s0pre);
	if(readcount != 5) $display("Read Error! %d", readcount);
end
/* verilator lint_off BLKSEQ */
always @(negedge clk) begin
	if($feof(fd)) $finish();
	readcount = $fscanf(fd, "DUMP: %x %x %x %x %x", toSigned, halfWidth, a, z0, s0pre);
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
	if(halfWidth) begin
		pass = (y[31:0]==z0[31:0]);
	end

	if(pass) begin
		//$display("Pass");
		//$display("a:  %b.%b.%b  z0: %b.%b.%b", aSign,aExp,aSig, z0Sign,z0Exp,z0Sig);
		//$display("a:  %b.%b.%b  y:  %b.%b.%b", aSign,aExp,aSig, ySign,yExp,ySig);
		//$display("----");
	end
	else begin
		$display("Fail!!");
		$display("a: %08h ",a);
		$display("a:  %b.%b.%b   z0: %b", aSign,aExp,aSig,   z0);
		$display("a:  %b.%b.%b   y:  %b shift: %b >> %d tooLarge:%b", aSign,aExp,aSig,   y,  I.floatToInt.sIn, I.floatToInt.shamt, I.floatToInt.tooLarge);
		$finish();
	end
end
/* verilator lint_on BLKSEQ */

endmodule

