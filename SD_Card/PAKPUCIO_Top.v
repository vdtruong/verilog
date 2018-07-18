//--------------------------------------------------------------------------
//  Module:     PAKPUCIO_Top
//  Project:    PAK Pumping Unit Controller
//  Version:    0.1
//
//  Description: Implements the top level module for the PAK PUC Controller
//	 Update:     5/13/14  Added RTC and ready for writing data to sd card.
//              6/12/14  Should add fpga revisions to the log?
//              6/12/14  Updated the Bus Arb. to work with the sdc card. 
// 
//--------------------------------------------------------------------------
   

 
module PAKPUCIO_Top  
//-----------------FPGA VERSION------------------------------------------------------
#(parameter FPGA_VERSION = 16'h0172)   
//----------------END FPGA VERSION---------------------------------------------------
(
	input         CLK_IO_50MHZ,             // System 50 MHz Clock
	input         IO_LOGIC_RESET_N,         // System Logic Reset (Active Low)
	output        IO_READY,                 // Discrete to indicate GTE off            
	output        IO_DISCRETE1,             // NH Logic discrete to COM
	output        IO_DISCRETE2,             // NL Logic discrete to COM
  
	// Next two signals are for LabVIEW.
	input         PUC_IO_TEST_RX,           // FTDI Test COM Interface RX          
	output        PUC_IO_TEST_TX,           // FTDI Test COM Interface TX
  
	output        DWNLINK_RX_IO_TX,         // COM Interface to COM FPGA TX
	input         DWNLINK_TX_IO_RX,         // COM Interface to COM FPGA RX   
 
	// Next two signals are for UIC Communication.
	output        IO_TX_UIC_RX,
	input         IO_RX_UIC_TX,
	
	input         UIC_CABLE_DET_N,

	// Next four signals are for UPLINK.
	input         IO_RX_C_TX,               // Control Interface RX
	output        IO_TX_C_RX,               // Control Interface TX
	input         IO_RX_S_TX,               // Safety Interface RX
	output        IO_TX_S_RX,               // Safety Interface TX 
  
	input         SBC_TO_IO,                
	output        IO_TO_SBC,
	input         SBC_CABLE_DET_N,

	output        IO_ADC1_CLK,
	output        IO_ADC1_CS_N,
	output        IO_ADC1_DIN,
	input         IO_ADC1_DOUT,
	input         IO_ADC1_BUSY,
  
	output        IO_EE_DIN,
	input         IO_EE_DOUT,
	output        IO_EE_DCLK,
	output        IO_EE_CS_L,
	output        IO_EE_HOLD,
	output        IO_EE_WP,
	output        DIN1_IO,
	input         DOUT1_IO,
	output        DCLK1_IO,
	input         CS1_IO_N, //Normally Output - Safety OFF Button
	output        DIN2_IO,
	input         DOUT2_IO,
	output        DCLK2_IO,
	output        CS2_IO_N,
  
	input        IO_SDC1_CD_WP,
	inout        IO_SDC1_D0,
	inout        IO_SDC1_D1,
	inout        IO_SDC1_D2,
	inout        IO_SDC1_D3,
	output       IO_SDC1_CLK,
	inout        IO_SDC1_CMD,
  
//  output        IO_SDC1_CD_WP,
//  output        IO_SDC1_D0,
//  output        IO_SDC1_D1,
//  output        IO_SDC1_D2,
//  output        IO_SDC1_D3,
//  output        IO_SDC1_CLK,
//  output        IO_SDC1_CMD,
  
  output        IO_SDC2_CD_WP,
  output        IO_SDC2_D0,
  output        IO_SDC2_D1,
  output        IO_SDC2_D2,
  output        IO_SDC2_D3,
  output        IO_SDC2_CLK,
  output        IO_SDC2_CMD,
  
  inout         RTC_I2C_SDA,
  inout         RTC_I2C_SCL,
  input         RTC_IRQ_N,
  
  output        MEAS_RTC_BAT,
  
  output        STATUS_LED_0,     // Status LED 0 logic low to turn on
  output        STATUS_LED_1,     // Status LED 1 logic low to turn on
  output        STATUS_LED_2,     // Status LED 2 logic low to turn on
  output        STATUS_LED_3,     // Status LED 3 logic low to turn on
  output        STATUS_LED_4,     // Status LED 4 logic low to turn on
  output        STATUS_LED_5,     // Status LED 5 logic low to turn on
  output        STATUS_LED_6,     // Status LED 6 logic low to turn on
  output        STATUS_LED_7,     // Status LED 7 logic low to turn on
  output [15:0] LA
);
  
  localparam NL_SEQ_LS = 64;
  localparam NL_MEM_SIZE = 4096;    
  localparam NL_ADDR_WD = 12;    
  localparam NL_DATA_WD = 36;       
  
  //Module connections
  wire                  clk;                 // System Clock
  wire                  reset;               // Logic Reset
  wire 		            strb_sysTmr;         // System Strobe   
  
  wire [7:0]            led_cntr;            // Counter to flash status LEDs
  
  wire [35:0]           rd_data;             // Arbitrated Data read  
  wire                  rd_strb;             // Arbitrated Read Register Strobe
  wire [8:0]            rd_addr;             // Arbitrated Address to read from
  wire [8:0]            wr_addr;             // Arbitrated Address to write to
  wire                  wr_strb;             // Arbitrated Write Register Strobe
  wire [35:0]           wr_data;             // Arbitrated Data to write 
  
  wire                  tst_rdy_strb;  
  wire [35:0]           tst_rd_data;         // Test Data read  
  wire                  tst_rd_strb;         // Test Read Register Strobe
  wire [9:0]            tst_rd_addr;         // Test Address to read from
  wire [9:0]            tst_wr_addr;         // Test Address to write to
  wire                  tst_wr_strb;         // Test Write Register Strobe
  wire [35:0]           tst_wr_data;         // Test Data to write 
  wire [1:0]            tst_comm_err;        // Test Communication Error
  
  wire                  dnl_rdy_strb;  
  wire [35:0]           dnl_rd_data;         // Downlink Data read  
  wire                  dnl_rd_strb;         // Downlink Read Register Strobe
  wire [9:0]            dnl_rd_addr;         // Downlink Address to read from
  wire [9:0]            dnl_wr_addr;         // Downlink Address to write to
  wire                  dnl_wr_strb;         // Downlink Write Register Strobe
  wire [35:0]           dnl_wr_data;         // Downlink Data to write 
  wire [1:0]            dnl_comm_err;        // Downlink Communication Error
  
  wire                  sub_rdy_strb;
  wire [35:0]           sub_rd_data;         // Sublink Data read  
  wire                  sub_rd_strb;         // Sublink Read Register Strobe
  wire [9:0]            sub_rd_addr;         // Sublink Address to read from
  wire [9:0]            sub_wr_addr;         // Sublink Address to write to
  wire                  sub_wr_strb;         // Sublink Write Register Strobe
  wire [35:0]           sub_wr_data;         // Sublink Data to write 
  wire [1:0]            sub_comm_err;        // Sublink Communication Error

  wire                  dwnlink_tx;          // Switch lines for downlink tx
  wire                  dwnlink_rx;          // Switch lines for downlink rx
  wire                  sublink_tx;          // Switch lines for sublink tx
  wire                  sublink_rx;          // Switch lines for sublink rx
  wire                  sub_tx;              // Switch lines for sublink tx
  wire                  sub_rx;              // Switch lines for sublink rx
  
  wire                  aut_rdy_strb;
  wire [35:0]           aut_rd_data;         // Autonomous Data read  
  wire                  aut_rd_strb;         // Autonomous Read Register Strobe
  wire [15:0]           aut_rd_addr;         // Autonomous Address to read from
  wire [15:0]           aut_wr_addr;         // Autonomous Address to write to
  wire                  aut_wr_strb;         // Autonomous Write Register Strobe
  wire [35:0]           aut_wr_data;         // Autonomous Data to write
  
  wire [15:0]           cmd_uic_addr;       // UIC Address to read from
  wire                  cmd_uic_rd_strb;    // UIC Read subsystem register strobe
  wire                  cmd_uic_wr_strb;    // UIC Write subsystem register strobe
  wire [35:0]           cmd_uic_wr_data;    // UIC Data to write to the bus
  wire [35:0]           cmd_uic_rd_data;    // UIC Data read from the bus
  wire                  cmd_uic_rdy_strb;   // UIC Strobe that read data is ready
  
  wire [15:0]           cmd_con_addr;       // CONTROL Address to read from
  wire                  cmd_con_rd_strb;    // CONTROL Read subsystem register strobe
  wire                  cmd_con_wr_strb;    // CONTROL Write subsystem register strobe
  wire [35:0]           cmd_con_wr_data;    // CONTROL Data to write to the bus
  wire [35:0]           cmd_con_rd_data;    // CONTROl Data read from the bus
  wire                  cmd_con_rdy_strb;   // CONTROL Strobe that read data is ready
  
  wire [15:0]           cmd_saf_addr;       // SAFETY Address to read from
  wire                  cmd_saf_rd_strb;    // SAFETY Read subsystem register strobe
  wire                  cmd_saf_wr_strb;    // SAFETY Write subsystem register strobe
  wire [35:0]           cmd_saf_wr_data;    // SAFETY Data to write to the bus
  wire [35:0]           cmd_saf_rd_data;    // SAFETY Data read from the bus
  wire                  cmd_saf_rdy_strb;   // SAFETY Strobe that read data is ready

  wire [15:0]           cmd_ioc_addr;       // IO Address to read from
  wire                  cmd_ioc_rd_strb;    // IO Read subsystem register strobe
  wire                  cmd_ioc_wr_strb;    // IO Write subsystem register strobe
  wire [35:0]           cmd_ioc_wr_data;    // IO Data to write to the bus
  wire [35:0]           cmd_ioc_rd_data;    // IO Data read from the bus
  wire                  cmd_ioc_rdy_strb;   // IO Strobe that read data is ready    
  
  wire [1:0]            cmd_uic_err;        // Error Flags for UIC
  wire [1:0]            cmd_con_err;        // Error Flags for CON
  wire [1:0]            cmd_saf_err;        // Error Flags for SAF
  
  wire                  RTC_I2C_SCL_in;     // Input SCL (As Slave)
  wire                  RTC_I2C_SCL_out;    // Output SCL (As Master)    
  wire                  RTC_I2C_SDA_in;     // Input SDA (Master Ack/Nack, Slave Recieve)
  wire                  RTC_I2C_SDA_out;    // Output SDA (Master/Slave Ack/Nack)

	// For SD Card.
	wire						IO_SDC1_CMD_in;
	wire						IO_SDC1_CMD_out;
	wire						IO_SDC1_D0_in;
	wire						IO_SDC1_D1_in;
	wire						IO_SDC1_D2_in;
	wire						IO_SDC1_D3_in;
	wire						IO_SDC1_D0_out;
	wire						IO_SDC1_D1_out;
	wire						IO_SDC1_D2_out;
	wire						IO_SDC1_D3_out;
	
	wire						strt_fifo_strb;  
	wire             		sdc_rdy_strb;
	wire [35:0]          sdc_rd_data;         // sdc Data read  
	wire                 sdc_rd_strb;         // sdc Read Register Strobe
	wire [15:0]          sdc_rd_addr;         // sdc Address to read from
	wire [63:0]          puc_data;         	// data to write to host bus fifo
	wire						puc_data_strb;		   // strobe to write to fifo
	wire                 rdy_for_nxt_pkt;	   // ready for next packet (fifo_data) from puc.
   wire 		            strb_data_cntr;      // strobe to latch date time stamp
	///////////////////////////////////////     
  
  wire                  sub_seq_strb;        // Strob to run sub sequence 1 
  wire [NL_ADDR_WD-1:0] sub_seq_addr;        // Address of subsequence to run
  wire [NL_ADDR_WD-1:0] sub_seq_cnt;         // Number of nets in the subsequence
  wire                  sub_seq_done;        // Flag that the sub sequence run has completed. 
    
  wire                  net_wr_strb;         // Net List
  wire [NL_ADDR_WD-1:0] net_wr_addr;         // Net Address
  wire [35:0]           net_wr_data;         // Net Data    
  
  wire [1:0]            COM_Cntrl;          // Output flag from UIC FGPA to Actel COM FPGA
  wire [11:0]           comm_err;           // Comm error vector  
 
  wire                  aut_wr_done_strb;
  
  wire                  sys_tmr_strb;       // System Timer Strobe

  wire [15:0]           LogicAnalyzer;      // Logic Debug for Logic Analyze
  
  wire                  backup_switch;  
  reg                   estop_pressed;  
  initial               estop_pressed <= 1'b0;
  
