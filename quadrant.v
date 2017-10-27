/*H**********************************************************************
* FILENAME    :       quadrant.v 
* DESCRIPTION :       Compute unit that works on 6x6 matrix
*
* AUTHOR      :       Utkarsh Mathur           START DATE :    14 Oct 17
*
* CHANGES :
*
*H***********************************************************************/

// synopsys translate_off
`include "/afs/eos.ncsu.edu/dist/syn2013.03/dw/sim_ver/DW02_mac.v"
// synopsys translate_on

module quadrant( 
   input  wire       clock, 
   input  wire       sample_acc,
   input  wire[31:0] acc_in, 
   input  wire[15:0] a, 
   input  wire[15:0] b, 
   output wire[31:0] data_out_wo_truncate
);

wire        tc;
wire [31:0] data_in;
reg  [31:0] mac;

assign tc           = 1'b1;

always@(posedge clock) begin //{
   mac             <= data_out_wo_truncate;
end //}

// Reset logic
assign data_in = ( sample_acc ) ? acc_in : mac;

DW02_mac #( .A_width(16), .B_width(16) ) mac0 ( .A(a), .B(b), .C(data_in), .MAC(data_out_wo_truncate), .TC(tc) );

endmodule
