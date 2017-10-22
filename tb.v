module tb;

reg clock;
reg reset;

initial begin
	$monitor("%d %d %d %d %d %d %d", u1.i, u1.j, u1.quad_select, u1.sub_quad_select, u1.layer, u1.load_regs, u1.step);
	clock = 0;
	reset = 1;
	#10 reset = 0;
	#5800;
	$finish;
end

always #5 clock = ~clock;
controller u1( .clock(clock), .reset(reset) );

endmodule