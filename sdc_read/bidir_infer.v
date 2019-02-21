`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:07:25 08/21/2012 
// Design Name: 
// Module Name:    bidir_infer 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module bidir_infer(
	input READ_WRITE,
   inout [1:0] DATA
   );
	 
	reg [1:0] LATCH_OUT;
	
	always @ (READ_WRITE or DATA)
	begin
		if (READ_WRITE == 1) // input
			LATCH_OUT <= DATA;
	end
	
	// if true read, if false write DATA = LATCH_OUT
	assign DATA = (READ_WRITE == 1) ? 2'bZ : LATCH_OUT;
	
endmodule
