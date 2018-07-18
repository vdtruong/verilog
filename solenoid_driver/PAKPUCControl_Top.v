//-----------------------------------------------------------------------------------
//  Module:     PAKPUCControl_Top
//  Project:    PAK Pumping Unit Controller
//  Version:    0.1
//
//  Description: Implements the top level module for the PAK PUC Controller
//
//
//-----------------------------------------------------------------------------------
 


module PAKPUCControl_Top 
//------------------FPGA VERSION-----------------------------------------------------
#(parameter C_FPGA_VERSION = 16'h0221)  
//----------------END FPGA VERSION---------------------------------------------------
(
  input         CLK_PUC_C,            // System Clock
  output        CLK_PUC_C_EN,         // System Clock Enable
  input         C_LOGIC_RESET_N,      // System Logic Reset (Active Low)
  output        C_READY,              // Discrete to indicate GTE off
  output        C_DISCRETE1,          // NH Logic discrete to COM
  output        C_DISCRETE2,          // NL Logic discrete to COM
  input         PUC_TEST_RX,          // FTDI Test COM Interface RX
  output        PUC_TEST_TX,          // FTDI Test COM Interface TX
  output        DWNLINK_RX_C_TX,      // COM Interface to COM FPGA TX
  input         DWNLINK_TX_C_RX,      // COM Interface to COM FPGA RX
  output        SUBLINK_C_TX,         // RAC Interface Optical Link TX
  input         SUBLINK_C_RX,         // RAC Interface Optical Link RX  
  input         UIC_CMD_TX_C_RX,      // UIC CMD Interface to COM FPGA RX
  output        UIC_CMD_RX_C_TX,      // UIC CMD Interface to COM FPGA TX
  input         UIC_EVT_TX_C_RX,      // UIC EVT Interface to COM FPGA RX
  output        UIC_EVT_RX_C_TX,      // UIC EVT Interface to COM FPGA TX
  input         RA_CABLE_DET_N,       // Detects if Reservoir Cable Connected
  output        CSDL_C_TX1_S_RX1,
  input         CSDL_C_RX1_S_TX1,
  output        CSDL_C_TX2_S_RX2,
  input         CSDL_C_RX2_S_TX2,
  output        CSDL_C_TX3_S_RX3,
  input         CSDL_C_RX3_S_TX3,
  output        CSDL_C_TX4_S_RX4,
  input         CSDL_C_RX4_S_TX4,
  output        FAN1_PWM,             // Fan #1 PWM Control Signal
  input         FAN1_TACH_N,          // Fan #1 Tach Feedback
  output        FAN2_PWM,             // Fan #2 PWM Control Signal
  input         FAN2_TACH_N,          // Fan #2 Tach Feedback
  input         TEMP_ALERT,           // Temperature Alert Feddback
  output        TSENSE_TEST,          // Temperature BIT trip
  inout         TEMP_SDA,             // Temperature Sensor I2C Data
  inout         TEMP_SCL,             // Temperature Sensor I2C Clock
  input         TEMP_BIT,             // Temperature Sensor BIT Fbk
  output        C_TEMP_TEST_01,       // Fluid Temperature sensor 1 BIT test 
  output        C_TEMP_TEST_02,       // Fluid Temperature sensor 2 BIT test   
  output        PUC_C_EE_DIN,
  input         PUC_C_EE_DOUT,
  output        PUC_C_EE_DCLK,
  output        PUC_C_EE_CS_L,
  output        PUC_C_EE_HOLD,
  output        PUC_C_EE_WP,
  output        PUC_C_EE_DIN2,
  input         PUC_C_EE_DOUT2,
  output        PUC_C_EE_DCLK2,
  output        PUC_C_EE_CS2_L,
  output        PUC_C_EE_HOLD2,
  output        PUC_C_EE_WP2,
  output        C_ADC1_CLK,           // ADC Interface Clock
  output        C_ADC1_CS_N,          // ADC Interface Chip Select
  output        C_ADC1_DIN,           // ADC Interface Data Input
  input         C_ADC1_DOUT,          // ADC Interface Data Output
  input         C_ADC1_BUSY,          // ADC Interface Data Busy
  output        C_ADC_1_MUXA,         // ADC Interface MUX Chan A
  output        C_ADC_1_MUXB,         // ADC Interface MUX Chan B
  output        C_DAC_DIN,            // DAC Interface Motor Current Limit Din
  input         C_DAC_DOUT,           // DAC Interface Motor Current Limit Dout
  output        C_DAC_DCLK,           // DAC Interface Motor Current Limit Clock
  output        C_DAC_CS_N,           // DAC Interface Motor Current Limit Chip Select
  output        C_DAC_CLR_N,          // DAC Interface Motor Current Limit Clear
  output        BP_STEP,              // Motor BP Step Command             
  output        BP_DIR,               // Motor BP Direction (Low Clockwise)
  output        BP_M1,                // Motor BP Bit 0 Micro Step Setting
  output        BP_M2,                // Motor BP Bit 1 Micro Step Setting
  output        BP_RESET_N,           // Motor BP Active Low Reset
  output        DP1_STEP,             // Motor DP1 Step Command
  output        DP1_DIR,              // Motor DP1 Direction (Low Clockwise)
  output        DP1_M1,               // Motor DP1 Bit 0 Micro Step Setting
  output        DP1_M2,               // Motor DP1 Bit 1 Micro Step Setting
  output        DP1_RESET_N,          // Motor DP1 Active Low Reset
  output        DP2_STEP,             // Motor DP2 Step Command
  output        DP2_DIR,              // Motor DP2 Direction (Low Clockwise)
  output        DP2_M1,               // Motor DP2 Bit 0 Micro Step Setting
  output        DP2_M2,               // Motor DP2 Bit 1 Micro Step Setting
  output        DP2_RESET_N,          // Motor DP2 Active Low Reset
  output        ELP_STEP,             // Motor ELP Step Command
  output        ELP_DIR,              // Motor ELP Direction (Low Clockwise)
  output        ELP_M1,               // Motor ELP Bit 0 Micro Step Setting
  output        ELP_M2,               // Motor ELP Bit 1 Micro Step Setting
  output        ELP_RESET_N,          // Motor ELP Active Low Reset
  output        HEP_STEP,             // Motor HEP Step Command
  output        HEP_DIR,              // Motor HEP Direction (Low Clockwise)
  output        HEP_M1,               // Motor HEP Bit 0 Micro Step Setting
  output        HEP_M2,               // Motor HEP Bit 1 Micro Step Setting
  output        HEP_RESET_N,          // Motor HEP Active Low Reset
  output        DL_STEP,              // Motor DL Step Command
  output        DL_DIR,               // Motor DL Direction (Low Clockwise)
  output        DL_M1,                // Motor DL Bit 0 Micro Step Setting
  output        DL_M2,                // Motor DL Bit 1 Micro Step Setting
  output        DL_RESET_N,           // Motor DL Active Low Reset
  input         BPR_CHB_C,
  input         BPR_CHA_C,
  input         DP1R_CHB_C,
  input         DP1R_CHA_C,
  input         DP2R_CHB_C,
  input         DP2R_CHA_C,
  input         HEPR_CHB_C,
  input         HEPR_CHA_C,
  input         ELPR_CHB_C,
  input         ELPR_CHA_C,
  input         DL_CHB_C,
  input         DL_CHA_C,
  
  output        DAC_SYNC_N,
  output        DAC_SCLK,
  output        DAC_SDIN,
  
  output        C_RL_SOL_PWM,         // RAC Latch Solenoid PWM
  output        C_VC_SOL_PWM,         // Venous Clamp Solenoid PWM
  output        C_DL_SOL_PWM,         // Door Lock Solenoid PWM  
  
  output        VLV_INA,              // Spare VC in A
  output        VLV_INB,              // Spare VC in B
  output        VLV_OPTOA,            // Spare VC opto A
  output        VLV_OPTOB,            // Spare VC opto B
  
  input         ABD_OUT2,             // ABD redudant input
  
  output        DV_OPEN,              // Flag to Open enabled MagValve
  output        DV_CLOSE,             // Flag to Close enabled MagValve
  inout         DV_SDA1,              // DV I2C bus 1 data
  inout         DV_SCL1,              // DV I2C bus 1 clock
  inout         DV_SDA2,              // DV I2C bus 2 data
  inout         DV_SCL2,              // DV I2C bus 2 clock
  inout         DV_SDA3,              // DV I2C bus 3 data
  inout         DV_SCL3,              // DV I2C bus 3 clock  
  output        EVP1,                 // Enable Valve 1
  output        EVP2,                 // Enable Valve 2
  output        EVP3,                 // Enable Valve 3
  output        EVP4,                 // Enable Valve 4
  output        EVP5,                 // Enable Valve 5
  output        EVP6,                 // Enable Valve 6    
  
  output        DRS_PWM,              // Door Reference Sensor PWM
  input         DRS_POS,              // Door Reference Sensor Postion Flag
  input         DRS_AMB,              // Door Reference Sensor Ambiant Level
  output        EXC_C_1BIT_DAC,       // Spare Output DAC (1 Bit DSM)  
  output        DIN1_C,
  output        DOUT1_C,              // Drive spare inputs as output lows
  output        DCLK1_C,
  output        CS1_C_N,
  output        DIN2_C,
  output        DOUT2_C,              // Drive spare inputs as output lows
  output        DCLK2_C,
  output        CS2_C_N,
  output        STATUS_LED_0,         // Status LED 0 logic low to turn on
  output        STATUS_LED_1,         // Status LED 1 logic low to turn on
  output        STATUS_LED_2,         // Status LED 2 logic low to turn on
  output        STATUS_LED_3,         // Status LED 3 logic low to turn on
  output        STATUS_LED_4,         // Status LED 4 logic low to turn on
  output        STATUS_LED_5,         // Status LED 5 logic low to turn on
  output        STATUS_LED_6,         // Status LED 6 logic low to turn on
  output        STATUS_LED_7,         // Status LED 7 logic low to turn on
  output        VC_L0_P,
  output        VC_L0_N,
  output        VC_L1_P,
  output        VC_L1_N,
  output        VC_L2_P,
  output        VC_L2_N,
  output        VC_L3_P,
  output        VC_L3_N,
  output        VC_CLK_P,
  output        VC_CLK_N,
  output        VC_AUX_P,
  output        VC_AUX_N,
  output        VC_SDA,
  output        VC_SCL,  
  output        VC_SE_1,
  output        VC_SE_2
);
    
  localparam NL_SEQ_LS = 36;
  localparam NL_MEM_SIZE = 8192;    
  localparam NL_ADDR_WD = 13;     
  localparam NL_CNTR_WD = 12;     
  localparam NL_DATA_WD = 36; 
  
  //Module connections
  wire      clk;                    // System Clock
  wire      reset;                  // Logic Reset
  wire 		strb_1us;                 // System Strobe 1 us
  wire 		strb_100us;               // System Strobe 100 us
  wire 		strb_500us;               // System Strobe 500 us
  wire		strb_1ms;                 // System Strobe 1 ms
  wire 		strb_500ms;               // System Strobe 500 ms
  wire 		strb_1s;                  // System Strobe 1 second
	
  reg         frame_led;            // LED frame toggle
  wire [15:0] LogicAnalyzer;        // Logic Analyzer
  
  wire [35:0] rd_data;              // Arbitrated Data read  
  wire        rd_strb;              // Arbitrated Read Register Strobe
  wire [7:0]  rd_addr;              // Arbitrated Address to read from
  wire [7:0]  wr_addr;              // Arbitrated Address to write to
  wire        wr_strb;              // Arbitrated Write Register Strobe
  wire [35:0] wr_data;              // Arbitrated Data to write 

  wire        tst_rdy_strb;
  wire [35:0] tst_rd_data;          // Test Data read  
  wire        tst_rd_strb;          // Test Read Register Strobe
  wire [7:0]  tst_rd_addr;          // Test Address to read from
  wire [7:0]  tst_wr_addr;          // Test Address to write to
  wire        tst_wr_strb;          // Test Write Register Strobe
  wire [35:0] tst_wr_data;          // Test Data to write 
  wire  [1:0] tst_comm_err;         // Test Communication Error
  
  wire        dnl_rdy_strb;
  wire [35:0] dnl_rd_data;          // Downlink Data read  
  wire        dnl_rd_strb;          // Downlink Read Register Strobe
  wire [7:0]  dnl_rd_addr;          // Downlink Address to read from
  wire [7:0]  dnl_wr_addr;          // Downlink Address to write to
  wire        dnl_wr_strb;          // Downlink Write Register Strobe
  wire [35:0] dnl_wr_data;          // Downlink Data to write 
  wire  [1:0] dnl_comm_err;         // Downlink Communication Error
  
  wire        csdl_rdy_strb;
  wire [35:0] csdl_rd_data;         // Sublink Data read  
  wire        csdl_rd_strb;         // Sublink Read Register Strobe
  wire [7:0]  csdl_rd_addr;         // Sublink Address to read from
  wire [7:0]  csdl_wr_addr;         // Sublink Address to write to
  wire        csdl_wr_strb;         // Sublink Write Register Strobe
  wire [35:0] csdl_wr_data;         // Sublink Data to write 
  wire  [1:0] csdl_comm_err;        // Sublink Communication Error

  wire        aut_rdy_strb;
  wire        aut_wr_done_strb;
  wire [35:0] aut_rd_data;          // Autonomous Data read  
  wire        aut_rd_strb;          // Autonomous Read Register Strobe
  wire [15:0] aut_rd_addr;          // Autonomous Address to read from
  wire [15:0] aut_wr_addr;          // Autonomous Address to write to
  wire        aut_wr_strb;          // Autonomous Write Register Strobe
  wire [35:0] aut_wr_data;          // Autonomous Data to write     
      
  wire         sub_seq_strb;        // Strob to run sub sequence 1 
  wire [NL_ADDR_WD-1:0] sub_seq_addr;// Address of subsequence to run
  wire [NL_CNTR_WD-1:0] sub_seq_cnt;// Number of nets in the subsequence
  wire         sub_seq_done;        // Flag that the sub sequence run has completed. 
    
  wire         net_wr_strb;         // Net List
  wire [NL_ADDR_WD-1:0] net_wr_addr;// Net Address
  wire [35:0]  net_wr_data;         // Net Data  
  
  wire        I2C_TMP275_SCL_in;    // Input SCL (As Slave)
  wire        I2C_TMP275_SCL_out;   // Output SCL (As Master)    
  wire        I2C_TMP275_SDA_in;    // Input SDA (Master Ack/Nack, Slave Recieve)
  wire        I2C_TMP275_SDA_out;   // Output SDA (Master/Slave Ack/Nack)     
  
  //I2C two wire interface. 1 = tri-state, 0 = drain at top level
  wire        I2C_DV1_SCL_in;       //  MV1 Input SCL (As Slave)
  wire        I2C_DV1_SCL_out;      //  MV1 Output SCL (As Master)
  wire        I2C_DV1_SDA_in;       //  MV1 Input SDA (Master Ack/Nack, Slave Recieve)
  wire        I2C_DV1_SDA_out;      //  MV1 Output SDA (Master/Slave Ack/Nack)

  wire        I2C_DV2_SCL_in;       //  MV2 Input SCL (As Slave)
  wire        I2C_DV2_SCL_out;      //  MV2 Output SCL (As Master)
  wire        I2C_DV2_SDA_in;       //  MV2 Input SDA (Master Ack/Nack, Slave Recieve)
  wire        I2C_DV2_SDA_out;      //  MV2 Output SDA (Master/Slave Ack/Nack)

  wire        I2C_DV3_SCL_in;       //  MV3 Input SCL (As Slave)
  wire        I2C_DV3_SCL_out;      //  MV3 Output SCL (As Master)
  wire        I2C_DV3_SDA_in;       //  MV3 Input SDA (Master Ack/Nack, Slave Recieve)
  wire        I2C_DV3_SDA_out;      //  MV3 Output SDA (Master/Slave Ack/Nack)  
  
  wire [1:0]  COM_Cntrl;            // Output flag from UIC FGPA to Actel COM FPGA
  wire [7:0]  comm_err;             // Comm error vector  


  wire        sync_strb;            // Write from COM's to sync strobe
  wire        sys_tmr_strb;         // Write timer strobe
  wire        por_strb;             // POR Strobe
  
  wire        clk_sys;
  
  initial 
  begin
    frame_led <= 1'b0;
  end
  


