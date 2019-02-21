//----------------------------------------------------------------
//  Module:     SequenceMapping
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
//
//----------------------------------------------------------------
module SequenceMapping
#(parameter BRAM_MEMORY_FILE = "C:/FPGA_Design/PAKPUCXXXX/src/BRAM_Memory_XXXX.txt",
  parameter BRAM_NVM_FILE    = "C:/FPGA_Design/PAKPUCXXXX/src/BRAM_NVM_XXXX.txt")
(  
  input               clk,                  // System Clock 
  input               reset,                // System Reset (Syncronous) 
  input               sys_tmr_strb,         // System Timer Strobe
  
  // Input net operation  
  input      [31:0]   net,                  // Netlist transaction
  input               net_strb,             // Strobe to process the net
  output              net_done_strb,        // Strobe that net has been processed   
     
  // Register IO Access
  input      [35:0]   reg_sys_rd_data,      // Register Data read
  input               reg_sys_rd_rdy_strb,  // Strobe to read data
  input               reg_sys_wr_done_strb, // Write done strobe
  output              reg_sys_rd_strb,      // Register Read Register Strobe
  output     [15:0]   reg_sys_rd_addr,      // Register Address to read from
  output     [15:0]   reg_sys_wr_addr,      // Register Address to write to
  output              reg_sys_wr_strb,      // Register Write Register Strobe
  output     [35:0]   reg_sys_wr_data,      // Register Data to write      
  
  input               NVM_DOUT,             // NVM output line
  output              NVM_DIN,              // NVM input line  
  output              NVM_DCLK,             // NVM clock line
  output              NVM_CS_L,             // NVM chip select
  output              NVM_HOLD,             // NVM hold
  output              NVM_WP                // NVM write protect    
);
	
  // 0XXX Constants Access
  //      Data return is integer form of address
  //      0000 will act as NOP for rd and wr.
  // 1XXX Spare
  // 2XXX Register IO Access
  //      See Register Addresses
  // 3XXX ALU Access
  //      3XA2 Input C
  //      3XA1 Input B     
  //      3X00 Input A, Operation = Add
  //      3X10 Input A, Operation = Sub
  //      3X20 Input A, Operation = Mult
  //      3X30 Input A, Operation = Div
  //      3X40 Input A, Operation = Abs
  //      3X50 Input A, Operation = Lim
  //      3X60 Input A, Operation = Inv
  //      3X70 Input A, Operation = Sel  
  // 4XXX GP RAM Access
  // 5000 Timer Access
  //      Data is N*20ns
  // 6XXX NVM Access
  //      Write to 001 : NVM Data (Must write data before command
  //      Write to 000 : NVM Command/Address
  //                      [35:32]
  //                      NVM Command = 1 : Erase
  //                      NVM Command = 2 : Write
  //                      NVM Command = 4 : Program
  //  
  //                      [31:24]
  //                      Opcode = 20     : Erase
  //                      Opcode = 02     : Program
  //                      Opcode = 03     : Read
  //
  //                      [23:0]
  //                      Sector Address in increments of 4096. 4KByte                
  //
  //      Read From 000-1ff is read array  
  // 7XXX Spare
  
  wire  [15:0]   con_sys_rd_addr;
  wire  [15:0]   con_sys_wr_addr;
  reg   [15:0]   con_sys_addr;
  wire           con_sys_rd_strb;
  wire           con_sys_wr_strb;
  wire  [35:0]   con_sys_rd_data;
  wire           con_sys_rd_rdy_strb;
  wire           con_sys_wr_done_strb;
      
  wire  [15:0]   alu_sys_rd_addr;
  wire  [15:0]   alu_sys_wr_addr;
  reg   [15:0]   alu_sys_addr;
  wire           alu_sys_rd_strb;
  wire           alu_sys_wr_strb;
  wire  [35:0]   alu_sys_wr_data;
  wire  [35:0]   alu_sys_rd_data;
  wire           alu_sys_rd_rdy_strb;
  wire           alu_sys_wr_done_strb;

  wire  [15:0]   ram_sys_rd_addr;
  wire  [15:0]   ram_sys_wr_addr;
  wire           ram_sys_wr_strb;
  wire  [35:0]   ram_sys_wr_data;
  wire  [35:0]   ram_sys_rd_data;
  wire           ram_sys_rd_strb;
  reg            ram_sys_rd_strbZ1;
  reg            ram_sys_wr_strbZ1;
  reg            ram_sys_rd_rdy_strb;
  reg            ram_sys_wr_done_strb;

  wire           tmr_sys_wr_strb;
  wire  [35:0]   tmr_sys_wr_data;
  wire           tmr_sys_rd_strb;
  wire           tmr_sys_rd_rdy_strb;
  wire           tmr_sys_wr_done_strb;
  
  wire           nvm_io_wr_strb;
  wire  [15:0]   nvm_sys_rd_addr;
  wire  [15:0]   nvm_sys_wr_addr;
  wire           nvm_sys_wr_strb;
  wire  [35:0]   nvm_sys_wr_data;
  wire  [35:0]   nvm_sys_rd_data;
  wire           nvm_sys_rd_strb;
  reg            nvm_sys_rd_strbZ1;
  reg            nvm_sys_wr_strbZ1;
  reg            nvm_sys_rd_rdy_strb;
  reg            nvm_sys_wr_done_strb;
  reg   [35:0]   nvm_io_wr_data;
  
  wire [15:0]    src_addr;           
  wire           src_rd_strb;        
  reg  [35:0]    src_rd_data;        
  wire           src_rd_rdy_strb;    
  
  wire           trg_done_strb;
  wire [15:0]    trg_addr;
  wire           trg_wr_strb;
  wire [35:0]    trg_wr_data;
  
    
  initial
  begin
    ram_sys_rd_strbZ1    <= 1'b0;
    ram_sys_wr_strbZ1    <= 1'b0;
    ram_sys_rd_rdy_strb  <= 1'b0;
    ram_sys_wr_done_strb <= 1'b0;
    
    nvm_sys_rd_strbZ1    <= 1'b0;
    nvm_sys_wr_strbZ1    <= 1'b0;
    nvm_sys_rd_rdy_strb  <= 1'b0;
    nvm_sys_wr_done_strb <= 1'b0;
  end
 
  
  //Convert the net transaction into source reads and target writes
  SequenceNetTransaction  SequenceNetTransaction_i
  (  
    .clk(clk),                        // System clock 								input 
    .reset(reset),                    // System reset (syncronous)            input 
                                                                               
    .net(net),                        // Netlist transaction                  input 
    .net_strb(net_strb),              // Strobe to process the net            input 
    .net_done_strb(net_done_strb),    // Strobe that net has been processed   output
                                                                              
    .src_addr(src_addr),              // Source read adddress                 output
    .src_rd_strb(src_rd_strb),        // Source rd strobe                     output
    .src_rd_data(src_rd_data),        // Data read from source                input 
    .src_rd_rdy_strb(src_rd_rdy_strb),// Strobe that read data is ready       input 
    .src_error(1'b0),                 // Source error                         input 
                                                                              
    .trg_done_strb(trg_done_strb),    // Target write is completed            input 
    .trg_addr(trg_addr),              // Target write address                 output
    .trg_wr_strb(trg_wr_strb),        // Target wr strobe                     output
    .trg_wr_data(trg_wr_data)         // Target wr data                       output
  );


  // Translate source reads and target writes to be from specific hardware blocks
  
  
  // Read address will always be source address
  assign con_sys_rd_addr = src_addr;
  assign reg_sys_rd_addr = src_addr;
  assign alu_sys_rd_addr = src_addr;
  assign ram_sys_rd_addr = src_addr;
  assign nvm_sys_rd_addr = src_addr;
     
  // Write address will always be target address
  assign con_sys_wr_addr = trg_addr;
  assign reg_sys_wr_addr = trg_addr;
  assign alu_sys_wr_addr = trg_addr;
  assign ram_sys_wr_addr = trg_addr;
  assign nvm_sys_wr_addr = trg_addr;
  
  // Constant is only one address
  always@(con_sys_wr_strb,con_sys_rd_addr,con_sys_wr_addr)
  begin
    case (con_sys_wr_strb) 
      1'b0    :  con_sys_addr <= con_sys_rd_addr;
      1'b1    :  con_sys_addr <= con_sys_wr_addr;
      default :  con_sys_addr <= con_sys_rd_addr;
    endcase
  end 
       
  // ALU is only one address
  always@(alu_sys_wr_strb,alu_sys_rd_addr,alu_sys_wr_addr)
  begin
    case (alu_sys_wr_strb) 
      1'b0    :  alu_sys_addr <= alu_sys_rd_addr;
      1'b1    :  alu_sys_addr <= alu_sys_wr_addr;
      default :  alu_sys_addr <= alu_sys_rd_addr;
    endcase
  end      
   
   
  // Read Strobe
  assign con_sys_rd_strb = src_rd_strb & ~src_addr[15] & ~src_addr[14] & ~src_addr[13] & ~src_addr[12];
  
  assign reg_sys_rd_strb = src_rd_strb & ~src_addr[15] & ~src_addr[14] &  src_addr[13] & ~src_addr[12];
  assign alu_sys_rd_strb = src_rd_strb & ~src_addr[15] & ~src_addr[14] &  src_addr[13] &  src_addr[12];  
  assign ram_sys_rd_strb = src_rd_strb & ~src_addr[15] &  src_addr[14] & ~src_addr[13] & ~src_addr[12];
  assign tmr_sys_rd_strb = src_rd_strb & ~src_addr[15] &  src_addr[14] & ~src_addr[13] &  src_addr[12];
  assign nvm_sys_rd_strb = src_rd_strb & ~src_addr[15] &  src_addr[14] &  src_addr[13] & ~src_addr[12];

  // Write Strobe
  assign con_sys_wr_strb = trg_wr_strb & ~trg_addr[15] & ~trg_addr[14] & ~trg_addr[13] & ~trg_addr[12];
  
  assign reg_sys_wr_strb = trg_wr_strb & ~trg_addr[15] & ~trg_addr[14] &  trg_addr[13] & ~trg_addr[12];
  assign alu_sys_wr_strb = trg_wr_strb & ~trg_addr[15] & ~trg_addr[14] &  trg_addr[13] &  trg_addr[12];
  assign ram_sys_wr_strb = trg_wr_strb & ~trg_addr[15] &  trg_addr[14] & ~trg_addr[13] & ~trg_addr[12];
  assign tmr_sys_wr_strb = trg_wr_strb & ~trg_addr[15] &  trg_addr[14] & ~trg_addr[13] &  trg_addr[12];
  assign nvm_sys_wr_strb = trg_wr_strb & ~trg_addr[15] &  trg_addr[14] &  trg_addr[13] & ~trg_addr[12];
    
  // Target write data
  always@(src_addr[14:12],con_sys_rd_data,reg_sys_rd_data,alu_sys_rd_data,ram_sys_rd_data,nvm_sys_rd_data)
  begin
    case (src_addr[14:12])
      3'h0    : src_rd_data <= con_sys_rd_data;
      3'h1    : src_rd_data <= {36{1'b0}};
      3'h2    : src_rd_data <= reg_sys_rd_data;
      3'h3    : src_rd_data <= alu_sys_rd_data;
      3'h4    : src_rd_data <= ram_sys_rd_data;
      3'h5    : src_rd_data <= {36{1'b0}};
      3'h6    : src_rd_data <= nvm_sys_rd_data;
      3'h7    : src_rd_data <= {36{1'b0}};
      default : src_rd_data <= {36{1'b0}};
    endcase
  end

  // Read ready strobe indicates data read is ready.
  assign src_rd_rdy_strb = con_sys_rd_rdy_strb | reg_sys_rd_rdy_strb | alu_sys_rd_rdy_strb | ram_sys_rd_rdy_strb | tmr_sys_rd_rdy_strb | nvm_sys_rd_rdy_strb;

  // Write has completed
  assign trg_done_strb = con_sys_wr_done_strb | reg_sys_wr_done_strb | alu_sys_wr_done_strb | ram_sys_wr_done_strb | tmr_sys_wr_done_strb | nvm_sys_wr_done_strb;

  //Map out data to write
  assign reg_sys_wr_data = trg_wr_data;
  assign alu_sys_wr_data = trg_wr_data;
  assign ram_sys_wr_data = trg_wr_data;
  assign tmr_sys_wr_data = trg_wr_data;
  assign nvm_sys_wr_data = trg_wr_data;
  

  //  System Constants
  SystemConstants SystemConstants_i
  (  
    .clk(clk),                          // System clock 
    .reset(reset),                      // System reset (syncronous)
    .rdwr_addr(con_sys_addr),           // rd/wr adddress
    .rd_strb(con_sys_rd_strb),          // Source rd strobe
    .wr_strb(con_sys_wr_strb),          // Source rd strobe
    .rd_data(con_sys_rd_data),          // Data read from source
    .rd_rdy_strb(con_sys_rd_rdy_strb),  // Strobe that read data is ready
    .wr_done_strb(con_sys_wr_done_strb) // Strobe that write is complete
  );  

  // ALU Interface
  SystemALU SystemALU_i
  (  
    .clk(clk),                           // System clock 
    .reset(reset),                       // System reset (syncronous)   
    .rdwr_addr(alu_sys_addr[7:0]),       // rd/wr adddress
    .rd_strb(alu_sys_rd_strb),           // Source rd strobe  
    .wr_strb(alu_sys_wr_strb),           // Source wr strobe  
    .wr_data(alu_sys_wr_data),           // Target write data
    .rd_data(alu_sys_rd_data),           // Data read from source
    .rd_rdy_strb(alu_sys_rd_rdy_strb),   // Strobe that read data is ready
    .wr_done_strb(alu_sys_wr_done_strb)  // Strobe that write is complete
  );

  // General Purpose rd/wr RAM
  defparam BlockRAM_GPrdwr_i.BRAM_INITIAL_FILE = BRAM_MEMORY_FILE;
  BlockRAM  BlockRAM_GPrdwr_i
  (
    .clk(clk),                          // System Clock
    .rdaddr(ram_sys_rd_addr[8:0]),      // read address [8:0] 
    .wraddr(ram_sys_wr_addr[8:0]),      // write address [8:0]
    .we(ram_sys_wr_strb),               // write enable
    .datain(ram_sys_wr_data),           // data to write [35:0]
    .dataout(ram_sys_rd_data)           // data output [35:0]
  );
  
  // Read ready strobe for RAM
  always@(posedge clk)
  begin
    if (reset) begin
      ram_sys_rd_strbZ1   <= 1'b0;
      ram_sys_rd_rdy_strb <= 1'b0;
    end else begin
      ram_sys_rd_strbZ1   <= ram_sys_rd_strb;
      ram_sys_rd_rdy_strb <= ram_sys_rd_strbZ1;
    end
  end  
  
  
  // Write done strobe for RAM
  always@(posedge clk)
  begin
    if (reset) begin
      ram_sys_wr_strbZ1    <= 1'b0;
      ram_sys_wr_done_strb <= 1'b0;
    end else begin
      ram_sys_wr_strbZ1    <= ram_sys_wr_strb;
      ram_sys_wr_done_strb <= ram_sys_wr_strbZ1;
    end
  end
  
  // System Timer
  SystemTimers SystemTimers_i
  (  
    .clk(clk),                          // System clock 
    .reset(reset),                      // System reset (syncronous)   
    .rd_strb(tmr_sys_rd_strb),          // Target wr strobe   
    .wr_strb(tmr_sys_wr_strb),          // Target wr strobe   
    .wr_data(tmr_sys_wr_data[33:18]),   // Source read data
    .rd_rdy_strb(tmr_sys_rd_rdy_strb),  // Strobe that read data is ready
    .wr_done_strb(tmr_sys_wr_done_strb) // Strobe that write is complete
  );  
  
  
  //NVM Access
  defparam NVM_SST25VF010A_i.BRAM_NVM_FILE = BRAM_NVM_FILE;
  NVM_SST25VF010A NVM_SST25VF010A_i 
  (
    .clk(clk),                          // System Clock
    .reset(reset),                      // System Reset (Syncronous) 
    .enable(1'b1),                      // Enable operation
    .sys_tmr_strb(sys_tmr_strb),        // System Timer Strobe
  
    .nvm_io_wr_command(nvm_sys_wr_data),// [35:32] =  NVM command ,[31:24] = NVM opcode, [23:0] = NVM Address
    .nvm_io_wr_data(nvm_io_wr_data),    // NVM data word to write
    .nvm_io_wr_strb(nvm_io_wr_strb),    // NVM write strobe for command/data 
    .nvm_io_srvcd_strb(),               // NVM serviced strobe
  
    .nvm_rd_addr(nvm_sys_rd_addr[9:0]), // NVM rd address
    .nvm_rd_data(nvm_sys_rd_data),      // NVM rd data
    
    .NVM_DOUT(NVM_DOUT),                // NVM output line
    .NVM_DIN(NVM_DIN),                  // NVM input line  
    .NVM_DCLK(NVM_DCLK),                // NVM clock line
    .NVM_CS_L(NVM_CS_L),                // NVM chip select
    .NVM_HOLD(NVM_HOLD),                // NVM hold
    .NVM_WP(NVM_WP)                     // NVM write protect    
  );  
  
  // IO write strobe only when writing to 
  assign nvm_io_wr_strb = ~nvm_sys_wr_addr[0] & nvm_sys_wr_strb;
  
  //Capture data to write to NVM first in two part write command
  always@(posedge clk)
  begin
    if (reset)
      nvm_io_wr_data <= 36'h000000000;
    else if (nvm_sys_wr_addr[0] && nvm_sys_wr_strb)
      nvm_io_wr_data <= nvm_sys_wr_data;
  end
  
  // Read ready strobe for NVM
  always@(posedge clk)
  begin
    if (reset) begin
      nvm_sys_rd_strbZ1   <= 1'b0;
      nvm_sys_rd_rdy_strb <= 1'b0;
    end else begin
      nvm_sys_rd_strbZ1   <= nvm_sys_rd_strb;
      nvm_sys_rd_rdy_strb <= nvm_sys_rd_strbZ1;
    end
  end    
  
  // Write done strobe for NVM
  always@(posedge clk)
  begin
    if (reset) begin
      nvm_sys_wr_strbZ1    <= 1'b0;
      nvm_sys_wr_done_strb <= 1'b0;
    end else begin
      nvm_sys_wr_strbZ1    <= nvm_sys_wr_strb;
      nvm_sys_wr_done_strb <= nvm_sys_wr_strbZ1;
    end
  end  
  
       
endmodule
