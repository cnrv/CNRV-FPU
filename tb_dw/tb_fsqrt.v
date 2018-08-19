
`include "R5FP_inc.vh"

/* verilator lint_off UNUSED */
/* verilator lint_off WIDTH */
/* verilator lint_off VARHIDDEN */
`include "../sim_ver/DW_fp_sqrt.v"
/* verilator lint_on UNUSED */
/* verilator lint_on WIDTH */
/* verilator lint_on VARHIDDEN */

module R5FP_sqrt_wrap #(
	parameter SIG_W = 23,
	parameter EXP_W = 8,
	localparam ExtWidth=(SIG_W%2==1)? (SIG_W + 3) : (SIG_W + 4) ) (
		input  [SIG_W + EXP_W:0] a_i,
		input  [2:0] rnd_i,
		input strobe_i,
		output reg [SIG_W + EXP_W:0] z_o,
		output [SIG_W + EXP_W+1:0] zx,
		output reg [7:0] status_o,

		output done_o, ready_o,
		input clk,reset);

wire [EXP_W+SIG_W+1:0] ax;

R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) exp_incr (.a(a_i), .z(ax));

logic [ExtWidth-1:0] isqrt_D;
logic isqrt_strobe;
logic [ExtWidth-1:0] isqrt_Quo, isqrt_Rem;
logic isqrt_done;
logic isqrt_ready;
R5FP_sqrt #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W+1)) sqrt (
		.a_i(ax),
		.rnd_i(rnd_i),
		.strobe_i(strobe_i),
		.z_o(zx),
		.status_o(status_o),

		.isqrt_D(isqrt_D), 
		.isqrt_strobe(isqrt_strobe),
		.isqrt_Quo(isqrt_Quo),
		.isqrt_Rem(isqrt_Rem),
		.isqrt_done(isqrt_done),
		.isqrt_ready(isqrt_ready),

		.done_o(done_o), 
		.ready_o(ready_o),
		.clk(clk),
		.reset(reset));

R5FP_int_div_sqrt #(.W(ExtWidth)) 
	int_div_sqrt (
		.N_i({ExtWidth{1'b0}}),
		.D_i(isqrt_D),
		.strobe_i(isqrt_strobe), 
		.is_div_i(1'b0),
		.Quo_o(isqrt_Quo), 
		.Rem_o(isqrt_Rem),
		.done_o(isqrt_done),
		.ready_o(isqrt_ready),
		.clk(clk),
		.reset(reset));

R5FP_exp_decr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) exp_decr (.a(zx), .z(z_o));

endmodule

///////////////////////////////////////////////////////////////////

module tb_fsqrt(input clk, reset, input [2:0] rnd);

parameter SIG_W=10;
parameter EXP_W=5;

logic done,strobe;
logic [7:0] status,status0;
logic [SIG_W-1:0] aSig,zSig0,zSig,zxSig;
logic [EXP_W-1:0] aExp,zExp0,zExp;
logic [EXP_W:0] zxExp;
/* verilator lint_off UNUSED */
logic zSign0,zSign,zxSign;
/* verilator lint_on UNUSED */

DW_fp_sqrt #(
	.sig_width(SIG_W),
	.exp_width(EXP_W),
	.ieee_compliance(1)) R (
		.a({1'b0,aExp,aSig}),
		.rnd(to_snps_rnd(rnd)), 
		.z({zSign0,zExp0,zSig0}), 
		.status(status0));

R5FP_sqrt_wrap #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) I (
	.a_i({1'b0,aExp,aSig}),
	.rnd_i(rnd),
	.strobe_i(strobe),
	.z_o({zSign,zExp,zSig}),
	.zx({zxSign,zxExp,zxSig}),
	.status_o(status),
	.done_o(done),
	/* verilator lint_off PINCONNECTEMPTY */
	.ready_o(),
	/* verilator lint_on PINCONNECTEMPTY */
	.clk(clk),
	.reset(reset));

always @(negedge clk) begin
	if(done&&!reset) begin
		reg pass;
		pass=(zSig0==zSig && zExp0==zExp && status0==status);

		if(pass) begin
			//$display("Pass");
			//$display("zSig0:%b zExp0:%b status0:%b",zSig0,zExp0,status0);
			//$display("zSig :%b zExp :%b status :%b",zSig, zExp, status);
		end
		else begin
			$display("Fail!! %d", $time);
			$display("input: %b-%b",aExp,aSig);
			$display("zSig0:%b zExp0:%b status0:%b",zSig0,zExp0,status0);
			$display("zSig :%b zExp :%b status :%b",zSig, zExp, status);
			$display("zxSig:%b zxExp:%b",zxSig, zxExp);
			$display("use_fast_r :%b ", I.sqrt.use_fast_r);
			$finish();
		end
	end
end

reg stop;
always @(negedge clk) begin
	if(reset) begin
		stop<=1'b0;
		{aExp,aSig}<=0;
	end
	else begin
		if(stop) begin
			$display("All Done");
			$stop();
		end
		if(done) begin
			logic [SIG_W-1:0] aSig_nxt;
			logic [EXP_W-1:0] aExp_nxt;
			if((&{aExp[EXP_W-1:1],aSig})==1) stop<=1'b1;
			{aExp_nxt,aSig_nxt}={aExp,aSig}+1;
			aExp<=aExp_nxt;
			aSig<=aSig_nxt;
			//$display("%d New input: %b-%b",$time, aExp_nxt,aSig_nxt);
		end
	end
end

always @(posedge clk) begin
	if(reset) strobe<=1'b1;
	else if (strobe) strobe<=1'b0;
	else if (done) strobe<=1'b1;
end


endmodule