//---------------------------------------------------------------  
// CLOCK AND RESET SIGNALS                                         
  
  //Input clock buffer directly from top level port
   IBUFG #(
      .IOSTANDARD("DEFAULT")
   ) IBUFG_inst (
      .O(clk_sys),                    // Clock buffer output
      .I(CLK_PUC_C)                   // Clock buffer input (connect directly to top-level port)
   );
   
  // System clock DCM 
  DCM_System_Clock DCM_System_Clock_i
  (  
    .clk_sys(clk_sys),                // Input System Clock 10MHz
    .async_reset(C_LOGIC_RESET_N),    // Input System Reset (Asyncronous) Active Low
    .sync_reset(reset),               // Output System Reset (Asyncronous) Active Low
    .clk(clk)                         // Output System Clock 50MHz Spread Spectrum
  );        
  
  
  assign CLK_PUC_C_EN = 1'b1;
//---------------------------------------------------------------  


//---------------------------------------------------------------
//SYSTEM TIMING STROBES
  
  //---------------------------------------------------------------
  // Master Timing Strobe
  defparam SystemTimingStrb_i.SYS_TIMEOUT_WIDTH = 26;
  defparam SystemTimingStrb_i.SYS_TIMEOUT_TIME  = 26'h2FAF07F; //1000 ms  
  SystemTimingStrb SystemTimingStrb_i
  (
    .clk(clk),                    // System Clock
    .reset(reset),                // System syncronous reset
    .sync_strb(sync_strb),        // Input strobe to drive system strobe
    .por_strb(por_strb),          // Power on Reset Strobe
    .sys_tmr_strb(sys_tmr_strb)   // Output system timing strobe
  );  
  //---------------------------------------------------------------  
  
  
