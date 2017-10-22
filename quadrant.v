module quadrant( input  clock, 
				 input  clear, 
				 input  wire[15:0] a, 
				 input  wire[15:0] filter, 
				 output reg [15:0] c 
	           );

wire [31:0] data_out_wo_truncate;
reg  [31:0] acc_data_in_mac;
wire [15:0] c_unregistered;

// Unsynthesizable emulation of MAC
task dw_mac;
	input  wire signed [15:0] a;
	input  wire signed [15:0] b;
	input  wire signed [31:0] acc;
	output wire signed [31:0] acc_out;
	acc_out = acc + a*b;
endtask

//TODO: study the effect of removing acc_data_in_mac from register
always@(posedge clock) begin //{
	if( clear ) begin //{
		acc_data_in_mac <= 0;
		c               <= 0;
	end //}
	else begin //{
		acc_data_in_mac <= data_out_wo_truncate;
		c               <= c_unregistered;
	end //}
end //}

// truncate logic
assign c_unregistered = ( data_out_wo_truncate[31] ) ? 16'b0 : data_out_wo_truncate[31:16];

dw_mac( a, filter, acc_data_in_mac, data_out_wo_truncate );

endmodule