
`include "R5FP_inc.vh"

module R5FP_int_sqrt #(parameter W=32) (input [W-1:0] num_in, 
                     input clk,reset,strobe, output logic complete,
                     output logic [W-1:0] res, rem, 
					 output logic rem_s);
logic[W-1:0] b,b0,num;
logic[W:0] aBar;
logic bPulsResHigh;

assign b0=({2'b01,{(W-2){1'b0}}}>>2);

logic finished;
always_ff @(posedge clk) begin
	if(reset) begin
		finished<=0;
	end
	else if(strobe) begin
		finished<=1'b0;
	end
	else if(!finished) begin
		finished<=((b>>1)==0);
	end
end
always_ff @(posedge clk) begin
	if(reset) begin
		complete<=0;
	end
	else if(complete) begin
		complete<=1'b0;
	end
	else if(!finished) begin
		complete<=((b>>1)==0);
	end
end
always_ff @(posedge clk) begin
	//$display("num:%b res:%b b:%b finished:%b",num,res,b,finished);
	if(strobe) begin
		if(num_in[W-1:W-3]!==3'bxxx) begin
			assert(num_in[W-1:W-3]==3'b001||num_in[W-1:W-4]==4'b0001) else begin
				$display("num_in: %b",num_in);
				$finish();
			end
		end
		res<=0;
		num<=num_in;
		if(b>num) begin
			b<=b0>>2;
		end
		else begin
			b<=b0;
		end
	end
	else if(!finished) begin
		logic[W-1:0] num0,res0;
		logic[W:0] a,a0;
		a0=({1'b0,num[W-1:0]}-
		    {1'b0,res[W-1:0]+b[W-1:0]});
		a=~(~{1'b0,num[W-1:0]}+1'b1+{(W+1){1'b1}}+
		     {1'b0,res[W-1:0]+b[W-1:0]});
		assert(a===a0) else begin
			$display("%b_%b",num[W-1],{num[W-2:W/4],{(W/4){1'b0}}});
			$display("%b_%b",res[W-1],{res[W-2:W/4],{(W/4){1'b0}}});
			$display("%b_%b",  b[W-1],{  b[W-2:W/4],{(W/4){1'b0}}});
			$display(" a:%b \na0:%b \nnum:%b \nres:%b \n  b:%b",a,a0,num,res,b);
			$finish();
		end
		if(a[W-1]==1'b0) begin //num>=res+b
			num0=a[W-1:0]; // num-=res+b;
			res0=((res>>1)|b);
		end
		else begin
			num0=num;
			res0=res>>1;
		end
		b<=b>>1;
		res<=res0<<1;
		num<=num0<<1;
		rem_s<=a[W-1];
	end
end

assign rem=num;

endmodule

module R5FP_sqrt_seq #(parameter SIG_W=23, parameter EXP_W=8) (
                       input [SIG_W+EXP_W:0] a_in, input  [2:0] rnd_in,
                       input clk, reset, strobe, output reg complete, ready,
                       output reg [SIG_W+EXP_W:0] z, output reg [7:0] status);

logic[SIG_W+EXP_W:0] a;
logic[2:0] rnd;
logic strobe_r;
always_ff @(posedge clk) begin
	if(reset) begin
		a<=0;
		rnd<=0;
	end
	else if(strobe) begin
		a<=a_in;
		rnd<=rnd_in;
	end
	strobe_r<=strobe;
end
typedef enum {IDLE, WAIT, OUTPUT} state_t;
state_t state_r;
wire isqrtComplete;
logic isZero,isInf,isNAN,isZero_r,isInf_r,isNAN_r;

always_ff @(posedge clk) begin
	//`DEBUG("state_r:%b isZero:%b isInf:%b isNAN:%b ready:%b complete:%b strobe:%b",state_r,isZero,isInf,isNAN,ready,complete,strobe);
	if(reset) begin
		state_r<=IDLE;
	end
	else begin
		case(state_r)
		IDLE: begin
			if(strobe_r) begin
				state_r<=( ({isZero,isInf,isNAN}==0)? WAIT : OUTPUT );
			end
		end
		WAIT: begin
			if(isqrtComplete) state_r<=OUTPUT;
		end
		OUTPUT: begin
			state_r<=IDLE;
		end
		endcase
	end
end

logic[SIG_W+3:0] sigA,sigZ,sigA_r;
logic[SIG_W+4:0] res,rem,res_r,res_sh,rem_r;
logic rem_s;
logic[EXP_W+1:0] expA,expZ,expZ0,expZ_r;
logic[SIG_W+EXP_W:0] z_pre;
logic[SIG_W-1:0] s0,s;
logic [7:0] status_pre;

