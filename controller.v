/*H**********************************************************************
* FILENAME    :       controller.v 
* DESCRIPTION :       Control logic for entire CNN project. Includes address
*                     generation, control signals
*
* AUTHOR      :       Utkarsh Mathur           START DATE :    14 Oct 17
*
* CHANGES :
*
*H***********************************************************************/

module controller( 
   input  wire       clock,         // Posedge sampling event
   input  wire       reset,         // Synchronous active high
   input  wire       go,
   output reg        finish,
   output wire [3:0] i,             // Pixel address
   output wire [3:0] j,             // Pixel address
   output reg  [1:0] layer,         // Filter address
   output reg  [2:0] dom_address,   // dom address runs one clock delayed as compared to others as it is write. add a FF
   output reg        dom_ready,
   output reg        wen,           // Storing/Using filter in/from register file *only*. 1 => store, 0 => retrieve
   output reg  [1:0] quad_select,   // Control signal for 4 modules on each quadrant
   output reg  [9:0] bvm_address,
   output reg        ready_3_3,     // Marks completion of a 3x3 unit
   output reg        store_la_filter,
   output reg  [2:0] la_filter_addr,
   output reg  [1:0] subblock //TODO
); //{

// Architecture selector
// 0 => simple         : Gives all outputs in 12*12 + 36 cycles
// 1 => max_throughput : Adds an SISO which stores m vectors in last 8 dummy
//                       cycles. Gives 1st output in 12*12 + 8 cycles then
//                       subsequent ones in 12*12 cycles at the cost of
//                       9 16bit registers

// synopsys template
parameter ARCH_SELECTOR = 0;

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
wire       wen_next;
wire       store_look_ahead_filter;
wire [2:0] look_ahead_filter_addr;
reg  [2:0] look_ahead_filter_addr_plus_one;
reg  [3:0] step;
reg  [3:0] step_reg;
reg  [5:0] look_ahead_lower_addr;
reg        next_process_started, process_started;

// Signals specifically to incorporate arch0
wire       arch0_add_skip_next;
reg        arch0_add_skip;
reg        next_sub_quad_overflow;
//----------------------- INTERNAL SIGNALS ENDS -------------------------------

// i,j index vars to be fed as address
// They need not be registerd as they will directly get attached
// to a reg on the module instantiating controller
// Adders for 1, j are required
assign i                       = partial_i + {2'b00, sub_quad_row};
assign j                       = partial_j + {2'b00, sub_quad_col};
assign wen_next                = &(~{quad_select_int, sub_quad_select});

generate
   if     ( ARCH_SELECTOR == 0 ) begin : gen_look_ahead_add_skip_1 //{
      assign store_look_ahead_filter = 1'b0;
      assign arch0_add_skip_next     = ( &{new_3b, sub_quad_select[1:0], quad_select_int[1:0]} ) ? ~arch0_add_skip : arch0_add_skip;
   end //}
   else if( ARCH_SELECTOR == 1 ) begin : gen_look_ahead_add_skip_2 //{
      assign store_look_ahead_filter = quad_select_int[1] & next_quad_row[2];
      assign arch0_add_skip_next     = 1'b0;
   end //}
endgenerate


assign look_ahead_filter_addr  = {quad_select_int[0], sub_quad_select};

//---------------------------- SYNC LOGIC BEGINS ------------------------------
always@( posedge clock ) begin //{
   if( reset | ~process_started ) begin //{
      quad_select_int         <= 0;
      sub_quad_select         <= 0;
      sub_quad_col            <= 0;
      {new_3b, sub_quad_row}  <= 3'b100;
      layer                   <= 0;
      finish                  <= 1;
      arch0_add_skip          <= 0;
   end //}
   else begin //{
      // Following signals are synced with i, j or address calculating logic
      // Since address calculating logic runs ahead of time, the following
      // need not be delayed
      sub_quad_col            <= next_quad_col;
      {new_3b, sub_quad_row}  <= next_quad_row;
      sub_quad_select         <= next_sub_quad_select[1:0];
      next_sub_quad_overflow  <= next_sub_quad_select[2];
      layer                   <= next_layer[1:0];
      quad_select_int         <= next_quad_select[1:0];
      finish                  <= next_layer[2];
      arch0_add_skip          <= arch0_add_skip_next;
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
   process_started     <= next_process_started;
   step_reg            <= step;
   dom_address         <= step_reg[2:0];
   // Write to output only when its ready i.e., at the very last 8 clocks.
   // Additionally write only 0-7 (not 8)
   dom_ready           <= ~|{step_reg[3], arch0_add_skip} & (&{step2_idx[5:4], quad_select, subblock});
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
generate
   if     ( ARCH_SELECTOR == 0 ) begin : gen_b_address_1 //{
      always@(*) begin //{
         casex( {wen_next} )
            1'b1: bvm_address = {4'b0000, layer, step};
            //TODO
            1'b0: bvm_address = ( &{sub_quad_select[1:0], quad_select_int[1:0], ~arch0_add_skip_next} ? 10'h41 : 10'h40) + 
                                 {step, step2_idx};
         endcase
      end //}
   end //}
   else if( ARCH_SELECTOR == 1 ) begin : gen_b_address_2 //{
      always@(*) begin //{
         casex( {wen_next, store_look_ahead_filter} )
            2'b10: bvm_address = {4'b0000, layer, step};
            //TODO
            2'b00: bvm_address = 10'h40 + {step, step2_idx};
            2'bx1: bvm_address = 10'h40 + {1'b0, look_ahead_filter_addr, look_ahead_lower_addr};
         endcase
      end //}
   end //}
endgenerate
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

always@(*) begin //{
   casex( {reset, process_started, go, next_layer[2]} )
      4'b0000: next_process_started = 1'b0;
      4'b0xx1: next_process_started = 1'b0;
      4'b1xxx: next_process_started = 1'b0;

      4'b0x10: next_process_started = 1'b1;
      4'b0100: next_process_started = 1'b1;
   endcase
end //}

always@(*)
   add_one_2bit( { ~arch0_add_skip_next & next_quad_row[2], sub_quad_select}, next_sub_quad_select );

// Add one to quad_select_int
always@(*)
   add_one_2bit( { next_sub_quad_select[2], quad_select_int}, next_quad_select );

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
      {2'd0, 2'd0} : step = 4'd0; 
      {2'd0, 2'd1} : step = 4'd1; 
      {2'd0, 2'd2} : step = 4'd2; 

      {2'd1, 2'd0} : step = 4'd3; 
      {2'd1, 2'd1} : step = 4'd4; 
      {2'd1, 2'd2} : step = 4'd5; 

      {2'd2, 2'd0} : step = 4'd6; 
      {2'd2, 2'd1} : step = 4'd7; 
      {2'd2, 2'd2} : step = 4'd8; 
      default      : step = 4'd0; 
   endcase
end //}
//---------------------------- ASYNC LOGIC ENDS -------------------------------

endmodule //}controller
