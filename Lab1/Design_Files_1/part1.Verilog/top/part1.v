// KEY[0] is the reset input, and KEY[1] is the clock. SW8-0 are the instructions,
// and SW[9] is the Run input. The processor bus appears on LEDR8-0 and
// Done appears on LEDR9
module part1 (KEY, SW, LEDR);
	input [1:0] KEY;
	input [9:0] SW;
	output [9:0] LEDR;	

	wire Resetn, Clock, Run, Done;
	wire [8:0] DIN, Bus;

	assign Resetn = KEY[0];
	assign Clock = KEY[1];	
	assign DIN = SW[8:0];
	assign Run = SW[9];

	// module proc(DIN, Resetn, Clock, Run, Done, Bus);
	proc U1 (DIN, Resetn, Clock, Run, Done, Bus);

	assign LEDR[8:0] = Bus;
	assign LEDR[9] = Done;

endmodule