function void prepare();
	expA=a[EXP_W-1+SIG_W:SIG_W];
	s0=a[SIG_W-1:0];

	s=s0;
	assert(expA!=0);

	if(expA==0&&s0[SIG_W-1]==1'b1) begin
		s=s<<1;
		expA=1;
		sigA={3'b001,s,1'b0};
		//`DEBUG("Here2 s:%b sigA:%b",s,sigA);
	end
	else begin
		if(expA[0]==1'b0) begin
			expA=expA+1;
			sigA={3'b001,s,1'b0};
		end
		else begin
			expA=expA+2;
			sigA={4'b0001,s};
		end
	end
	expZ=((expA - {EXP_W-1{1'b1}})>>1)+{EXP_W-1{1'b1}}-1;
	isZero=(a[EXP_W-1+SIG_W:0]==0);
	isInf=((&a[EXP_W-1+SIG_W:SIG_W])==1 && a[SIG_W-1:0]==0);
	isNAN=((&a[EXP_W-1+SIG_W:SIG_W])==1 && a[SIG_W-1:0]!=0);
	//`DEBUG("here2 isInf:%b isNAN:%b a:%b.%b",isInf,isNAN, a[EXP_W-1+SIG_W:SIG_W], a[SIG_W-1:0]);
endfunction

always_comb begin
	prepare();
end

//always_ff @(negedge clk) begin
//	$display("sigA:%b expZ:%b a:%b strobe_r:%b state_r:%b ready:%b complete:%b",sigA,expZ,a,strobe_r,state_r[2:0],ready,complete);
//end
always_ff @(posedge clk) begin
	if(strobe_r) begin
		//$display("HERE sigA:%b expZ:%b a:%b strobe_r:",sigA,expZ,a,strobe_r);
		expZ_r<=expZ;
		sigA_r<=sigA;
		isZero_r<=isZero;
		isInf_r<=isInf;
		isNAN_r<=isNAN;
	end
end

logic isqrtStrobe;
always @(posedge clk) begin
	if(reset) begin
		isqrtStrobe<=1'b0;
	end
	else if(isqrtStrobe) begin
		isqrtStrobe<=1'b0;
	end
	else if(state_r==IDLE&&strobe_r) begin
		isqrtStrobe<=1'b1;
	end
end
R5FP_int_sqrt #(.W(SIG_W+5)) isqrt (.num_in({sigA_r,1'b0}), .res(res), .rem(rem), .rem_s(rem_s),
                     .clk(clk), .reset(reset), .strobe(isqrtStrobe), .complete(isqrtComplete));
always_ff @(posedge clk) begin
	if(state_r==WAIT&&isqrtComplete) begin
		//`DEBUG("HERE2 sigA_r:%b res:%b rem:%b rem_s:%b res*res:%b res*res+rem:%b a:%b complete:%b",sigA_r,res,rem,rem_s, {{SIG_W+5{1'b0}},res}*{{SIG_W+5{1'b0}},res}, {{SIG_W+5{1'b0}},res}*{{SIG_W+5{1'b0}},res}+rem,a,complete);
		res_r<=res;
		rem_r<=rem;
	end
end

reg [6:0] status_tmp;
always @(*) begin
	status_tmp=0;
	status_tmp[`STICKY]=(rem_r!=0);
	res_sh=res_r;
	if(res_sh[SIG_W+3]==0) res_sh=res_sh<<1;
end
R5FP_postproc #(
        .I_SIG_W(SIG_W+5),
        .SIG_W(SIG_W),
        .EXP_W(EXP_W)) pp (
        .aStatus(status_tmp),
		.aSign(1'b0),
        .aExp({1'b1, {EXP_W-1{1'b0}}}),
        .aSig(res_sh),
		.tailZeroCnt({EXP_W{1'b0}}),
        .rnd(rnd),
        .z(z_pre),
        .status(status_pre));

always_comb begin
	expZ0=expZ_r;
	if(rnd==`RND_UP||rnd==`RND_FROM_ZERO) begin
		expZ0=expZ0+z_pre[SIG_W];
	end
	z={1'b0,expZ0[EXP_W-1:0],z_pre[SIG_W-1:0]};
	status=0;
	status[`Z_INEXACT]=status_pre[`Z_INEXACT];
	if(rnd==`RND_NEAREST_EVEN) begin
		if(rem_r) status[`Z_IS_ZERO]=1'b0;
	end

	if(isZero_r) begin //zero
		z=0;
		status=8'b00000001;
	end
	else if(isInf_r) begin //Infinity
		z=a;
		status=0;
		status[`Z_IS_INF]=1'b1;
	end
	else if(isNAN_r) begin //NAN
		z={1'b1, {EXP_W-1{1'b1}}, {SIG_W-1{1'b0}}, 1'b1};
		status=0;
		status[`Z_INVALID]=1'b1;
	end
end

always_ff @(posedge clk) begin
	if(reset) begin
		ready<=1'b1;
	end
	else if(strobe) begin
		ready<=1'b0;
	end
	else if(state_r==OUTPUT) begin
		ready<=1'b1;
	end
end
always_ff @(posedge clk) begin
	if(reset) begin
		complete<=1'b0;
	end
	else if(state_r==OUTPUT) begin
		complete<=1'b0;
	end
	else if(state_r==WAIT&&isqrtComplete) begin
		complete<=1'b1;
		//$display("HERE3 sigA_r:%b res:%b rem:%b a:%b complete:%b",sigA_r,res,rem,a,complete);
	end
end

endmodule
