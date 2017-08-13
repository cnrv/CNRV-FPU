
`include "R5FP_inc.vh"

`define FLOAT33_DEFAULT_NAN 'h1FFC00000
`define FLOAT65_DEFAULT_NAN bits65'(65'h1FFF8000000000000)

typedef logic unsigned [63:0] float64;
typedef logic unsigned [31:0] float32;
typedef logic unsigned [64:0] bits65;
typedef logic unsigned [63:0] bits64;
typedef logic unsigned [32:0] bits33;
typedef logic unsigned [31:0] bits32;
typedef logic unsigned [15:0] bits16;
typedef logic signed [31:0] sbits32;
typedef logic signed [63:0] sbits64;
typedef logic signed [31:0] int32;
typedef logic signed [63:0] int64;
typedef logic signed [15:0] int16;
typedef logic signed [7:0] int8;
typedef logic flag;

typedef enum logic {
    FLOAT_TININESS_AFTER_ROUNDING  = 0,
    FLOAT_TININESS_BEFORE_ROUNDING = 1
} float_detect_tininess_t;

//`define RND_NEAREST_EVEN 3'b000
//`define RND_TO_ZERO 3'b001
//`define RND_UP 3'b010
//`define RND_DOWN 3'b011
typedef enum logic [2:0] {
    FLOAT_ROUND_NEAREST_EVEN = 0,
    FLOAT_ROUND_DOWN         = 3,
    FLOAT_ROUND_UP           = 2,
    FLOAT_ROUND_TO_ZERO      = 1,
    FLOAT_ROUND_NEAREST_UP   = 4,
    FLOAT_ROUND_FROM_ZERO    = 5
} float_rounding_mode_t;


typedef logic [5:0] float_exception_flags_t;
const logic [5:0] FLOAT_FLAG_INVALID   =  1;
const logic [5:0] FLOAT_FLAG_DIVBYZERO =  4;
const logic [5:0] FLOAT_FLAG_OVERFLOW  =  8;
const logic [5:0] FLOAT_FLAG_UNDERFLOW = 16;
const logic [5:0] FLOAT_FLAG_INEXACT   = 32;

typedef struct packed {
	float_detect_tininess_t	float_detect_tininess;
	float_rounding_mode_t  	float_rounding_mode;
	float_exception_flags_t	float_exception_flags;
} float_ctrl_t;


function automatic logic [64:0] sub_sub (bits64 base, bits64 sub1, bits64 sub2);
	//return base-sub1-sub2;
	bits64 add1=~sub1;
	bits64 add2=~sub2;
	bits64 c=( (base&add1) | (base&add2) | (add1&add2) );
	bits64 v=( base^add1^add2 );
	logic [64:0] result=(c<<1)+v+2;
	return result;

endfunction

