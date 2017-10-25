/*H**********************************************************************
* FILENAME    :       sr_siso9.v 
* DESCRIPTION :       9 Reg Serial In Serial Out with rotate unit
*
* AUTHOR      :       Utkarsh Mathur           START DATE :    14 Oct 17
*
* CHANGES :
*
*H***********************************************************************/

// Serial in serial out shift register
module sr_siso9( clock, wen, write_bus, read_bus );

// synopsys template
parameter BUS_WIDTH = 16;

input  wire                    clock;
input  wire                    wen;
input  wire [BUS_WIDTH - 1: 0] write_bus;
output wire [BUS_WIDTH - 1: 0] read_bus;

// Manually craft the registers as 9 is not a pow of 2
reg  [BUS_WIDTH - 1 : 0] reg0, reg1, reg2, reg3, reg4, reg5, reg6, reg7, reg8;

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
