// Serial in serial out shift register
module sr_siso9( 
   clock, 
   wen, 
   write_bus, 
   read_bus 
);

parameter bus_width=32;

input  wire clock;
input  wire wen;
input  wire [bus_width - 1 : 0] write_bus;
output wire [bus_width - 1 : 0] read_bus;

// Manually craft the registers as 9 is not a pow of 2
reg  [bus_width - 1 : 0] reg0, reg1, reg2, reg3, reg4, reg5, reg6, reg7, reg8;

always@(posedge clock) begin //{
   reg0 <= wen ? write_bus : reg8;
   reg1 <= reg0;
   reg2 <= reg1;
   reg3 <= reg2;
   reg4 <= reg3;
   reg5 <= reg4;
   reg6 <= reg5;
   reg7 <= reg6;
   reg8 <= reg7;
end //}

assign read_bus = reg8;

endmodule
