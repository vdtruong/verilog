//-----------------------------------------------------------------
//  Module:     BusArbitration
//  Project:    
//  Version:    0.01-1
//
//  Description: Perform a time division rd/wr permision for each
//  interface requesting rd/wr's
//  6/26/14  This version includes data retreive for sdc card.
//
//
//-----------------------------------------------------------------
module BusArbitration
#(parameter ADDR_DW = 6)                           // ADRESS DATA WIDTH   
(  
  input                       clk,                 // System Clock 
  input                       reset,               // System Reset (Syncronous) 
  input                       enable,              // System enable
      
  input      [35:0]           rd_data,             // Arbitrated Data read from data concentrator  
  output                      rd_strb,             // Arbitrated Read Register Strobe to data concentrator 
  output reg [ADDR_DW-1:0]    rd_addr,             // Arbitrated Address to read from to data concentrator
  output reg [ADDR_DW-1:0]    wr_addr,             // Arbitrated Address to write to
  output                      wr_strb,             // Arbitrated Write Register Strobe
  output reg [35:0]           wr_data,             // Arbitrated Data to write 

  output reg [35:0]           tst_rd_data,         // Test Data read
  output                      tst_rdy_strb,        // Test Data read ready strobe  
  input                       tst_rd_strb,         // Test Read Register Strobe
  input      [ADDR_DW-1:0]    tst_rd_addr,         // Test Address to read from
  input      [ADDR_DW-1:0]    tst_wr_addr,         // Test Address to write to
  input                       tst_wr_strb,         // Test Write Register Strobe
  input      [35:0]           tst_wr_data,         // Test Data to write   

  output reg [35:0]           dnl_rd_data,         // Downlink Data read  
  output                      dnl_rdy_strb,        // Downlink Data read ready strobe
  input                       dnl_rd_strb,         // Downlink Read Register Strobe
  input      [ADDR_DW-1:0]    dnl_rd_addr,         // Downlink Address to read from
  input      [ADDR_DW-1:0]    dnl_wr_addr,         // Downlink Address to write to
  input                       dnl_wr_strb,         // Downlink Write Register Strobe
  input      [35:0]           dnl_wr_data,         // Downlink Data to write   

  output reg [35:0]           sub_rd_data,         // sub Data read  
  output                      sub_rdy_strb,        // sub Data read ready strobe
  input                       sub_rd_strb,         // sub Read Register Strobe
  input      [ADDR_DW-1:0]    sub_rd_addr,         // sub Address to read from
  input      [ADDR_DW-1:0]    sub_wr_addr,         // sub Address to write to
  input                       sub_wr_strb,         // sub Write Register Strobe
  input      [35:0]           sub_wr_data,         // sub Data to write   

  output reg [35:0]           aut_rd_data,         // Autonomous Data read  
  output                      aut_rdy_strb,        // Autonomous Data read ready strobe  
  input                       aut_rd_strb,         // Autonomous Read Register Strobe
  input      [ADDR_DW-1:0]    aut_rd_addr,         // Autonomous Address to read from
  input      [ADDR_DW-1:0]    aut_wr_addr,         // Autonomous Address to write to
  input                       aut_wr_strb,         // Autonomous Write Register Strobe
  input      [35:0]           aut_wr_data,         // Autonomous Data to write 
  output reg                  aut_wr_cmplt_strb,   // Strobe that a write has completed

  output reg [35:0]           sdc_rd_data,         // sdc Data read  
  output                      sdc_rdy_strb,        // sdc Data read ready strobe  
  input                       sdc_rd_strb,         // sdc Read Register Strobe
  input      [ADDR_DW-1:0]    sdc_rd_addr          // sdc Address to read from      
);
	      
  wire                tst_strb_wr;
  wire                tst_strb_rd;
  wire                tst_rd_done_strb;           // Strobe that holding test rd strb is done
  wire                tst_wr_done_strb;           // Strobe that holding test wr strb is done
  reg                 tst_rd_strb_h;              // Held test rd strobe
  reg                 tst_wr_strb_h;              // Held test wr strobe
  reg [ADDR_DW-1:0]   tst_rd_addr_h;              // Held test read address
  reg [ADDR_DW-1:0]   tst_wr_addr_h;              // Held test write address
  reg [35:0]          tst_wr_data_h;              // Held test write data

  wire                dnl_strb_wr;
  wire                dnl_strb_rd;
  wire                dnl_rd_done_strb;           // Strobe that holding down link rd strb is done
  wire                dnl_wr_done_strb;           // Strobe that holding down link wr strb is done
  reg                 dnl_rd_strb_h;              // Held down link rd strobe
  reg                 dnl_wr_strb_h;              // Held down link wr strobe
  reg [ADDR_DW-1:0]   dnl_rd_addr_h;              // Held down link read address
  reg [ADDR_DW-1:0]   dnl_wr_addr_h;              // Held down link write address
  reg [35:0]          dnl_wr_data_h;              // Held down link write data
  
  wire                sub_strb_wr;
  wire                sub_strb_rd;
  wire                sub_rd_done_strb;           // Strobe that holding sub rd strb is done
  wire                sub_wr_done_strb;           // Strobe that holding sub wr strb is done
  reg                 sub_rd_strb_h;              // Held sub rd strobe
  reg                 sub_wr_strb_h;              // Held sub wr strobe
  reg [ADDR_DW-1:0]   sub_rd_addr_h;              // Held sub read address
  reg [ADDR_DW-1:0]   sub_wr_addr_h;              // Held sub write address
  reg [35:0]          sub_wr_data_h;              // Held sub write data

  wire                aut_strb_wr;
  wire                aut_strb_rd;
  wire                aut_rd_done_strb;           // Strobe that holding autonomous rd strb is done
  //wire                aut_wr_done_strb;           // Strobe that holding autonomous wr strb is done
  reg                 aut_rd_strb_h;              // Held autonomous rd strobe
  reg                 aut_wr_strb_h;              // Held autonomous wr strobe
  reg [ADDR_DW-1:0]   aut_rd_addr_h;              // Held autonomous read address
  reg [ADDR_DW-1:0]   aut_wr_addr_h;              // Held autonomous write address
  reg [35:0]          aut_wr_data_h;              // Held autonomous write data
  
  wire                sdc_strb_rd;
  wire                sdc_rd_done_strb;           // Strobe that holding sdc rd strb is done
  reg                 sdc_rd_strb_h;              // Held sdc rd strobe
  reg [ADDR_DW-1:0]   sdc_rd_addr_h;              // Held sdc read address
  
  wire [4:0]  cntr_arb;                           // Output counter wire (reg)
        
  reg tst_rdy_strb_en;   
  reg dnl_rdy_strb_en;
  reg sub_rdy_strb_en;
  reg aut_rdy_strb_en;        
  reg sdc_rdy_strb_en;        
        
  //Initialize
  initial
  begin
    tst_rd_data       <= 36'h000000000;
    dnl_rd_data       <= 36'h000000000;
    sub_rd_data       <= 36'h000000000;
    aut_rd_data       <= 36'h000000000;
    sdc_rd_data       <= 36'h000000000;
  
    tst_rd_strb_h     <= 1'b0;
    tst_wr_strb_h     <= 1'b0;
    tst_rd_addr_h     <= {ADDR_DW{1'b0}};
    tst_wr_addr_h     <= {ADDR_DW{1'b0}};
    tst_wr_data_h     <= 36'h000000000;
   
    dnl_rd_strb_h     <= 1'b0;
    dnl_wr_strb_h     <= 1'b0;
    dnl_rd_addr_h     <= {ADDR_DW{1'b0}};
    dnl_wr_addr_h     <= {ADDR_DW{1'b0}};
    dnl_wr_data_h     <= 36'h000000000;

    sub_rd_strb_h     <= 1'b0;
    sub_wr_strb_h     <= 1'b0;
    sub_rd_addr_h     <= {ADDR_DW{1'b0}};
    sub_wr_addr_h     <= {ADDR_DW{1'b0}};
    sub_wr_data_h     <= 36'h000000000;

    aut_rd_strb_h     <= 1'b0;
    aut_wr_strb_h     <= 1'b0;
    aut_rd_addr_h     <= {ADDR_DW{1'b0}};
    aut_wr_addr_h     <= {ADDR_DW{1'b0}};
    aut_wr_data_h     <= 36'h000000000; 
    aut_wr_cmplt_strb <= 1'b0;
  
    sdc_rd_strb_h     <= 1'b0;
    sdc_rd_addr_h     <= {ADDR_DW{1'b0}};
     
    tst_rdy_strb_en   <= 1'b0;
    dnl_rdy_strb_en   <= 1'b0;
    sub_rdy_strb_en   <= 1'b0;
    aut_rdy_strb_en   <= 1'b0;
    sdc_rdy_strb_en   <= 1'b0;
     
  end
  
  
  // Capture and hold all input address, data inputs on strobe
  // Hold strobes for arbitration time for arbitrator to order
  // Time division multiplex rd/wr commands over 16 clocks. 4 clocks per interface.
      
  
//-----------------------------------------------------------------  
// TEST INTERFACE HOLD SIGNALS  
//-----------------------------------------------------------------
  
   //---------------------------------------------------------------
   // 22 counts read strobe hold for test interface
   defparam SeqCounter_tst_rd_i.dw  = 5;
   defparam SeqCounter_tst_rd_i.max = 5'h15;//5'h16;               
   //---------------------------------------------------------------
   CounterSeq SeqCounter_tst_rd_i
   ( 
    .clk(clk),                // Clock input 50 MHz 
    .reset(reset),            // GSR
    .enable(enable),          // Enable Counter
    .start_strb(tst_rd_strb), // Strobe to start hold
    .cntr(), 
    .strb(tst_rd_done_strb)   // Hold complete strobe             
   );    
  
   //---------------------------------------------------------------
   // 16 count write strobe hold for test interface
   defparam SeqCounter_tst_wr_i.dw  = 5;
   defparam SeqCounter_tst_wr_i.max = 5'h0F;               
   //---------------------------------------------------------------
   CounterSeq SeqCounter_tst_wr_i
   (
    .clk(clk),                // Clock input 50 MHz 
    .reset(reset),            // GSR
    .enable(enable),          // Enable Counter
    .start_strb(tst_wr_strb), // Strobe to start hold
    .cntr(), 
    .strb(tst_wr_done_strb)   // Hold complete strobe             
   );   
  
  //Hold read strobe from test interface
  always@(posedge clk)
  begin
    if (reset | tst_rd_done_strb)
        tst_rd_strb_h <= 1'b0;
    else if (tst_rd_strb)
        tst_rd_strb_h <= 1'b1;
  end
  
  //Capture and hold rd address
  always@(posedge clk)
  begin
    if (reset) begin
        tst_rd_addr_h <= {ADDR_DW{1'b0}};
    end else if (tst_rd_strb) begin
        tst_rd_addr_h <= tst_rd_addr;
    end
  end  
  
  //Hold write strobe from test interface
  always@(posedge clk)
  begin
    if (reset | tst_wr_done_strb)
        tst_wr_strb_h <= 1'b0;
    else if (tst_wr_strb)
        tst_wr_strb_h <= 1'b1;
  end  
  
  //Capture and hold wr address and write data
  always@(posedge clk)
  begin
    if (reset) begin
        tst_wr_addr_h <= {ADDR_DW{1'b0}};
        tst_wr_data_h <= 36'h000000000;
    end else if (tst_wr_strb) begin
        tst_wr_addr_h <= tst_wr_addr;
        tst_wr_data_h <= tst_wr_data;
    end
  end
  
//-----------------------------------------------------------------  
// END TEST INTERFACE HOLD SIGNALS  
//-----------------------------------------------------------------  
  
//-----------------------------------------------------------------  
// DOWNLINK INTERFACE HOLD SIGNALS  
//-----------------------------------------------------------------
  
   //---------------------------------------------------------------
   // 22 counts read strobe hold for test interface
   defparam SeqCounter_dnl_rd_i.dw  = 5;
   defparam SeqCounter_dnl_rd_i.max = 5'h15;               
   //---------------------------------------------------------------
   CounterSeq SeqCounter_dnl_rd_i
   (
    .clk(clk),                // Clock input 50 MHz 
    .reset(reset),            // GSR
    .enable(enable),          // Enable Counter
    .start_strb(dnl_rd_strb), // Strobe to start hold
    .cntr(), 
    .strb(dnl_rd_done_strb)   // Hold complete strobe             
   );    
  
   //---------------------------------------------------------------
   // 16 count write strobe hold for test interface
   defparam SeqCounter_dnl_wr_i.dw  = 5;
   defparam SeqCounter_dnl_wr_i.max = 5'h0F;               
   //---------------------------------------------------------------
   CounterSeq SeqCounter_dnl_wr_i
   (
    .clk(clk),                // Clock input 50 MHz 
    .reset(reset),            // GSR
    .enable(enable),          // Enable Counter
    .start_strb(dnl_wr_strb), // Strobe to start hold
    .cntr(), 
    .strb(dnl_wr_done_strb)   // Hold complete strobe             
   );   
  
  //Hold read strobe from test interface
  always@(posedge clk)
  begin
    if (reset | dnl_rd_done_strb)
        dnl_rd_strb_h <= 1'b0;
    else if (dnl_rd_strb)
        dnl_rd_strb_h <= 1'b1;
  end
  
  //Capture and hold rd address
  always@(posedge clk)
  begin
    if (reset) begin
        dnl_rd_addr_h <= {ADDR_DW{1'b0}};
    end else if (dnl_rd_strb) begin
        dnl_rd_addr_h <= dnl_rd_addr;
    end
  end  
  
  //Hold write strobe from test interface
  always@(posedge clk)
  begin
    if (reset | dnl_wr_done_strb)
        dnl_wr_strb_h <= 1'b0;
    else if (dnl_wr_strb)
        dnl_wr_strb_h <= 1'b1;
  end  
  
  //Capture and hold wr address and write data
  always@(posedge clk)
  begin
    if (reset) begin
        dnl_wr_addr_h <= {ADDR_DW{1'b0}};
        dnl_wr_data_h <= 36'h000000000;
    end else if (dnl_wr_strb) begin
        dnl_wr_addr_h <= dnl_wr_addr;
        dnl_wr_data_h <= dnl_wr_data;
    end
  end
  
//-----------------------------------------------------------------  
// END DOWNLINK INTERFACE HOLD SIGNALS  
//-----------------------------------------------------------------  

//-----------------------------------------------------------------  
// sub INTERFACE HOLD SIGNALS  
//-----------------------------------------------------------------
  
   //---------------------------------------------------------------
   // 22 counts read strobe hold for test interface
   defparam SeqCounter_sub_rd_i.dw  = 5;
   defparam SeqCounter_sub_rd_i.max = 5'h15;               
   //---------------------------------------------------------------
   CounterSeq SeqCounter_sub_rd_i
   (
    .clk(clk),                // Clock input 50 MHz 
    .reset(reset),            // GSR
    .enable(enable),          // Enable Counter
    .start_strb(sub_rd_strb), // Strobe to start hold
    .cntr(), 
    .strb(sub_rd_done_strb)   // Hold complete strobe             
   );    
  
   //---------------------------------------------------------------
   // 16 count write strobe hold for test interface
   defparam SeqCounter_sub_wr_i.dw  = 5;
   defparam SeqCounter_sub_wr_i.max = 5'h0F;               
   //---------------------------------------------------------------
   CounterSeq SeqCounter_sub_wr_i
   (
    .clk(clk),                // Clock input 50 MHz 
    .reset(reset),            // GSR
    .enable(enable),          // Enable Counter
    .start_strb(sub_wr_strb), // Strobe to start hold
    .cntr(), 
    .strb(sub_wr_done_strb)   // Hold complete strobe             
   );   
  
  //Hold read strobe from test interface
  always@(posedge clk)
  begin
    if (reset | sub_rd_done_strb)
        sub_rd_strb_h <= 1'b0;
    else if (sub_rd_strb)
        sub_rd_strb_h <= 1'b1;
  end
  
  //Capture and hold rd address
  always@(posedge clk)
  begin
    if (reset) begin
        sub_rd_addr_h <= {ADDR_DW{1'b0}};
    end else if (sub_rd_strb) begin
        sub_rd_addr_h <= sub_rd_addr;
    end
  end  
  
  //Hold write strobe from test interface
  always@(posedge clk)
  begin
    if (reset | sub_wr_done_strb)
        sub_wr_strb_h <= 1'b0;
    else if (sub_wr_strb)
        sub_wr_strb_h <= 1'b1;
  end  
  
  //Capture and hold wr address and write data
  always@(posedge clk)
  begin
    if (reset) begin
        sub_wr_addr_h <= {ADDR_DW{1'b0}};
        sub_wr_data_h <= 36'h000000000;
    end else if (sub_wr_strb) begin
        sub_wr_addr_h <= sub_wr_addr;
        sub_wr_data_h <= sub_wr_data;
    end
  end
  
//-----------------------------------------------------------------  
// END sub INTERFACE HOLD SIGNALS  
//-----------------------------------------------------------------  

//-----------------------------------------------------------------  
// AUTONOMOUS INTERFACE HOLD SIGNALS  
//-----------------------------------------------------------------
  
   //---------------------------------------------------------------
   // 22 counts read strobe hold for test interface
   defparam SeqCounter_aut_rd_i.dw  = 5;
   defparam SeqCounter_aut_rd_i.max = 5'h15;               
   //---------------------------------------------------------------
   CounterSeq SeqCounter_aut_rd_i
   (
    .clk(clk),                // Clock input 50 MHz 
    .reset(reset),            // GSR
    .enable(aut_rd_strb_h),   // Enable Counter
    .start_strb(aut_rd_strb), // Strobe to start hold
    .cntr(), 
    .strb(aut_rd_done_strb)   // Hold complete strobe             
   );    
  
//  //---------------------------------------------------------------
//  // 16 count write strobe hold for test interface
//    defparam SeqCounter_aut_wr_i.dw = 5;
//    defparam SeqCounter_aut_wr_i.max = 5'h10;               
//  //---------------------------------------------------------------
//  gCounterSeq SeqCounter_aut_wr_i
//  (
//    .clk(clk),                // Clock input 50 MHz 
//    .reset(reset),            // GSR
//    .enable(enable),          // Enable Counter
//    .start_strb(aut_wr_strb), // Strobe to start hold
//    .cntr(), 
//    .strb(aut_wr_done_strb)   // Hold complete strobe             
//  );   
  
  //Hold read strobe from test interface
  always@(posedge clk)
  begin
    if (reset | aut_rd_done_strb | aut_rdy_strb)
        aut_rd_strb_h <= 1'b0;
    else if (aut_rd_strb)
        aut_rd_strb_h <= 1'b1;
  end
  
  //Capture and hold rd address
  always@(posedge clk)
  begin
    if (reset) begin
        aut_rd_addr_h <= {ADDR_DW{1'b0}};
    end else if (aut_rd_strb) begin
        aut_rd_addr_h <= aut_rd_addr;
    end
  end  
  
  //Hold write strobe from test interface
  always@(posedge clk)
  begin
    if (reset | aut_strb_wr)
        aut_wr_strb_h <= 1'b0;
    else if (aut_wr_strb)
        aut_wr_strb_h <= 1'b1;
  end  
  
  //Capture and hold wr address and write data
  always@(posedge clk)
  begin
    if (reset) begin
        aut_wr_addr_h <= {ADDR_DW{1'b0}};
        aut_wr_data_h <= 36'h000000000;
    end else if (aut_wr_strb) begin
        aut_wr_addr_h <= aut_wr_addr;
        aut_wr_data_h <= aut_wr_data;
    end
  end
  
//-----------------------------------------------------------------  
// END AUTONOMOUS INTERFACE HOLD SIGNALS  
//-----------------------------------------------------------------  
        
//-----------------------------------------------------------------  
// SDC INTERFACE HOLD SIGNALS  
//-----------------------------------------------------------------
  
   //---------------------------------------------------------------
   // 22 counts read strobe hold for sdc interface
   defparam SeqCounter_sdc_rd_i.dw  = 5;
   defparam SeqCounter_sdc_rd_i.max = 5'h15;               
   //---------------------------------------------------------------
   CounterSeq SeqCounter_sdc_rd_i
   (
    .clk(clk),                // Clock input 50 MHz 
    .reset(reset),            // GSR
    .enable(enable),          // Enable Counter
    .start_strb(sdc_rd_strb), // Strobe to start hold
    .cntr(), 
    .strb(sdc_rd_done_strb)   // Hold complete strobe             
   );   
  
   //Hold read strobe from sdc interface
   always@(posedge clk)
   begin
     if (reset | sdc_rd_done_strb)
        sdc_rd_strb_h <= 1'b0;
     else if (sdc_rd_strb)
        sdc_rd_strb_h <= 1'b1;
   end
  
   //Capture and hold rd address
   always@(posedge clk)
   begin
     if (reset) begin
        sdc_rd_addr_h <= {ADDR_DW{1'b0}};
     end else if (sdc_rd_strb) begin
        sdc_rd_addr_h <= sdc_rd_addr;
     end
   end  
  
//-----------------------------------------------------------------  
// END SDC INTERFACE HOLD SIGNALS  
//-----------------------------------------------------------------


   //---------------------------------------------------------------
   // 20 counts 
   defparam Counter_i.dw  = 5;
   defparam Counter_i.max = 5'h13;//5'h15;//5'h13;               
   //---------------------------------------------------------------
   Counter Counter_i
   (
    .clk(clk),            // Clock input 50 MHz 
    .reset(reset),        // GSR
    .enable(enable),      // Enable Counter
    .cntr(cntr_arb),      // Counter value for arbitration
    .strb()               
   );  
  
    
  //Read Address
  always@(cntr_arb[4:2],tst_rd_addr_h,dnl_rd_addr_h,sub_rd_addr_h,aut_rd_addr_h,sdc_rd_addr_h)
  begin
    case (cntr_arb[4:2])
      3'b000   : rd_addr <= tst_rd_addr_h;  
      3'b001   : rd_addr <= dnl_rd_addr_h;
      3'b010   : rd_addr <= sub_rd_addr_h;
      3'b011   : rd_addr <= aut_rd_addr_h;
      3'b100   : rd_addr <= sdc_rd_addr_h;
      default  : rd_addr <= tst_rd_addr_h;  
    endcase
  end 
  
  //Write Address
  always@(cntr_arb[3:2],tst_wr_addr_h,dnl_wr_addr_h,sub_wr_addr_h,aut_wr_addr_h)
  begin
    case (cntr_arb[3:2])
      2'b00   : wr_addr <= tst_wr_addr_h;  
      2'b01   : wr_addr <= dnl_wr_addr_h;
      2'b10   : wr_addr <= sub_wr_addr_h;
      2'b11   : wr_addr <= aut_wr_addr_h;
      default : wr_addr <= tst_wr_addr_h;  
    endcase
  end 
  
  //Write Data
  always@(cntr_arb[3:2],tst_wr_data_h,dnl_wr_data_h,sub_wr_data_h,aut_wr_data_h)
  begin
    case (cntr_arb[3:2])
      2'b00   : wr_data <= tst_wr_data_h;  
      2'b01   : wr_data <= dnl_wr_data_h;
      2'b10   : wr_data <= sub_wr_data_h;
      2'b11   : wr_data <= aut_wr_data_h;
      default : wr_data <= tst_wr_data_h;  
    endcase
  end 

  //Wr Strobe
  assign tst_strb_wr  = (cntr_arb == 5'b00000 & tst_wr_strb_h) ? 1'b1 : 1'b0; // 0
  assign dnl_strb_wr  = (cntr_arb == 5'b00100 & dnl_wr_strb_h) ? 1'b1 : 1'b0; // 4
  assign sub_strb_wr  = (cntr_arb == 5'b01000 & sub_wr_strb_h) ? 1'b1 : 1'b0; // 8
  assign aut_strb_wr  = (cntr_arb == 5'b01100 & aut_wr_strb_h) ? 1'b1 : 1'b0; // 12
  assign wr_strb      = (tst_strb_wr | dnl_strb_wr | sub_strb_wr | aut_strb_wr);

  
  //Rd Strobe
  assign tst_strb_rd  = (cntr_arb == 5'b00000 & tst_rd_strb_h) ? 1'b1 : 1'b0; // 0
  assign dnl_strb_rd  = (cntr_arb == 5'b00100 & dnl_rd_strb_h) ? 1'b1 : 1'b0; // 4
  assign sub_strb_rd  = (cntr_arb == 5'b01000 & sub_rd_strb_h) ? 1'b1 : 1'b0; // 8
  assign aut_strb_rd  = (cntr_arb == 5'b01100 & aut_rd_strb_h) ? 1'b1 : 1'b0; // 12
  assign sdc_strb_rd  = (cntr_arb == 5'b10000 & sdc_rd_strb_h) ? 1'b1 : 1'b0; // 16
  assign rd_strb      = (tst_strb_rd | dnl_strb_rd | sub_strb_rd | aut_strb_rd | sdc_strb_rd);
     

  //Enable ready signals only if following a rd strb
  always@(posedge clk)
  begin
    if (reset)
      tst_rdy_strb_en <= 1'b0;
    else if (tst_strb_rd)
      tst_rdy_strb_en <= 1'b1;
    else if (tst_rd_done_strb)
      tst_rdy_strb_en <= 1'b0;      
  end

  always@(posedge clk)
  begin
    if (reset)
      dnl_rdy_strb_en <= 1'b0;
    else if (dnl_strb_rd)
      dnl_rdy_strb_en <= 1'b1;
    else if (dnl_rd_done_strb)
      dnl_rdy_strb_en <= 1'b0;      
  end
  
  always@(posedge clk)
  begin
    if (reset)
      sub_rdy_strb_en <= 1'b0;
    else if (sub_strb_rd)
      sub_rdy_strb_en <= 1'b1;
    else if (sub_rd_done_strb)
      sub_rdy_strb_en <= 1'b0;      
  end

  always@(posedge clk)
  begin
    if (reset)
      aut_rdy_strb_en <= 1'b0;
    else if (aut_strb_rd)
      aut_rdy_strb_en <= 1'b1;
    else if (aut_rd_done_strb | aut_rdy_strb)
      aut_rdy_strb_en <= 1'b0;      
  end
  
  always@(posedge clk)
  begin
    if (reset)
      sdc_rdy_strb_en <= 1'b0;
    else if (sdc_strb_rd)
      sdc_rdy_strb_en <= 1'b1;
    else if (sdc_rd_done_strb)
      sdc_rdy_strb_en <= 1'b0;      
  end
      
  //Capture read data    
  assign tst_rdy_strb = (cntr_arb == 5'b00011 & tst_rd_strb_h & tst_rdy_strb_en) ? 1'b1 : 1'b0; // 3
  assign dnl_rdy_strb = (cntr_arb == 5'b00111 & dnl_rd_strb_h & dnl_rdy_strb_en) ? 1'b1 : 1'b0; // 7
  assign sub_rdy_strb = (cntr_arb == 5'b01011 & sub_rd_strb_h & sub_rdy_strb_en) ? 1'b1 : 1'b0; // 11
  assign aut_rdy_strb = (cntr_arb == 5'b01111 & aut_rd_strb_h & aut_rdy_strb_en) ? 1'b1 : 1'b0; // 15
  assign sdc_rdy_strb = (cntr_arb == 5'b10011 & sdc_rd_strb_h & sdc_rdy_strb_en) ? 1'b1 : 1'b0; // 19

  always@(posedge clk)
  begin
    if (reset)
      tst_rd_data <= 36'h000000000;
    else if (cntr_arb == 5'b00010 & tst_rd_strb_h) // 2
      tst_rd_data <= rd_data;
  end

  always@(posedge clk)
  begin
    if (reset)
      dnl_rd_data <= 36'h000000000;
    else if (cntr_arb == 5'b00110 & dnl_rd_strb_h) // 6
      dnl_rd_data <= rd_data;
  end
  
  always@(posedge clk)
  begin
    if (reset)
      sub_rd_data <= 36'h000000000;
    else if (cntr_arb == 5'b01010 & sub_rd_strb_h) // 10
      sub_rd_data <= rd_data;
  end

  always@(posedge clk)
  begin
    if (reset)
      aut_rd_data <= 36'h000000000;
    else if (cntr_arb == 5'b01110 & aut_rd_strb_h) // 14
      aut_rd_data <= rd_data;
  end

  always@(posedge clk)
  begin
    if (reset)
      sdc_rd_data <= 36'h000000000;
    else if (cntr_arb == 5'b10010 & sdc_rd_strb_h) // 18
      sdc_rd_data <= rd_data;
  end

  // Auto wr done strb
  always@(posedge clk)
  begin
    if (reset)
      aut_wr_cmplt_strb <= 1'b0;
    else 
      aut_wr_cmplt_strb <= aut_strb_wr;
  end
  
endmodule
