`timescale 1ns / 1ps

module testbench ( );

	parameter CLOCK_PERIOD = 20;

	reg [8:0] Instruction;
	reg Run;
	wire Done;
	wire [8:0] BusWires;

	reg CLOCK_50;
	initial begin
		CLOCK_50 <= 1'b0;
	end // initial
	always @ (*)
	begin : Clock_Generator
		#((CLOCK_PERIOD) / 2) CLOCK_50 <= ~CLOCK_50;
	end
	
	reg Resetn;
	initial begin
		Resetn <= 1'b0;
		#20 Resetn <= 1'b1;
	end // initial

	initial begin
				Run	<= 1'b0;	Instruction	<= 9'b000000000;	
		#20	Run	<= 1'b1; Instruction	<= 9'b001000000;	
		#20	Run	<= 1'b0; Instruction	<= 9'b000000101;	
		#20	Run	<= 1'b1; Instruction	<= 9'b000001000;	
		#20	Run	<= 1'b0;
		#20	Run	<= 1'b1; Instruction	<= 9'b010000001;
		#20	Run	<= 1'b0;
		#60	Run	<= 1'b1; Instruction	<= 9'b011000000;
		#20	Run	<= 1'b0;
	end // initial

	proc U1 (Instruction, Resetn, CLOCK_50, Run, Done, BusWires);

endmodule
