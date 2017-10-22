module cnn( input             clock, 
	        input             reset, 
			output reg[8:0]   bvm_address, 
			output reg[8:0]   dim_address, 
			input  wire[15:0] dim_data_unreg, 
			input  wire[15:0] bvm_data_unreg
		  );

reg [15:0]  dim_data;
reg [15:0]  bvm_data;
wire [3:0]  i, j, step;
wire [1:0]  layer;
wire        wen_unregistered;
reg         wen;
wire [1:0]  quad_select_unregistered;
reg  [1:0]  quad_select;
wire [15:0] reg_read_data;
reg  [15:0] filter_data;
reg  [3:0]  write_address;

// Interface register *mandatory*
always@(posedge clock) begin //{
	bvm_address      <= {3'b000, layer, step};
	dim_address      <= {1'b0, i, j};
	dim_data         <= dim_data_unreg;
	bvm_data         <= bvm_data_unreg;
   // Controller outputs to be synchronized with data have to be registered
   quad_select      <= quad_select_unregistered;
   wen              <= wen_unregistered;
   write_address    <= bvm_address[3:0];
   filter_data      <= wen ? bvm_data : reg_read_data;
end //}

always@(*) begin
   if( wen )
      filter_data    = bvm_data;
   else
      filter_data    = reg_read_data;
end
		  
controller c0( .clock(clock), .reset(reset), .i(i), .j(j), .layer(layer), .step(step), .wen(wen_unregistered), .quad_select(quad_select_unregistered) );

register_file_9x16 r0( .clock(clock), .wen(wen), .write_bus(bvm_data), .read_bus(reg_read_data) );

initial begin
   $monitor("[%0t] %d %d %d [%x %6d] [%d %6d] [%x %6d] %d", $time, reset, i, j, dim_address, dim_data, step, bvm_data, bvm_address, filter_data, wen);
end

endmodule
