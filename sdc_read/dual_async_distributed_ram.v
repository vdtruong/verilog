`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:03:21 10/05/2012 
// Design Name: 
// Module Name:    dual_async_distributed_ram 
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
module dual_async_distributed_ram
#( parameter RAM_WIDTH 		= 72,	// Bits for each row.
   parameter RAM_ADDR_BITS = 8) 	// Address of array.
(
	input									clk,
	input 								wr_ram_enb,
	input 	[RAM_ADDR_BITS-1:0] 	wr_ram_addr,
   input 	[RAM_WIDTH-1:0] 		wr_ram_data,
	input 	[RAM_ADDR_BITS-1:0] 	rd_ram_addr,
   output 	[RAM_WIDTH-1:0]		output_ram_data
);

   (* RAM_STYLE="{AUTO | DISTRIBUTED | PIPE_DISTRIBUTED}" *)
	// Memory of 256 rows, each row is 72 bits.
   reg [RAM_WIDTH-1:0] sys_mem [(2**RAM_ADDR_BITS)-1:0];

   always @(posedge clk)
      if (wr_ram_enb)
         sys_mem[wr_ram_addr] <= wr_ram_data;

   assign output_ram_data = sys_mem[rd_ram_addr];


endmodule
