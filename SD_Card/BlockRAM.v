//-----------------------------------------------------------------
//  Module:     BlockRAM
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
// 
//
//-----------------------------------------------------------------
module BlockRAM
#(parameter BRAM_INITIAL_FILE = "C:/FPGA_Design/sd_card_controller/src/BRAM_128_x_64.txt",
  parameter MEM_SIZE 			= 512,
  parameter ADDR_WD 				= 9,
  parameter DATA_WD 				= 36)
(
  	input                     clk,      // System Clock
  	input      [ADDR_WD-1:0]  rdaddr,   // read address  
  	input      [ADDR_WD-1:0]  wraddr,   // write address
  	input                     we,       // write enable
 	input      [DATA_WD-1:0]  datain,   // data to write
  	output reg [DATA_WD-1:0]  dataout   // data output
);
  
  	reg [DATA_WD-1:0] mem[0:MEM_SIZE-1]; // MEM_SIZE X DATA_WD block RAM  
  	initial $readmemh(BRAM_INITIAL_FILE, mem);
  
  	reg [ADDR_WD-1:0] rd_address;  // reg rd address to infer BRAM
  
  
  	//Initialize
	initial			
	begin
		rd_address 	<= {ADDR_WD{1'b0}};
    	dataout 		<= {DATA_WD{1'b0}};
	end

	//Read/Write memory
	always@(posedge clk)
	begin
    	rd_address 		<= rdaddr;
    	if (we)
      	mem[wraddr] <= datain;
    	else
      	dataout 		<= mem[rd_address];
	end		
    
endmodule
