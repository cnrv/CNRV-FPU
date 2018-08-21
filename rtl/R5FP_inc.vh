
`ifndef R5FP_INC
`define R5FP_INC

//000 RNE Round to Nearest, ties to Even
//001 RTZ Round towards Zero
//010 RDN Round Down (towards -Inf)
//011 RUP Round Up (towards +Inf)
//100 RMM Round to Nearest, ties to Max Magnitude

`define RND_NEAREST_EVEN 3'b000
`define RND_TO_ZERO 3'b001
`define RND_DOWN 3'b010
`define RND_UP 3'b011
`define RND_NEAREST_UP 3'b100
`define RND_FROM_ZERO 3'b101

function automatic [2:0] to_snps_rnd(logic [2:0] i);
	if(i==3'b010) return 3'b011;
	else if(i==3'b011) return 3'b010;
	else return i;
endfunction

`define INVALID 5
`define SIGN 4
`define STICKY 3
`define IS_NAN 2
`define IS_INF 1
`define IS_ZERO 0

`define Z_IS_ZERO 0
`define Z_IS_INF 1
`define Z_INVALID 2
`define Z_TINY 3
`define Z_HUGE 4
`define Z_INEXACT 5
`define Z_HUGE_INT 6
`define Z_DIV_BY_0 7

parameter   softfloat_flag_inexact   =  1; //0
parameter   softfloat_flag_underflow =  2; //1
parameter   softfloat_flag_overflow  =  4; //2
parameter   softfloat_flag_infinite  =  8; //3
parameter   softfloat_flag_invalid   = 16; //4

/* verilator lint_off UNUSED */
function automatic [4:0] to_tf_flags(logic [7:0] status);
	return {status[`Z_INVALID],1'b0,status[`Z_HUGE],status[`Z_TINY],status[`Z_INEXACT]};
endfunction
/* verilator lint_on UNUSED */

`define EXP_DENORMAL_MIN(e,s) ((1<<((e)-1))+1-(s))
`define EXP_DENORMAL_MAX(e) (1<<((e)-1))
`define EXP_NORMAL_MIN(e) ((1<<((e)-1))+1)
`define EXP_NORMAL_MAX(e) ((1<<((e)-1))+((1<<(e))-2))

`define EXP_DENORMAL_MIN_X(large,small,s) (((1<<(large-1))-(1<<(small-1)))+1-(s))
`define EXP_DENORMAL_MAX_X(large,small) ((1<<(large-1))-(1<<(small-1)))
`define EXP_NORMAL_MIN_X(large,small) (((1<<(large-1))-(1<<(small-1)))+1)
`define EXP_NORMAL_MAX_X(large,small) (((1<<(large-1))-(1<<(small-1)))+(1<<(small))-2)

function automatic logic getRoundCarry( input [2:0] rnd_i, input sig_sign,
                        input guard_bit,round_bit,sticky);
begin
    logic round = 0;
    if ($time > 0) begin
        case (rnd_i)
        `RND_NEAREST_EVEN: begin
            round = round_bit&(guard_bit|sticky);
        end
        `RND_TO_ZERO: begin
            round = 0;
        end
        `RND_UP: begin
            round = ~sig_sign & (round_bit|sticky);
        end
        `RND_DOWN: begin
            round = sig_sign & (round_bit|sticky);
        end
        `RND_NEAREST_UP: begin
            round = round_bit;
        end
        `RND_FROM_ZERO: begin
            round = round_bit|sticky;
        end
        default: $display("Unkown rounding mode: %b!\n",rnd_i);
        endcase
    end
	return round;
end
endfunction

`endif

