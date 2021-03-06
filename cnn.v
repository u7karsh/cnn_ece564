/*H**********************************************************************
* FILENAME    :       cnn.v 
* DESCRIPTION :       Parameterized CNN module that will be instantiated
*                     in MyDesign.v
*
* AUTHOR      :       Utkarsh Mathur           START DATE :    14 Oct 17
*
* CHANGES :
*
*H***********************************************************************/

module cnn( 
   input             clock, 
   input             reset, 
   input             go,
   output reg        finish,
   output reg[9:0]   bvm_address, 
   output reg[8:0]   dim_address, 
   input  wire[15:0] dim_data_unreg, 
   input  wire[15:0] bvm_data_unreg,
   output reg[15:0]  dom_data,
   output reg[2:0]   dom_address,
   output reg        dom_ready
);

// Architecture selector
// 0 => simple         : Gives all outputs in 12*12 + 36 cycles
// 1 => max_throughput : Adds an SISO which stores m vectors in last 8 dummy
//                       cycles. Gives 1st output in 12*12 + 8 cycles then
//                       subsequent ones in 12*12 cycles at the cost of
//                       9 16bit registers

// synopsys template
parameter ARCH_SELECTOR = 0;

// synopsys template
parameter MULT_SQUEEZE  = 0;

// Interface signals
reg  [15:0] dim_data;
reg  [15:0] bvm_data;
wire [3:0]  i, j;
wire [1:0]  layer;
wire [9:0]  bvm_address_unreg;

// Buffered outputs from controller which have to be further delayed by
// 1 clock to sync with data which is 2 clocks delayed
wire [1:0]  quad_select_unreg;
wire        wen_unreg;
wire        ready_3_3_unreg;
wire        store_la_filter_unreg;
wire [2:0]  la_filter_addr_unreg;
wire [1:0]  subblock_unreg;
wire        finish_unreg;

// Controller outputs synced with data (2 clock delay)
reg  [1:0]  quad_select;
reg         wen;
reg         ready_3_3;
reg         store_la_filter;
reg  [2:0]  la_filter_addr;
reg  [1:0]  subblock;

// Wire assigns
wire [15:0] dom_data_unreg;
wire [15:0] step2_filter;
wire [15:0] out_3_3;
wire [15:0] step1_filter;

// Internal signals
wire [15:0] la_reg_out;
wire [2:0]  dom_address_unreg;
wire        dom_ready_unreg;
wire [31:0] step2_acc;
wire [31:0] out0, out1, out2, out3;
wire [15:0] reg_read_data;


reg  [15:0] out_3_3_uncut;
reg  [15:0] step2_input;
reg  [31:0] step2_reg_input;
wire        write_partial_sum_step2;

wire [31:0] step2_output;
reg  [31:0] step2_output_alt;

generate
   if( MULT_SQUEEZE == 1 ) begin : gen_wire_reg_step2_output //{
      assign step2_output = step2_output_alt;
   end //}
endgenerate

// Addon wires to incorporate MULT_SQUEEZE
wire        q0_ready_3_3, q1_ready_3_3, q2_ready_3_3, q3_ready_3_3;
wire [15:0] q0_a, q1_a, q2_a, q3_a;
wire [15:0] q0_b, q1_b, q2_b, q3_b;
wire [31:0] q0_acc_in, q1_acc_in, q2_acc_in, q3_acc_in;

// Truncate
assign dom_data_unreg          = ( step2_output[31] )     ? 16'b0    : step2_output[31:16];
assign out_3_3                 = out_3_3_uncut[15]        ? 16'b0    : out_3_3_uncut;
assign step1_filter            = wen                      ? bvm_data : reg_read_data;

generate
   if     ( ARCH_SELECTOR == 0 ) begin : gen_step_filter_partial_sum_1 //{
      assign step2_filter            = bvm_data;
      assign write_partial_sum_step2 = (quad_select==0 & subblock==0 && layer!=0) ? 1'b0     : 1'b1;
   end //}
   else if( ARCH_SELECTOR == 1 ) begin : gen_step_filter_partial_sum_2 //{
      assign step2_filter            = |{quad_select, subblock} ? bvm_data : la_reg_out;
      assign write_partial_sum_step2 = 1'b1;
   end //}