//---------------------------------------------------------------  
// CLOCK AND RESET SIGNALS
  assign clk    = CLK_IO_50MHZ;
  assign reset  = ~IO_LOGIC_RESET_N;    
//---------------------------------------------------------------
  
//---------------------------------------------------------------
//SYSTEM TIMING STROBES

// SYSTEM TIMER STROBE (POR OR 500ms)
    reg     reset_Z1;
    reg     reset_Z2;
    wire    por_strb;
    initial reset_Z1 <= 1'b0;
    initial reset_Z1 <= 1'b0;
    
    always@(posedge clk)
    begin
      reset_Z1 <= reset;
      reset_Z2 <= reset_Z1;
    end
 
    assign por_strb     = ~reset_Z1 & reset_Z2; 
    assign sys_tmr_strb = por_strb | strb_sysTmr;     
    
   //---------------------------------------------------------------
   // SysTmrStrbe 
   defparam StrobeSysTmr_i.dw = 25;
   defparam StrobeSysTmr_i.max = 25'h17D783F;    //dec2hex(floor((500E-3/20E-9)-1))         
   //defparam StrobeSysTmr_i.dw = 25;
   //defparam StrobeSysTmr_i.max = 25'h098967F;  //dec2hex(floor((200E-3/20E-9)-1)) 
   //---------------------------------------------------------------
   Counter StrobeSysTmr_i
   (
      .clk(clk),            // Clock input 50 MHz 
      .reset(reset),        // GSR
      .enable(1'b1),        // Enable Counter
      .cntr(),              // Counter value
      .strb(strb_sysTmr)    // 1 Clk Strb when Counter == max 500 ms
   );      
//---------------------------------------------------------------
// End sys timer strobe
//---------------------------------------------------------------

////---------------------------------------------------------------
//// LED Test Outputs
////---------------------------------------------------------------   
  
  assign STATUS_LED_0 = LogicAnalyzer[0];  
  assign STATUS_LED_1 = LogicAnalyzer[1];  
  assign STATUS_LED_2 = LogicAnalyzer[2];  
  assign STATUS_LED_3 = LogicAnalyzer[3];  
  assign STATUS_LED_4 = LogicAnalyzer[4];  
  assign STATUS_LED_5 = LogicAnalyzer[5]; 
  assign STATUS_LED_6 = LogicAnalyzer[6]; 
  assign STATUS_LED_7 = LogicAnalyzer[7]; 

//---------------------------------------------------------------
// END LED Test Counter  
//---------------------------------------------------------------  

	// Chipscope for sd card
	
//	wire [35:0]  control0;
//	wire [127:0] cs_test_vector_0;
//	wire [127:0] cs_test_vector_0_tmp;
//
//	chipscope_icon1 cs_test_icon
//		(
//			.CONTROL0(control0)              // inout
//		);
//
//	chipscope_ila_1k_trig cs_test_ila0
//		(
//			.CONTROL(control0),              // inout 
//			.CLK(clk),                       // input 
//			.TRIG0(cs_test_vector_0_tmp),    // input 
//			.TRIG_OUT()                      // output
//		);
//		
//	assign cs_test_vector_0_tmp = cs_test_vector_0;
  
//---------------------------------------------------------------	
// COM PORT TEST 921600, 8, E, 1
//---------------------------------------------------------------
   defparam COM_Port_Test_i.ascii_prompt  = 8'h6D;    // m
	defparam COM_Port_Test_i.BAUD_MASK     = 16'h0035;
	defparam COM_Port_Test_i.BAUD_QUALIFY  = 16'h0024;
   defparam COM_Port_Test_i.PARITY_BIT    = 1'b1;
   defparam COM_Port_Test_i.CLEAR_ON_IDLE = 1'b0;
   defparam COM_Port_Test_i.ADDR_DW       = 10;
   defparam COM_Port_Test_i.ECHO_ON       = 1'b1;
	CommControlSlave COM_Port_Test_i
   (  
    .clk(clk),                  // System Clock 					input 
    .reset(reset),              // System Reset (Syncronous)   input 
    .enable(1'b1),              // Enable COM                  input 
    .rx_en(1'b1),  	           // Recieve enable              input 
    .rx(PUC_IO_TEST_RX),        // Data recieve bit            input 
    .tx(PUC_IO_TEST_TX),        // Tx bit to send out on pin   output
    .tx_en(),                   // Tx enable signal            output
    .rd_data(tst_rd_data),      // Data read                   input 
    .rd_rdy_strb(tst_rdy_strb), // Strobe to send read data    input 
    .rd_strb(tst_rd_strb),      // Read Register Strobe        output
    .rd_addr(tst_rd_addr),      // Address to read from        output
    .wr_addr(tst_wr_addr),      // Address to write to         output
    .wr_strb(tst_wr_strb),      // Write Register Strobe       output
    .wr_data(tst_wr_data),      // Data to write               output
    .error(tst_comm_err)        // Error in Com                output
   );                                                           
//---------------------------------------------------------------	
// END COM PORT TEST
//---------------------------------------------------------------

//---------------------------------------------------------------	
// COM PORT DOWNLINK 921600, 8, E, 1  (COM CONTROLLER)
// This is for the SBC board.
//---------------------------------------------------------------
   defparam COM_Port_DwnLink_i.ascii_prompt  = 8'h6D;    // m
	defparam COM_Port_DwnLink_i.BAUD_MASK     = 16'h0035;
	defparam COM_Port_DwnLink_i.BAUD_QUALIFY  = 16'h0024;
   defparam COM_Port_DwnLink_i.PARITY_BIT    = 1'b1;
   defparam COM_Port_DwnLink_i.CLEAR_ON_IDLE = 1'b0;
   defparam COM_Port_DwnLink_i.ADDR_DW       = 10;    
   defparam COM_Port_DwnLink_i.ECHO_ON       = 1'b1;
	CommControlSlave COM_Port_DwnLink_i
   (  
    .clk(clk),                  // System Clock						input  
    .reset(reset),              // System Reset (Syncronous)   input 
    .enable(1'b1),              // Enable COM                  input 
    .rx_en(1'b1),  	           // Recieve enable              input 
    .rx(DWNLINK_TX_IO_RX),      // Data recieve bit            input 
    .tx(DWNLINK_RX_IO_TX),      // Tx bit to send out on pin   output
    .tx_en(),                   // Tx enable signal            output
    .rd_data(dnl_rd_data),      // Data read                   input 
    .rd_rdy_strb(dnl_rdy_strb), // Strobe to send read data    input 
    .rd_strb(dnl_rd_strb),      // Read Register Strobe        output
    .rd_addr(dnl_rd_addr),      // Address to read from        output
    .wr_addr(dnl_wr_addr),      // Address to write to         output
    .wr_strb(dnl_wr_strb),      // Write Register Strobe       output
    .wr_data(dnl_wr_data),      // Data to write               output
    .error(dnl_comm_err)        // Error in Com                output
   );    
//---------------------------------------------------------------	
// END COM PORT DOWNLINK
//---------------------------------------------------------------
          
//---------------------------------------------------------------	
// COM PORT SUBLINK 921600, 8, E, 1 (SBC)
//---------------------------------------------------------------
   defparam COM_Port_SubLink_i.ascii_prompt = 8'h6D;    // m
	defparam COM_Port_SubLink_i.BAUD_MASK    = 16'h0035;
	defparam COM_Port_SubLink_i.BAUD_QUALIFY = 16'h0024;
   defparam COM_Port_SubLink_i.PARITY_BIT   = 1'b1;
   defparam COM_Port_SubLink_i.ADDR_DW      = 10;
   defparam COM_Port_SubLink_i.ECHO_ON      = 1'b1;
	CommControlSlave COM_Port_SubLink_i
   (  
    .clk(clk),                  // System Clock 					input 
    .reset(reset),              // System Reset (Syncronous)   input 
    .enable(1'b1),              // Enable COM                  input 
    .rx_en(1'b1),  	           // Recieve enable              input 
    .rx(SBC_TO_IO),             // Data recieve bit            input 
    .tx(IO_TO_SBC),             // Tx bit to send out on pin   output
    .tx_en(),                   // Tx enable signal            output
    .rd_data(sub_rd_data),      // Data read                   input 
    .rd_rdy_strb(sub_rdy_strb), // Strobe to send read data    input 
    .rd_strb(sub_rd_strb),      // Read Register Strobe        output
    .rd_addr(sub_rd_addr),      // Address to read from        output
    .wr_addr(sub_wr_addr),      // Address to write to         output
    .wr_strb(sub_wr_strb),      // Write Register Strobe       output
    .wr_data(sub_wr_data),      // Data to write               output
    .error(sub_comm_err)        // Error in Com                output
   );    
//---------------------------------------------------------------	
// END COM PORT SUBLINK
//---------------------------------------------------------------
     
//---------------------------------------------------------------	
// COM ARBITRATION
// Select Commands from these priorities:
//  1. Autonomous COM
//  4. Test Port
//  2. Downlink
//  3. Sublink
//---------------------------------------------------------------  
  defparam BusArbitration_i.ADDR_DW = 9;
  BusArbitration BusArbitration_i
  (  
		.clk(clk),                         // System Clock 																			input 
		.reset(reset),                     // System Reset (Syncronous)                                            	input 
		.enable(1'b1),                     // System enable                                                        	input 
                                                                                                                   
		.rd_data(rd_data),                 // Arbitrated Data read					                           			input 
		.rd_strb(rd_strb),                 // Arbitrated Read Register Strobe	                           			output
		.rd_addr(rd_addr),                 // Arbitrated Address to read from                            				output
		.wr_addr(wr_addr),                 // Arbitrated Address to write to                             				output
		.wr_strb(wr_strb),                 // Arbitrated Write Register Strobe                           				output
		.wr_data(wr_data),                 // Arbitrated Data to write                                   				output
                                                                                                               
		.tst_rd_data(tst_rd_data),         // Test Data read                                                       	output
		.tst_rdy_strb(tst_rdy_strb),       // Test Data read ready strobe                                          	output
		.tst_rd_strb(tst_rd_strb),         // Test Read Register Strobe                                            	input 
		.tst_rd_addr({tst_rd_addr[9],tst_rd_addr[8],tst_rd_addr[6:0]}),         // Test Address to read from       	input 
		.tst_wr_addr({tst_wr_addr[9],tst_wr_addr[8],tst_wr_addr[6:0]}),         // Test Address to write to        	input 
		.tst_wr_strb(tst_wr_strb),         // Test Write Register Strobe                                           	input 
		.tst_wr_data(tst_wr_data),         // Test Data to write                                                   	input 
                                                                                                               
		.dnl_rd_data(dnl_rd_data),         // Downlink Data read                                                   	output
		.dnl_rdy_strb(dnl_rdy_strb),       // Downlink Data read ready strobe                                      	output
		.dnl_rd_strb(dnl_rd_strb),         // Downlink Read Register Strobe                                        	input 
		.dnl_rd_addr({dnl_rd_addr[9],dnl_rd_addr[8],dnl_rd_addr[6:0]}),         // Downlink Address to read from   	input 
		.dnl_wr_addr({dnl_wr_addr[9],dnl_wr_addr[8],dnl_wr_addr[6:0]}),         // Downlink Address to write to    	input 
		.dnl_wr_strb(dnl_wr_strb),         // Downlink Write Register Strobe                                       	input 
		.dnl_wr_data(dnl_wr_data),         // Downlink Data to write                                               	input 
                                                                                                               
		.sub_rd_data(sub_rd_data),         // Sublink Data read                                                    	output
		.sub_rdy_strb(sub_rdy_strb),       // Sublink Data read ready strobe                                       	output
		.sub_rd_strb(sub_rd_strb),         // Sublink Read Register Strobe                                         	input 
		.sub_rd_addr({sub_rd_addr[9],sub_rd_addr[8],sub_rd_addr[6:0]}),         // Sublink Address to read from    	input 
		.sub_wr_addr({sub_wr_addr[9],sub_wr_addr[8],sub_wr_addr[6:0]}),         // Sublink Address to write to     	input 
		.sub_wr_strb(sub_wr_strb),         // Sublink Write Register Strobe                                        	input 
		.sub_wr_data(sub_wr_data),         // Sublink Data to write                                                	input 
                                                                                                               
		.aut_rd_data(aut_rd_data),         // Autonomous Data read                                                 	output
		.aut_rdy_strb(aut_rdy_strb),       // Autonomous Data read ready strobe                                    	output
		.aut_rd_strb(aut_rd_strb),         // Autonomous Read Register Strobe                                      	input 
		.aut_rd_addr({aut_rd_addr[9],aut_rd_addr[8],aut_rd_addr[6:0]}),    // Autonomous Address to read from      	input 
		.aut_wr_addr({aut_wr_addr[9],aut_wr_addr[8],aut_wr_addr[6:0]}),    // Autonomous Address to write to       	input 
		.aut_wr_strb(aut_wr_strb),         // Autonomous Write Register Strobe                                    	input 
		.aut_wr_data(aut_wr_data),          	// Autonomous Data to write                                          input 
		.aut_wr_cmplt_strb(aut_wr_done_strb),	// Autonomous Write is Done                                          output
	 
		.sdc_rd_data(sdc_rd_data),         // sdc Data read  																			output
		.sdc_rdy_strb(sdc_rdy_strb),       // sdc Data read ready strobe                                            output
		.sdc_rd_strb(sdc_rd_strb),    	  // sdc Read Register Strobe         													input 
		.sdc_rd_addr({sdc_rd_addr[9],sdc_rd_addr[8],sdc_rd_addr[6:0]})	    // sdc Address to read from              input 
  );  
  
//---------------------------------------------------------------	
// END COM ARBITRATION
//---------------------------------------------------------------  


//---------------------------------------------------------------	
// USER INTERFACE MASTER IO
// READS/WRITES TO THE UIC BOARD
// 921600, 8, E, 1
//---------------------------------------------------------------
   defparam CommControlMaster_UIC_i.BAUD_MASK    = 16'h0035;
	defparam CommControlMaster_UIC_i.BAUD_QUALIFY = 16'h0024;
   defparam CommControlMaster_UIC_i.PARITY_BIT   = 1'b1;
   defparam CommControlMaster_UIC_i.ECHO_ON      = 1'b0;
   CommControlMaster CommControlMaster_UIC_i
   (  
    .clk(clk),                      // System Clock 							input 
    .reset(reset),                  // System Reset (Syncronous)        input 
    .enable(1'b1),                  // System enable                    input
    .rx_en(1'b1),  	               // Recieve enable                   input
    .rx(IO_RX_UIC_TX),  	         // Data recieve bit                 input
    .tx(IO_TX_UIC_RX),              // Tx bit to send out on pin        output
    .tx_en(),                       // Tx enable signal                 output
    .cmd_addr(cmd_uic_addr),        // [15:0] Address to read from      input
    .rd_strb(cmd_uic_rd_strb),      // Read subsystem register strobe   input
    .wr_strb(cmd_uic_wr_strb),      // Write subsystem register strobe  input
    .wr_data(cmd_uic_wr_data),      // [35:0] Data to write to the bus  input
    .rd_data(cmd_uic_rd_data),      // [35:0] Data read from the bus    output
    .rd_rdy_strb(cmd_uic_rdy_strb), // Strobe that read data is ready   output
    .error(cmd_uic_err)             // Error in com (rx packet, parity) output
   );
//---------------------------------------------------------------	
// END USER INTERFACE MASTER IO  
//---------------------------------------------------------------	


//---------------------------------------------------------------	
// CONTROL LANE MASTER IO
// READS/WRITES TO THE CONTROL LANE
// 921600, 8, E, 1
//---------------------------------------------------------------
   defparam CommControlMaster_CON_i.BAUD_MASK    = 16'h0035;
	defparam CommControlMaster_CON_i.BAUD_QUALIFY = 16'h0024;
   defparam CommControlMaster_CON_i.PARITY_BIT   = 1'b1;
   defparam CommControlMaster_CON_i.ECHO_ON      = 1'b0;
   CommControlMaster CommControlMaster_CON_i
   (  
    .clk(clk),                      // System Clock 							input 
    .reset(reset),                  // System Reset (Syncronous) 			input 
    .enable(1'b1),                  // System enable 							input
    .rx_en(1'b1),  	               // Recieve enable							input
    .rx(IO_RX_C_TX),  	            // Data recieve bit						input
    .tx(IO_TX_C_RX),                // Tx bit to send out on pin			output
    .tx_en(),                       // Tx enable signal   					output
    .cmd_addr(cmd_con_addr),        // [15:0] Address to read from		input
    .rd_strb(cmd_con_rd_strb),      // Read subsystem register strobe	input
    .wr_strb(cmd_con_wr_strb),      // Write subsystem register strobe	input
    .wr_data(cmd_con_wr_data),      // [35:0] Data to write to the bus	input
    .rd_data(cmd_con_rd_data),      // [35:0] Data read from the bus		output
    .rd_rdy_strb(cmd_con_rdy_strb), // Strobe that read data is ready	output
    .error(cmd_con_err)             // Error in com (rx packet, parity)	output
   );
//---------------------------------------------------------------	
// END USER INTERFACE MASTER IO  
//---------------------------------------------------------------

//---------------------------------------------------------------	
// SAFETY LANE MASTER IO
// READS/WRITES TO THE SAFETY LANE
// 921600, 8, E, 1
//---------------------------------------------------------------
   defparam CommControlMaster_SAF_i.BAUD_MASK    = 16'h0035;
	defparam CommControlMaster_SAF_i.BAUD_QUALIFY = 16'h0024;
   defparam CommControlMaster_SAF_i.PARITY_BIT   = 1'b1;
   defparam CommControlMaster_SAF_i.ECHO_ON      = 1'b0;
   CommControlMaster CommControlMaster_SAF_i
   (  
    .clk(clk),                      // System Clock 							input 
    .reset(reset),                  // System Reset (Syncronous)        input 
    .enable(1'b1),                  // System enable                    input
    .rx_en(1'b1),  	                // Recieve enable                  input
    .rx(IO_RX_S_TX),  	            // Data recieve bit                 input
    .tx(IO_TX_S_RX),                // Tx bit to send out on pin        output
    .tx_en(),                       // Tx enable signal                 output
    .cmd_addr(cmd_saf_addr),        // [15:0] Address to read from      input
    .rd_strb(cmd_saf_rd_strb),      // Read subsystem register strobe   input
    .wr_strb(cmd_saf_wr_strb),      // Write subsystem register strobe  input
    .wr_data(cmd_saf_wr_data),      // [35:0] Data to write to the bus  input
    .rd_data(cmd_saf_rd_data),      // [35:0] Data read from the bus    output
    .rd_rdy_strb(cmd_saf_rdy_strb), // Strobe that read data is ready   output
    .error(cmd_saf_err)             // Error in com (rx packet, parity) output
   );
//---------------------------------------------------------------	
// END USER INTERFACE MASTER IO  
//---------------------------------------------------------------
       
    
//---------------------------------------------------------------	
// IO DATA CONCENTRATOR
  defparam DataConcentrator_i.MSG_TIME        = 16'h84D0; 
//--------------------------------------------------------------- 
  DataConcentrator  DataConcentrator_i
  (  
    .clk(clk),                            // System Clock 
    .reset(reset),                        // System Reset (Syncronous) 
    .enable(1'b1),                        // System enable
    .sys_tmr_strb(sys_tmr_strb),          // System timer strobe 100 ms.
  
    .rd_data(rd_data),                    // Concentrated Data read  						output reg
    .rd_strb(rd_strb),                    // Concentrated Write Register Strobe			input
    .rd_addr(rd_addr),                    // Concentrated Address to read from  			input
    .wr_strb(wr_strb),                    // Concentrated Write Register Strobe			input
    .wr_addr(wr_addr),                    // Concentrated Address to read from  			input
    .wr_data(wr_data),                    // Concentrated Data to write 					input
  
    .cmd_uic_addr(cmd_uic_addr),          // UIC Address to read from						output reg
    .cmd_uic_rd_strb(cmd_uic_rd_strb),    // UIC Read subsystem register strobe			output reg
    .cmd_uic_wr_strb(cmd_uic_wr_strb),    // UIC Write subsystem register strobe			output reg
    .cmd_uic_wr_data(cmd_uic_wr_data),    // UIC Data to write to the bus					output 
    .cmd_uic_rd_data(cmd_uic_rd_data),    // UIC Data read from the bus						input
    .cmd_uic_rdy_strb(cmd_uic_rdy_strb),  // UIC Strobe that read data is ready			input
  
    .cmd_con_addr(cmd_con_addr),          // CONTROL Address to read from					output reg
    .cmd_con_rd_strb(cmd_con_rd_strb),    // CONTROL Read subsystem register strobe		output reg
    .cmd_con_wr_strb(cmd_con_wr_strb),    // CONTROL Write subsystem register strobe	output reg
    .cmd_con_wr_data(cmd_con_wr_data),    // CONTROL Data to write to the bus				output 
    .cmd_con_rd_data(cmd_con_rd_data),    // CONTROl Data read from the bus				input
    .cmd_con_rdy_strb(cmd_con_rdy_strb),  // CONTROL Strobe that read data is ready		input			
  
    .cmd_saf_addr(cmd_saf_addr),          // SAFETY Address to read from					output reg
    .cmd_saf_rd_strb(cmd_saf_rd_strb),    // SAFETY Read subsystem register strobe     output reg
    .cmd_saf_wr_strb(cmd_saf_wr_strb),    // SAFETY Write subsystem register strobe    output reg
    .cmd_saf_wr_data(cmd_saf_wr_data),    // SAFETY Data to write to the bus           output 
    .cmd_saf_rd_data(cmd_saf_rd_data),    // SAFETY Data read from the bus             input
    .cmd_saf_rdy_strb(cmd_saf_rdy_strb),  // SAFETY Strobe that read data is ready     input			

    .cmd_ioc_addr(cmd_ioc_addr),          // IO Address to read from							output reg
    .cmd_ioc_rd_strb(cmd_ioc_rd_strb),    // IO Read subsystem register strobe         output 
    .cmd_ioc_wr_strb(cmd_ioc_wr_strb),    // IO Write subsystem register strobe        output 
    .cmd_ioc_wr_data(cmd_ioc_wr_data),    // IO Data to write to the bus               output 
    .cmd_ioc_rd_data(cmd_ioc_rd_data),    // IO Data read from the bus                 input
    .cmd_ioc_rdy_strb(cmd_ioc_rdy_strb)   // IO Strobe that read data is ready         input			
  ); 

//---------------------------------------------------------------	
// END IO DATA CONCENTRATOR
//--------------------------------------------------------------- 


  assign comm_err = {cmd_uic_err, cmd_con_err, cmd_saf_err, tst_comm_err, dnl_comm_err, sub_comm_err};

//---------------------------------------------------------------	
// UNUSED INPUTS AND OUTPUTS 
  
  //DOUT1_IO;
  //DOUT2_IO;
  //RTC_IRQ_N;
  
  //Assign Outputs    
  
  assign DIN1_IO       = DOUT1_IO;
  assign DCLK1_IO      = RTC_IRQ_N;
  //assign CS1_IO_N      = 1'b0;
  assign DIN2_IO       = DOUT2_IO;
  assign DCLK2_IO      = 1'b0;
  assign CS2_IO_N      = 1'b0;
  
  assign IO_SDC1_CMD   	= 	(IO_SDC1_CMD_out) ? 1'bZ : 1'b0;
  assign IO_SDC1_CMD_in	= 	IO_SDC1_CMD;
  assign IO_SDC1_D0    	= 	(IO_SDC1_D0_out) 	? 1'bZ : 1'b0;
  assign IO_SDC1_D0_in	=	IO_SDC1_D0; 	
  assign IO_SDC1_D1    	= 	(IO_SDC1_D1_out) 	? 1'bZ : 1'b0;
  assign IO_SDC1_D1_in	=	IO_SDC1_D1;
  assign IO_SDC1_D2    	= 	(IO_SDC1_D2_out) 	? 1'bZ : 1'b0;
  assign IO_SDC1_D2_in	=	IO_SDC1_D2;
  assign IO_SDC1_D3    	= 	(IO_SDC1_D3_out) 	? 1'bZ : 1'b0;
  assign IO_SDC1_D3_in	= 	IO_SDC1_D3;
  
  assign LA[0] = IO_SDC1_CMD;
  assign LA[1] = IO_SDC1_D0; 
  assign LA[2] = IO_SDC1_CLK; 
  
//  assign IO_SDC1_CD_WP = 1'b0;
//  assign IO_SDC1_CLK   = 1'b0;
//  assign IO_SDC1_CMD   = 1'b0;
//  assign IO_SDC1_D0    = 1'bZ;
//  assign IO_SDC1_D1    = 1'bZ;
//  assign IO_SDC1_D2    = 1'bZ;
//  assign IO_SDC1_D3    = 1'bZ;
  
  assign IO_SDC2_CD_WP = 1'b0;
  assign IO_SDC2_CLK   = 1'b0;
  assign IO_SDC2_CMD   = 1'b0;  
  assign IO_SDC2_D0    = 1'bZ;
  assign IO_SDC2_D1    = 1'bZ;
  assign IO_SDC2_D2    = 1'bZ;
  assign IO_SDC2_D3    = 1'bZ;
  
  
// END USE UP ALL OUTPUTS
//-----------------------------------------------------------------

//----------------------------------------------------------------- 
// REAL TIME CLOCK I2C LINES
  //assign RTC_I2C_SCL        = 1'bZ;
  //assign RTC_I2C_SDA        = 1'bZ;  
  assign RTC_I2C_SCL        = (RTC_I2C_SCL_out) ? 1'bZ : 1'b0;
  assign RTC_I2C_SCL_in     =  RTC_I2C_SCL;
  
  assign RTC_I2C_SDA        = (RTC_I2C_SDA_out) ? 1'bZ : 1'b0;
  assign RTC_I2C_SDA_in     =  RTC_I2C_SDA;
// END REAL TIME CLOCK
//-----------------------------------------------------------------

	// Instantiate the module
	// One part of this module interacts with
	// the Bus Arbitrator, the other part interacts with the
	// PUC IO Controller.
   // This module basically generates the necessary address to get
   // data from the bus arbitrator.  Once the data comes back from the
   // bus arbitrator, it is made available for the puc fifo.  After the
   // puc fifo has saved this data, it will strobe to tell this module
   // to get the next data.
	GetPUCData GetPUCData_i 
   (
      .clk(clk), 								                  //input       
		.reset(reset),                                     //input       
		.rd_addr(sdc_rd_addr),                             //output    to bus arbitrator      
		.rd_strb(sdc_rd_strb),                             //output    to bus arbitrator      
		.rd_data(sdc_rd_data),                             //input     from bus arbitrator      
		.rd_rdy_strb(sdc_rdy_strb),                        //input     from bus arbitrator      
		.puc_data(puc_data),                               //output    to fifo      
		.puc_data_strb(puc_data_strb),                     //output    to fifo      
		.rdy_for_nxt_pkt(rdy_for_nxt_pkt | strt_fifo_strb) //input     ready for next packet from puc.
	);                               
  	//----------------------------------------------------------------- 
   
   // PUC Controller
   defparam PUC_IO_Controller_i.FPGA_VERSION 		= FPGA_VERSION;
	// Make sure this path reflects the true path when building.
   defparam PUC_IO_Controller_i.BROM_INITIAL_FILE 	= "C:/FPGA_Design/PAKPUCIO/src/BROM_NetLists_IO_64_x_36.txt";
   defparam PUC_IO_Controller_i.LS 						= NL_SEQ_LS;
   defparam PUC_IO_Controller_i.NL_ADDR_WD 			= NL_ADDR_WD;
   defparam PUC_IO_Controller_i.ADDR_DW 				= 9;
	PUC_IO_Controller  PUC_IO_Controller_i  
	(  
		.clk(clk),                                // System Clock 												input  	
		.reset(reset),                            // System Reset (Syncronous)                      	input  
		.por_strb(por_strb),                      // Power on Reset Strobe                          	input  
		.sys_tmr_strb(sys_tmr_strb),              // System Timer Strobe                            	input  
		.estop_pressed(estop_pressed),            // Estop switch pressed                           	input  
                                                                                                
		.rd_strb(cmd_ioc_rd_strb),                // Read Register Strobe					            	input  
		.rd_addr(cmd_ioc_addr[5:0]),              // Address to read from[5:0]                      	input  
		.wr_addr(cmd_ioc_addr[5:0]),              // Address to write to[5:0]                       	input  
		.wr_strb(cmd_ioc_wr_strb),                // Write Register Strobe                          	input  
		.wr_data(cmd_ioc_wr_data),                // Data to write[15:0]                            	input  
		.rd_data(cmd_ioc_rd_data),                // Data read[35:0]                                	output 
		.rd_rdy_strb(cmd_ioc_rdy_strb),           // Strobe that data is ready to read              	output 
                                                                                                
		.COM_Cntrl(COM_Cntrl),                    // Output Flags to COM FPGA and internal COMs     	output 
		.comm_err(comm_err),                      // Communication Error                            	input  
                                                                                                
		.ADC1_DOUT(IO_ADC1_DOUT),                 // Dout from ADC1                                 	input  
		.ADC1_BUSY(IO_ADC1_BUSY),                 // Busy from ADC1                                 	input  
		.ADC1_CS_N(IO_ADC1_CS_N),                 // Chip Select to ADC1                            	output 
		.ADC1_CLK(IO_ADC1_CLK),                   // Dclk to ADC1                                   	output 
		.ADC1_DIN(IO_ADC1_DIN),                   // Din to ADC1                                    	output 
                                                                                                
		.UIC_CABLE_DET_N(UIC_CABLE_DET_N),        // UIC Cable connected                            	input  
		.SBC_CABLE_DET_N(SBC_CABLE_DET_N),        // SBC Cable connected                            	input  
                                                                                                
		.MEAS_RTC_BAT(MEAS_RTC_BAT),              // Measure Battery For RTC                        	output 
                                                                                                
		.sub_seq_done(sub_seq_done),              // Flag that the sub sequence run has completed.  	input  
		.sub_seq_strb(sub_seq_strb),              // Strobe to run sub sequence                     	output 
		.sub_seq_addr(sub_seq_addr),              // Address of subsequence to run                  	output 
		.sub_seq_cnt(sub_seq_cnt),                // Number of nets in the subsequence              	output 
                                                                                                  
		.net_wr_strb(net_wr_strb),                // Net List                                       	output 
		.net_wr_addr(net_wr_addr),                // Net Address                                    	output 
		.net_wr_data(net_wr_data),                // Net Data    
    
	   .RTC_I2C_SCL_in(RTC_I2C_SCL_in),  		   // Input ISL1208 SCL
	   .RTC_I2C_SCL_out(RTC_I2C_SCL_out), 		   // Output ISL1208 SCL
	   .RTC_I2C_SDA_in(RTC_I2C_SDA_in),  		   // Input ISL1208 SDA
	   .RTC_I2C_SDA_out(RTC_I2C_SDA_out), 		   // Output ISL1208 SDA                              output 
	                                                                                             
		// Autonomous data from Sequencer.    
		.aut_rd_strb(dnl_rd_strb),						//                                                	input 					
		.aut_rd_addr({dnl_rd_addr[9],dnl_rd_addr[8],dnl_rd_addr[6:0]}),                	//          input
		.aut_rdy_strb(dnl_rdy_strb),					//                                                	input
		.aut_rd_data(dnl_rd_data),                //                                                	input
		// For SD Card
		.strt_fifo_strb(strt_fifo_strb),          // Start filling up fifo.							      output
		.puc_data_strb(puc_data_strb),			   // write puc data to fifo									input
		.puc_data(puc_data),							   // data to be logged.                              input
		.rdy_for_nxt_pkt(rdy_for_nxt_pkt),	      // ready for next packet (fifo_data) from puc.     output
		
		.IO_SDC1_CD_WP(IO_SDC1_CD_WP),          	//                                                	input 
		.IO_SDC1_D0_in(IO_SDC1_D0_in),          	//                                                	input	
		.IO_SDC1_D0_out(IO_SDC1_D0_out),        	//                                                	output
		.IO_SDC1_D1_in(IO_SDC1_D1_in),          	//                                                	input	
		.IO_SDC1_D1_out(IO_SDC1_D1_out),        	//                                                	output
		.IO_SDC1_D2_in(IO_SDC1_D2_in),          	//                                                	input	
		.IO_SDC1_D2_out(IO_SDC1_D2_out),        	//                                                	output
		.IO_SDC1_D3_in(IO_SDC1_D3_in),          	//                                                	input	
		.IO_SDC1_D3_out(IO_SDC1_D3_out),        	//                                                	output
		.IO_SDC1_CLK(IO_SDC1_CLK),              	//                                                	output
		.IO_SDC1_CMD_in(IO_SDC1_CMD_in),        	//                                                	input 
		.IO_SDC1_CMD_out(IO_SDC1_CMD_out),      	//                                                	output
                                                                                                
		.LogicAnalyzer(LogicAnalyzer),           	// Output Logic Analyzer                          	output 
		.cs_test_vector()           
  );      
// END SYSTEM CONTROLLER
//----------------------------------------------------------------- 

  assign LA[15:3] = LogicAnalyzer[15:3];

//----------------------------------------------------------------- 
// SEQUENCER
  // Make sure this path reflects the true path when building.
  defparam Sequencer_i.BRAM_NETLIST_FILE  = "C:/FPGA_Design/PAKPUCIO/src/BRAM_Netlist_IO.txt";
  defparam Sequencer_i.NL_MEM_SIZE        = NL_MEM_SIZE;
  defparam Sequencer_i.NL_ADDR_WD         = NL_ADDR_WD;
  defparam Sequencer_i.NL_DATA_WD         = NL_DATA_WD;
  defparam Sequencer_i.BRAM_MEMORY_FILE   = "C:/FPGA_Design/PAKPUCIO/src/BRAM_Memory_IO.txt";
  defparam Sequencer_i.BRAM_NVM_FILE      = "C:/FPGA_Design/PAKPUCIO/src/BRAM_NVM_IO.txt";
  Sequencer Sequencer_i
  (  
    .clk(clk),                                  // System Clock 												input 
    .reset(reset),                              // System Reset (Syncronous)                       input 
    .enable(1'b1),                              // System enable                                   input 
    .sys_tmr_strb(sys_tmr_strb),                // System Timer Strobe                             input 
                                                                                                   
    .sub_seq_strb(sub_seq_strb),                // Strob to run sub sequence 1                     input 
    .sub_seq_addr(sub_seq_addr),                // Address of subsequence to run                   input 
    .sub_seq_cnt(sub_seq_cnt),                  // Number of nets in the subsequence               input 
    .sub_seq_done(sub_seq_done),                // Flag that the sub sequence run has completed.   output
                                                                                                     
    .reg_sys_rd_data(aut_rd_data),              // Register Data read                              input 
    .reg_sys_rd_rdy_strb(aut_rdy_strb),         // Strobe to read data                             input 
    .reg_sys_wr_done_strb(aut_wr_done_strb),    // Strobe that write is done.                      input 
    .reg_sys_rd_strb(aut_rd_strb),              // Register Read Register Strobe                   output
    .reg_sys_rd_addr(aut_rd_addr),              // Register Address to read from                   output
    .reg_sys_wr_addr(aut_wr_addr),              // Register Address to write to                    output
    .reg_sys_wr_strb(aut_wr_strb),              // Register Write Register Strobe                  output
    .reg_sys_wr_data(aut_wr_data),              // Register Data to write                          output
                                                                                                   
    .net_wr_strb(net_wr_strb),                  // Net List                                        input 
    .net_wr_addr(net_wr_addr),                  // Net Address                                     input 
    .net_wr_data(net_wr_data),                  // Net Data                                        input 
                                                                                                   
    .NVM_DOUT(IO_EE_DOUT),                   // NVM output line                                    input 
    .NVM_DIN(IO_EE_DIN),                     // NVM input line                                     output
    .NVM_DCLK(IO_EE_DCLK),                   // NVM clock line                                     output
    .NVM_CS_L(IO_EE_CS_L),                   // NVM chip select                                    output
    .NVM_HOLD(IO_EE_HOLD),                   // NVM hold                                           output
    .NVM_WP(IO_EE_WP)                        // NVM write protect                                  output
  );
 
// END SYSTEM SEQUENCER
//-----------------------------------------------------------------

   //  Debounce the backup button switch
   defparam Debounce_i1.DEBOUNCE = 26'h2FAF07F;
   Debounce Debounce_i1
   (
     .clk(clk),                  // System Clock
     .reset(reset),              // System Reset (Syncronous) 
     .enable(1'b1),              // Enable toggle
     .signal_in(CS1_IO_N),       // Signal to debounce
     .signal_out(backup_switch)  // Debounced Signal
   );
   
   //  Latch the backup switch
   always@(posedge clk)
   begin
     if (reset)
       estop_pressed <= 1'b0;
     else if (backup_switch)
       estop_pressed <= 1'b1;
     else
       estop_pressed <= 1'b0;
   end

//-----------------------------------------------------------------
// SYSTEM READY AND DISCRETE FLAGS    

  //Indicates GTE is released and device programmed (Norm Pulled Low)
  assign IO_READY     = 1'b1;          

  //Control Signal to Actel COM FPGA bit 0 (Norm Pulled High)
  assign IO_DISCRETE1 = ~COM_Cntrl[0]; 
  
  //Control Signal to Actel COM FPGA bit 1 (Norm Pulled Low)
  assign IO_DISCRETE2 = COM_Cntrl[1];  
  
// END SYSTEM READY FLAG
//-----------------------------------------------------------------
  
 endmodule