//---------------------------------------------------------------
// 1us Strobe 
    defparam Strobe1us_i.dw = 6;
    defparam Strobe1us_i.max = 6'h31;               
//---------------------------------------------------------------
  Counter Strobe1us_i
  (
    .clk(clk),            // Clock input 50 MHz 
    .reset(reset),        // GSR
    .enable(1'b1),        // Enable Counter
    .cntr(),              // Counter value
    .strb(strb_1us)       // 1 Clk Strb when Counter == max 1 us
  );    
//---------------------------------------------------------------
// End 1 us Strobe 
//---------------------------------------------------------------
  
  
//---------------------------------------------------------------
// 100us Strobe 
    defparam Strobe100us_i.dw = 13;
    defparam Strobe100us_i.max = 13'h1387;               
//---------------------------------------------------------------
  Counter Strobe100us_i
  (
    .clk(clk),            // Clock input 50 MHz 
    .reset(reset),        // GSR
    .enable(1'b1),        // Enable Counter
    .cntr(),              // Counter value
    .strb(strb_100us)     // 1 Clk Strb when Counter == max 100 us
  );    
//---------------------------------------------------------------
// End 100 us Strobe 
//---------------------------------------------------------------

//---------------------------------------------------------------
// 500us Strobe 
    defparam Strobe500us_i.dw		= 15;
    defparam Strobe500us_i.max 	= 15'h61A7;               
//---------------------------------------------------------------
  Counter Strobe500us_i
  (
    .clk(clk),            // Clock input 50 MHz 
    .reset(reset),        // GSR
    .enable(1'b1),        // Enable Counter
    .cntr(),              // Counter value
    .strb(strb_500us)     // 1 Clk Strb when Counter == max 500 us
  );      
//---------------------------------------------------------------
// End 500 us Strobe 
//---------------------------------------------------------------

//---------------------------------------------------------------
// 1ms Strobe 
    defparam Strobe1ms_i.dw = 16;
    defparam Strobe1ms_i.max = 16'hC34F;
//---------------------------------------------------------------
  Counter Strobe1ms_i
  (
    .clk(clk),            // Clock input 50 MHz 
    .reset(reset),        // GSR
    .enable(1'b1),        // Enable Counter
    .cntr(),              // Counter value
    .strb(strb_1ms)      // 1 Clk Strb when Counter == max 1 ms
  );  
//---------------------------------------------------------------
// End 1 ms Strobe 
//---------------------------------------------------------------
  
  
//---------------------------------------------------------------
// 500ms Strobe 
    defparam Strobe500ms_i.dw = 25;
    defparam Strobe500ms_i.max = 25'h17D783F;               
//---------------------------------------------------------------
  Counter Strobe500ms_i
  (
    .clk(clk),            // Clock input 50 MHz 
    .reset(reset),        // GSR
    .enable(1'b1),        // Enable Counter
    .cntr(),              // Counter value
    .strb(strb_500ms)     // 1 Clk Strb when Counter == max 500 ms
  );      
//---------------------------------------------------------------
// End 500 ms Strobe 
//---------------------------------------------------------------

  
//---------------------------------------------------------------
// 1 sec Strobe 
    defparam Strobe1sec_i.dw = 26;
    defparam Strobe1sec_i.max = 26'h2FAF07F;               
//---------------------------------------------------------------
  Counter Strobe1sec_i
  (
    .clk(clk),            // Clock input 50 MHz 
    .reset(reset),        // GSR
    .enable(1'b1),        // Enable Counter
    .cntr(),              // Counter value
    .strb(strb_1s)        // 1 Clk Strb when Counter == max 1 sec
  );      
//---------------------------------------------------------------
// End 1 sec Strobe 
//---------------------------------------------------------------

  // Toggle the msb LED every sys tmr strobe
  always@(posedge clk)
  begin
    if (reset)
      frame_led <= 1'b0;
    else if (sys_tmr_strb)
      frame_led <= ~frame_led;
  end     
  
  //Assign LED Outputs to toggle at 1 sec period
  assign STATUS_LED_0 = LogicAnalyzer[0]; 
  assign STATUS_LED_1 = LogicAnalyzer[1]; 
  assign STATUS_LED_2 = LogicAnalyzer[2]; 
  assign STATUS_LED_3 = LogicAnalyzer[3]; 
  assign STATUS_LED_4 = LogicAnalyzer[4]; 
  assign STATUS_LED_5 = LogicAnalyzer[5]; 
  assign STATUS_LED_6 = LogicAnalyzer[6]; 
  assign STATUS_LED_7 = frame_led; 

//---------------------------------------------------------------
// END LED Test Counter  
//---------------------------------------------------------------  
  
//---------------------------------------------------------------	
// COM PORT TEST 921600, 8, E, 1
//---------------------------------------------------------------
   defparam COM_Port_Test_i.ascii_prompt 	= 8'h63;    // c
	defparam COM_Port_Test_i.BAUD_MASK 		= 16'h0035;
	defparam COM_Port_Test_i.BAUD_QUALIFY 	= 16'h0024;
   defparam COM_Port_Test_i.PARITY_BIT 	= 1'b1;
   defparam COM_Port_Test_i.CLEAR_ON_IDLE = 1'b0;
   defparam COM_Port_Test_i.ADDR_DW 		= 8;
   defparam COM_Port_Test_i.ECHO_ON 		= 1'b1;
	CommControlSlave COM_Port_Test_i
  (  
    .clk(clk),                  // System Clock 
    .reset(reset),              // System Reset (Syncronous) 
    .enable(1'b1),              // Enable COM
    .rx_en(1'b1),  	            // Recieve enable
    .rx(PUC_TEST_RX),           // Data recieve bit
    .tx(PUC_TEST_TX),           // Tx bit to send out on pin
    .tx_en(),                   // Tx enable signal     
    .rd_data(tst_rd_data),      // Data read
    .rd_rdy_strb(tst_rdy_strb), // Strobe to send read data
    .rd_strb(tst_rd_strb),      // Read Register Strobe
    .rd_addr(tst_rd_addr),      // Address to read from
    .wr_addr(tst_wr_addr),      // Address to write to
    .wr_strb(tst_wr_strb),      // Write Register Strobe
    .wr_data(tst_wr_data),      // Data to write    
    .error(tst_comm_err)        // Error in Com
  );    
//---------------------------------------------------------------	
// END COM PORT TEST
//---------------------------------------------------------------

//---------------------------------------------------------------	
// COM PORT DOWNLINK 921600, 8, E, 1
//---------------------------------------------------------------
	defparam COM_Port_DwnLink_i.ascii_prompt 	= 8'h63;    // c
   defparam COM_Port_DwnLink_i.BAUD_MASK 		= 16'h0035;
	defparam COM_Port_DwnLink_i.BAUD_QUALIFY 	= 16'h0024;
   defparam COM_Port_DwnLink_i.PARITY_BIT 	= 1'b1;
   defparam COM_Port_DwnLink_i.CLEAR_ON_IDLE = 1'b1;
   defparam COM_Port_DwnLink_i.ADDR_DW 		= 8;
   defparam COM_Port_DwnLink_i.ECHO_ON 		= 1'b1;
	CommControlSlave COM_Port_DwnLink_i
  (  
    .clk(clk),                  // System Clock 
    .reset(reset),              // System Reset (Syncronous) 
    .enable(1'b1),              // Enable COM
    .rx_en(1'b1),  	            // Recieve enable
    .rx(DWNLINK_TX_C_RX),       // Data recieve bit
    .tx(DWNLINK_RX_C_TX),       // Tx bit to send out on pin
    .tx_en(),                   // Tx enable signal     
    .rd_data(dnl_rd_data),      // Data read
    .rd_rdy_strb(dnl_rdy_strb), // Strobe to send read data
    .rd_strb(dnl_rd_strb),      // Read Register Strobe
    .rd_addr(dnl_rd_addr),      // Address to read from
    .wr_addr(dnl_wr_addr),      // Address to write to
    .wr_strb(dnl_wr_strb),      // Write Register Strobe
    .wr_data(dnl_wr_data),      // Data to write    
    .error(dnl_comm_err)        // Error in Com
  );    
//---------------------------------------------------------------	
// END COM PORT DOWNLINK
//---------------------------------------------------------------
          
//---------------------------------------------------------------	
// COM PORT CSDL 921600, 8, E, 1
//---------------------------------------------------------------
    defparam COM_Port_CSDL_i.ascii_prompt = 8'h63;    // c
		defparam COM_Port_CSDL_i.BAUD_MASK = 16'h0035;
		defparam COM_Port_CSDL_i.BAUD_QUALIFY = 16'h0024;
    defparam COM_Port_CSDL_i.PARITY_BIT = 1'b1;
    defparam COM_Port_CSDL_i.CLEAR_ON_IDLE = 1'b1;
    defparam COM_Port_CSDL_i.ADDR_DW = 8;
    defparam COM_Port_CSDL_i.ECHO_ON = 1'b1;
	CommControlSlave COM_Port_CSDL_i
  (  
    .clk(clk),                  // System Clock 
    .reset(reset),              // System Reset (Syncronous) 
    .enable(1'b1),              // Enable COM
    .rx_en(1'b1),  	            // Recieve enable
    .rx(CSDL_C_RX2_S_TX2),      // Data recieve bit
    .tx(CSDL_C_TX2_S_RX2),      // Tx bit to send out on pin
    .tx_en(),                   // Tx enable signal     
    .rd_data(csdl_rd_data),      // Data read
    .rd_rdy_strb(csdl_rdy_strb), // Strobe to send read data
    .rd_strb(csdl_rd_strb),      // Read Register Strobe
    .rd_addr(csdl_rd_addr),      // Address to read from
    .wr_addr(csdl_wr_addr),      // Address to write to
    .wr_strb(csdl_wr_strb),      // Write Register Strobe
    .wr_data(csdl_wr_data),      // Data to write    
    .error(csdl_comm_err)        // Error in Com
  );    
//---------------------------------------------------------------	
// END COM PORT CSDL
//---------------------------------------------------------------
  
      
//---------------------------------------------------------------	
// COM ARBITRATION
// Select Commands from these priorities:
//  1. Autonomous COM
//  4. Test Port
//  2. Downlink
//  3. Sublink
//---------------------------------------------------------------
  defparam BusArbitration_i.ADDR_DW = 8;  
  BusArbitration BusArbitration_i
  (  
    .clk(clk),                         // System Clock 
    .reset(reset),                     // System Reset (Syncronous) 
    .enable(1'b1),                   // System enable      

    .rd_data(rd_data),                 // Arbitrated Data read  
    .rd_strb(rd_strb),                 // Arbitrated Read Register Strobe
    .rd_addr(rd_addr),                 // Arbitrated Address to read from
    .wr_addr(wr_addr),                 // Arbitrated Address to write to
    .wr_strb(wr_strb),                 // Arbitrated Write Register Strobe
    .wr_data(wr_data),                 // Arbitrated Data to write 

    .tst_rd_data(tst_rd_data),         // Test Data read
    .tst_rdy_strb(tst_rdy_strb),       // Test Data read ready strobe  
    .tst_rd_strb(tst_rd_strb),         // Test Read Register Strobe
    .tst_rd_addr(tst_rd_addr),         // Test Address to read from
    .tst_wr_addr(tst_wr_addr),         // Test Address to write to
    .tst_wr_strb(tst_wr_strb),         // Test Write Register Strobe
    .tst_wr_data(tst_wr_data),         // Test Data to write   

    .dnl_rd_data(dnl_rd_data),         // Downlink Data read  
    .dnl_rdy_strb(dnl_rdy_strb),       // Downlink Data read ready strobe
    .dnl_rd_strb(dnl_rd_strb),         // Downlink Read Register Strobe
    .dnl_rd_addr(dnl_rd_addr),         // Downlink Address to read from
    .dnl_wr_addr(dnl_wr_addr),         // Downlink Address to write to
    .dnl_wr_strb(dnl_wr_strb),         // Downlink Write Register Strobe
    .dnl_wr_data(dnl_wr_data),         // Downlink Data to write   

    .sub_rd_data(csdl_rd_data),        // CSDL Data read  
    .sub_rdy_strb(csdl_rdy_strb),      // CSDL Data read ready strobe
    .sub_rd_strb(csdl_rd_strb),        // CSDL Read Register Strobe
    .sub_rd_addr(csdl_rd_addr),        // CSDL Address to read from
    .sub_wr_addr(csdl_wr_addr),        // CSDL Address to write to
    .sub_wr_strb(csdl_wr_strb),        // CSDL Write Register Strobe
    .sub_wr_data(csdl_wr_data),        // CSDL Data to write   

    .aut_rd_data(aut_rd_data),         // Autonomous Data read  
    .aut_rdy_strb(aut_rdy_strb),       // Autonomous Data read ready strobe  
    .aut_rd_strb(aut_rd_strb),         // Autonomous Read Register Strobe
    .aut_rd_addr(aut_rd_addr[7:0]),    // Autonomous Address to read from
    .aut_wr_addr(aut_wr_addr[7:0]),    // Autonomous Address to write to
    .aut_wr_strb(aut_wr_strb),         // Autonomous Write Register Strobe
    .aut_wr_data(aut_wr_data),         // Autonomous Data to write
    .aut_wr_cmplt_strb(aut_wr_done_strb)// Autonomous Write is Done    
  );  

  assign comm_err = {2'b00,tst_comm_err, dnl_comm_err, csdl_comm_err};
  
//---------------------------------------------------------------	
// END COM ARBITRATION
//---------------------------------------------------------------  

//---------------------------------------------------------------	
// UNUSED INPUTS AND OUTPUTS 

  //Assign Outputs   
  assign CSDL_C_TX3_S_RX3 = 1'b1;  
  assign CSDL_C_TX4_S_RX4 = 1'b1; 
  
  assign UIC_CMD_RX_C_TX = UIC_CMD_TX_C_RX;
  assign UIC_EVT_RX_C_TX = UIC_EVT_TX_C_RX;  
  
    
  assign DIN1_C           = 1'b0;
  assign DOUT1_C          = 1'b0;
  assign DCLK1_C          = 1'b0;
  assign CS1_C_N          = 1'b0;  
  assign DIN2_C           = 1'b0;
  assign DOUT2_C          = 1'b0;
  assign DCLK2_C          = 1'b0;
  assign CS2_C_N          = 1'b0;
  
// END USE UP ALL OUTPUTS
//-----------------------------------------------------------------

//----------------------------------------------------------------- 
// TEMPERATURE I2C CONTROL LINES
  assign TEMP_SCL           = (I2C_TMP275_SCL_out) ? 1'bZ : 1'b0;
  assign I2C_TMP275_SCL_in  = TEMP_SCL;
  
  assign TEMP_SDA           = (I2C_TMP275_SDA_out) ? 1'bZ : 1'b0;
  assign I2C_TMP275_SDA_in  = TEMP_SDA;
// END TEMPERATURE I2C CONTROL LINES
//-----------------------------------------------------------------


//----------------------------------------------------------------- 
// MV0 I2C CONTROL LINES, U4
  assign DV_SCL1          = (I2C_DV1_SCL_out) ? 1'bZ : 1'b0;   //MV1 SCL OUTPUT
  assign I2C_DV1_SCL_in   = DV_SCL1 ;                          //MV1 SCL INPUT
  
  assign DV_SDA1          = (I2C_DV1_SDA_out) ? 1'bZ : 1'b0;   //MV1 SDA OUTPUT
  assign I2C_DV1_SDA_in   = DV_SDA1;                            //MV1 SDA  INPUT
// END MV1 I2C CONTROL LINES
//----------------------------------------------------------------- 

//----------------------------------------------------------------- 
// MV1 I2C CONTROL LINES, U5
  assign DV_SCL2          = (I2C_DV2_SCL_out) ? 1'bZ : 1'b0;   //MV2 SCL OUTPUT
  assign I2C_DV2_SCL_in   = DV_SCL2;                           //MV2 SCL INPUT
  
  assign DV_SDA2          = (I2C_DV2_SDA_out) ? 1'bZ : 1'b0;   //MV2 SDA OUTPUT
  assign I2C_DV2_SDA_in   = DV_SDA2;                           //MV2 SDA  INPUT
// END MV2 I2C CONTROL LINES
//----------------------------------------------------------------- 

//----------------------------------------------------------------- 
// MV2 I2C CONTROL LINES, U8
  assign DV_SCL3          = (I2C_DV3_SCL_out) ? 1'bZ : 1'b0;   //MV3 SCL OUTPUT
  assign I2C_DV3_SCL_in   = DV_SCL3;                          //MV3 SCL INPUT
  
  assign DV_SDA3          = (I2C_DV3_SDA_out) ? 1'bZ : 1'b0;   //MV3 SDA OUTPUT
  assign I2C_DV3_SDA_in   = DV_SDA3;                            //MV3 SDA  INPUT
// END MV1 I2C CONTROL LINES
//----------------------------------------------------------------- 

  
//----------------------------------------------------------------- 
// PUC Controller
    defparam PUC_C_Controller_i.FPGA_VERSION = C_FPGA_VERSION;
    defparam PUC_C_Controller_i.BROM_INITIAL_FILE = "C:/FPGA_Design/PAKPUCControl/src/BROM_Netlist_101542.txt";
    defparam PUC_C_Controller_i.NL_CNTR_WD = NL_CNTR_WD;
    defparam PUC_C_Controller_i.NL_ADDR_WD = NL_ADDR_WD;
//-----------------------------------------------------------------
  // SYSTEM CONTROLLER
  PUC_C_Controller  PUC_C_Controller_i  
  (  
    .clk(clk),                                // System Clock 
    .reset(reset),                            // System Reset (Syncronous)
    .enable(1'b1),                            // Enable   
    .por_strb(por_strb),                      // Power On Reset Strobe
    .sys_tmr_strb(sys_tmr_strb),              // System Timer Strobe
    .sync_strb(sync_strb),                    // System Timer Syncronization Strobe
    .strb_1us(strb_1us),                      // 1 us system strobe
    .strb_100us(strb_100us),                  // 100 us system strobe
    .strb_500us(strb_500us),                  // 500 us system strobe
    .strb_1ms(strb_1ms),                      // 1 ms strobe
    .strb_500ms(strb_500ms),                  // 500 ms strobe
    .strb_1s(strb_1s),                        // 1 sec system strobe
    
    .rd_strb(rd_strb),                        // Read Register Strobe
    .rd_addr(rd_addr),                        // Address to read from[3:0]
    .wr_addr(wr_addr),                        // Address to write to[1:0]
    .wr_strb(wr_strb),                        // Write Register Strobe
    .wr_data(wr_data),                        // Data to write[15:0]  
    .rd_data(rd_data),                        // Data read[35:0]  
    
    .COM_Cntrl(COM_Cntrl),                    // Output Flags to COM FPGA and internal COMs
    .comm_err(comm_err),                      // Communication Error
        
    .ADC1_DOUT(C_ADC1_DOUT),                  // Dout from ADC1
    .ADC1_BUSY(C_ADC1_BUSY),                  // Busy from ADC1
    .ADC1_CS_N(C_ADC1_CS_N),                  // Chip Select to ADC1
    .ADC1_CLK(C_ADC1_CLK),                    // Dclk to ADC1
    .ADC1_DIN(C_ADC1_DIN),                    // Din to ADC1
    .ADC_1_MUXA(C_ADC_1_MUXA),                // Multiplexer Select Chan A
    .ADC_1_MUXB(C_ADC_1_MUXB),                // Multiplexer Select Chan B
    
    .RA_CABLE_DET_N(RA_CABLE_DET_N),          // RAC Cable Connected
    
    .FAN1_TACH_N(FAN1_TACH_N),                // Tach 1 feedback mechanism
    .FAN1_PWM(FAN1_PWM),                      // FAN PWM Signal
    .FAN2_TACH_N(FAN2_TACH_N),                // Tach 1 feedback mechanism
    .FAN2_PWM(FAN2_PWM),                      // FAN PWM Signal    
    
    .TEMP_ALERT(TEMP_ALERT),                  // Temperature alert interrupt
    .TEMP_BIT(TEMP_BIT),                      // Temperature test switch state
    .TSENSE_TEST(TSENSE_TEST),                // BIT test temperature sense
    
    .I2C_TMP275_SCL_in(I2C_TMP275_SCL_in),    // Input SCL (As Slave)
    .I2C_TMP275_SCL_out(I2C_TMP275_SCL_out),  // Output SCL (As Master)
    .I2C_TMP275_SDA_in(I2C_TMP275_SDA_in),    // Input SDA (Master Ack/Nack, Slave Recieve)
    .I2C_TMP275_SDA_out(I2C_TMP275_SDA_out),  // Output SDA (Master/Slave Ack/Nack)              
    
    .C_TEMP_TEST_01(C_TEMP_TEST_01),          // Fluid Temperature sensor 1 BIT test 
    .C_TEMP_TEST_02(C_TEMP_TEST_02),          // Fluid Temperature sensor 2 BIT test
    
    .RL_SOL_PWM(C_RL_SOL_PWM),                // RAC Lock Solenoid PWM
    .VC_SOL_PWM(C_VC_SOL_PWM),                // Venous Clamp Solenoid PWM
    .DL_SOL_PWM(C_DL_SOL_PWM),                // Door Lock Solenoid PWM
    
    .VLV_INA(VLV_INA),                        // Spare VC in A
    .VLV_INB(VLV_INB),                        // Spare VC in B
    .VLV_OPTOA(VLV_OPTOA),                    // Spare VC opto A
    .VLV_OPTOB(VLV_OPTOB),                    // Spare VC opto B    
    
    .DRS_PWM(DRS_PWM),                        // Door Reference Sensor PWM
    .DRS_POS(DRS_POS),                        // Door Reference Sensor Postion Flag
    .DRS_AMB(DRS_AMB),                        // Door Reference Sensor Ambiant Level
    
    .ABD_OUT2(ABD_OUT2),                      // Redudant ABD
    
    .DV_OPEN(DV_OPEN),                        //  Flag to Open enabled DiaphragmValve
    .DV_CLOSE(DV_CLOSE),                      //  Flag to Close enabled DiaphragmValve
    .EVP1(EVP1),                              //  Enable Valve Plunger 1
    .EVP2(EVP2),                              //  Enable Valve Plunger 2
    .EVP3(EVP3),                              //  Enable Valve Plunger 3
    .EVP4(EVP4),                              //  Enable Valve Plunger 4
    .EVP5(EVP5),                              //  Enable Valve Plunger 5
    .EVP6(EVP6),                              //  Enable Valve Plunger 6    
    .I2C_DV1_SCL_in(I2C_DV1_SCL_in),          //  DV1 Input SCL (As Slave)
    .I2C_DV1_SCL_out(I2C_DV1_SCL_out),        //  DV1 Output SCL (As Master)
    .I2C_DV1_SDA_in(I2C_DV1_SDA_in),          //  DV1 Input SDA (Master Ack/Nack, Slave Recieve)
    .I2C_DV1_SDA_out(I2C_DV1_SDA_out),        //  DV1 Output SDA (Master/Slave Ack/Nack)
    .I2C_DV2_SCL_in(I2C_DV2_SCL_in),          //  DV2 Input SCL (As Slave)
    .I2C_DV2_SCL_out(I2C_DV2_SCL_out),        //  DV2 Output SCL (As Master)
    .I2C_DV2_SDA_in(I2C_DV2_SDA_in),          //  DV2 Input SDA (Master Ack/Nack, Slave Recieve)
    .I2C_DV2_SDA_out(I2C_DV2_SDA_out),        //  DV2 Output SDA (Master/Slave Ack/Nack)
    .I2C_DV3_SCL_in(I2C_DV3_SCL_in),          //  DV3 Input SCL (As Slave)
    .I2C_DV3_SCL_out(I2C_DV3_SCL_out),        //  DV3 Output SCL (As Master)
    .I2C_DV3_SDA_in(I2C_DV3_SDA_in),          //  DV3 Input SDA (Master Ack/Nack, Slave Recieve)
    .I2C_DV3_SDA_out(I2C_DV3_SDA_out),        //  DV3 Output SDA (Master/Slave Ack/Nack)    
    
    .DAC_DOUT(C_DAC_DOUT),                    // DAC Interface Motor Current Limit Dout
    .DAC_DIN(C_DAC_DIN),                      // DAC Interface Motor Current Limit Din    
    .DAC_DCLK(C_DAC_DCLK),                    // DAC Interface Motor Current Limit Clock
    .DAC_CS_N(C_DAC_CS_N),                    // DAC Interface Motor Current Limit Chip Select
    .DAC_CLR_N(C_DAC_CLR_N),                  // DAC Interface Motor Current Limit Clear

    .BP_STEP(BP_STEP),                        // Motor BP Step Command             
    .BP_DIR(BP_DIR),                          // Motor BP Direction (Low Clockwise)
    .BP_M1(BP_M1),                            // Motor BP Bit 0 Micro Step Setting
    .BP_M2(BP_M2),                            // Motor BP Bit 1 Micro Step Setting
    .BP_RESET_N(BP_RESET_N),                  // Motor BP Active Low Reset
    .DP1_STEP(DP1_STEP),                      // Motor DP1 Step Command
    .DP1_DIR(DP1_DIR),                        // Motor DP1 Direction (Low Clockwise)
    .DP1_M1(DP1_M1),                          // Motor DP1 Bit 0 Micro Step Setting
    .DP1_M2(DP1_M2),                          // Motor DP1 Bit 1 Micro Step Setting
    .DP1_RESET_N(DP1_RESET_N),                // Motor DP1 Active Low Reset
    .DP2_STEP(DP2_STEP),                      // Motor DP2 Step Command
    .DP2_DIR(DP2_DIR),                        // Motor DP2 Direction (Low Clockwise)
    .DP2_M1(DP2_M1),                          // Motor DP2 Bit 0 Micro Step Setting
    .DP2_M2(DP2_M2),                          // Motor DP2 Bit 1 Micro Step Setting
    .DP2_RESET_N(DP2_RESET_N),                // Motor DP2 Active Low Reset
    .ELP_STEP(ELP_STEP),                      // Motor ELP Step Command
    .ELP_DIR(ELP_DIR),                        // Motor ELP Direction (Low Clockwise)
    .ELP_M1(ELP_M1),                          // Motor ELP Bit 0 Micro Step Setting
    .ELP_M2(ELP_M2),                          // Motor ELP Bit 1 Micro Step Setting
    .ELP_RESET_N(ELP_RESET_N),                // Motor ELP Active Low Reset
    .HEP_STEP(HEP_STEP),                      // Motor HEP Step Command
    .HEP_DIR(HEP_DIR),                        // Motor HEP Direction (Low Clockwise)
    .HEP_M1(HEP_M1),                          // Motor HEP Bit 0 Micro Step Setting
    .HEP_M2(HEP_M2),                          // Motor HEP Bit 1 Micro Step Setting
    .HEP_RESET_N(HEP_RESET_N),                // Motor HEP Active Low Reset
    .DL_STEP(DL_STEP),                        // Motor DL Step Command
    .DL_DIR(DL_DIR),                          // Motor DL Direction (Low Clockwise)
    .DL_M1(DL_M1),                            // Motor DL Bit 0 Micro Step Setting
    .DL_M2(DL_M2),                            // Motor DL Bit 1 Micro Step Setting
    .DL_RESET_N(DL_RESET_N),                  // Motor DL Active Low Reset
  
    .BPR_CHA_C(BPR_CHA_C),                    // Motor BP Encoder Channel A
    .BPR_CHB_C(BPR_CHB_C),                    // Motor BP Encoder Channel B
    .DP1R_CHA_C(DP1R_CHA_C),                  // Motor DP1 Encoder Channel A
    .DP1R_CHB_C(DP1R_CHB_C),                  // Motor DP1 Encoder Channel B
    .DP2R_CHA_C(DP2R_CHA_C),                  // Motor DP2 Encoder Channel A
    .DP2R_CHB_C(DP2R_CHB_C),                  // Motor DP2 Encoder Channel B
    .HEPR_CHA_C(HEPR_CHA_C),                  // Motor HEP Encoder Channel A
    .HEPR_CHB_C(HEPR_CHB_C),                  // Motor HEP Encoder Channel B
    .ELPR_CHA_C(ELPR_CHA_C),                  // Motor ELP Encoder Channel A
    .ELPR_CHB_C(ELPR_CHB_C),                  // Motor ELP Encoder Channel B
    .DL_CHA_C(DL_CHA_C),                      // Motor DL Encoder Channel A
    .DL_CHB_C(DL_CHB_C),                      // Motor DL Encoder Channel B  
    
    .DAC_SYNC_N(DAC_SYNC_N),                  // Spare output DAC sync
    .DAC_SCLK(DAC_SCLK),                      // Spare output DAC sclk
    .DAC_SDIN(DAC_SDIN),                      // Spare output DAC sdin
    
    .CSDL_C_RX1_S_TX1(CSDL_C_RX1_S_TX1),      // Cross Channel Master Recieve
    .CSDL_C_TX1_S_RX1(CSDL_C_TX1_S_RX1),      // Cross Channel Master Transmit 
    
    .SUBLINK_C_RX(SUBLINK_C_RX),              // Subsystem Recieve Line  
    .SUBLINK_C_TX(SUBLINK_C_TX),              // Subsystem Transmit Line    
    
    .PUC_C_EE_DOUT2(PUC_C_EE_DOUT2),          // NVM output line
    .PUC_C_EE_DIN2(PUC_C_EE_DIN2),            // NVM input line  
    .PUC_C_EE_DCLK2(PUC_C_EE_DCLK2),          // NVM clock line
    .PUC_C_EE_CS2_L(PUC_C_EE_CS2_L),          // NVM chip select
    .PUC_C_EE_HOLD2(PUC_C_EE_HOLD2),          // NVM hold
    .PUC_C_EE_WP2(PUC_C_EE_WP2),              // NVM write protect     
    
    .sub_seq_done(sub_seq_done),              // Flag that the sub sequence run has completed. 
    .sub_seq_strb(sub_seq_strb),              // Strob to run sub sequence 1 
    .sub_seq_addr(sub_seq_addr),              // Address of subsequence to run
    .sub_seq_cnt(sub_seq_cnt),                // Number of nets in the subsequence
     
    .net_wr_strb(net_wr_strb),                // Net List
    .net_wr_addr(net_wr_addr),                // Net Address
    .net_wr_data(net_wr_data),                // Net Data

    .EXC_C_1BIT_DAC(EXC_C_1BIT_DAC),          // Output 1 bit DAC        
        
    .LogicAnalyzer(LogicAnalyzer)             // Output Logic Analyzer
  );      
// END SYSTEM CONTROLLER
//----------------------------------------------------------------- 
  

//----------------------------------------------------------------- 
// SEQUENCER
  defparam Sequencer_i.BRAM_NETLIST_FILE = "C:/FPGA_Design/PAKPUCControl/src/BRAM_Netlist_101542.txt";
  defparam Sequencer_i.NL_MEM_SIZE        = NL_MEM_SIZE;
  defparam Sequencer_i.NL_CNTR_WD         = NL_CNTR_WD;
  defparam Sequencer_i.NL_ADDR_WD         = NL_ADDR_WD;
  defparam Sequencer_i.NL_DATA_WD         = NL_DATA_WD;
  defparam Sequencer_i.BRAM_MEMORY_FILE  = "C:/FPGA_Design/PAKPUCControl/src/BRAM_Memory_101542.txt";
  defparam Sequencer_i.BRAM_NVM_FILE     = "C:/FPGA_Design/PAKPUCControl/src/BRAM_NVM_Control.txt";
  Sequencer Sequencer_i
  (  
    .clk(clk),                                  // System Clock 
    .reset(reset),                              // System Reset (Syncronous) 
    .enable(1'b1),                              // System enable
    .sys_tmr_strb(sys_tmr_strb),                // System Timer Strobe    
    
    .sub_seq_strb(sub_seq_strb),                // Strob to run sub sequence 1 
    .sub_seq_addr(sub_seq_addr),                // Address of subsequence to run
    .sub_seq_cnt(sub_seq_cnt),                  // Number of nets in the subsequence
    .sub_seq_done(sub_seq_done),                // Flag that the sub sequence run has completed.  
      
    .reg_sys_rd_data(aut_rd_data),              // Register Data read
    .reg_sys_rd_rdy_strb(aut_rdy_strb),         // Strobe to read data
    .reg_sys_wr_done_strb(aut_wr_done_strb),    // Strobe that write is done.
    .reg_sys_rd_strb(aut_rd_strb),              // Register Read Register Strobe
    .reg_sys_rd_addr(aut_rd_addr),              // Register Address to read from
    .reg_sys_wr_addr(aut_wr_addr),              // Register Address to write to
    .reg_sys_wr_strb(aut_wr_strb),              // Register Write Register Strobe
    .reg_sys_wr_data(aut_wr_data),              // Register Data to write      
 
    .net_wr_strb(net_wr_strb),                  // Net List
    .net_wr_addr(net_wr_addr),                  // Net Address
    .net_wr_data(net_wr_data),                  // Net Data
    
    .NVM_DOUT(PUC_C_EE_DOUT),                   // NVM output line
    .NVM_DIN(PUC_C_EE_DIN),                     // NVM input line  
    .NVM_DCLK(PUC_C_EE_DCLK),                   // NVM clock line
    .NVM_CS_L(PUC_C_EE_CS_L),                   // NVM chip select
    .NVM_HOLD(PUC_C_EE_HOLD),                   // NVM hold
    .NVM_WP(PUC_C_EE_WP)                        // NVM write protect 
  );
 

// END SYSTEM SEQUENCER
//----------------------------------------------------------------- 

// VERIFICATION PORT
  Verification_Port  Verification_Port_i
  (
    .clk(clk),
    .reset(reset),
    .enable(1'b1),
  
    .logic_analyzer(LogicAnalyzer),     
  
    .V_L0_P(VC_L0_P),
    .V_L0_N(VC_L0_N),
    .V_L1_P(VC_L1_P),
    .V_L1_N(VC_L1_N),
    .V_L2_P(VC_L2_P),
    .V_L2_N(VC_L2_N),
    .V_L3_P(VC_L3_P),
    .V_L3_N(VC_L3_N),
    .V_CLK_P(VC_CLK_P),
    .V_CLK_N(VC_CLK_N),
    .V_AUX_P(VC_AUX_P),
    .V_AUX_N(VC_AUX_N),
    .V_SDA(VC_SDA),
    .V_SCL(VC_SCL),  
    .V_SE_1(VC_SE_1),
    .V_SE_2(VC_SE_2)
  );

//-----------------------------------------------------------------
// SYSTEM READY AND DISCRETE FLAGS    

  //Indicates GTE is released and device programmed (Norm Pulled Low)
  assign C_READY     = 1'b1;          

  //Control Signal to Actel COM FPGA bit 0 (Norm Pulled High)
  assign C_DISCRETE1 = ~COM_Cntrl[0]; 
  
  //Control Signal to Actel COM FPGA bit 1 (Norm Pulled Low)
  assign C_DISCRETE2 =  COM_Cntrl[1];  
  
// END SYSTEM READY FLAG
//-----------------------------------------------------------------
  
 endmodule
  
  

 