endgenerate

// Interface register *mandatory*
always@(posedge clock) begin //{
   bvm_address       <= bvm_address_unreg;
   dim_address       <= {1'b0, i, j};
   dim_data          <= dim_data_unreg;
   bvm_data          <= bvm_data_unreg;
   dom_address       <= dom_address_unreg;
   dom_data          <= dom_data_unreg;
   dom_ready         <= dom_ready_unreg;


   // Controller outputs to be synchronized with data have to be registered
   // Since data is delayed by 2 cycles, we need to delay controller output
   // further by 1 clock
   quad_select       <= quad_select_unreg;
   wen               <= wen_unreg;
   ready_3_3         <= ready_3_3_unreg;
   store_la_filter   <= store_la_filter_unreg;
   la_filter_addr    <= la_filter_addr_unreg;
   subblock          <= subblock_unreg;
   finish            <= finish_unreg;

   step2_input       <= ready_3_3_unreg ? out_3_3 : step2_input;
end //}

// Mux to select output from the correct quadrant
always@(*) begin //{
   case( quad_select )
      2'd0: out_3_3_uncut  = out0[31:16];
      2'd1: out_3_3_uncut  = out1[31:16];
      2'd2: out_3_3_uncut  = out2[31:16];
      2'd3: out_3_3_uncut  = out3[31:16];
   endcase
end //}

// Reset logic to clear accumulators of step2 during Z0
always@(*) begin //{
   case( wen & ~|layer )
      1'b0:  step2_reg_input = step2_output;
      1'b1:  step2_reg_input = 32'b0;
   endcase
end //}

// Instantiate the controller
controller #(.ARCH_SELECTOR(ARCH_SELECTOR))
c0( 
   .clock(clock), 
   .reset(reset), 
   .go(go), 
   .finish(finish_unreg), 
   .i(i), .j(j), 
   .layer(layer), 
   .dom_address(dom_address_unreg), 
   .dom_ready(dom_ready_unreg), 
   .wen(wen_unreg), 
   .quad_select(quad_select_unreg), 
   .ready_3_3(ready_3_3_unreg), 
   .bvm_address(bvm_address_unreg), 
   .la_filter_addr(la_filter_addr_unreg), 
   .store_la_filter(store_la_filter_unreg), 
   .subblock(subblock_unreg) 
);

generate
   if( MULT_SQUEEZE == 0 ) begin : gen_quad_inputs_1 //{
      assign q0_ready_3_3 = ready_3_3; 
      assign q1_ready_3_3 = ready_3_3; 
      assign q2_ready_3_3 = ready_3_3; 
      assign q3_ready_3_3 = ready_3_3; 

      assign q0_acc_in    = 32'h0;
      assign q1_acc_in    = 32'h0;
      assign q2_acc_in    = 32'h0;
      assign q3_acc_in    = 32'h0;

      assign q0_a         = dim_data;
      assign q1_a         = dim_data;
      assign q2_a         = dim_data;
      assign q3_a         = dim_data;

      assign q0_b         = step1_filter;
      assign q1_b         = step1_filter;
      assign q2_b         = step1_filter;
      assign q3_b         = step1_filter;
   end //}
   else if( MULT_SQUEEZE == 1 ) begin : gen_quad_inputs_2 //{
      wire q0_select, q1_select, q2_select, q3_select;
      assign q0_select    = quad_select == 0;
      assign q1_select    = quad_select == 1;
      assign q2_select    = quad_select == 2;
      assign q3_select    = quad_select == 3;

      assign q0_ready_3_3 = ( q0_select ) ? ready_3_3 : 1'b1; 
      assign q1_ready_3_3 = ( q1_select ) ? ready_3_3 : 1'b1; 
      assign q2_ready_3_3 = ( q2_select ) ? ready_3_3 : 1'b1; 
      assign q3_ready_3_3 = ( q3_select ) ? ready_3_3 : 1'b1; 

      assign q0_acc_in    = ( q0_select ) ? 32'h0 : step2_acc;
      assign q1_acc_in    = ( q1_select ) ? 32'h0 : step2_acc;
      assign q2_acc_in    = ( q2_select ) ? 32'h0 : step2_acc;
      assign q3_acc_in    = ( q3_select ) ? 32'h0 : step2_acc;

      assign q0_a         = ( q0_select ) ? dim_data : step2_input;
      assign q1_a         = ( q1_select ) ? dim_data : step2_input;
      assign q2_a         = ( q2_select ) ? dim_data : step2_input;
      assign q3_a         = ( q3_select ) ? dim_data : step2_input;

      assign q0_b         = ( q0_select ) ? step1_filter : step2_filter;
      assign q1_b         = ( q1_select ) ? step1_filter : step2_filter;
      assign q2_b         = ( q2_select ) ? step1_filter : step2_filter;
      assign q3_b         = ( q3_select ) ? step1_filter : step2_filter;
   end //}
endgenerate

// Step2 MAC
generate
   if     ( MULT_SQUEEZE == 0 ) begin : gen_step2_mac_1 //{
      quadrant   step2( .clock(clock), 
                        .sample_acc(1'b1), 
                        .acc_in(step2_acc), 
                        .a(step2_input), 
                        .b(step2_filter), 
                        .data_out_wo_truncate(step2_output) 
                     );
   end //}
   else if( MULT_SQUEEZE == 1 ) begin : gen_step2_mac_2 //{
      always@(*) begin //{
         case(quad_select) //{
            0: step2_output_alt = out1;
            1: step2_output_alt = out2;
            2: step2_output_alt = out3;
            3: step2_output_alt = out0;
         endcase //}
      end //}
   end //}
endgenerate

// 4 Quadrants
quadrant   q0( .clock(clock), .sample_acc(q0_ready_3_3), .acc_in(q0_acc_in), .a(q0_a), .b(q0_b), .data_out_wo_truncate(out0) );
quadrant   q1( .clock(clock), .sample_acc(q1_ready_3_3), .acc_in(q1_acc_in), .a(q1_a), .b(q1_b), .data_out_wo_truncate(out1) );
quadrant   q2( .clock(clock), .sample_acc(q2_ready_3_3), .acc_in(q2_acc_in), .a(q2_a), .b(q2_b), .data_out_wo_truncate(out2) );
quadrant   q3( .clock(clock), .sample_acc(q3_ready_3_3), .acc_in(q3_acc_in), .a(q3_a), .b(q3_b), .data_out_wo_truncate(out3) );

// B vector ROT SISO
sr_siso9 #(.BUS_WIDTH(16)) s0 ( .clock(clock), .wen(wen), .write_bus(bvm_data), .read_bus(reg_read_data) );

// O vector SISO for step 2 accumulators
sr_siso9 #(.BUS_WIDTH(32)) s1 ( .clock(clock), .wen(write_partial_sum_step2), .write_bus(step2_reg_input), .read_bus(step2_acc) );

generate
   if( ARCH_SELECTOR == 1 ) begin : gen_la_filter_regfile //{
      // Reg file for M vector: used only in max_throughput architecture
      register_file_9x16 r0 ( 
         .clock(clock), 
         .wen(store_la_filter),
         .address({1'b0,la_filter_addr}), 
         .write_bus(bvm_data), 
         .read_bus(la_reg_out) 
      );
   end //}
endgenerate

//initial begin
//   $monitor("[%0t] %d %d %d %d [%x %6d] [%d %6d] [%x %6d] %d %d %d [%d %d %d %d %d] [%d %d %d %x : %d %x %d] [%d %d] [%d %d %d %d] [%d %d %d]", 
//      $time, reset,go, i, j, 
//      dim_address, dim_data, 
//      c0.step, bvm_data, 
//      bvm_address, step1_filter, 
//      wen, ready_3_3, quad_select, 
//      step2_input, step2_filter, step2_acc, step2_output, step2_reg_input,
//      c0.store_look_ahead_filter, c0.look_ahead_filter_addr, c0.look_ahead_lower_addr, c0.bvm_address, 
//      // :
//      store_la_filter, la_filter_addr, la_reg_out, 
//      c0.layer, c0.next_step2_idx_lower_nibble, 
//      c0.process_started, c0.go, c0.next_layer[2], c0.finish, 
//      dom_address, dom_data, dom_ready);
//end

endmodule
