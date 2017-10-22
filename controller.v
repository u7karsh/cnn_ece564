module controller( input  wire       clock,         // Posedge sampling event
	               input  wire       reset,         // Synchronous active high
				   output wire [3:0] i,             // Pixel address
				   output wire [3:0] j,             // Pixel address
				   output reg  [1:0] layer,         // Filter address
				   output reg  [3:0] step,          // Filter address (0-8) *only* (not registered)
				   output reg        wen,     // Storing/Using filter in/from register file *only*. 1 => store, 0 => retrieve
				   output reg  [1:0] quad_select    // Control signal for 4 modules on each quadrant
				  ); //{

//----------------------- INTERNAL SIGNALS BEGINS -----------------------------
// State machine variables
reg        inc_sub_quad_row;
reg  [1:0] sub_quad_select;
reg  [1:0] sub_quad_col, next_quad_col;
reg  [1:0] sub_quad_row;

// Async logic variables
reg  [2:0] next_quad_row;
reg  [2:0] next_sub_quad_select;
reg  [2:0] next_quad_select;
reg  [2:0] next_layer;
reg  [3:0] partial_i, partial_j;
wire       done_3_3;
//----------------------- INTERNAL SIGNALS ENDS -------------------------------

// Placeholder wire
assign done_3_3  = next_quad_row[2];

// i,j index vars to be fed as address
// They need not be registerd as they will directly get attached
// to a reg on the module instantiating controller
assign i         = partial_i + {2'b00, sub_quad_row};
assign j         = partial_j + {2'b00, sub_quad_col};

//TODO: Do an analysis on timing as it is async

//---------------------------- SYNC LOGIC BEGINS ------------------------------
always@( posedge clock ) begin //{
   if( reset ) begin //{
	   quad_select      <= 0;
	   sub_quad_select  <= 0;
	   sub_quad_col     <= 0;
	   sub_quad_row     <= 0;
	   layer            <= 0;
      wen              <= 0;
   end //}
   else begin //{
	   sub_quad_col     <= next_quad_col;
	   sub_quad_row     <= next_quad_row[1:0];
	   sub_quad_select  <= next_sub_quad_select[1:0];
	   quad_select      <= next_quad_select[1:0];
	   layer            <= next_layer[1:0];
      wen              <= &{~quad_select, ~sub_quad_select};
   end //}
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
	case( sub_quad_col )
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
	endcase
end //}

// Optimized to eliminate multiplier and adder from the following equations
// partial_ij: between {}
// i = { (quad_select[0] * 6) + (sub_quad_select[0] * 3) } + sub_quad_row;
// j = { (quad_select[1] * 6) + (sub_quad_select[1] * 3) } + sub_quad_col;
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

// Add one to sub_quad
always@(*)
	add_one_2bit( {next_quad_row[2], sub_quad_select}, next_sub_quad_select );

// Add one to quad_select
always@(*)
	add_one_2bit( {next_sub_quad_select[2], quad_select}, next_quad_select );
	
// Add one to layer
always@(*)
	add_one_2bit( {next_quad_select[2], layer}, next_layer );
	
// Compute partial i and j
always@(*) begin //{
	compute_partial_ij( {quad_select[1], sub_quad_select[1]}, partial_i );
	compute_partial_ij( {quad_select[0], sub_quad_select[0]}, partial_j );
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
