
module R5FP_sqrt_seq_wrap #(
	parameter EXP_W=5,
	parameter SIG_W=6) (
	input [EXP_W+SIG_W:0] a,
    input  [2:0] rnd,
    output [7:0] status,
	output [EXP_W+SIG_W:0] z,
	input clk,reset,strobe,
	output ready, complete);

wire [EXP_W+SIG_W+1:0] ax,zx;

R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) a_i (.a(a), .z(ax));

R5FP_sqrt_seq #(.SIG_W(SIG_W), .EXP_W(EXP_W+1)) sqrt (.a_in(ax), .rnd_in(rnd), 
            .clk(clk), .reset(reset), .strobe(strobe), .complete(complete), .ready(ready),
            .z(zx), .status(status));

R5FP_exp_decr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) z_d (.a(zx), .z(z));

endmodule


module tb_R5FP_sqrt;
parameter ClockPeriod=10;
parameter SIG_W=7;
parameter EXP_W=7;
parameter [2:0] rnd=`RND_MODE;
bit clk,reset,strobe,complete,ready,strobe_r;

bit[SIG_W+EXP_W:0] a;
const bit[SIG_W+EXP_W:0] startVal=({1'b0,{EXP_W{1'b0}},{SIG_W{1'b0}}});
const bit[SIG_W+EXP_W:0] endVal={1'b0,{EXP_W{1'b1}}, {SIG_W{1'b1}}};

typedef struct packed {
	logic[SIG_W+EXP_W:0] a;
	logic[SIG_W+EXP_W:0] z;
	logic[7:0] status;
} result_t;
result_t resQ[$];

initial begin
  strobe=1'b0;
  a=startVal;
  reset=1'b1;
  #25
  reset=1'b0;
end
initial begin
  clk=1'b0;
  #1
  forever clk=#(ClockPeriod/2)~clk;
end
wire #1 clk_delayed=clk;

logic[SIG_W+EXP_W:0] z0,z1;
logic[7:0] status0,status1;

DW_fp_sqrt #(.sig_width(SIG_W), .exp_width(EXP_W), .ieee_compliance(1)) r (
	.a(a), .rnd(rnd), .z(z0), .status(status0));

always @(posedge clk_delayed) begin
	if(strobe) begin
		strobe<=1'b0;
	end
	else if(reset==1'b0&&ready==1'b1&&$urandom()%2==0) begin
		if(a%100000==0) $display(a);
		a<=a+1;
		if(a==endVal) begin
			$display("All Done");
			$finish();
		end
		strobe<=1'b1;
	end
	strobe_r<=strobe;
	if(strobe_r) begin
		result_t res;
		res.a=a;
		res.z=z0;
		res.status=status0;
		//$display("PUSH: a:%b z:%b status:%b",a,z0,status0);
		resQ.push_back(res);
	end
end

R5FP_sqrt_seq_wrap #(.SIG_W(SIG_W), .EXP_W(EXP_W)) i (.a(a), .rnd(rnd), 
            .clk(clk), .reset(reset), .strobe(strobe), .complete(complete), .ready(ready),
            .z(z1), .status(status1));

logic cmpOK;
always_ff @(negedge clk) begin
	if(complete) begin
		result_t res;
		res=resQ.pop_front();
		//$display("POP: a:%b z:%b status:%b",res.a,res.z,res.status);
		if(res.a==endVal) $finish();
		cmpOK=(res.z==z1&&res.status==status1);
		if(cmpOK) $display("Pass! %b", res.a);
		assert(cmpOK) else begin
			$display("z0:%b_%b a:%b_%b",res.z[EXP_W-1+SIG_W:SIG_W],res.z[SIG_W-1:0],res.a[EXP_W-1+SIG_W:SIG_W], res.a[SIG_W-1:0]);
			$display("z1:%b_%b",z1[EXP_W-1+SIG_W:SIG_W],z1[SIG_W-1:0]);
			$display("status0 %b",res.status);
			$display("status1 %b",status1);
			$finish();
		end
	end
end

endmodule
	