function automatic void div64_iter(output bits64 quotient_o, remainder_o, input bits64 quotient, remainder, subtractor, result_mask, src_mask);
	bits64 remainder_tmp1, remainder_tmp2;
	bits64 quotient_tmp1, quotient_tmp2;
	flag level1_select, level2_select;
	logic [64:0] sub_sub_out;
	remainder &= src_mask;
	subtractor &= src_mask;
	if( remainder>=(subtractor<<1) && (subtractor>>63)==0 ) begin
		level1_select=1;
		remainder_tmp1 = (remainder-(subtractor<<1)); //one adder
		quotient_tmp1 = (quotient|(result_mask<<1));
	end
	else begin
		level1_select=0;
		remainder_tmp1 = remainder;
		quotient_tmp1 = quotient;
	end

	sub_sub_out=sub_sub(remainder,(subtractor<<1),subtractor); //one adder
	// level2_select==(remainder_tmp1>=subtractor))
	if(level1_select==1'b1) begin
		level2_select=~sub_sub_out[64];
	end
	else begin
		level2_select=(remainder>=subtractor);
	end

	if(level2_select!=(remainder_tmp1>=subtractor)) begin
		$display("error!");
		$finish(2);
	end

	if(level2_select) begin
		//remainder_tmp2 = (remainder_tmp1-subtractor);
		if(level1_select) remainder_tmp2 = sub_sub_out[63:0];
		else   remainder_tmp2 = remainder-subtractor; //one adder
		quotient_tmp2 = (quotient_tmp1|result_mask);
	end
	else begin
		remainder_tmp2 = remainder_tmp1;
		quotient_tmp2 = quotient_tmp1;
	end

	remainder_o = remainder_tmp2;
	quotient_o = quotient_tmp2;
endfunction


function automatic flag float64_is_nan( float64 a );
    return ( bits64'( 64'hFFE0000000000000 ) < bits64'( a<<1 ) );
endfunction


function automatic flag float64_is_signaling_nan( float64 a );
    return
           ( ( ( a>>51 ) & 'hFFF ) == 'hFFE )
        && ( a & bits64'( 64'h0007FFFFFFFFFFFF ) );
endfunction

function automatic float64 propagateFloat65NaN( bits65 a, bits65 b, input float_ctrl_t fctrl, output float_ctrl_t fctrl_o );
	return propagateFloat64NaN( {a[64],a[62:0]}, {b[64],b[62:0]}, fctrl, fctrl_o );
endfunction

function automatic float64 propagateFloat64NaN( float64 a, float64 b, input float_ctrl_t fctrl, output float_ctrl_t fctrl_o );
    flag aIsNaN, aIsSignalingNaN, bIsNaN, bIsSignalingNaN;
	fctrl_o=fctrl;

    aIsNaN = float64_is_nan( a );
    aIsSignalingNaN = float64_is_signaling_nan( a );
    bIsNaN = float64_is_nan( b );
    bIsSignalingNaN = float64_is_signaling_nan( b );
    a |= bits64'( 64'h0008000000000000 );
    b |= bits64'( 64'h0008000000000000 );
    if ( aIsSignalingNaN | bIsSignalingNaN ) fctrl_o.float_exception_flags |=( FLOAT_FLAG_INVALID );
    if ( aIsSignalingNaN ) begin
        if ( bIsSignalingNaN ) begin
			if ( bits64'( a<<1 ) < bits64'( b<<1 ) ) return b;
			if ( bits64'( b<<1 ) < bits64'( a<<1 ) ) return a;
			return ( a < b ) ? a : b;
		end
        return bIsNaN ? b : a;
    end
    else if ( aIsNaN ) begin
        if ( bIsSignalingNaN | ! bIsNaN ) return a;
        if ( bits64'( a<<1 ) < bits64'( b<<1 ) ) return b;
        if ( bits64'( b<<1 ) < bits64'( a<<1 ) ) return a;
        return ( a < b ) ? a : b;
    end
    else begin
        return b;
    end
endfunction


function automatic bits64 extractFloat65Frac( bits65 a );
    return a & bits64'( 64'h000FFFFFFFFFFFFF );
endfunction

function automatic int16 extractFloat65Exp( bits65 a );
    return ( a>>52 ) & 'hFFF;
endfunction

function automatic flag extractFloat65Sign( bits65 a );
    return a[64];
endfunction



