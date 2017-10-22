// synposys translate_off
`include "/afs/eos.ncsu.edu/dist/syn2013.03/dw/sim_ver/DW02_mac.v"

// synposys translate_on
module quadrant( 
   input  clock, 
   input  clear, 
   input  wire[15:0] a, 
   input  wire[15:0] b, 
   output wire[15:0] out 
);

wire        tc;
reg  [31:0] data_out_wo_truncate;
wire [31:0] data_in;
wire [31:0] mac;

assign tc   = 1'b1;

always@(posedge clock)
   data_out_wo_truncate <= mac;

// truncate logic
assign out     = ( data_out_wo_truncate[31] ) ? 16'b0 : data_out_wo_truncate[31:16];
// Reset logic
assign data_in = ( clear ) ? 32'b0 : data_out_wo_truncate;

DW02_mac #( .A_width(16), .B_width(16) ) mac0 ( .A(a), .B(b), .C(data_in), .MAC(mac), .TC(tc) );

endmodule
