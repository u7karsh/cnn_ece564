module controller( 
   input  wire       clock,         // Posedge sampling event
   input  wire       reset,         // Synchronous active high
   output wire [3:0] i,             // Pixel address
   output wire [3:0] j,             // Pixel address
   output reg  [1:0] layer,         // Filter address
   output reg        wen,           // Storing/Using filter in/from register file *only*. 1 => store, 0 => retrieve
   output reg  [1:0] quad_select,   // Control signal for 4 modules on each quadrant
   output reg  [9:0] bvm_address,
   output reg        ready_3_3,     // Marks completion of a 3x3 unit
   output reg        store_la_filter,
   output reg  [2:0] la_filter_addr,
   output reg  [1:0] subblock //TODO
); //{

//----------------------- INTERNAL SIGNALS BEGINS -----------------------------
// Registers 
reg        inc_sub_quad_row;
reg  [1:0] sub_quad_select;
reg  [1:0] sub_quad_col, next_quad_col;
reg  [1:0] sub_quad_row;
reg  [1:0] quad_select_int;
reg        new_3b;
reg  [5:0] step2_idx;
reg  [3:0] next_step2_idx_lower_nibble;

// Async logic variables
reg  [2:0] next_quad_row;
reg  [2:0] next_sub_quad_select;
reg  [2:0] next_quad_select;
reg  [2:0] next_layer;
reg  [3:0] partial_i, partial_j;
wire        wen_next;
wire        store_look_ahead_filter;
wire [2:0]  look_ahead_filter_addr;
reg  [2:0]  look_ahead_filter_addr_plus_one;
reg  [3:0]  step;
reg  [5:0]  look_ahead_lower_addr;
//----------------------- INTERNAL SIGNALS ENDS -------------------------------

