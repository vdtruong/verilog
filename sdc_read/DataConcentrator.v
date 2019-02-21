//-----------------------------------------------------------------
//  Module:     DataConcentrator
//  Project:    
//  Version:    0.01-1
//
//  Description: Sequentially read and write all system registers.
//
//-----------------------------------------------------------------
module DataConcentrator
# (parameter MSG_TIME = 16'h490C)       // Counter value to time expected for each read and write
(  
  input               clk,              // System Clock 
  input               reset,            // System Reset (Syncronous) 
  input               enable,           // System enable
  input               sys_tmr_strb,     // System timer strobe 100 ms.
  
  output reg [35:0]   rd_data,          // Concentrated Data read  
  input               rd_strb,          // Concentrated Read Register Strobe
  input       [8:0]   rd_addr,          // Concentrated Address to read from  
  input               wr_strb,          // Concentrated Write Register Strobe
  input       [8:0]   wr_addr,          // Concentrated Address to read from  
  input      [35:0]   wr_data,          // Concentrated Data to write 
  
  output reg [15:0]   cmd_uic_addr,     // UIC Address to read from
  output reg          cmd_uic_rd_strb,  // UIC Read subsystem register strobe
  output reg          cmd_uic_wr_strb,  // UIC Write subsystem register strobe
  output     [35:0]   cmd_uic_wr_data,  // UIC Data to write to the bus
  input      [35:0]   cmd_uic_rd_data,  // UIC Data read from the bus
  input               cmd_uic_rdy_strb, // UIC Strobe that read data is ready
  
  output reg [15:0]   cmd_con_addr,     // CONTROL Address to read from
  output reg          cmd_con_rd_strb,  // CONTROL Read subsystem register strobe
  output reg          cmd_con_wr_strb,  // CONTROL Write subsystem register strobe
  output     [35:0]   cmd_con_wr_data,  // CONTROL Data to write to the bus
  input      [35:0]   cmd_con_rd_data,  // CONTROl Data read from the bus
  input               cmd_con_rdy_strb, // CONTROL Strobe that read data is ready
  
  output reg [15:0]   cmd_saf_addr,     // SAFETY Address to read from
  output reg          cmd_saf_rd_strb,  // SAFETY Read subsystem register strobe
  output reg          cmd_saf_wr_strb,  // SAFETY Write subsystem register strobe
  output     [35:0]   cmd_saf_wr_data,  // SAFETY Data to write to the bus
  input      [35:0]   cmd_saf_rd_data,  // SAFETY Data read from the bus
  input               cmd_saf_rdy_strb, // SAFETY Strobe that read data is ready

  output reg [15:0]   cmd_ioc_addr,     // IO Address to read from
  output              cmd_ioc_rd_strb,  // IO Read subsystem register strobe
  output              cmd_ioc_wr_strb,  // IO Write subsystem register strobe
  output     [35:0]   cmd_ioc_wr_data,  // IO Data to write to the bus
  input      [35:0]   cmd_ioc_rd_data,  // IO Data read from the bus
  input               cmd_ioc_rdy_strb  // IO Strobe that read data is ready  
); 
    
  wire [9:0]    ioc_rd_addr;
  wire [35:0]   rd_buff_data;
  wire          rd_io_direct;
  
  wire [35:0]   sys_rd_data;
  wire [35:0]   sys_rd_address;
  reg  [9:0]    sys_rd_addr;  
  wire [9:0]    sys_wr_addr;
  wire          next_seq_strb;
  wire [8:0]    seq_cntr;
  wire [15:0]   msg_tmr_cntr;
  wire          seq_done_strb;
  
  reg           sys_addr_bit;
  reg           ioc_addr_bit;
  reg           msg_action_strb;
  reg           sys_wr_strb;
  reg [35:0]    sys_wr_data;
    
