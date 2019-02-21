//-----------------------------------------------------------------
//  Module:     BlockRAM_DPM_1024_x_36
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
//
//
//-----------------------------------------------------------------
module BlockRAM_DPM_1024_x_36
#(parameter BRAM_DPM_INITIAL_FILE = "C:/FPGA_Design/PAKPUCXXX/src/BRAM_1024_x_36.txt")
(
  input             clk,        	// System Clock
  input       [9:0] addr_a,     	// address port A
  input      [35:0] datain_a,   	// data to write port A
  input             wr_a,       	// Write strobe port A
  input       [9:0] addr_b,     	// address port B
  input             wr_b,       	// write enable
  input      [35:0] datain_b,   	// data to write port B
  output reg [35:0] dataout_a,  	// data output
  output reg [35:0] dataout_b   	// data output
);
  
  reg [35:0] mem[0:1023]; 			//512x36 block RAM  
  initial $readmemh(BRAM_DPM_INITIAL_FILE, mem);
  
  //Initialize
	initial			
	begin
    dataout_a <= {36{1'b0}};
    dataout_b <= {36{1'b0}};
	end

    
	// Port A
  always @(posedge clk) begin
    dataout_a     <= mem[addr_a];
    if(wr_a) begin
      dataout_a   <= datain_a;
      mem[addr_a] <= datain_a;
    end
  end
  	 
  // Port B
  always @(posedge clk) begin
    dataout_b     <= mem[addr_b];
    if(wr_b) begin
      dataout_b   <= datain_b;
      mem[addr_b] <= datain_b;
    end
  end  
  
    
endmodule
