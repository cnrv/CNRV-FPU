
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

module R5FP_roundToInt_helper #(
	parameter SIG_W = 23,
	parameter EXP_W = 8) (
	input zSign,
	input  [2:0] rnd_i,
	input [EXP_W:0] zExp,
	input [SIG_W-1:0] zSig,
	output reg usePP, useOrig,
	output reg [SIG_W + EXP_W + 1:0] zx);

always @(*) begin
	logic [SIG_W + EXP_W:0] one, zero;
	zero = {(SIG_W+EXP_W+1){1'b0}};
	one = { {1'b0,{EXP_W{1'b1}}}, {SIG_W{1'b0}} };
	usePP = 1'b0;
	useOrig = 1'b0;
	zx = {(SIG_W + EXP_W + 2){1'bx}};
	if(zExp==0 && zSig==0) begin
		zx = {zSign, zero};
	end
	else if( zExp == ({1'b1,{EXP_W{1'b0}}}-2) ) begin // special case: to 1 or to 0
		if(rnd_i == `RND_NEAREST_EVEN) begin
			if(zSig!=0) begin
				zx = {zSign, one};
			end
			else begin
				zx = {zSign, zero };
			end
		end
		else if(rnd_i == `RND_NEAREST_UP) begin
			zx = {zSign, one};
		end
		else if(rnd_i == `RND_TO_ZERO) begin
			zx = {zSign, zero};
		end
		else if(rnd_i == `RND_DOWN && !zSign) begin
			zx = {1'b0, zero};
		end
		else if(rnd_i == `RND_DOWN && zSign) begin
			zx = {1'b1, one};
		end
		else if(rnd_i == `RND_UP && !zSign) begin
			zx = {1'b0, one};
		end
		else if(rnd_i == `RND_UP && zSign) begin
			zx = {1'b1, zero};
		end
	end
	else if(zExp<{1'b0,{EXP_W{1'b1}}}) begin
		if(rnd_i == `RND_NEAREST_EVEN || rnd_i == `RND_TO_ZERO || rnd_i == `RND_NEAREST_UP || 
		(rnd_i == `RND_DOWN && !zSign) || (rnd_i == `RND_UP && zSign) ) begin
			zx = {zSign, zero};
		end
		else if(rnd_i == `RND_DOWN && zSign) begin
			zx = {1'b1, one};
		end
		else if(rnd_i == `RND_UP && !zSign) begin
			zx = {1'b0, one};
		end
	end
	else if(SIG_W<(zExp-{EXP_W{1'b1}})) begin
		useOrig = 1'b1;
	end
	else begin
		usePP = 1'b1;
	end
end

endmodule

module R5FP_bidirectional_shifter #(
	parameter EXP_W = 8,
	parameter INT_W = 64) (
	input signed [EXP_W:0] shamt,
	input [INT_W-1:0] a,
	output reg [INT_W-1:0] z);

always @(*) begin
	if( shamt >= 0 )begin
		z = a << shamt;
	end
	else begin
		z = a >> -shamt;
	end
end

endmodule

module R5FP_floatToInt #(
	parameter SIG_W = 23,
	parameter EXP_W = 8,
	parameter INT_W = 64) (
	input toSigned, halfWidth,
	input aSign,
	input [EXP_W:0] aExp,
	input [SIG_W-1:0] aSig,

	output reg [INT_W-1:0] z);

wire [INT_W-1:0] sIn = {{(INT_W-SIG_W-1){1'b0}}, 1'b1, aSig};
wire signed [EXP_W:0] shamt = (aExp - {1'b0, {EXP_W{1'b1}}} - SIG_W );
wire [INT_W-1:0] sOut;
R5FP_bidirectional_shifter #(
	.EXP_W(EXP_W),
	.INT_W(INT_W)) biSh (
	.shamt(shamt), .a(sIn), .z(sOut));

reg [EXP_W:0] intWidth;
reg tooLarge;
always @(*) begin
	tooLarge = 1'b0;
	if(toSigned) begin
		intWidth = halfWidth? INT_W/2-1 : INT_W-1;
	end
	else begin
		intWidth = halfWidth? INT_W/2 : INT_W;
	end

	if(aExp<{1'b0,{EXP_W{1'b1}}}) begin
		z = 0;
	end
	else if(aExp >= {1'b0, {EXP_W{1'b1}}} + intWidth) begin
		tooLarge = 1'b1;
	end
	else begin
		z = sOut;
	end

	if(aSign) begin
		if(!toSigned) begin
			z = 0;
		end
		else begin
			z = -z;
		end
	end
	if(halfWidth) begin
		if(toSigned) begin
			if(z[INT_W/2-1]) begin // negative
				if(z[INT_W-1:INT_W/2] != {INT_W/2{1'b1}}) begin
					z = { {INT_W/2{1'b0}}, 1'b1, {(INT_W/2-1){1'b0}} }; //minimum negative value
				end
			end
			else begin // positive
				if(z[INT_W-1:INT_W/2] != {INT_W/2{1'b0}}) begin
					z = { {INT_W/2{1'b0}}, 1'b0, {(INT_W/2-1){1'b1}} }; //maximum positive value
				end
			end
		end
		else begin
			if(z[INT_W-1:INT_W/2] != {INT_W/2{1'b0}}) begin
				z = { {INT_W/2{1'b0}}, {(INT_W/2){1'b1}} }; //maximum positive value
			end
		end
	end

	if(aExp == {EXP_W+1{1'b1}} && aSig != 0) begin //NaN
		if(halfWidth) begin
			if(toSigned) begin
				z = { {INT_W/2{1'b0}}, 1'b0, {(INT_W/2-1){1'b1}} }; //maximum positive value
			end
			else begin
				z = { {INT_W/2{1'b0}}, {(INT_W/2){1'b1}} }; //maximum positive value
			end
		end
		else begin
			if(toSigned) begin
				z = { 1'b0, {(INT_W-1){1'b1}} }; //maximum positive value
			end
			else begin
				z = {INT_W{1'b1}}; //maximum positive value
			end
		end
	end
	else if( (aExp == {EXP_W+1{1'b1}} && aSig != 0) || tooLarge ) begin //Inf
		if(halfWidth) begin
			if(toSigned) begin
				if(aSign) begin // negative
					z = { {INT_W/2{1'b0}}, 1'b1, {(INT_W/2-1){1'b0}} }; //minimum negative value
				end
				else begin // positive
					z = { {INT_W/2{1'b0}}, 1'b0, {(INT_W/2-1){1'b1}} }; //maximum positive value
				end
			end
			else begin
				if(aSign) begin // negative
					z = 0;
				end
				else begin
					z = { {INT_W/2{1'b0}}, {(INT_W/2){1'b1}} }; //maximum positive value
				end
			end
		end
		else begin
			if(toSigned) begin
				if(aSign) begin // negative
					z = { 1'b1, {(INT_W-1){1'b0}} }; //minimum negative value
				end
				else begin // positive
					z = { 1'b0, {(INT_W-1){1'b1}} }; //maximum positive value
				end
			end
			else begin
				if(aSign) begin // negative
					z = 0;
				end
				else begin
					z = {INT_W{1'b1}}; //maximum positive value
				end
			end
		end
	end
end

endmodule


module R5FP_intToFloat_helper #(
	parameter SIG_W = 23,
	parameter EXP_W = 8,
	parameter INT_W = 64,
	localparam I_SIG_W=SIG_W*2+5
	) (
	input isSigned,
	input [INT_W-1:0] a,
	output reg [EXP_W:0] tailZeroCnt,
	output [EXP_W:0] aExp,
	output reg [6-1:0] aStatus,
	output reg [I_SIG_W-1:0] aSig,
	output aSign);

localparam a_width=INT_W;
localparam addr_width=$clog2(a_width)+1;
/* verilator lint_off WIDTH */
`include "DW_lzd_function.inc"
/* verilator lint_on WIDTH */

wire [EXP_W:0] aLZC;
wire aMSB = a[INT_W-1];
wire [INT_W-1:0] aAbs = (isSigned&aMSB)? (-a) : a;
assign aLZC = { {EXP_W-addr_width{1'b0}}, DWF_lzd_enc(aAbs) };
wire [INT_W-1:0] aShifted = aAbs << aLZC;
assign aExp = (INT_W - 1 - aLZC) + {1'b0, {EXP_W{1'b1}}};

logic sticky;
generate
if(INT_W >= I_SIG_W+1) begin
	always @(*) begin
		logic [INT_W-1:0] mask;
		mask = {INT_W{1'b1}};
		mask = mask << (INT_W+1-I_SIG_W);
		mask = ~mask;
		aSig = {1'b0, aShifted[INT_W-1:INT_W+1-I_SIG_W]};
		sticky = 1'b0;
		if((aShifted&mask)!=0) begin
			sticky = 1'b1;
		end
	end
end
else begin
	assign aSig = {1'b0, aShifted, {(I_SIG_W-INT_W-1){1'b0}}};
	assign sticky = 1'b0;
end
endgenerate

always @(*) begin
	tailZeroCnt = 0;
	aStatus = 0;
	if(sticky) begin
		aStatus[`STICKY] = 1'b1;
	end
end

assign aSign = isSigned&aMSB;

endmodule
