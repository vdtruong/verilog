`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   14:10:00 08/21/2012
// Design Name:   bidir_infer
// Module Name:   C:/FPGA_Design/sd_card_controller/test_bidir_ver.v
// Project Name:  sd_card_controller
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: bidir_infer
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module test_bidir_ver;

	// Inputs
	reg READ_WRITE;

	// Bidirs
	wire [1:0] DATA, data_out;
	
	// reg
	reg [1:0] data_in;

	// Instantiate the Unit Under Test (UUT)
	bidir_infer uut (
		.READ_WRITE(READ_WRITE), 
		.DATA(DATA)
	);

	assign DATA 		= (READ_WRITE == 1) ? data_in 	: 2'bZ;
	assign data_out 	= (READ_WRITE == 0) ? DATA 		: 2'bZ;
		
	initial begin
		// Initialize Inputs
		READ_WRITE = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		
		READ_WRITE 			= 1;
		data_in 				= 11;
		#50 READ_WRITE 	= 0;
		#50 data_in			= 10;
		#50 READ_WRITE 	= 1;
		#50 data_in			= 01;
		#50 READ_WRITE 	= 0;
		
	end
      
endmodule