//  wire          ts_ioc_A_push_strb;
//  wire [6:0]    ts_ioc_A_push_addr;  
//  wire          ts_ioc_A_pop_strb;
//  wire [6:0]    ts_ioc_A_pop_addr;  
//  wire          ts_ioc_A_is_empty;  
//  wire          ts_ioc_B_push_strb;
//  wire [6:0]    ts_ioc_B_push_addr;  
//  wire          ts_ioc_B_pop_strb; 
//  wire [6:0]    ts_ioc_B_pop_addr;  
//  wire          ts_ioc_B_is_empty;  

  wire          ts_con_A_push_strb;
  wire [6:0]    ts_con_A_push_addr;  
  wire          ts_con_A_pop_strb;
  wire [6:0]    ts_con_A_pop_addr;  
  wire          ts_con_A_is_empty;  
  wire          ts_con_B_push_strb;
  wire [6:0]    ts_con_B_push_addr;  
  wire          ts_con_B_pop_strb; 
  wire [6:0]    ts_con_B_pop_addr;  
  wire          ts_con_B_is_empty;

  wire          ts_saf_A_push_strb;
  wire [6:0]    ts_saf_A_push_addr;  
  wire          ts_saf_A_pop_strb;
  wire [6:0]    ts_saf_A_pop_addr;  
  wire          ts_saf_A_is_empty;  
  wire          ts_saf_B_push_strb;
  wire [6:0]    ts_saf_B_push_addr;  
  wire          ts_saf_B_pop_strb; 
  wire [6:0]    ts_saf_B_pop_addr;  
  wire          ts_saf_B_is_empty;

  wire          ts_uic_A_push_strb;
  wire [6:0]    ts_uic_A_push_addr;  
  wire          ts_uic_A_pop_strb;
  wire [6:0]    ts_uic_A_pop_addr;  
  wire          ts_uic_A_is_empty;  
  wire          ts_uic_B_push_strb;
  wire [6:0]    ts_uic_B_push_addr;  
  wire          ts_uic_B_pop_strb; 
  wire [6:0]    ts_uic_B_pop_addr;  
  wire          ts_uic_B_is_empty;  
  
    
  wire [35:0]   ioc_push_data; 
  reg  [9:0]    ioc_push_addr;  
  wire [35:0]   ioc_push_address;
  wire          ioc_push_strb;          
  
  reg           wr_strb_Z1;
  reg           wr_strb_Z2;

  wire [2:0]    push_addr_sel;
  wire [2:0]    pop_addr_sel;  

  wire          cmd_ioc_wr_en;
  wire          cmd_con_wr_en;
  wire          cmd_saf_wr_en;
  wire          cmd_uic_wr_en;  
    
  reg           running_seq;  
    
  //Initialize
  initial
  begin
    running_seq       <= 1'b0;
    cmd_uic_rd_strb   <= 1'b0;
    cmd_uic_wr_strb   <= 1'b0;
    cmd_con_rd_strb   <= 1'b0;
    cmd_con_wr_strb   <= 1'b0;
    cmd_saf_rd_strb   <= 1'b0;
    cmd_saf_wr_strb   <= 1'b0;
    //cmd_ioc_rd_strb   <= 1'b0;
    //cmd_ioc_wr_strb   <= 1'b0;
    sys_addr_bit      <= 1'b0;
    ioc_addr_bit      <= 1'b1;
    msg_action_strb   <= 1'b0;
    sys_wr_strb       <= 1'b0;
    sys_wr_data       <= 36'h000000000;   
    
    wr_strb_Z1        <= 1'b0;
    wr_strb_Z2        <= 1'b0;
  end
  
      
  
