module register_file_9x16( input clock, input wen, input [3:0] address, input [15:0] write_bus, output wire[15:0] read_bus );

// Manually craft the registers as 9 is not a pow of 2
reg  [15:0] reg0, reg1, reg2, reg3, reg4, reg5, reg6, reg7, reg8;

always@(posedge clock)
	if( wen )
		case( address )
			0:    reg0 <= write_bus;
			1:    reg1 <= write_bus;
			2:    reg2 <= write_bus;
			3:    reg3 <= write_bus;
			4:    reg4 <= write_bus;
			5:    reg5 <= write_bus;
			6:    reg6 <= write_bus;
			7:    reg7 <= write_bus;
			8:    reg8 <= write_bus;
		endcase
		
assign read_bus = address == 0 ? reg0 :
                  address == 1 ? reg1 :
                  address == 2 ? reg2 :
                  address == 3 ? reg3 :
                  address == 4 ? reg4 :
                  address == 5 ? reg5 :
                  address == 6 ? reg6 :
                  address == 7 ? reg7 :
                  address == 8 ? reg8 : 0;

endmodule
