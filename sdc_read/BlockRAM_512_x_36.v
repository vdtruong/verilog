//-----------------------------------------------------------------
//  Module:     BlockRAM_512_x_36
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
//
//
//-----------------------------------------------------------------
module BlockRAM_512_x_36
#(parameter BRAM_INITIAL_FILE = "C:/FPGA_Design/DigilentBoard/DigilentBrd/src/BRAM_512_x_36.txt")
(
  input             clk,      // System Clock
  input      [8:0]  rdaddr,   // read address  
  input      [8:0]  wraddr,   // write address
  input             we,       // write enable
  input      [35:0] datain,   // data to write
  output reg [35:0] dataout   // data output
);
  
  reg [35:0] mem[0:511]; //512x36 block RAM  
  initial $readmemh(BRAM_INITIAL_FILE, mem);
  
  reg [9:0] rd_address;  // reg rd address to infer BRAM
  
  
  //Initialize
	initial			
	begin
		rd_address <= {9{1'b0}};
    dataout <= {36{1'b0}};
	end

	//Read/Write memory
	always@(posedge clk)
	begin
    rd_address <= rdaddr;
    if (we)
      mem[wraddr] <= datain;
    else
      dataout <= mem[rd_address];
	end		
    
endmodule
