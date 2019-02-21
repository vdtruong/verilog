`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:03:21 10/05/2012 
// Design Name: 
// Module Name:    single_async_distributed_ram 
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
module single_async_distributed_ram
#( parameter RAM_WIDTH 		= 512,	// Element bits.
   parameter RAM_ADDR_BITS = 8)    	// Address of array.
(
	input									clk,
	input 	[RAM_ADDR_BITS-1:0] 	address,
   input 	[RAM_WIDTH-1:0] 		input_data,
   input 								wr_enb,
   output 	[RAM_WIDTH-1:0]		output_data
);

   (* RAM_STYLE="{AUTO | DISTRIBUTED | PIPE_DISTRIBUTED}" *)
   reg [RAM_WIDTH-1:0] sys_mem [(2**RAM_ADDR_BITS)-1:0];

   always @(posedge clk)
      if (wr_enb)
         sys_mem[address] <= input_data;

   assign output_data = sys_mem[address];


endmodule
