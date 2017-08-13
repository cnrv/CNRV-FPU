
`include "R5FP_div.v"
function automatic int16 extractFloat32Exp( float32 a );
    return ( a>>23 ) & 'hFF;
endfunction

module test_div_float ();

logic clk, rst_n, strobe_in;
bits64 aRef_in, bRef_in;
bits65 a_in, b_in;
float_ctrl_t fctrl_in;
bits64 result, result_right;
bits65 result_out;
float_ctrl_t fctrl_out;
float_ctrl_t fctrl_tmp;
logic valid_out;
int test_counter;
int tiny, round;
integer fd;
float_exception_flags_t flags_right;

R5FP_exp_incr #(
	.SIG_W(52),
	.EXP_W(11)) a_incr (.a(aRef_in), .z(a_in));

R5FP_exp_incr #(
	.SIG_W(52),
	.EXP_W(11)) b_incr (.a(bRef_in), .z(b_in));


R5FP_div_seq U_float_div_seq (.is_single_in(1'b0), .*);

R5FP_exp_decr #(
	.SIG_W(52),
	.EXP_W(11)) U_decr (.a(result_out), .z(result));

initial begin
fd = $fopen("../test_cases/test_case_float64_div_L2.txt", "r");

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
		fctrl_imp.float_exception_flags[4:3]=0; //TODO
		flags_right[4:3]=0; //TODO
		ok=(result_right==result && flags_right==fctrl_imp.float_exception_flags);
		if(result_right[62:52]==11'h7FF && result[62:52]==11'h7FF) ok=1'b1; //TODO
		if(!ok) begin
			$display("tiny:%d round:%d, a:%b-%h-%h b:%b-%h-%h resRight:%b.%h.%h flagRight:%b : result:%b.%h.%h(%b.%h.%h) flag:%b", tiny, round, 
			a_in[63],a_in[62:52],a_in[51:0],
			b_in[63],b_in[62:52],b_in[51:0],
			result_right[63],result_right[62:52],result_right[51:0],flags_right,  
			result[63],result[62:52],result[51:0],
			result_out[64],result_out[63:52],result_out[51:0],
			fctrl_imp.float_exception_flags);
			$finish(2);
		end
		else begin
			//$display("PASS! %d %d, %h %h %h %h : %h %h", tiny, round, a_in,b_in,result_right,flags_right,  result, fctrl_imp.float_exception_flags);
		end
	end
	if(strobe_in==1'b1) strobe_in=1'b0;
	if(test_counter==0 || valid_out) begin
		$fscanf(fd, "%d %d %h %h %h %h", tiny, round, aRef_in, bRef_in, result_right, flags_right);
		//finish_loop=0;
		//while (!finish_loop) begin
		//	$fscanf(fd, "%d %d %h %h %h %h", tiny, round, aRef_in, bRef_in, result_right, flags_right);
		//	finish_loop=1;
		//	if(extractFloat32Exp(aRef_in)==0&&is_single) finish_loop=0;
		//	else if(extractFloat64Exp(aRef_in)==0&&!is_single) finish_loop=0;
		//	else if(extractFloat32Exp(bRef_in)==0&&is_single) finish_loop=0;
		//	else if(extractFloat64Exp(bRef_in)==0&&!is_single) finish_loop=0;
		//end
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



