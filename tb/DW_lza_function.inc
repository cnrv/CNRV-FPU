function automatic [addr_width-1:0] DWF_lza(input [width-1:0] A, input [width-1:0] B);
	int pos;
	if(A == B) begin
		pos = {addr_width{1'b1}};
	end
	else begin
		for (int i = width-1; i >=0; i=i-1) begin
			logic lza;
			if(i == 0) begin
				lza =  (A[i]&!B[i])|(!A[i]&B[i]);      
			end
			else begin
				lza = ((A[i]&!B[i])&!(!A[i-1]&B[i-1]))|((!A[i]&B[i])&!(!A[i-1]&B[i-1]));
			end
			if (lza) begin
				pos = width -i-1; 
				break;
			end 
		end
	end
	return pos;
endfunction
