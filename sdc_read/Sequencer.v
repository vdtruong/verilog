//-----------------------------------------------------------------
//  Module:     Sequencer
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
//
//--------------------------------------------------------------------------------
module Sequencer
#(parameter BRAM_NETLIST_FILE = "C:/FPGA_Design/PAKPUCXXXX/src/BRAM_Netlist_XXXX.txt",
  parameter NL_MEM_SIZE       = 512,
  parameter NL_ADDR_WD        = 9,
  parameter NL_DATA_WD        = 36,
  parameter BRAM_MEMORY_FILE  = "C:/FPGA_Design/PAKPUCXXXX/src/BRAM_Memory_XXXX.txt",
  parameter BRAM_NVM_FILE     = "C:/FPGA_Design/PAKPUCXXXX/src/BRAM_NVM_XXXX.txt")
(  
  input                   clk,                  // System Clock 
  input                   reset,                // System Reset (Syncronous) 
  input                   enable,               // System enable 
  input                   sys_tmr_strb,         // System Timer Strobe
  
  input                   sub_seq_strb,         // Strobe to run sub sequence
  input  [NL_ADDR_WD-1:0] sub_seq_addr,         // Address of subsequence to run
  input  [NL_ADDR_WD-1:0] sub_seq_cnt,          // Number of nets in the subsequence
  output                  sub_seq_done,         // Flag that the sub sequence run has completed.
    
  input  [35:0]           reg_sys_rd_data,      // Register Data read
  input                   reg_sys_rd_rdy_strb,  // Strobe to read data
  input                   reg_sys_wr_done_strb, // Write to register is done.
  output                  reg_sys_rd_strb,      // Register Read Register Strobe
  output [15:0]           reg_sys_rd_addr,      // Register Address to read from
  output [15:0]           reg_sys_wr_addr,      // Register Address to write to
  output                  reg_sys_wr_strb,      // Register Write Register Strobe
  output [35:0]           reg_sys_wr_data,      // Register Data to write      
 
  input                   net_wr_strb,          // Net List
  input  [NL_ADDR_WD-1:0] net_wr_addr,          // Net Address
  input  [35:0]           net_wr_data,          // Net Data
  
  input                   NVM_DOUT,             // NVM output line
  output                  NVM_DIN,              // NVM input line  
  output                  NVM_DCLK,             // NVM clock line
  output                  NVM_CS_L,             // NVM chip select
  output                  NVM_HOLD,             // NVM hold
  output                  NVM_WP                // NVM write protect    
);
	  
  wire                  net_done_strb;
  wire                  net_strb;
  wire [NL_ADDR_WD-1:0] net_rd_addr;    
  wire [35:0]           net_rd_data;
  
  reg                   net_strb_Z1;
  reg                   net_strb_Z2;
   
  initial
  begin
    net_strb_Z1 <= 1'b0;
    net_strb_Z2 <= 1'b0;
  end
  
  // Based on a sequence strobe, sequence address and net count
  // Read nets from memory and route it to the sequence mapper.
  defparam SequenceLoader_i.NL_ADDR_WD = NL_ADDR_WD; 
  SequenceLoader SequenceLoader_i
  (  
    .clk(clk),                          // System Clock 									input     
    .reset(reset),                      // System Reset (Syncronous)             input     
    .enable(enable),                    // System enable                         input     
    .sub_seq_strb(sub_seq_strb),        // Strob to run sub sequence 1           input
    .sub_seq_addr(sub_seq_addr),        // Address of subsequence to run         input     
    .sub_seq_cnt(sub_seq_cnt),          // Number of nets in the subsequence     input     
    .net_done_strb(net_done_strb),      // Input Net Done Strobe                 input          
    .net_rd_addr(net_rd_addr),          // Output address to get net from        output    
    .net_rd_strb(net_strb),             // Strobe to read next net               output reg
    .sub_seq_done(sub_seq_done)         // Strobe that output sequence is done   output    
  );                                                                             
                                                                                 
  // Netlist RAM
  defparam BlockRAM_Netlist_i.BRAM_INITIAL_FILE = BRAM_NETLIST_FILE;
  defparam BlockRAM_Netlist_i.MEM_SIZE          = NL_MEM_SIZE;
  defparam BlockRAM_Netlist_i.ADDR_WD           = NL_ADDR_WD;
  defparam BlockRAM_Netlist_i.DATA_WD           = NL_DATA_WD;  
  BlockRAM  BlockRAM_Netlist_i
  (
    .clk(clk),                      // System Clock				input     
    .rdaddr(net_rd_addr),           // read address [N:0]      input     
    .wraddr(net_wr_addr),           // write address [N:0]     input     
    .we(net_wr_strb),               // write enable            input     
    .datain(net_wr_data),           // data to write [35:0]    input     
    .dataout(net_rd_data)           // data output [35:0]      output reg
  );    
  
  //Two clocks to read out of RAM
  always@(posedge clk)
  begin
    if (reset) begin
      net_strb_Z1 <= 1'b0;
      net_strb_Z2 <= 1'b0;
    end else begin
      net_strb_Z1 <= net_strb;
      net_strb_Z2 <= net_strb_Z1;
    end
  end
  
  //Handle every net transaction
  defparam SequenceMapping_i.BRAM_MEMORY_FILE = BRAM_MEMORY_FILE;
  defparam SequenceMapping_i.BRAM_NVM_FILE    = BRAM_NVM_FILE;
  SequenceMapping SequenceMapping_i
  (  
    .clk(clk),                                       // System Clock 								input 
    .reset(reset),                                   // System Reset (Syncronous)            input 
    .sys_tmr_strb(sys_tmr_strb),                     // System Timer Strobe                  input 
                                                                                             
    .net(net_rd_data[31:0]),                         // [31:0] Netlist transaction           input 
    .net_strb(net_strb_Z2),                          // Strobe to process the net            input 
    .net_done_strb(net_done_strb),                   // Strobe that net has been processed   output
                                                                                             
    .reg_sys_rd_data(reg_sys_rd_data),               // Register Data read                   input    
    .reg_sys_rd_rdy_strb(reg_sys_rd_rdy_strb),       // Strobe to read data                  input 
    .reg_sys_wr_done_strb(reg_sys_wr_done_strb),     // Write to register is done            input 
    .reg_sys_rd_strb(reg_sys_rd_strb),               // Register Read Register Strobe        output
    .reg_sys_rd_addr(reg_sys_rd_addr),               // Register Address to read from        output
    .reg_sys_wr_addr(reg_sys_wr_addr),               // Register Address to write to         output
    .reg_sys_wr_strb(reg_sys_wr_strb),               // Register Write Register Strobe       output
    .reg_sys_wr_data(reg_sys_wr_data),               // Register Data to write               output
                                                                                             
    .NVM_DOUT(NVM_DOUT),                             // NVM output line                      input 
    .NVM_DIN(NVM_DIN),                               // NVM input line                       output
    .NVM_DCLK(NVM_DCLK),                             // NVM clock line                       output
    .NVM_CS_L(NVM_CS_L),                             // NVM chip select                      output
    .NVM_HOLD(NVM_HOLD),                             // NVM hold                             output
    .NVM_WP(NVM_WP)                                  // NVM write protect                    output
  );                                                                                         
                                                                                             
      
endmodule
