//-----------------------------------------------------------------
//  Module:     BlockRAM_DPM_1K_x_8
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
//
//
//-----------------------------------------------------------------
module BlockRAM_DPM_1K_x_8
#(parameter BRAM_INITIAL_FILE = "C:/FPGA_Design/PAKCOMController/src/BRAM_1K_x_8.txt")
(
 	input            clk,        // System Clock
  	input      [9:0] addr_a,     // address port A
  	input      [7:0] datain_a,   // data to write port A
  	input            wr_a,       // Write strobe port A
  	
	input      [9:0] addr_b,     // address port B
  	input      [7:0] datain_b,   // data to write port B
  	input            wr_b,       // write enable
	  
  	output reg [7:0] dataout_a,  // data output
  	output reg [7:0] dataout_b   // data output
);
  
  	reg [7:0] mem[0:1023]; /* synthesis syn_ramstyle="no_rw_check" */  //1Kx8 block RAM  
  	initial $readmemh(BRAM_INITIAL_FILE, mem);
  
  	//Initialize
	initial			
	begin
    	dataout_a <= {8{1'b0}};
    	dataout_b <= {8{1'b0}};
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
