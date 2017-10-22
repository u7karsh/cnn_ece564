module cnn( 
   input             clock, 
   input             reset, 
   output reg[9:0]   bvm_address, 
   output reg[8:0]   dim_address, 
   input  wire[15:0] dim_data_unreg, 
   input  wire[15:0] bvm_data_unreg
);

// Interface signals
reg [15:0]  dim_data;
reg [15:0]  bvm_data;
wire [3:0]  i, j;
wire [1:0]  layer;
reg  [15:0] step1_filter;
wire [15:0] dom_data;
wire [9:0]  bvm_address_unreg;

// Buffered outputs from controller which have to be further delayed by
// 1 clock to sync with data which is 2 clocks delayed
wire        ready_3_3_unreg;
wire [1:0]  quad_select_unreg;
wire        wen_unreg;
wire        store_la_filter_unreg;
wire [2:0]  la_filter_addr_unreg;
wire [15:0] la_reg_out;
wire [1:0]  subblock_unreg;

// Controller outputs synced with data (2 clock delay)
reg         ready_3_3;
reg  [1:0]  quad_select;
reg         wen;
reg         store_la_filter;
reg  [2:0]  la_filter_addr;
wire [5:0]  step2_idx;
wire [31:0] step2_acc;
reg  [1:0] subblock;


reg  [15:0] out_3_3;
wire [15:0] out0, out1, out2, out3;
wire [15:0] reg_read_data;
reg  [15:0] step2_input_stasher;
wire [15:0] step2_input;
reg  [31:0] step2_reg_input;
wire [15:0] step2_filter;
wire [31:0] step2_output;

wire        tc;
assign tc            = 1'b1;
assign dom_data      = ( step2_output[31] ) ? 16'b0 : step2_output[31:16];
assign step2_filter  = (quad_select==0 & subblock==0) ? la_reg_out : bvm_data;
assign step2_input   = ready_3_3 ? out_3_3 : step2_input_stasher;

// Interface register *mandatory*
always@(posedge clock) begin //{
   bvm_address      <= bvm_address_unreg;
   dim_address      <= {1'b0, i, j};
   dim_data         <= dim_data_unreg;
   bvm_data         <= bvm_data_unreg;

   step1_filter     <= wen ? bvm_data : reg_read_data;

   // Controller outputs to be synchronized with data have to be registered
   // Since data is delayed by 2 cycles, we need to delay controller output
   // further by 1 clock
   quad_select      <= quad_select_unreg;
   wen              <= wen_unreg;
   ready_3_3        <= ready_3_3_unreg;
   store_la_filter  <= store_la_filter_unreg;
   la_filter_addr   <= la_filter_addr_unreg;
   subblock         <= subblock_unreg;

   if( ready_3_3 )
      step2_input_stasher   <= out_3_3;
end //}

always@(*) begin
   if( wen )
      step1_filter   = bvm_data;
   else
      step1_filter   = reg_read_data;
end

always@(*) begin //{
   case( quad_select )
      2'd0: out_3_3  = out0;
      2'd1: out_3_3  = out1;
      2'd2: out_3_3  = out2;
      2'd3: out_3_3  = out3;
   endcase
end //}


controller c0( .clock(clock), .reset(reset), .i(i), .j(j), .layer(layer), .wen(wen_unreg), .quad_select(quad_select_unreg), .ready_3_3(ready_3_3_unreg), .bvm_address(bvm_address_unreg), .la_filter_addr(la_filter_addr_unreg), .store_la_filter(store_la_filter_unreg), .subblock(subblock_unreg) );

sr_siso9   #(.WIDTH(16)) 
           s0( .clock(clock), .wen(wen), .write_bus(bvm_data), .read_bus(reg_read_data) );

// 4 Quadrants
quadrant   q0( .clock(clock), .clear(ready_3_3), .a(dim_data), .b(step1_filter), .out(out0) );
quadrant   q1( .clock(clock), .clear(ready_3_3), .a(dim_data), .b(step1_filter), .out(out1) );
quadrant   q2( .clock(clock), .clear(ready_3_3), .a(dim_data), .b(step1_filter), .out(out2) );
quadrant   q3( .clock(clock), .clear(ready_3_3), .a(dim_data), .b(step1_filter), .out(out3) );

always@(*) begin //{
   case( wen & (layer==0) )
      1'b0:  step2_reg_input = step2_output;
      1'b1:  step2_reg_input = 32'b0;
   endcase
end //}

// Step2 MAC
DW02_mac #( .A_width(16), .B_width(16) ) step2 ( .A(step2_input), .B(step2_filter), .C(step2_acc), .MAC(step2_output), .TC(tc) );
//TODO
sr_siso9   #(.WIDTH(32)) 
           s1( .clock(clock), .wen(1'b1), .write_bus(step2_reg_input), .read_bus(step2_acc) );

register_file_9x16 r0 ( .clock(clock), .wen(store_la_filter), .address({1'b0,la_filter_addr}), .write_bus(bvm_data), .read_bus(la_reg_out) );
initial begin
   $monitor("[%0t] %d %d %d [%x %6d] [%d %6d] [%x %6d] %d %d %d %d [%d %d %d %d] %d [%d %d %d %x : %d %x %d] [%d %d %d]", $time, reset, i, j, dim_address, dim_data, c0.step, bvm_data, bvm_address, step1_filter, wen, ready_3_3, step2_input, quad_select, step2_input, step2_filter, step2_acc, step2_output, dom_data, c0.store_look_ahead_filter, c0.look_ahead_filter_addr, c0.look_ahead_lower_addr, c0.bvm_address, store_la_filter, la_filter_addr, la_reg_out, c0.layer, c0.next_step2_idx_lower_nibble, c0.step2_idx);
end

endmodule
