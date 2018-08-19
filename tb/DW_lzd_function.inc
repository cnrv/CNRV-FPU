function automatic [addr_width:0] DWF_lzd_enc(input [a_width-1:0]  A);
	logic [addr_width:0]   temp;
	temp = {addr_width+1{1'b1}};
	for(int i=0; i<a_width; i=i+1) begin
		if (A[a_width-1-i] == 1'b1) begin
			temp = i;
			break;
		end
	end
	return temp;
endfunction
