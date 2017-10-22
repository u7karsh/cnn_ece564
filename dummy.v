module dummy( input clock, input [15:0] a, input [15:0] b, output [31:0] c );

   DW02_mult #(16, 16)
   U1 ( .A(a), .B(b), .TC(1'b1), .PRODUCT(c) );
endmodule