function automatic bits65 float65_div_prepare( bits65 a, bits65 b, output bits64 aSig,bSig,  
								int16 aExp,bExp, flag aSign,bSign,zSign,got_result, input float_ctrl_t fctrl, output float_ctrl_t fctrl_o );
	bits64 result;
    aSig = extractFloat65Frac( a );
    aExp = extractFloat65Exp( a );
    aSign = extractFloat65Sign( a );
    bSig = extractFloat65Frac( b );
    bExp = extractFloat65Exp( b );
    bSign = extractFloat65Sign( b );

	fctrl_o=fctrl;
	got_result=1'b1;
    zSign = aSign ^ bSign;
    if ( aExp == 16'hFFF ) begin
        if ( aSig ) begin
			result = propagateFloat65NaN( a, b, fctrl_o, fctrl_o );
			return {result[63],1'b1,result[62:0]};
		end
        if ( bExp == 16'hFFF ) begin
            if ( bSig ) begin
				result = propagateFloat65NaN( a, b, fctrl_o, fctrl_o );
				return {result[63],1'b1,result[62:0]};
			end
            fctrl_o.float_exception_flags |=( FLOAT_FLAG_INVALID );
            return `FLOAT65_DEFAULT_NAN;
        end
        return {zSign, {12{1'b1}}, 52'b0};
    end
    if ( bExp == 16'hFFF ) begin
        if ( bSig ) begin
			result = propagateFloat65NaN( a, b, fctrl_o, fctrl_o );
			return {result[63],1'b1,result[62:0]};
		end
        return {zSign, {12{1'b0}}, 52'b0};
    end
    if ( bExp == 0 ) begin
		if( bSig ==0 ) begin
			if({aExp,aSig}==0) begin
				fctrl_o.float_exception_flags |=( FLOAT_FLAG_INVALID );
				return `FLOAT65_DEFAULT_NAN;
			end
			else begin
				fctrl_o.float_exception_flags |=( FLOAT_FLAG_DIVBYZERO );
				return {1'b0,64'hFFF0000000000000};
			end
		end
		else begin
			assert(0);
		end
    end
    if ( aExp == 0 ) begin
		if( aSig ==0 ) begin
			return {zSign, {12{1'b0}}, 52'b0};
		end
		else begin
			assert(0);
		end
    end
	got_result=1'b0;
	return 0;
endfunction



module R5FP_div128by64_unsigned_seq (input logic clk,rst_n, strobe_in, is_single_in,  logic [63:0] dividend_in, divisor_in, 
                                output logic valid_out, logic [63:0] quotient_out, remainder_out);
	logic [63:0] quotient_r,remainder_r,dividend_r, divisor_r, subtractor_r, result_mask_r,
	             quotient  ,remainder  ,dividend  , divisor  , subtractor  , result_mask    ;
	logic is_single_r, valid_r,
	      is_single  , valid;
	logic [6:0]  iter_count_r,
	             iter_count;

	typedef enum logic {
		ITER, IDLE
	} state_t;
	state_t state_r, state;

	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			valid_r<=1'b0;
			state_r<=IDLE;
		end
		else begin
			valid_r<=valid;
			state_r<=state;
		end
	end
	always_ff @(posedge clk) begin
		quotient_r<=quotient;
		remainder_r<=remainder;
		divisor_r<=divisor;
		dividend_r<=dividend;
		is_single_r<=is_single;
		subtractor_r<=subtractor;
		result_mask_r<=result_mask;
		iter_count_r<=iter_count;
	end


	always_comb begin
		quotient=quotient_r;
		remainder=remainder_r;
		divisor=divisor_r;
		dividend=dividend_r;
		valid=valid_r;
		is_single=is_single_r;
		subtractor=subtractor_r;
		result_mask=result_mask_r;
		iter_count=iter_count_r;
		valid=valid_r;
		state=state_r;

		case(state_r)
		ITER: begin
			if(iter_count_r>=29) begin
				valid=1'b1;
				state=IDLE;
			end
			else begin
				div64_iter(quotient, remainder, quotient, remainder, subtractor_r, result_mask_r, {64{1'b1}}<<6);
				//$display("quotient: %x", quotient);
				remainder <<= 2;
				result_mask = (result_mask_r>>2);
				iter_count = iter_count_r+1;
			end
		end
		IDLE: begin
			if(strobe_in) begin
				dividend=dividend_in;
				divisor=divisor_in;
				valid=1'b0;
				quotient=0;
				remainder=dividend;
				subtractor=divisor;
				result_mask={1'b1,{63{1'b0}}};
				is_single=is_single_in;
				if(is_single) begin
					iter_count=16;
				end
				else begin
					iter_count=0;
				end
				state=ITER;
			end
		end
		endcase

		//$display(" %s -> %s ", state_r.name(), state.name() );
	end

	assign valid_out=valid_r;
	assign quotient_out=quotient_r;
	assign remainder_out=remainder_r;

endmodule

module R5FP_div_seq(input logic clk, rst_n, strobe_in, is_single_in, bits65 a_in, bits65 b_in, float_ctrl_t fctrl_in, 
                     output bits65 result_out, float_ctrl_t fctrl_out, logic valid_out );
    flag aSign, bSign, zSign, zSign_r, got_result, sub_strobe_in, sub_valid_out;
	flag is_single_r, is_single;
    int16 aExp, bExp, zExp;
    int16 aExp_r, bExp_r, zExp_r;
    bits65 a,b;
	bits64 aSig, bSig, zSig, zSigFast, rem1;
    bits65 a_r,b_r;
	bits64 aSig_r, bSig_r, zSig_r, zSigFast_r;
	bits65 result, result_r;
	flag valid, valid_r;
	float_ctrl_t fctrl,fctrl_r;

	bits64 dividend_in, divisor_in;
	bits64 quotient_out, remainder_out;
	int16 expOut;
	logic[7:0] statusOut;
	logic [12-1:0] tailZeroCnt;
	logic[6:0] aStatus;

parameter I_SIG_W=63;
parameter SIG_W=52;
parameter EXP_W=12;
`define FUNC_POSTPROC func_postproc
`include "R5FP_postproc.v"
`undef FUNC_POSTPROC


	R5FP_div128by64_unsigned_seq U_div128by64_unsigned_seq (.strobe_in(sub_strobe_in), .is_single_in(is_single),
													.valid_out(sub_valid_out), .*);

	typedef enum logic [2:0] {
		PREPROC0, PREPROC1, WAIT, POSTPROC, IDLE
	} state_t;
	state_t state_r, state;

	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			valid_r<=1'b0;
			state_r<=IDLE;
		end
		else begin
			valid_r<=valid;
			state_r<=state;
		end
	end
	always_ff @(posedge clk) begin
		a_r<=a;
		b_r<=b;
		is_single_r<=is_single;
		zSign_r<=zSign;
		aExp_r<=aExp;
		bExp_r<=bExp;
		zExp_r<=zExp;
		aSig_r<=aSig;
		bSig_r<=bSig;
		zSig_r<=zSig;
		zSigFast_r<=zSigFast;
		result_r<=result;
		fctrl_r<=fctrl;
	end

	always_comb begin
		a=a_r;
		b=b_r;
		zSign=zSign_r;
		aExp=aExp_r;
		bExp=bExp_r;
		zExp=zExp_r;
		aSig=aSig_r;
		bSig=bSig_r;
		zSig=zSig_r;
		zSigFast=zSigFast_r;
		result=result_r;
		valid=valid_r;
		fctrl=fctrl_r;
		is_single=is_single_r;
		state=state_r;

		sub_strobe_in=1'b0;
		dividend_in='bx;
		divisor_in='bx;

		case(state_r)
		PREPROC0: begin
			result=float65_div_prepare(a_r, b_r, aSig,bSig,  aExp,bExp, aSign,bSign,zSign,got_result, fctrl, fctrl);
			if(got_result) begin
				state=IDLE;
				valid=1'b1;
			end
			else begin
				state=state_r.next();
			end
		end
		PREPROC1: begin
			zExp = aExp_r - bExp_r + 16'h3FD;
			aSig = ( aSig_r | 64'h0010000000000000 )<<10;
			bSig = ( bSig_r | 64'h0010000000000000 )<<11;
			//$display("PREPROC1: aSig:%b bSig:%b",aSig,bSig);
			if ( bSig <= ( aSig*2 ) ) begin
				aSig >>= 1;
				zExp=zExp+1;
			end
			sub_strobe_in=1'b1;
			dividend_in=aSig;
			divisor_in=bSig>>2;
			state=state_r.next();
		end
		WAIT: begin
			zSig=quotient_out>>1;
			rem1=remainder_out;
			zSig |= ( rem1 != 0 );
			
			//$display("WAIT: zSig:%b rem1:%b",zSig,rem1);
			if(sub_valid_out) state=state_r.next();
		end
		POSTPROC: begin
			expOut=zExp_r+{10{1'b1}}+2;

			if(is_single_r) begin
				if(expOut<=`EXP_DENORMAL_MIN_X(EXP_W,8,SIG_W)-2)
					expOut=`EXP_DENORMAL_MIN_X(EXP_W,8,SIG_W)-2;
				if(expOut>=`EXP_NORMAL_MAX_X(EXP_W,8)+1)
					expOut=`EXP_NORMAL_MAX_X(EXP_W,8)+1;
				tailZeroCnt=29;
				if(expOut>=`EXP_DENORMAL_MIN_X(EXP_W,8,SIG_W) && expOut<=`EXP_DENORMAL_MAX_X(EXP_W,8)) begin
					tailZeroCnt=29+1+(`EXP_DENORMAL_MAX_X(EXP_W,8)-expOut);
				end
				//$display("zExp_r:%d expOut:%d zSig_r:%b-%h tailZeroCnt:%d %d %d", zExp_r,expOut, zSig_r[63:62], zSig_r[61:0], tailZeroCnt,`EXP_DENORMAL_MIN_X(EXP_W,8,SIG_W),`EXP_DENORMAL_MAX_X(EXP_W,8));
			end
			else begin
				if(expOut<=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-2)
					expOut=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-2;
				if(expOut>=`EXP_NORMAL_MAX(EXP_W-1)+1)
					expOut=`EXP_NORMAL_MAX(EXP_W-1)+1;
				tailZeroCnt=0;
				if(expOut>=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W) && expOut<=`EXP_DENORMAL_MAX(EXP_W-1)) begin
					tailZeroCnt=1+(`EXP_DENORMAL_MAX(EXP_W-1)-expOut);
				end
				//$display("zExp_r:%d expOut:%h zSig_r:%b-%h tailZeroCnt:%d %d %d", zExp_r,expOut, zSig_r[63:62], zSig_r[61:0], tailZeroCnt,`EXP_DENORMAL_MIN(EXP_W-1,SIG_W),`EXP_DENORMAL_MAX(EXP_W-1));
			end

			aStatus=0;
			aStatus[`STICKY]=zSig_r[0];
			func_postproc(
				.aExp(expOut[11:0]),
				.aStatus(aStatus),
				.aSig(zSig_r[63:1]),
				.rnd(fctrl.float_rounding_mode),
				.aSign(zSign_r),
				.tailZeroCnt(tailZeroCnt),
				.z(result),
				.status(statusOut));
			//if(statusOut[`Z_IS_INF]) fctrl.float_exception_flags|=FLOAT_FLAG_OVERFLOW;
			//if(statusOut[`Z_TINY]) fctrl.float_exception_flags|=FLOAT_FLAG_UNDERFLOW;
			if(statusOut[`Z_INEXACT]) fctrl.float_exception_flags|=FLOAT_FLAG_INEXACT;

			valid=1'b1;
			state=state_r.next();
		end
		IDLE: begin
			if(strobe_in) begin
				a=a_in;
				b=b_in;
				fctrl=fctrl_in;
				is_single=is_single_in;
				valid=1'b0;
				state=PREPROC0;
			end
		end
		endcase

		//$display(" %s (%x) => %s (%x) ", state_r.name(), result_r, state.name(), result );
	end

	assign valid_out=valid_r;
	assign result_out=result_r;
	assign fctrl_out=fctrl_r;

endmodule

module R5FP_fp65_to_fp33 (input [64:0] a, input [2:0] rnd, output [32:0] z);
wire aSign;
wire [11:0] aExp;
wire [51:0] aSig;
assign {aSign,aExp,aSig}=a;

reg useMinValue;
reg signed [12:0] zExp;
reg [22:0] zSig;
assign z={aSign,zExp[8:0],zSig};

always @(*) begin
	useMinValue=0;
	if(aExp==0) begin
		zExp=0;
		zSig=0;
	end
	else if(aExp=={12{1'b1}}) begin
		zExp = {9{1'b1}};
		zSig=aSig[51:51-22];
	end
	else begin
		zSig=aSig[51:51-22];
		zExp = aExp - (1<<12)/2 + (1<<9)/2;
		//$display("HereH0 zExp:%b aExp:%b %b %b",zExp,aExp,`EXP_DENORMAL_MIN(8,23),`EXP_NORMAL_MAX(9));
		if(zExp>`EXP_NORMAL_MAX(8)) begin
			if (rnd==FLOAT_ROUND_TO_ZERO || (rnd==FLOAT_ROUND_DOWN && !aSign) || (rnd==FLOAT_ROUND_UP && aSign) ) begin
				zExp = `EXP_NORMAL_MAX(8);
				zSig = {23{1'b1}};
			end
			else begin
				zExp = {9{1'b1}};
				zSig = 0;
			end
		end
		else if(zExp<`EXP_DENORMAL_MIN(8,23)) begin
			//if( rnd==FLOAT_ROUND_NEAREST_UP && zExp==`EXP_DENORMAL_MIN(8,23)-1 && !needShift ) 
			//	useMinValue=1;
			if( rnd==FLOAT_ROUND_FROM_ZERO || (rnd==FLOAT_ROUND_DOWN && aSign) || (rnd==FLOAT_ROUND_UP && !aSign) )
				useMinValue=1;
			if(useMinValue) begin
				zExp=`EXP_DENORMAL_MIN(8,23);
				zSig=1;
			end
			else begin
				zExp=0;
				zSig=0;
			end
		end
		//$display("HereH zExp:%b aExp:%b",zExp,aExp);
	end
end

endmodule

