//-----------------------------------------------------------------
//  Module:     BlockRAM_128_x_64 (128 words of 64 bits word)
//  Project:    
//  Version:    0.01-1
//
//  Description:	Choose one address to write and one address to read. 
//
//
//
//-----------------------------------------------------------------
module BlockRAM_128_x_64
#(parameter BRAM_INITIAL_FILE = "C:/FPGA_Design/sd_card_controller/src/BRAM_128_x_64.txt")
(
 	input            		clk,     	// System Clock
  	input      	[7:0] 	addr_a,  	// address port A
  	input      	[63:0] 	datain_a,	// data to write port A
  	input            		wr_a,    	// Write strobe port A
  	
	input      	[7:0]	   addr_b,  	// address port B
  	input      	[63:0] 	datain_b,	// data to write port B
  	input            		wr_b,    	// write enable
	  
  	output reg	[63:0] 	dataout_a,	// data output
  	output reg 	[63:0] 	dataout_b	// data output
);
  
  	reg [63:0] mem[0:127]; /* synthesis syn_ramstyle="no_rw_check" */  //128x64 block RAM  
  	initial $readmemh(BRAM_INITIAL_FILE, mem);
  
  	//Initialize
	initial			
	begin
    	dataout_a <= {64{1'b0}};
    	dataout_b <= {64{1'b0}};
	end

	// Port A
  	always @(posedge clk) begin
    	dataout_a     	<= mem[addr_a];
    	if(wr_a) begin
      	dataout_a   <= datain_a;
      	mem[addr_a] <= datain_a;
    	end
  	end
  	 
  	// Port B
  	always @(posedge clk) begin
    	dataout_b     	<= mem[addr_b];
    	if(wr_b) begin
      	dataout_b   <= datain_b;
      	mem[addr_b] <= datain_b;
    	end
  	end  
  
    
endmodule