// i,j index vars to be fed as address
// They need not be registerd as they will directly get attached
// to a reg on the module instantiating controller
assign i                       = partial_i + {2'b00, sub_quad_row};
assign j                       = partial_j + {2'b00, sub_quad_col};
assign wen_next                = &(~{quad_select_int, sub_quad_select});
assign store_look_ahead_filter = quad_select_int[1] & next_quad_row[2];
assign look_ahead_filter_addr  = {quad_select_int[0], sub_quad_select};

//assign next_ready_3_3   = reset ? 1'b1 : next_quad_row[2];
//TODO: Do an analysis on timing as it is async

//---------------------------- SYNC LOGIC BEGINS ------------------------------
always@( posedge clock ) begin //{
   if( reset ) begin //{
      quad_select_int         <= 0;
      sub_quad_select         <= 0;
      sub_quad_col            <= 0;
      {new_3b, sub_quad_row}  <= 3'b100;
      layer                   <= 0;
   end //}
   else begin //{
      // Following signals are synced with i, j or address calculating logic
      // Since address calculating logic runs ahead of time, the following
      // need not be delayed
      sub_quad_col            <= next_quad_col;
      {new_3b, sub_quad_row}  <= next_quad_row;
      sub_quad_select         <= next_sub_quad_select[1:0];
      layer                   <= next_layer[1:0];
      quad_select_int         <= next_quad_select[1:0];

   end //}
end //}

// Interface signals
// Since these signals are calculated using address, they need to be
// delayed by one clock for the read cycle synchronization
// NOTE: the following signals have to be calculated using FF outputs
// not async outputs to maintain synchronization
// TODO: Optimize
// Values that are derived must be added to non-resettable FF as they take up
// less space
always@(posedge clock) begin //{
   quad_select         <= quad_select_int;
   wen                 <= wen_next;
   ready_3_3           <= new_3b;
   la_filter_addr      <= store_look_ahead_filter ? look_ahead_filter_addr : step;
   store_la_filter     <= store_look_ahead_filter;
   subblock            <= sub_quad_select;
   step2_idx           <= {layer, next_step2_idx_lower_nibble};
end //}
//---------------------------- SYNC LOGIC ENDS --------------------------------

//---------------------------- COMMON TASKS BEGINS ----------------------------	
// Not using ripple adder as synopsys *might* simplify this further
// TODO: replace with ripple adder and check perf
task add_one_2bit;
   input  [2:0] in_data;
   output [2:0] out_data;
   case( in_data )
      3'b000: out_data = 3'b000;
      3'b001: out_data = 3'b001;
      3'b010: out_data = 3'b010;
      3'b011: out_data = 3'b011;

      3'b100: out_data = 3'b001;
      3'b101: out_data = 3'b010;
      3'b110: out_data = 3'b011;
      3'b111: out_data = 3'b100; // Just for overflow checking
   endcase
endtask	
//---------------------------- COMMON TASKS ENDS ------------------------------	

//---------------------------- ASYNC LOGIC BEGINS -----------------------------
always@(*) begin //{
   case( sub_quad_col ) //{
      2'b00  : begin //{
         next_quad_col    = 1;
         inc_sub_quad_row = 0;
      end //} 

      2'b01  : begin //{
         next_quad_col    = 2;
         inc_sub_quad_row = 0;
      end //} 

      2'b10  : begin //{
         next_quad_col    = 0;
         inc_sub_quad_row = 1;
      end //} 

      default: begin //{
         next_quad_col    = 0;
         inc_sub_quad_row = 0;
      end //} 
   endcase //}
end //}

// Optimized to eliminate multiplier and adder from the following equations
// partial_ij: between {}
// i = { (quad_select_int[0] * 6) + (sub_quad_select[0] * 3) } + sub_quad_row;
// j = { (quad_select_int[1] * 6) + (sub_quad_select[1] * 3) } + sub_quad_col;
task compute_partial_ij;
   input  [1:0] ij_multipliers;
   output [3:0] partial_ij;
   case( ij_multipliers )
      2'b00: partial_ij = 4'd0;
      2'b01: partial_ij = 4'd3;
      2'b10: partial_ij = 4'd6;
      2'b11: partial_ij = 4'd9;
   endcase
endtask

// Add one to row.
// Not using ripple adder as synopsys *might* simplify this further
// TODO: replace with ripple adder and check perf
always@(*) begin //{
   case( {inc_sub_quad_row, sub_quad_row} )
      3'b000 : next_quad_row = 3'b000;
      3'b001 : next_quad_row = 3'b001;
      3'b010 : next_quad_row = 3'b010;

      3'b100 : next_quad_row = 3'b001;
      3'b101 : next_quad_row = 3'b010;
      // Just for overflow checking and marking the completion of 3x3 process
      3'b110 : next_quad_row = 3'b100;

      default: next_quad_row = 3'b000;
   endcase
end //}

// b vector address decoding logic
always@(*) begin //{
   casex( {wen_next, store_look_ahead_filter} )
      2'b10: bvm_address = {4'b0000, layer, step};
      //TODO
      2'b00: bvm_address = 10'h40 + {step, step2_idx};
      2'bx1: bvm_address = 10'h40 + {1'b0, look_ahead_filter_addr, look_ahead_lower_addr};
   endcase
end //}

always@(*) begin //{
   case( layer )
      2'd0 : look_ahead_lower_addr = 6'h0F;
      2'd1 : look_ahead_lower_addr = 6'h1F;
      2'd2 : look_ahead_lower_addr = 6'h2F;
      2'd3 : look_ahead_lower_addr = 6'h3F;
   endcase
end //}

// step2_idx decoder
always@(*) begin //{
   case( {next_quad_select[1:0], next_sub_quad_select[1:0]} )
      4'b00_00: next_step2_idx_lower_nibble = 4'hF;
      4'b00_01: next_step2_idx_lower_nibble = 4'h0;
      4'b00_10: next_step2_idx_lower_nibble = 4'h1;
      4'b00_11: next_step2_idx_lower_nibble = 4'h4;

      4'b01_00: next_step2_idx_lower_nibble = 4'h5;
      4'b01_01: next_step2_idx_lower_nibble = 4'h2;
      4'b01_10: next_step2_idx_lower_nibble = 4'h3;
      4'b01_11: next_step2_idx_lower_nibble = 4'h6;

      4'b10_00: next_step2_idx_lower_nibble = 4'h7;
      4'b10_01: next_step2_idx_lower_nibble = 4'h8;
      4'b10_10: next_step2_idx_lower_nibble = 4'h9;
      4'b10_11: next_step2_idx_lower_nibble = 4'hC;

      4'b11_00: next_step2_idx_lower_nibble = 4'hD;
      4'b11_01: next_step2_idx_lower_nibble = 4'hA;
      4'b11_10: next_step2_idx_lower_nibble = 4'hB;
      4'b11_11: next_step2_idx_lower_nibble = 4'hE;
   endcase
end //}

// Custom logic instead of ripple adder might save some space
always@(*) begin //{
   case( look_ahead_filter_addr )
      3'b000: look_ahead_filter_addr_plus_one = 3'b001;
      3'b001: look_ahead_filter_addr_plus_one = 3'b010;
      3'b010: look_ahead_filter_addr_plus_one = 3'b011;
      3'b011: look_ahead_filter_addr_plus_one = 3'b100;
      3'b100: look_ahead_filter_addr_plus_one = 3'b101;
      3'b101: look_ahead_filter_addr_plus_one = 3'b110;
      3'b110: look_ahead_filter_addr_plus_one = 3'b111;
      3'b111: look_ahead_filter_addr_plus_one = 3'b000;
   endcase
end //}

// Add one to sub_quad
always@(*)
   add_one_2bit( {next_quad_row[2], sub_quad_select}, next_sub_quad_select );

// Add one to quad_select_int
always@(*)
   add_one_2bit( {next_sub_quad_select[2], quad_select_int}, next_quad_select );

// Add one to layer
always@(*)
   add_one_2bit( {next_quad_select[2], layer}, next_layer );

// Compute partial i and j
always@(*) begin //{
   compute_partial_ij( {quad_select_int[1], sub_quad_select[1]}, partial_i );
   compute_partial_ij( {quad_select_int[0], sub_quad_select[0]}, partial_j );
end //}

// Compute step
// No need to register as this will go into register instantiating this module
always@(*) begin //{
   case( {sub_quad_row, sub_quad_col} )
      {2'd0, 2'd0} : step = 0;
      {2'd0, 2'd1} : step = 1;
      {2'd0, 2'd2} : step = 2;

      {2'd1, 2'd0} : step = 3;
      {2'd1, 2'd1} : step = 4;
      {2'd1, 2'd2} : step = 5;

      {2'd2, 2'd0} : step = 6;
      {2'd2, 2'd1} : step = 7;
      {2'd2, 2'd2} : step = 8;
      default      : step = 0;
   endcase
end //}
//---------------------------- ASYNC LOGIC ENDS -------------------------------

endmodule //}controller