//-----------------------------------------------------------------  
// EVERY SYSTEM FRAME - 
//            SEQUENCE THROUGH READING/WRITING FROM/TO ALL SYSTEMS
//-----------------------------------------------------------------
  
  //---------------------------------------------------------------
  // Sequence through all system reads/writes 
    defparam SeqCounter_i.dw  = 9;
    defparam SeqCounter_i.max = 9'h1FF;               
  //---------------------------------------------------------------
  CounterSeq SeqCounter_i
  (
    .clk(clk),                        // Clock input 50 MHz 
    .reset(reset),                    // GSR
    .enable(enable & next_seq_strb),  // Enable Counter
    .start_strb(sys_tmr_strb),        // Strobe to start hold
    .cntr(seq_cntr),                  // Sequence Counter 
    .strb(seq_done_strb)              // Sequence done strobe
  );    
  
  
  //---------------------------------------------------------------
  // Timer for each message
    defparam MsgTmrCounter_i.dw  = 16;
    defparam MsgTmrCounter_i.max = MSG_TIME;               
  //---------------------------------------------------------------
  Counter MsgTmrCounter_i
  (
    .clk(clk),                          // Clock input 50 MHz 
    .reset(reset | sys_tmr_strb),       // GSR
    .enable(enable & running_seq),      // Enable Counter
    .cntr(msg_tmr_cntr),                // Msg Timer Counter 
    .strb(next_seq_strb)                // Next message strobe
  );   
  
  //Flag that sequence is running
  always@(posedge clk)
  begin
    if (reset || seq_done_strb)
      running_seq <= 1'b0;
    else if (sys_tmr_strb)
      running_seq <= 1'b1;    
  end
  
  //Delays to extend write process
  always@(posedge clk)
  begin
    if (reset) begin
      wr_strb_Z1 <= 1'b0;  
      wr_strb_Z2 <= 1'b0;
    end else begin
      wr_strb_Z1 <= wr_strb;
      wr_strb_Z2 <= wr_strb_Z1;
    end
  end
  
  //---------------------------------------------------------------
  // CONVERT WRITING ADDRESS AND READING ADDRESS
  // ALTERNATE SPACES EVERY SYSTEM FRAM
  // INFORMATION READ AND RECIEVED WILL BE 1 FRAME DELAY
  always@(posedge clk)
  begin
    if (reset) begin
      sys_addr_bit <= 1'b0;
      ioc_addr_bit <= 1'b1;
    end else if (sys_tmr_strb)  begin
      sys_addr_bit <= ~sys_addr_bit;
      ioc_addr_bit <= ~ioc_addr_bit;
    end
  end
  
  assign ioc_rd_addr = {ioc_addr_bit,rd_addr};
  
  // END CONVERT WRITING ADDRESS AND READING ADDRESS  
  //---------------------------------------------------------------  
  //
  // Sequence 
  // 000-07F (Read From IO Controller)                      (Write To IO Controller Lane) if Mask is Set
  // 080-0FF (Read From Control Lane)                       (Write To Control Lane) if Mask is Set
  // 100-17F (Read From Safety Lane)                        (Write To Safety Lane) if Mask is Set
  // 180-1FF (Read From UIC)                                (Write To UIC) if Mask is Set  
  // 200 Done
  
  // sub_address = seq_cntr[6:0]; //Ranges 00-7F
  // sub_select  = seq_cntr[8:7]; //00 = uic, 01 = con, 10 = saf, 11 = ioc
  // wr_enable   = seq_cntr[9];   //Write cycles

  //Strobe to perform rd/wr action on system bus
  always@(posedge clk)
  begin
    if (reset)
      msg_action_strb = 1'b0;
    else if (msg_tmr_cntr == 16'h0001)
      msg_action_strb = 1'b1;
    else
      msg_action_strb = 1'b0;
  end  

  // UIC Address from reading fifos or sequence counter
  // Address to read and write is derived
  // sequence counter lsb when in read from mode writing into RAM
  // address read out of fifo to write to uic subsystem
  always@(cmd_uic_wr_en,seq_cntr,sys_rd_address[6:0])
  begin
    case (cmd_uic_wr_en)
      1'b0    : cmd_uic_addr  = {9'h000,seq_cntr[6:0]};       // Reads
      1'b1    : cmd_uic_addr  = {9'h000,sys_rd_address[6:0]}; // Writes
      default : cmd_uic_addr  = {9'h000,seq_cntr[6:0]};       // Reads
    endcase  
  end
  
  // Enable to read from UIC fifo "00"
  assign cmd_uic_wr_en = ~seq_cntr[8] & ~seq_cntr[7];
    
  //Data to write will always be what is read from FIFO
  assign cmd_uic_wr_data = sys_rd_data;
  
  //UIC rd strb
  always@(posedge clk)
  begin
    if (reset)
      cmd_uic_rd_strb <= 1'b0;
    else if (seq_cntr[8:7] == 2'b11 && msg_action_strb == 1'b1)
      cmd_uic_rd_strb <= 1'b1;
    else
      cmd_uic_rd_strb <= 1'b0;
  end  
  
  // CON Address from reading fifos or sequence counter
  // Address to read and write is derived
  // sequence counter lsb when in read from mode writing into RAM
  // address read out of fifo to write to uic subsystem
  always@(cmd_con_wr_en,seq_cntr,sys_rd_address[6:0])
  begin
    case (cmd_con_wr_en)
      1'b0    : cmd_con_addr  = {9'h000,seq_cntr[6:0]};       // Reads
      1'b1    : cmd_con_addr  = {9'h000,sys_rd_address[6:0]}; // Writes
      default : cmd_con_addr  = {9'h000,seq_cntr[6:0]};       // Reads
    endcase  
  end  
  
  // Enable to read from CON fifo "10"
  assign cmd_con_wr_en =  seq_cntr[8] & ~seq_cntr[7];
    
  //Data to write will always be what is read from FIFO
  assign cmd_con_wr_data = sys_rd_data;
  
  //CON rd strb
  always@(posedge clk)
  begin
    if (reset)
      cmd_con_rd_strb <= 1'b0;
    else if (seq_cntr[8:7] == 2'b01 && msg_action_strb == 1'b1)
      cmd_con_rd_strb <= 1'b1;
    else
      cmd_con_rd_strb <= 1'b0;
  end
  
  // SAF Address from reading fifos or sequence counter
  // Address to read and write is derived
  // sequence counter lsb when in read from mode writing into RAM
  // address read out of fifo to write to uic subsystem
  always@(cmd_saf_wr_en,seq_cntr,sys_rd_address[6:0])
  begin
    case (cmd_saf_wr_en)
      1'b0    : cmd_saf_addr  = {9'h000,seq_cntr[6:0]};       // Reads
      1'b1    : cmd_saf_addr  = {9'h000,sys_rd_address[6:0]}; // Writes
      default : cmd_saf_addr  = {9'h000,seq_cntr[6:0]};       // Reads
    endcase  
  end    
  
  // Enable to read from SAF fifo "01"
  assign cmd_saf_wr_en = ~seq_cntr[8] &  seq_cntr[7];  
  
  //Data to write will always be what is read from FIFO
  assign cmd_saf_wr_data = sys_rd_data;
  
  //SAF rd strb
  always@(posedge clk)
  begin
    if (reset)
      cmd_saf_rd_strb <= 1'b0;
    else if (seq_cntr[8:7] == 2'b10 && msg_action_strb == 1'b1)
      cmd_saf_rd_strb <= 1'b1;
    else
      cmd_saf_rd_strb <= 1'b0;
  end
    
  
// ALLOW DIRECT ACCESS TO IOC, NO DELAYS  

  //IOC write enable 
  assign cmd_ioc_wr_en =  wr_strb | wr_strb_Z1 | wr_strb_Z2;
  
  //Select Read or write address
  always@(cmd_ioc_wr_en,rd_addr,wr_addr)
  begin
    case (cmd_ioc_wr_en)
      1'b0    : cmd_ioc_addr  = {9'h000,rd_addr[6:0]};  // Reads
      1'b1    : cmd_ioc_addr  = {9'h000,wr_addr[6:0]};  // Write
      default : cmd_ioc_addr  = {9'h000,rd_addr[6:0]};  // Reads
    endcase                                                         
  end                                                           
  
 
  //Data to write will always be direct
  assign cmd_ioc_wr_data = wr_data;
  
  //Direct read and write strobes if IO rd/wr
  assign cmd_ioc_rd_strb = ((rd_strb == 1'b1) && (rd_addr[8:7] == 2'b00)) ? 1'b1 : 1'b0;
  assign cmd_ioc_wr_strb = ((wr_strb == 1'b1) && (wr_addr[8:7] == 2'b00)) ? 1'b1 : 1'b0;

  //Read from system , write to BRAM
  always@(posedge clk)
  begin
    if (reset)
      sys_wr_data <= 36'h000000000;
//    else if (seq_cntr[8:7] == 2'b00 && cmd_ioc_rdy_strb)
//      sys_wr_data <= cmd_ioc_rd_data;
    else if (seq_cntr[8:7] == 2'b01 && cmd_con_rdy_strb)
      sys_wr_data <= cmd_con_rd_data;
    else if (seq_cntr[8:7] == 2'b10 && cmd_saf_rdy_strb)
      sys_wr_data <= cmd_saf_rd_data;
    else if (seq_cntr[8:7] == 2'b11 && cmd_uic_rdy_strb)
      sys_wr_data <= cmd_uic_rd_data;      
  end


  //Strobe to write in the data read  
  always@(posedge clk)
  begin
    if (reset)
      sys_wr_strb <= 1'b0;
    else if (cmd_uic_rdy_strb || cmd_con_rdy_strb || cmd_saf_rdy_strb)// || cmd_ioc_rdy_strb)
      sys_wr_strb <= 1'b1;
    else
      sys_wr_strb <= 1'b0;
  end       

  //Address for system reads and writes based on counter and ping-pong selection bit. 
  assign sys_wr_addr = {sys_addr_bit, seq_cntr[8], seq_cntr[7],seq_cntr[6:0]};  
   

	//---------------------------------------------------------------
	// DPM FOR IOC READING FROM SUBSYSTEMS
	// IOC IS PORT B, SUBSYSTEM IS PORT A
	// Port "a" is for writing, port "b" is for reading.
	// Write system data to port A and read it out of port B.
   defparam BlockRAM_DPM_Reads_i.BRAM_DPM_INITIAL_FILE = "C:/FPGA_Design/PAKPUCIO/src/BRAM_1024_x_36.txt";
	//---------------------------------------------------------------  
	BlockRAM_DPM_1024_x_36 BlockRAM_DPM_Reads_i
	(
		.clk(clk),                // System Clock					input     
		.addr_a(sys_wr_addr),     // address port A, input    input     
		.datain_a(sys_wr_data),   // data to write port A     input     
		.wr_a(sys_wr_strb),       // Write strobe port A      input     
		.addr_b(ioc_rd_addr),     // address port B           input     
		.wr_b(1'b0),              // write enable             input     
		.datain_b(36'h000000000), // data to write port B     input     
		.dataout_a(),             // data output              output reg
		.dataout_b(rd_buff_data)  // data output              output reg
	);    
  
  //Flag to determine if read direct IO or from subsystem buffers.
  assign rd_io_direct = (rd_addr[8:7] == 2'b00) ? 1'b1 : 1'b0;
  
  //Select read data to be either from memory or direct depending on ioc_rd_addr
  always@(rd_io_direct,rd_buff_data,cmd_ioc_rd_data)
    begin
      case (rd_io_direct)
        1'b0    : rd_data <= rd_buff_data;
        1'b1    : rd_data <= cmd_ioc_rd_data;	// from puc_io_con
        default : rd_data <= rd_buff_data;
      endcase
    end
    
  //---------------------------------------------------------------
  // DPM FOR IOC WRITING TO SUBSYSTEMS SET UP AS FIFO
  
  // Convert Write Address and Data into 
  assign ioc_push_data    = wr_data;                                    // Write Data
  assign ioc_push_address = {28'h0000000,wr_addr[8:0]};                 // Write subsystem address     
  assign ioc_push_strb    = ts_con_A_push_strb | ts_con_B_push_strb |
                            ts_saf_A_push_strb | ts_saf_B_push_strb |
                            ts_uic_A_push_strb | ts_uic_B_push_strb; //ts_ioc_A_push_strb | ts_ioc_B_push_strb | 

      
  //Push into ioc write fifo if upper address bits are 00
//  assign ts_ioc_A_push_strb =  ioc_addr_bit & ~wr_addr[8] & ~wr_addr[7] & wr_strb & ~rd_strb;   
//  assign ts_ioc_B_push_strb = ~ioc_addr_bit & ~wr_addr[8] & ~wr_addr[7] & wr_strb & ~rd_strb;
//  assign ts_ioc_A_pop_strb  =  sys_addr_bit & ~ts_ioc_A_is_empty & msg_action_strb & cmd_ioc_wr_en;
//  assign ts_ioc_B_pop_strb  = ~sys_addr_bit & ~ts_ioc_B_is_empty & msg_action_strb & cmd_ioc_wr_en;

  //Push into con write fifo if upper address bits are 00
  assign ts_con_A_push_strb =  ioc_addr_bit & ~wr_addr[8] &  wr_addr[7] & wr_strb & ~rd_strb;   
  assign ts_con_B_push_strb = ~ioc_addr_bit & ~wr_addr[8] &  wr_addr[7] & wr_strb & ~rd_strb;
  assign ts_con_A_pop_strb  =  sys_addr_bit & ~ts_con_A_is_empty & msg_action_strb & cmd_con_wr_en;
  assign ts_con_B_pop_strb  = ~sys_addr_bit & ~ts_con_B_is_empty & msg_action_strb & cmd_con_wr_en;
  
  //Push into saf write fifo if upper address bits are 00
  assign ts_saf_A_push_strb =  ioc_addr_bit &  wr_addr[8] & ~wr_addr[7] & wr_strb & ~rd_strb;   
  assign ts_saf_B_push_strb = ~ioc_addr_bit &  wr_addr[8] & ~wr_addr[7] & wr_strb & ~rd_strb;
  assign ts_saf_A_pop_strb  =  sys_addr_bit & ~ts_saf_A_is_empty & msg_action_strb & cmd_saf_wr_en;
  assign ts_saf_B_pop_strb  = ~sys_addr_bit & ~ts_saf_B_is_empty & msg_action_strb & cmd_saf_wr_en;

  //Push into uic write fifo if upper address bits are 00
  assign ts_uic_A_push_strb =  ioc_addr_bit &  wr_addr[8] &  wr_addr[7] & wr_strb & ~rd_strb;   
  assign ts_uic_B_push_strb = ~ioc_addr_bit &  wr_addr[8] &  wr_addr[7] & wr_strb & ~rd_strb;
  assign ts_uic_A_pop_strb  =  sys_addr_bit & ~ts_uic_A_is_empty & msg_action_strb & cmd_uic_wr_en;
  assign ts_uic_B_pop_strb  = ~sys_addr_bit & ~ts_uic_B_is_empty & msg_action_strb & cmd_uic_wr_en;
  
  //Select the address to push based on ping-pong bit and upper address bits
  assign push_addr_sel = {ioc_addr_bit,wr_addr[8:7]};
  
  //RAM address is built from time slice bit, subsystem, 6 bit address from fifo
  //ts_ioc_A_push_addr,
  //ts_ioc_B_push_addr,
  always@(push_addr_sel, ts_con_A_push_addr,ts_saf_A_push_addr,ts_uic_A_push_addr,
                         ts_con_B_push_addr,ts_saf_B_push_addr,ts_uic_B_push_addr)
  begin
    case (push_addr_sel)    
      3'b000   : ioc_push_addr <= 10'h000; //{1'b0,2'b00,ts_ioc_B_push_addr[6:0]};
      3'b001   : ioc_push_addr <= {1'b0,2'b01,ts_con_B_push_addr[6:0]};
      3'b010   : ioc_push_addr <= {1'b0,2'b10,ts_saf_B_push_addr[6:0]};
      3'b011   : ioc_push_addr <= {1'b0,2'b11,ts_uic_B_push_addr[6:0]};
      3'b100   : ioc_push_addr <= 10'h000; //{1'b1,2'b00,ts_ioc_A_push_addr[6:0]};
      3'b101   : ioc_push_addr <= {1'b1,2'b01,ts_con_A_push_addr[6:0]};
      3'b110   : ioc_push_addr <= {1'b1,2'b10,ts_saf_A_push_addr[6:0]};
      3'b111   : ioc_push_addr <= {1'b1,2'b11,ts_uic_A_push_addr[6:0]};
      default  : ioc_push_addr <= 10'h000; //{1'b0,2'b00,ts_ioc_B_push_addr[6:0]};
    endcase
  end
      
  // Read out of FIFO's and manage           
  //  Select the address to push based on ping-pong bit and upper address bits
  assign pop_addr_sel = {sys_addr_bit,~seq_cntr[8],~seq_cntr[7]};
  
  //ts_ioc_A_pop_addr,
  //ts_ioc_B_pop_addr,
  always@(pop_addr_sel, ts_con_A_pop_addr,ts_saf_A_pop_addr,ts_uic_A_pop_addr,
                        ts_con_B_pop_addr,ts_saf_B_pop_addr,ts_uic_B_pop_addr)
  begin
    case (pop_addr_sel)
      3'b000  : sys_rd_addr <= 10'h000; // {1'b0,2'b00,ts_ioc_B_pop_addr[6:0]};
      3'b001  : sys_rd_addr <= {1'b0,2'b01,ts_con_B_pop_addr[6:0]};
      3'b010  : sys_rd_addr <= {1'b0,2'b10,ts_saf_B_pop_addr[6:0]};
      3'b011  : sys_rd_addr <= {1'b0,2'b11,ts_uic_B_pop_addr[6:0]};
      3'b100  : sys_rd_addr <= 10'h000; // {1'b1,2'b00,ts_ioc_A_pop_addr[6:0]};
      3'b101  : sys_rd_addr <= {1'b1,2'b01,ts_con_A_pop_addr[6:0]};
      3'b110  : sys_rd_addr <= {1'b1,2'b10,ts_saf_A_pop_addr[6:0]};
      3'b111  : sys_rd_addr <= {1'b1,2'b11,ts_uic_A_pop_addr[6:0]};
      default : sys_rd_addr <= 10'h000; // {1'b0,2'b00,ts_ioc_B_pop_addr[6:0]};
    endcase
  end
  
//  //Write Strobe for IOC
//  always@(posedge clk)
//  begin
//    if (reset)
//      cmd_ioc_wr_strb <= 1'b0;
//    else if (ts_ioc_A_pop_strb | ts_ioc_B_pop_strb)
//      cmd_ioc_wr_strb <= 1'b1;
//    else
//      cmd_ioc_wr_strb <= 1'b0;
//  end

  // Write Strobe for CON
  always@(posedge clk)
  begin
    if (reset)
      cmd_con_wr_strb <= 1'b0;
    else if (ts_con_A_pop_strb | ts_con_B_pop_strb)
      cmd_con_wr_strb <= 1'b1;
    else
      cmd_con_wr_strb <= 1'b0;
  end
  
  // Write Strobe for SAF
  always@(posedge clk)
  begin
    if (reset)
      cmd_saf_wr_strb <= 1'b0;
    else if (ts_saf_A_pop_strb | ts_saf_B_pop_strb)
      cmd_saf_wr_strb <= 1'b1;
    else
      cmd_saf_wr_strb <= 1'b0;
  end

  // Write Strobe for UIC
  always@(posedge clk)
  begin
    if (reset)
      cmd_uic_wr_strb <= 1'b0;
    else if (ts_uic_A_pop_strb | ts_uic_B_pop_strb)
      cmd_uic_wr_strb <= 1'b1;
    else
      cmd_uic_wr_strb <= 1'b0;
  end        
  
	// This is for saving and reading the data.
	// IOC IS PORT A, SUBSYSTEM IS PORT B
	// Port "a" is for writing, port "b" is for reading.
   defparam BlockRAM_DPM_WriteData_i.BRAM_DPM_INITIAL_FILE = "C:/FPGA_Design/PAKPUCIO/src/BRAM_1024_x_36.txt";
	//---------------------------------------------------------------  
	BlockRAM_DPM_1024_x_36 BlockRAM_DPM_WriteData_i
	(
		.clk(clk),                // System Clock					input     
		.addr_a(ioc_push_addr),   // address port A           input     
		.datain_a(ioc_push_data), // data to write port A     input     
		.wr_a(ioc_push_strb),     // Write strobe port A      input     
		.addr_b(sys_rd_addr),     // address port B           input     
		.wr_b(1'b0),              // write enable             input     
		.datain_b(36'h000000000), // data to write port B     input     
		.dataout_a(),             // data output              output reg
		.dataout_b(sys_rd_data)   // data output              output reg
	);

	// This is for saving and reading the address.
	// IOC IS PORT A, SUBSYSTEM IS PORT B
	// Port "a" is for writing, port "b" is for reading.
   defparam BlockRAM_DPM_WriteAddress_i.BRAM_DPM_INITIAL_FILE = "C:/FPGA_Design/PAKPUCIO/src/BRAM_1024_x_36.txt";
	//---------------------------------------------------------------  
	BlockRAM_DPM_1024_x_36 BlockRAM_DPM_WriteAddress_i
	(
		.clk(clk),                    // System Clock				input     
		.addr_a(ioc_push_addr),       // address port A          input     
		.datain_a(ioc_push_address),  // data to write port A    input     
		.wr_a(ioc_push_strb),         // Write strobe port A     input     
		.addr_b(sys_rd_addr),         // address port B          input     
		.wr_b(1'b0),                  // write enable            input     
		.datain_b(36'h000000000),     // data to write port B    input     
		.dataout_a(),                 // data output             output reg
		.dataout_b(sys_rd_address)    // data output             output reg
	);

	//FIFO CONTROLLERS 
  
	//Clear the fifo's every ping-pong
	assign ts_A_reset = seq_done_strb &  sys_addr_bit;
	assign ts_B_reset = seq_done_strb & ~sys_addr_bit;
  
//  // FIFO Controller For Time Slice A
//  defparam FifoController_IOC_A_i.WIDTH = 7;
//  FifoController FifoController_IOC_A_i
//  (
//    .clk(clk),                        // System Clock
//    .reset(reset | ts_A_reset),       // System Reset
//    .enable(enable),                  // Enable Fifo   
//    .rd_a_strb(ts_ioc_A_pop_strb),    // Read Strobe to empty
//    .wr_b_strb(ts_ioc_A_push_strb),   // Write Strobe to fill
//    .addr_a(ts_ioc_A_pop_addr),       // output address
//    .addr_b(ts_ioc_A_push_addr),      // input address
//    .fifo_empty(ts_ioc_A_is_empty),   // flag that fifo is empty
//    .fifo_full(),                     // flag that fifo is full
//    .fifo_half()                      // flag that fifo is half full
//  );
//
//  // FIFO Controller For Time Slice B
//  defparam FifoController_IOC_B_i.WIDTH = 7;
//  FifoController FifoController_IOC_B_i
//  (
//    .clk(clk),                        // System Clock
//    .reset(reset | ts_B_reset),       // System Reset
//    .enable(enable),                  // Enable Fifo   
//    .rd_a_strb(ts_ioc_B_pop_strb),    // Read Strobe to empty
//    .wr_b_strb(ts_ioc_B_push_strb),   // Write Strobe to fill
//    .addr_a(ts_ioc_B_pop_addr),       // output address
//    .addr_b(ts_ioc_B_push_addr),      // input address
//    .fifo_empty(ts_ioc_B_is_empty),   // flag that fifo is empty
//    .fifo_full(),                     // flag that fifo is full
//    .fifo_half()                      // flag that fifo is half full
//  );
  
  // FIFO Controller For Time Slice A
  defparam FifoController_CON_A_i.WIDTH = 7;
  FifoController FifoController_CON_A_i
  (
    .clk(clk),                        // System Clock							input     
    .reset(reset | ts_A_reset),       // System Reset                   input     
    .enable(enable),                  // Enable Fifo                    input     
    .rd_a_strb(ts_con_A_pop_strb),    // Read Strobe to empty           input     
    .wr_b_strb(ts_con_A_push_strb),   // Write Strobe to fill           input     
    .addr_a(ts_con_A_pop_addr),       // output address                 output reg
    .addr_b(ts_con_A_push_addr),      // input address                  output reg
    .fifo_empty(ts_con_A_is_empty),   // flag that fifo is empty        output reg
    .fifo_full(),                     // flag that fifo is full         output reg
    .fifo_half()                      // flag that fifo is half full    output reg
  );

  // FIFO Controller For Time Slice B
  defparam FifoController_CON_B_i.WIDTH = 7;
  FifoController FifoController_CON_B_i
  (
    .clk(clk),                        // System Clock
    .reset(reset | ts_B_reset),       // System Reset
    .enable(enable),                  // Enable Fifo   
    .rd_a_strb(ts_con_B_pop_strb),    // Read Strobe to empty
    .wr_b_strb(ts_con_B_push_strb),   // Write Strobe to fill
    .addr_a(ts_con_B_pop_addr),       // output address
    .addr_b(ts_con_B_push_addr),      // input address
    .fifo_empty(ts_con_B_is_empty),   // flag that fifo is empty
    .fifo_full(),                     // flag that fifo is full
    .fifo_half()                      // flag that fifo is half full
  );

  // FIFO Controller For Time Slice A
  defparam FifoController_SAF_A_i.WIDTH = 7;
  FifoController FifoController_SAF_A_i
  (
    .clk(clk),                        // System Clock
    .reset(reset | ts_A_reset),       // System Reset
    .enable(enable),                  // Enable Fifo   
    .rd_a_strb(ts_saf_A_pop_strb),    // Read Strobe to empty
    .wr_b_strb(ts_saf_A_push_strb),   // Write Strobe to fill
    .addr_a(ts_saf_A_pop_addr),       // output address
    .addr_b(ts_saf_A_push_addr),      // input address
    .fifo_empty(ts_saf_A_is_empty),   // flag that fifo is empty
    .fifo_full(),                     // flag that fifo is full
    .fifo_half()                      // flag that fifo is half full
  );

  // FIFO Controller For Time Slice B
  defparam FifoController_SAF_B_i.WIDTH = 7;
  FifoController FifoController_SAF_B_i
  (
    .clk(clk),                        // System Clock
    .reset(reset  | ts_B_reset),      // System Reset
    .enable(enable),                  // Enable Fifo   
    .rd_a_strb(ts_saf_B_pop_strb),    // Read Strobe to empty
    .wr_b_strb(ts_saf_B_push_strb),   // Write Strobe to fill
    .addr_a(ts_saf_B_pop_addr),       // output address
    .addr_b(ts_saf_B_push_addr),      // input address
    .fifo_empty(ts_saf_B_is_empty),   // flag that fifo is empty
    .fifo_full(),                     // flag that fifo is full
    .fifo_half()                      // flag that fifo is half full
  );

  // FIFO Controller For Time Slice A
  defparam FifoController_UIC_A_i.WIDTH = 7;
  FifoController FifoController_UIC_A_i
  (
    .clk(clk),                        // System Clock
    .reset(reset  | ts_A_reset),      // System Reset
    .enable(enable),                  // Enable Fifo   
    .rd_a_strb(ts_uic_A_pop_strb),    // Read Strobe to empty
    .wr_b_strb(ts_uic_A_push_strb),   // Write Strobe to fill
    .addr_a(ts_uic_A_pop_addr),       // output address
    .addr_b(ts_uic_A_push_addr),      // input address
    .fifo_empty(ts_uic_A_is_empty),   // flag that fifo is empty
    .fifo_full(),                     // flag that fifo is full
    .fifo_half()                      // flag that fifo is half full
  );

  // FIFO Controller For Time Slice B
  defparam FifoController_UIC_B_i.WIDTH = 7;
  FifoController FifoController_UIC_B_i
  (
    .clk(clk),                        // System Clock
    .reset(reset  | ts_B_reset),      // System Reset
    .enable(enable),                  // Enable Fifo   
    .rd_a_strb(ts_uic_B_pop_strb),    // Read Strobe to empty
    .wr_b_strb(ts_uic_B_push_strb),   // Write Strobe to fill
    .addr_a(ts_uic_B_pop_addr),       // output address
    .addr_b(ts_uic_B_push_addr),      // input address
    .fifo_empty(ts_uic_B_is_empty),   // flag that fifo is empty
    .fifo_full(),                     // flag that fifo is full
    .fifo_half()                      // flag that fifo is half full
  );  

  
endmodule
