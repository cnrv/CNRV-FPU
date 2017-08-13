
`include "R5FP_div.v"
function automatic int16 extractFloat32Exp( float32 a );
    return ( a>>23 ) & 'hFF;
endfunction

module test_div_float ();

logic clk, rst_n, strobe_in;
bits64 a32Ref_in, b32Ref_in;
bits33 aRef_in, bRef_in;
bits65 a_in, b_in;
float_ctrl_t fctrl_in;
bits64 result_right;
bits65 result_out;
bits33 result33;
bits32 result;
float_ctrl_t fctrl_out;
float_ctrl_t fctrl_tmp;
logic valid_out;
int test_counter;
int tiny, round;
integer fd;
float_exception_flags_t flags_right;

R5FP_exp_incr #(
	.SIG_W(23),
	.EXP_W(8)) a_incr (.a(a32Ref_in[31:0]), .z(aRef_in));
R5FP_exp_incr #(
	.SIG_W(23),
	.EXP_W(8)) b_incr (.a(b32Ref_in[31:0]), .z(bRef_in));

R5FP_fp2fp_expand #(
	.SIG_W(23),
	.EXP_W(9),
	.SIG_W_INCR(29),
	.EXP_W_INCR(3)) a_x (.a(aRef_in), .z(a_in));
R5FP_fp2fp_expand #(
	.SIG_W(23),
	.EXP_W(9),
	.SIG_W_INCR(29),
	.EXP_W_INCR(3)) b_x (.a(bRef_in), .z(b_in));

R5FP_div_seq U_float_div_seq (.is_single_in(1'b1), .*);

R5FP_fp65_to_fp33 fp65to33 (.rnd(fctrl_in.float_rounding_mode), .a(result_out), .z(result33));

R5FP_exp_decr #(
	.SIG_W(23),
	.EXP_W(8)) U_decr (.a(result33), .z(result));

initial begin
fd = $fopen("../test_cases/test_case_float32_div_L2.txt", "r");

$display("Now start...");
	test_counter=0;
	clk=0;
	rst_n=1;
	strobe_in=1'b0;
	#3
	rst_n=0;
	#3
	rst_n=1;
	#3
	clk=1;
	#3
	forever begin
		#10
		clk = ~clk;
	end
end

reg finish_loop,ok;
float_ctrl_t fctrl_imp;
always @(negedge clk) begin
	//if(test_counter>100*10000) $finish(2);
	if(test_counter%10000==0) $display("test_counter: %d", test_counter);
	if(test_counter>0 && valid_out) begin
		fctrl_imp=fctrl_out;
		fctrl_imp.float_exception_flags[5:3]=0; //TODO
		flags_right[5:3]=0; //TODO
		ok=(result_right==result && flags_right==fctrl_imp.float_exception_flags);
		if(result_right[30:23]==8'hFF && result[30:23]==8'hFF) ok=1'b1; //TODO
		if(!ok) begin
			$display("tiny:%d round:%d, a:%b-%h-%h b:%b-%h-%h resRight:%b.%h.%h flagRight:%b : result_out:%b.%h.%h -> result33:%b.%h.%h -> result:%b.%h.%h flag:%b", tiny, round, 
			a_in[64],a_in[63:52],a_in[51:0],
			b_in[64],b_in[63:52],b_in[51:0],
			result_right[31],result_right[30:23],result_right[22:0],flags_right,  
			result_out[64],result_out[63:52],result_out[51:0],
			result33[32],result33[31:23],result[22:0],
			result[31],result[30:23],result[22:0],
			fctrl_imp.float_exception_flags);
			$finish(2);
		end
		else begin
			//$display("PASS! %d %d, %h %h %h %h : %h %h", tiny, round, a_in,b_in,result_right,flags_right,  result, fctrl_imp.float_exception_flags);
		end
	end
	if(strobe_in==1'b1) strobe_in=1'b0;
	if(test_counter==0 || valid_out) begin
		$fscanf(fd, "%d %d %h %h %h %h", tiny, round, a32Ref_in, b32Ref_in, result_right, flags_right);
		//$display("Read: a:%b.%h.%h b:%b.%h.%h", a32Ref_in[31],a32Ref_in[30:23],a32Ref_in[22:0], b32Ref_in[31],b32Ref_in[30:23],b32Ref_in[22:0]);
		if(tiny==0)  fctrl_in.float_detect_tininess=FLOAT_TININESS_AFTER_ROUNDING;
		if(tiny==1)  fctrl_in.float_detect_tininess=FLOAT_TININESS_BEFORE_ROUNDING;
		if(tiny==100) begin
			$display("File finished!");
			$finish();
		end
		if(round==0) fctrl_in.float_rounding_mode=FLOAT_ROUND_NEAREST_EVEN;
		if(round==1) fctrl_in.float_rounding_mode=FLOAT_ROUND_DOWN;
		if(round==2) fctrl_in.float_rounding_mode=FLOAT_ROUND_UP;
		if(round==3) fctrl_in.float_rounding_mode=FLOAT_ROUND_TO_ZERO;
		fctrl_in.float_exception_flags=0;
		test_counter=test_counter+1;
		strobe_in=1'b1;
		//fctrl_tmp=fctrl_in;
		//float64_div(a_in, b_in, fctrl_in);
	end
end

endmodule



