
`include "R5FP_inc.vh"

module R5FP_fp2fp_expand #(
	parameter SIG_W=10,
	parameter EXP_W=5,
	parameter SIG_W_INCR=1,
	parameter EXP_W_INCR=1) (
	input [SIG_W+EXP_W:0] a,
	output reg [SIG_W+SIG_W_INCR+EXP_W+EXP_W_INCR:0] z);

localparam SIG_W_O=SIG_W_INCR+SIG_W;
localparam EXP_W_O=EXP_W_INCR+EXP_W;
always @(*) begin
	z[SIG_W_O+EXP_W_O]=a[SIG_W+EXP_W];
	z[SIG_W_O-1:0]={a[SIG_W-1:0], {SIG_W_INCR{1'b0}}};
	if(a[SIG_W+EXP_W-1:SIG_W]=={EXP_W{1'b1}}) begin
		z[SIG_W_O+EXP_W_O-1:SIG_W_O] = {EXP_W_O{1'b1}};
	end
	else if(a[SIG_W+EXP_W-1:SIG_W]=={EXP_W{1'b0}}) begin
		z[SIG_W_O+EXP_W_O-1:SIG_W_O] = 0;
	end
	else begin
		z[SIG_W_O+EXP_W_O-1:SIG_W_O] = a[SIG_W+EXP_W-1:SIG_W] + ( (1<<EXP_W_O)/2 - (1<<EXP_W)/2 );
	end
end
endmodule 

module R5FP_exp_incr #(
	parameter SIG_W=10,
	parameter EXP_W=5) (
	input [SIG_W+EXP_W:0] a,
	output [SIG_W+EXP_W+1:0] z);

localparam a_width=SIG_W;
localparam addr_width=$clog2(a_width)+1;
/* verilator lint_off WIDTH */
`include "DW_lzd_function.inc"
/* verilator lint_on WIDTH */

localparam EXP_W_O=EXP_W+1;
wire [EXP_W-1:0] aExp=a[SIG_W+EXP_W-1:SIG_W];
wire [SIG_W-1:0] aSig=a[SIG_W-1:0];
reg [addr_width:0] lzCount;
reg [EXP_W_O-1:0] zExp;
reg [SIG_W-1:0] zSig;
assign z={a[SIG_W+EXP_W],zExp,zSig};

always @(*) begin
	zExp = aExp + ( (1<<EXP_W_O)/2 - (1<<EXP_W)/2 );
	zSig = aSig;
	lzCount=0;
	if(aExp==0) begin
		if(aSig==0) begin
			zExp=0;
			zSig=0;
		end
		else begin
			lzCount=DWF_lzd_enc(aSig);
			zExp=zExp-EXP_W_O'(lzCount);
			zSig=zSig<<lzCount;
			zSig=zSig<<1;
		end
	end
	else if(aExp=={EXP_W{1'b1}}) begin
		zExp = {EXP_W_O{1'b1}};
	end
	//$display("Here4: a:%b aSig:%b zSig:%b lzCount:%b aSig<<lzCount:%b",a,aSig,zSig,lzCount,aSig<<lzCount);
end

endmodule

module R5FP_exp_decr #(
	parameter SIG_W=10,
	parameter EXP_W=5) (
	input [SIG_W+EXP_W+1:0] a,
	output [SIG_W+EXP_W:0] z);

localparam EXP_W_I=EXP_W+1;
localparam enc_width=$clog2(SIG_W)+1;
wire [EXP_W_I-1:0] aExp=a[SIG_W+EXP_W_I-1:SIG_W];
wire [SIG_W-1:0] aSig=a[SIG_W-1:0];
reg [enc_width-1:0] shCount;
reg [EXP_W-1:0] zExp;
reg [SIG_W-1:0] zSig;
assign z={a[SIG_W+EXP_W_I],zExp,zSig};

always @(*) begin
/* verilator lint_off WIDTH */
	zExp = aExp - ( (1<<EXP_W_I)/2 - (1<<EXP_W)/2 );
/* verilator lint_on WIDTH */
	zSig = aSig;
	if(aExp==0) begin
		zExp=0;
		zSig=0;
	end
	else if(aExp=={EXP_W_I{1'b1}}) begin
		zExp = {EXP_W{1'b1}};
	end
	else if(aExp>=`EXP_DENORMAL_MIN(EXP_W,SIG_W)&&aExp<=`EXP_DENORMAL_MAX(EXP_W)) begin
/* verilator lint_off WIDTH */
		shCount=1+(`EXP_DENORMAL_MAX(EXP_W)-aExp);
		zSig={1'b1,aSig}>>shCount;
/* verilator lint_on WIDTH */
		zExp=0;
	end
	//$display("Here4: zSig:%b shCount:%b aExp:%b zExp:%b %b %b",zSig,shCount,aExp,zExp,`EXP_DENORMAL_MIN(EXP_W,SIG_W),`EXP_DENORMAL_MAX(EXP_W));
end

endmodule

