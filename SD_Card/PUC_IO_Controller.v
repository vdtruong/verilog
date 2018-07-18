  //-----------------------------------------------------------------
//  Module:     PUC_IO_Controller
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
//-----------------------------------------------------------------
module PUC_IO_Controller 
#( parameter FPGA_VERSION 			= 16'h0000,
   parameter BROM_INITIAL_FILE 	= "C:/FPGA_Design/PAKPUCIO/src/BROM_NetLists_XXXX_64_x_36.txt",
   parameter NL_ADDR_WD 			= 9,
   parameter LS 						= 36,
	parameter ADDR_DW 				= 6)						// ADRESS DATA WIDTH
(  
	input                         clk,                	// System Clock 
	input                         reset,              	// System Reset (Syncronous)  
	input                         por_strb,           	// Power on reset strobe
	input                         sys_tmr_strb,       	// System Timer Strobe
	input                         estop_pressed,      	// Estop switch pressed
  
	input                         rd_strb,            	// Read Register Strobe
	input        [5:0]            rd_addr,            	// Address to read from 0-64
	input        [5:0]            wr_addr,            	// Address to write to 0-64
	input                         wr_strb,            	// Write Register Strobe
	input       [35:0]            wr_data,            	// Data to write 36 bit data 
	output  reg [35:0]            rd_data,            	// Data read 36 bit data
	output  reg                   rd_rdy_strb,        	// Strobe that data is ready to read
  
	output       [1:0]            COM_Cntrl,          	// Output flag to Actel COM FPGA
	input       [11:0]            comm_err,           	// Communication Error
 
	input                         ADC1_DOUT,          	// Dout from ADC1
	input                         ADC1_BUSY,          	// Busy from ADC1
	output                        ADC1_CS_N,          	// Chip Select to ADC1
	output                        ADC1_CLK,           	// Dclk to ADC1
	output                        ADC1_DIN,           	// Din to ADC1 
  
	input                         UIC_CABLE_DET_N,    	// UIC Cable connected
	input                         SBC_CABLE_DET_N,    	// SBC Cable connected
  
	output                        MEAS_RTC_BAT,       	// Measure Battery for RTC
  
	input                         sub_seq_done,       	// Flag that the sub sequence run has completed. 
	output                        sub_seq_strb,       	// Strobe to run sub sequence 1 
	output      [NL_ADDR_WD-1:0]  sub_seq_addr,       	// Address of subsequence to run
	output      [NL_ADDR_WD-1:0]  sub_seq_cnt,        	// Number of nets in the subsequence  
    
	output  reg                   net_wr_strb,        	// Net List
	output      [NL_ADDR_WD-1:0]  net_wr_addr,        	// Net Address
	output      [35:0]            net_wr_data,        	// Net Data    
  
   input               				RTC_I2C_SCL_in,  		// Input ISL1208 SCL
   output              				RTC_I2C_SCL_out, 		// Output ISL1208 SCL
   input               				RTC_I2C_SDA_in,  		// Input ISL1208 SDA
   output              				RTC_I2C_SDA_out, 		// Output ISL1208 SDA 
  
	// For SD Card 1
   // Autonomous data from Sequencer.   
	input                       	aut_rd_strb,         // Autonomous Read Register Strobe
	input  		[ADDR_DW-1:0]     aut_rd_addr,         // Autonomous Address to read from
	input                   		aut_rdy_strb,  		// Strobe to read data
	input  		[35:0]           	aut_rd_data,      	// Register Data read
	output 							   strt_fifo_strb,	   // Start filling up fifo, first fifo_data.
	input									puc_data_strb,	   	// write puc data to fifo
	input			[63:0]				puc_data,				// data to be logged.
	output                        rdy_for_nxt_pkt,     // ready for next packet (fifo_data) from puc 
  
	input 								IO_SDC1_CD_WP,
	input									IO_SDC1_D0_in,
	output								IO_SDC1_D0_out,
	input									IO_SDC1_D1_in,
	output								IO_SDC1_D1_out,
	input									IO_SDC1_D2_in,
	output								IO_SDC1_D2_out,
	input									IO_SDC1_D3_in,
	output								IO_SDC1_D3_out,
	output        						IO_SDC1_CLK,
	input        						IO_SDC1_CMD_in,
	output        						IO_SDC1_CMD_out,

	output reg  [15:0]            LogicAnalyzer,       	// Logic Analyzer
	output wire [127:0]           cs_test_vector
);

/*-----------------------------------------------------------------------
                             MEMORY/REGISTER MAP
WRITE SPACE:  
  0x0000  SPARE    
  0x0001  DAC/ADC Control Register
          Bit[0] : 1 Bit DAC Enable == 1, Disable == 0
          Bit[1] : ADC1 Enable == 1, Disable == 0
          Bit[2] : ADC2 Enable == 1, Disable == 0
          Bit[3] : DAC Reference Enable == 1, Disable == 0
          Bit[4] : RTC BAT Monitor Enable == 1, Disable == 0
  0x0002  Command Sub System Sequence to run 1-36
          Bit[35:0] : Sequence enable bits
  0x0003  Command Sub System Sequence to run 37-64
          Bit[35:0] : Sequence enable bits
  0x0004  SPARE     
  0x0005  SPARE
  0x0006  Program Net List Address (Auto Increment after write to Data
  0x0007  Program Net List Data (+Strb) 
  0x0008  NVM Write 01
  0x0009  NVM Write 02
  0x000A  NVM Write 03
  0x000B  NVM Write 04
  0x000C  NVM Write 05
  0x000D  NVM Write 06
  0x000E  COM FLAG(S)
          Bit[0] : Route thru to test COMs
          Bit[1] : Spare Discrete to COM FPGA
  0x000F  RTC Write 01 -- 33 bits -- wrtc(1), sc(8), mn(8), hr(8), dt(8)
  0x0010  RTC Write 02 -- 24 bits -- mo(8), yr(8), dw(8)          
  0x0011  Send a command to the SD Card. Command Register field (00Eh)
  0x0012  Triggers the sdc initialization procedure manually. 
  0x0013  Write sd host controller map address. Used to be 0x000F.
  0x0014  Manual write to sd card host controller.  wreg_sdc_hc_reg_man. Used to be 0x0010
  0x0015  SD Card Address to write to.
  0x0016  SD Card Address to read from.
  0x0017  Write to generate start_data_tf_strb.
  0x0018  Write to tf_mode.
  0x0019  Use this register to write the command index in the sdc command format.
  0x001a  SPARE
  0x001b  SPARE
  0x001c  SPARE
  0x001d  SPARE
  0x001e  SPARE
  0x001f  SPARE
  0x0020  DEBUG RTL 26
  0x0021  SPARE 
  0x0022  SPARE 
  0x0023  SPARE 
  0x0024  SPARE 
  0x0025  SPARE 
  0x0026  SPARE 
  0x0027  SPARE 
  0x0028  SPARE 
  0x0029  SPARE 
  0x002A  SPARE 
  0x002B  SPARE
  0x002C  SPARE
  0x002D  SPARE
  0x002E  SPARE
  0x002F  SPARE
  0x0030  SPARE
  0x0031  SPARE
  0x0032  SPARE
  0x0033  SPARE
  0x0034  SPARE
  0x0035  SPARE
  0x0036  SPARE
  0x0037  SPARE
  0x0038  
  0x0039  
  0x003A  GP 
  0x003B  SPARE
  0x003C  SPARE
  0x003D  SPARE
  0x003E  SPARE
  0x003F  Write manually to sdc host controller.
END WRITE SPACE

READ REGISTERS:
  0x0000  ADC1 NO MUX CH0 (24V)
  0x0001  ADC1 NO MUX CH1 (5V) 
  0x0002  ADC1 NO MUX CH2 (3.3V)
  0x0003  ADC1 NO MUX CH3 (1.8V)
  0x0004  ADC1 NO MUX CH4 (1.5V)
  0x0005  ADC1 NO MUX CH5 (1.2V)
  0x0006  ADC1 NO MUX CH6 (24V_IO_SENSE)
  0x0007  ADC1 NO MUX CH7 (VRTC CHECK)
  0x0008  NVM Read 01
  0x0009  NVM Read 02
  0x000A  NVM Read 03
  0x000B  NVM Read 04
  0x000C  NVM Read 05
  0x000D  NVM Read 06
  0x000E  SPARE
  0x000F  
  0x0010  
  0x0011  rreg_sdc_cmd
  0x0012  Data from Host Controller Map Registers.
  0x0013  Autonomous Data from Sequencer.
  0x0014  Autonomous Address to read from.
  0x0015  2.2.5 Transfer Mode Register (Offset 00Ch)                       (Monitors Tripped 0-35)
  0x0016  2.2.6 Command Register (Offset 00Eh) 			                     (Monitors Tripped 36-71)
  0x0017  2.2.7 Response Register (Offset 010h) 				               (Monitors Tripped 72-107)
  0x0018  2.2.9 Present State Register (Offset 024h)	                     (Monitors Tripped 108-143)
  0x0019  2.2.14 Clock Control Register (Offset 02Ch)                      (Monitors Tripped 144-179)
  0x001A  2.2.17 Normal Interrupt Status Register (Offset 030h) (pg 63)
  0x001B  2.2.18 Error Interrupt Status Register (Offset 032h) (pg 68)     (SkipLabDraw)
  0x001C  2.2.19 Normal Interrupt Status Enable Register (Offset 034h)     (VA Recovery Mode)
  0x001D  2.2.20 Error Interrupt Status Enable Register (Offset 036h)      (LabDrawDone)
  0x001E  2.2.21 Normal Interrupt Signal Enable Register (Offset 038h)     (Empty Done)
  0x001F  2.2.22 Error Interrupt Signal Enable Register (Offset 03Ah)      (SOM Ready)
  0x0020  2.2.30 ADMA System Address Register (Offset 058h)                (ESTOP Processed)
  0x0021  Read sd host controller map address.
  0x0022  rreg_sdc_hc_reg_man
  0x0023  STATUS REGISTER
  0x0024  COMM ERROR REGISTER
  0x0025  SPARE
  0x0026  SPARE
  0x0027  SPARE
  0x0028  SPARE
  0x0029  SPARE
  0x002a  SPARE
  0x002b  SPARE
  0x002c  SPARE
  0x002d  SPARE
  0x002e  SPARE
  0x002f  SPARE
  0x0030  SPARE
  0x0031  SPARE
  0x0032  IO STATE
  0x0033  ALARM STATE
  0x0034  SPARE
  0x0035  SPARE
  0x0036  SPARE
  0x0037  SPARE
  0x0038  
  0x0039  
  0x003A  SPARE
  0x003B  SPARE
  0x003C  SPARE
  0x003D  SPARE
  0x003E  SPARE
  0x003F  Read from wreg_hc_reg.
  ------------------------------------------------------------------------*/


//WRITE REGISTERS:  
  //0x0000  SPARE
  //reg[35:0] wreg_Spare_62; 
  
  //0x0001  One Bit DAC Control Register
  //        Bit[0] : DSM Enable == 1, Disable == 0    
  //reg       wreg_DSM_en;     
  //        Bit[1] : ADC1 Enable == 1, Disable == 0
  reg       wreg_ADC1_en;     
  //        Bit[2] : ADC2 Enable == 1, Disable == 0  
  //reg       wreg_ADC2_en;     
  //        Bit[3] : DAC Enable == 1, Disable == 0  
  //reg       wreg_DAC_en;       
  //        Bit[4] : RTC Monitor Enable == 1, Disable == 0  
  reg       wreg_RTC_meas;       
  //0x0002  Command Sub System Sequence to run 1-36
  //        Bit[35:0] : Sequence enable bits
  reg[35:0] wreg_sub_seq_cmd_1; 
  //0x0003  Command Sub System Sequence to run 37-64
  //        Bit[35:0] : Sequence enable bits
  reg[35:0] wreg_sub_seq_cmd_2; 
  //0x0003  SPARE
  //reg[35:0] wreg_Spare_52;
  //0x0004  SPARE
  //reg[35:0] wreg_Spare_51;  
  //0x0005  SPARE
  //reg[35:0] wreg_Spare_50;
  //0x0006  
  reg       [NL_ADDR_WD-1:0] wreg_netlist_address;
  //0x0007  
  reg[35:0] wreg_netlist_data;  
  //0x0008  
  reg[35:0] wreg_NVM_01;
  //0x0009  
  reg[35:0] wreg_NVM_02;
  //0x000A  
  reg[35:0] wreg_NVM_03;
  //0x000B  
  reg[35:0] wreg_NVM_04;
  //0x000C  
  reg[35:0] wreg_NVM_05;
  //0x000D  
  reg[35:0] wreg_NVM_06;
  //0x000E  COM Flags
  //        Bit[0] = Discrete 1 (Switch Actel Pass Thru)
  //        Bit[1] = Discrete 2
  reg [1:0] wreg_COM_Cntrl;
  //0x000F  RTC Write 01 -- 33 bits -- wrtc(1), sc(8), mn(8), hr(8), dt(8) 
  reg[35:0] wreg_RTC_01;
  //0x0010  RTC Write 02 -- 24 bits -- mo(8), yr(8), dw(8)
  reg[23:0] wreg_RTC_02;
  // strobe to send to the RTC
  reg       wr_rtc_strb;
  //0x0011  Data to go with register 0x0011.
  //        0x0011   0x000000700 Move to transfer state.
  //        0x0011   0x000001100 Read a single block.
  reg[35:0] wreg_sdc_cmd;
  //0x0012  // Triggers the sdc initialization procedure manually. Data not needed.
  //        0x0012   0xXXXXXXXXX
  reg[35:0] wreg_Spare_46;
  //0x0013  Write sd host controller map address to read, used to be 0x000F.
  //        0x0013   0x000000010 Points to Response SDC address
  //        0x0013   0x000000024 Points to Present State SDC address
  reg[35:0] wreg_hc_addr;
  //0x0014  Write data to host controller reg. map manually, used to be 0x0010.
  //        0x0014   0x0002C4005 choose and turn on clock speed
  //        0x0014   0x0000C0027 transfer mode, writing multiple block
  //        0x0014   0x0000C0037 transfer mode, read multiple block
  //        0x0014   0x0000C0007 transfer mode, writing one block
  //        0x0014   0x0000C0017 transfer mode, read one block
  //        0x0014   0x0000E1900 Command register for multiple blocks write
  //                 attribute     [30:28] 3 bits
  //                 h.c. register [27:16] 12 bits
  //                 data          [15:0]  16 bits
  reg[35:0] wreg_sdc_hc_reg_man;
  //0x0015  SD Card Address to write to.
  //        0x0015   0x000080200
  reg[35:0] wreg_sdc_wr_addr;
  //0x0016  SD Card Address to read from.
  //        0x0016   0x000080200
  reg[35:0] wreg_sdc_rd_addr;
  //0x0017  Write to generate start_data_tf_strb.  No data needed.
  //        0x0017   0xXXXXXXXXX
  reg       wreg_strt_data_tf_strb;
  //0x0018  sd card transfer mode
  //        0x0018   0x0000C0025 transfer mode, writing multiple block
  //        0x0018   0x0000C0035 transfer mode, read multiple block
  //        0x0018   0x0000C0005 transfer mode, writing one block
  //        0x0018   0x0000C0015 transfer mode, read one block
  reg[35:0] wreg_tf_mode;
  //0x0019  Write the command index for the sdc command format.
  reg[35:0] wreg_cmd_indx;
  //0x001A  SPARE
  reg[35:0] wreg_Spare_38;
  //0x001B  SPARE
  reg[35:0] wreg_Spare_37;
  //0x001C  SPARE
  reg[35:0] wreg_Spare_36;
  //0x001D  SPARE
  reg[35:0] wreg_Spare_35;
  //0x001E  SPARE
  reg[35:0] wreg_Spare_34;
  //0x001F  SPARE   
  reg[35:0] wreg_Spare_33;
  //0x0020  SPARE
  reg[35:0] wreg_Spare_32;
  //0x0021  SPARE
  reg[35:0] wreg_Spare_31;
  //0x0022  SPARE
  reg[35:0] wreg_Spare_30;
  //0x0023  SPARE
  reg[35:0] wreg_Spare_29;
  //0x0024  SPARE
  reg[35:0] wreg_Spare_28;
  //0x0025  SPARE
  reg[35:0] wreg_Spare_27;
  //0x0026  SPARE
  reg[35:0] wreg_Spare_26;
  //0x0027  SPARE
  reg[35:0] wreg_Spare_25;
  //0x0028  SPARE
  reg[35:0] wreg_Spare_24;
  //0x0029  SPARE
  reg[35:0] wreg_Spare_23;
  //0x002a  SPARE
  reg[35:0] wreg_Spare_22;
  //0x002b  SPARE
  reg[35:0] wreg_Spare_21;
  //0x002c  SPARE
  reg[35:0] wreg_Spare_20;
  //0x002d  SPARE
  reg[35:0] wreg_Spare_19;
  //0x002e  SPARE
  reg[35:0] wreg_Spare_18;
  //0x002f  SPARE
  reg[35:0] wreg_Spare_17;
  //0x0030  SPARE
  reg[35:0] wreg_Spare_16;
  //0x0031  SPARE
  reg[35:0] wreg_Spare_15;
  //0x0032  SPARE
  //reg[35:0] wreg_Spare_14;
  //0x0033  SPARE
  //reg[35:0] wreg_Spare_13;
  //0x0034  SPARE
  reg[35:0] wreg_Spare_12;
  //0x0035  SPARE
  reg[35:0] wreg_Spare_11;
  //0x0036  SPARE
  reg[35:0] wreg_Spare_10;
  //0x0037  SPARE
  reg[35:0] wreg_Spare_09;
  //0x0038  SPARE
  reg[35:0] wreg_Spare_08;
  //0x0039  SPARE
  reg[35:0] wreg_Spare_07;
  //0x003a  SPARE
  reg[35:0] wreg_Spare_06;
  //0x003b  SPARE
  reg[35:0] wreg_Spare_05;
  //0x003c  SPARE
  reg[35:0] wreg_Spare_04;
  //0x003d  SPARE
  reg[35:0] wreg_Spare_03;
  //0x003e  SPARE
  reg[35:0] wreg_Spare_02;
  //0x003f  SPARE
  reg[35:0] wreg_hc_reg;  
  //0x0060  GPRW
  reg[35:0] wreg_GPRW_60; 
  //0x0061  GPRW
  reg[35:0] wreg_GPRW_61; 
  //0x0062  GPRW
  reg[35:0] wreg_GPRW_62; 
  //0x0063  GPRW
  reg[35:0] wreg_GPRW_63; 
  //0x0064  GPRW
  reg[35:0] wreg_GPRW_64; 
  //0x0065  GPRW
  reg[35:0] wreg_GPRW_65;    
    
//READ REGISTERS:
  //0x0000  rreg_ADC1_NOMUX_CH0
  reg[15:0] rreg_ADC1_NOMUX_CH0;
  //0x0001  rreg_ADC1_NOMUX_CH1
  reg[15:0] rreg_ADC1_NOMUX_CH1;
  //0x0002  rreg_ADC1_NOMUX_CH2
  reg[15:0] rreg_ADC1_NOMUX_CH2;
  //0x0003  rreg_ADC1_NOMUX_CH3
  reg[15:0] rreg_ADC1_NOMUX_CH3;
  //0x0004  rreg_ADC1_NOMUX_CH4
  reg[15:0] rreg_ADC1_NOMUX_CH4;
  //0x0005  rreg_ADC1_NOMUX_CH5
  reg[15:0] rreg_ADC1_NOMUX_CH5;
  //0x0006  rreg_ADC1_NOMUX_CH6
  reg[15:0] rreg_ADC1_NOMUX_CH6;
  //0x0007  rreg_ADC1_NOMUX_CH7
  reg[15:0] rreg_ADC1_NOMUX_CH7;
  //0x0008  
  reg[35:0] rreg_NVM_01;
  //0x0009  
  reg[35:0] rreg_NVM_02;
  //0x000A  
  reg[35:0] rreg_NVM_03;
  //0x000B  
  reg[35:0] rreg_NVM_04;
  //0x000C  
  reg[35:0] rreg_NVM_05;
  //0x000D  
  reg[35:0] rreg_NVM_06;
  //0x000E  SPARE
  reg[35:0] rreg_Spare_48;
  //0x000F  RTC Read 01
  reg[31:0] rreg_RTC_01;  
  //0x0010  RTC Read 02
  reg[23:0] rreg_RTC_02;
  //0x0011  SPARE
  reg[35:0] rreg_sdc_cmd;
  //0x0012  SPARE
  reg[35:0] rreg_sdc_blk_size;
  //0x0013  Autonomous data from Sequencer.
  reg[35:0] rreg_auto_data;
  //0x0014  Autonomous Address to read from
  reg[35:0] rreg_auto_addr;
  //0x0015  SPARE
  reg[35:0] rreg_sdc_trans_mde;
  //0x0016  SPARE
  reg[35:0] rreg_sdc_command;
  //0x0017  SPARE
  reg[35:0] rreg_sdc_resp;
  //0x0018  SPARE
  reg[35:0] rreg_sdc_pres_ste;
  //0x0019  SPARE
  reg[35:0] rreg_sdc_clk_cntrl;
  //0x001A  SPARE
  reg[35:0] rreg_sdc_norm_int_stat;
  //0x001B  SPARE
  reg[35:0] rreg_sdc_err_int_stat;
  //0x001C  SPARE
  reg[35:0] rreg_sdc_norm_int_stat_enb;
  //0x001D  SPARE
  reg[35:0] rreg_sdc_err_int_stat_enb;
  //0x001E  SPARE
  reg[35:0] rreg_sdc_norm_int_sig_enb;
  //0x001F  SPARE
  reg[35:0] rreg_sdc_err_int_sig_enb; 
  //0x0020  SPARE
  reg[35:0] rreg_sdc_adma_sys_addr;    
  //0x0021  Read sd host controller address
  reg[35:0] rreg_hc_addr;//rreg_Spare_29;  
  //0x0022  rreg_sdc_hc_reg_man
  reg[35:0] rreg_sdc_hc_reg_man;
  //0x0023  STATUS
  reg[35:0] rreg_status;
  //0x0024  SPARE
  reg[11:0] rreg_com_err;
  //0x0025  SPARE
  reg[35:0] rreg_Spare_27;
  //0x0026  SPARE
  reg[35:0] rreg_Spare_26;
  //0x0027  SPARE
  reg[35:0] rreg_Spare_25;
  //0x0028  SPARE
  reg[35:0] rreg_Spare_24;
  //0x0029  SPARE
  reg[35:0] rreg_Spare_23;
  //0x002A  SPARE
  reg[35:0] rreg_Spare_22;
  //0x002B  SPARE
  reg[35:0] rreg_Spare_21;
  //0x002C  SPARE
  reg[35:0] rreg_Spare_20;
  //0x002D  SPARE
  reg[35:0] rreg_Spare_19;
  //0x002E  SPARE
  reg[35:0] rreg_Spare_18;
  //0x002F  SPARE
  reg[35:0] rreg_Spare_17;  
  //0x0030  SPARE
  reg[35:0] rreg_Spare_16;  
  //0x0031  SPARE
  reg[35:0] rreg_Spare_15;
  //0x0032  SPARE
  reg[35:0] rreg_Spare_14;
  //0x0033  SPARE
  reg[35:0] rreg_Spare_13;
  //0x0034  SPARE
  reg[35:0] rreg_Spare_12;
  //0x0035  SPARE
  reg[35:0] rreg_Spare_11;
  //0x0036  SPARE
  reg[35:0] rreg_Spare_10;
  //0x0037  SPARE
  reg[35:0] rreg_Spare_09;
  //0x0038  SPARE
  reg[35:0] rreg_Spare_08;
  //0x0039  SPARE
  reg[35:0] rreg_Spare_07;
  //0x003A  SPARE
  reg[35:0] rreg_Spare_06;
  //0x003B  SPARE
  reg[35:0] rreg_Spare_05;
  //0x003C  SPARE
  reg[35:0] rreg_Spare_04;
  //0x003D  SPARE
  reg[35:0] rreg_Spare_03;
  //0x003E  SPARE
  reg[35:0] rreg_Spare_02;
  //0x003F  SPARE
  reg[35:0] rreg_hc_reg; 
  //0x0060  GPRW
  reg[35:0] rreg_GPRW_60;
  //0x0061  GPRW
  reg[35:0] rreg_GPRW_61;
  //0x0062  GPRW
  reg[35:0] rreg_GPRW_62;
  //0x0063  GPRW
  reg[35:0] rreg_GPRW_63;
  //0x0064  GPRW
  reg[35:0] rreg_GPRW_64;
  //0x0065  GPRW
  reg[35:0] rreg_GPRW_65;
  //////////// End of registers map ///////
  
	reg         wr_strb_Z1;    
   
	reg [35:0]  reg_selected;  
	
	/////////// For SD Card ////////////////////////// 
	// send the sdc initialization procedure manually.
	reg				man_init_sdc_strb;
	// test cmd strb from host (ie, CMD8)
	reg				host_tst_cmd_strb;
	reg				wr_reg_man;				// indicates wr command from puc
	wire				wr_reg_man_fin;		// turn off the wr_reg_man latch
	reg				data_in_strb;
	reg				last_set_of_data_strb;
	reg 	[35:0]	sd_data; 
	//reg 	[11:0]	rd_reg_indx_puc; 		// rd reg. from host controller.
	wire	[35:0]	rd_reg_output_puc; 	// map register output from host controller
	wire				sdc_dat_rdy;			// sdc host controller register data ready
	reg				sdc_dat_rdy_z1;		// delay
	reg				sdc_dat_rdy_z2;		// delay
	reg            puc_data_strb_z1;
	reg            puc_data_strb_z2;
	reg            puc_data_strb_z3;
	wire				strt_fifo_strb;    	// ready to start fifo transfer to sd card.
	reg            strt_fifo_strb_z1; 	// delay
	reg            strt_fifo_strb_z2; 	// delay
	reg            strt_fifo_strb_z3; 	// delay
	reg  [63:0]    time_stamp; 			// mo,dt,yr,hr,mn,sc
	reg  [63:0]    time_stamp_latch; 	// mo,dt,yr,hr,mn,sc
	reg  [63:0]    fifo_data;  			// data to be sent to fifo
	reg  [63:0]    puc_data_dts;  		// puc_data with dts embedded
	wire [11:0]    puc_data_index;  		// puc data index

	//////////// End of SD Card //////////////////////
  
	reg         	adc1_error;
	wire [2:0]  	adc1_num;
	wire [2:0]  	adc1_addr;
	wire        	adc1_smpl_strb;
	wire        	adc1_data_strb;
	wire [15:0] 	adc1_data;  
	wire        	adc1_busy_err;  
	
	wire        	seq_list_done_strb;
	wire [LS-1:0]	seq_list_en;  
  
	wire [72:0] 	wreg_sub_seq_cmd;
	reg         	wr_seq_strb;
	reg         	wr_seq_strb_Z1;
    
	wire [35:0] 	io_state;
	wire [35:0] 	alarm_state;
  
	wire [15:0] 	state_debug;
  
	wire [31:0]    rtc_01;
	wire [23:0]    rtc_02;
	wire           rtc_strb;
  
   initial			
	begin    
		wreg_ADC1_en                  <= 1'b0;                     
		wreg_RTC_meas                 <= 1'b0;           
                                          
		wreg_sub_seq_cmd_1            <= 36'b000000000;       
		wreg_sub_seq_cmd_2            <= 36'b000000000;       
		wr_seq_strb                   <= 1'b0;      
		wr_seq_strb_Z1                <= 1'b0;      
                                          
		wreg_netlist_address          <= {NL_ADDR_WD{1'b0}};      
		wreg_netlist_data             <= {36{1'b0}};      
		net_wr_strb                   <= 1'b0;      
                                          
		 wreg_NVM_01                  <= {30{1'b0}};                       
		 wreg_NVM_02                  <= {36{1'b0}};       
		 wreg_NVM_03                  <= {36{1'b0}};       
		 wreg_NVM_04                  <= {36{1'b0}};       
		 wreg_NVM_05                  <= {36{1'b0}};       
		 wreg_NVM_06                  <= {30{1'b0}};       
		                                    
		 wreg_COM_Cntrl               <= 2'b00;       
		                                    
		 wreg_RTC_01           	      <= {36{1'b0}};       
		 wreg_RTC_02           	      <= {24{1'b0}};       
		 wr_rtc_strb                  <= 1'b0;       
		                                    
		 wreg_hc_addr                 <= {36{1'b0}};       
		 wreg_sdc_hc_reg_man          <= {36{1'b0}};       
		 wreg_sdc_cmd                 <= {36{1'b0}};       
		 wreg_Spare_46 			      <= {36{1'b0}};       
		 wreg_sdc_wr_addr             <= {36{1'b0}};       
		 wreg_sdc_rd_addr             <= {36{1'b0}};       
		 wreg_strt_data_tf_strb       <= 1'b0;       
		 wreg_tf_mode                 <= {36{1'b0}};                  
		 wreg_cmd_indx                <= {6{1'b0}};       
		 wreg_Spare_38                <= {36{1'b0}};       
		 wreg_Spare_37                <= {36{1'b0}};       
		 wreg_Spare_36                <= {36{1'b0}};       
		 wreg_Spare_35                <= {36{1'b0}};       
		 wreg_Spare_34                <= {36{1'b0}};       
		 wreg_Spare_33                <= {36{1'b0}};       
		 wreg_Spare_32                <= {36{1'b0}};       
		 wreg_Spare_31                <= {36{1'b0}};       
		 wreg_Spare_30                <= {36{1'b0}};       
		 wreg_Spare_29                <= {36{1'b0}};       
		 wreg_Spare_28                <= {36{1'b0}};       
		 wreg_Spare_27                <= {36{1'b0}};       
		 wreg_Spare_26                <= {36{1'b0}};       
		 wreg_Spare_25                <= {36{1'b0}};       
		 wreg_Spare_24                <= {36{1'b0}};       
		 wreg_Spare_23                <= {36{1'b0}};       
		 wreg_Spare_22                <= {36{1'b0}};       
		 wreg_Spare_21                <= {36{1'b0}};       
		 wreg_Spare_20                <= {36{1'b0}};       
		 wreg_Spare_19                <= {36{1'b0}};       
		 wreg_Spare_18                <= {36{1'b0}};       
		 wreg_Spare_17                <= {36{1'b0}};       
		 wreg_Spare_16                <= {36{1'b0}};       
		 wreg_Spare_15                <= {36{1'b0}};       
		 wreg_Spare_12                <= {36{1'b0}};       
		 wreg_Spare_11                <= {36{1'b0}};       
		 wreg_Spare_10                <= {36{1'b0}};       
		 wreg_Spare_09                <= {36{1'b0}};       
		 wreg_Spare_08                <= {36{1'b0}};       
		 wreg_Spare_07                <= {36{1'b0}};       
		 wreg_Spare_06                <= {36{1'b0}};       
		 wreg_Spare_05                <= {36{1'b0}};       
		 wreg_Spare_04                <= {36{1'b0}};       
		 wreg_Spare_03                <= {36{1'b0}};       
		 wreg_Spare_02                <= {36{1'b0}};       
		 wreg_hc_reg           	      <= {36{1'b0}};       
       wreg_GPRW_60                 <= {36{1'b0}};       
       wreg_GPRW_61                 <= {36{1'b0}};       
       wreg_GPRW_62                 <= {36{1'b0}};       
       wreg_GPRW_63                 <= {36{1'b0}};       
       wreg_GPRW_64                 <= {36{1'b0}};       
       wreg_GPRW_65                 <= {36{1'b0}};       
			                                 
		 rreg_ADC1_NOMUX_CH0          <= {16{1'b0}};        
		 rreg_ADC1_NOMUX_CH1          <= {16{1'b0}};       
		 rreg_ADC1_NOMUX_CH2          <= {16{1'b0}};       
		 rreg_ADC1_NOMUX_CH3          <= {16{1'b0}};       
		 rreg_ADC1_NOMUX_CH4          <= {16{1'b0}};       
		 rreg_ADC1_NOMUX_CH5          <= {16{1'b0}};       
		 rreg_ADC1_NOMUX_CH6          <= {16{1'b0}};       
		 rreg_ADC1_NOMUX_CH7          <= {16{1'b0}};       
		                                    
		 rreg_NVM_01                  <= {30{1'b0}};               
		 rreg_NVM_02                  <= {36{1'b0}};       
		 rreg_NVM_03                  <= {36{1'b0}};       
		 rreg_NVM_04                  <= {36{1'b0}};       
		 rreg_NVM_05                  <= {36{1'b0}};       
		 rreg_NVM_06                  <= {30{1'b0}};       
		                                    
		 rreg_RTC_01	               <= {32{1'b0}};       
		 rreg_RTC_02   	            <= {24{1'b0}};       
		                                    
		 strt_fifo_strb_z1            <= 1'b0;        
		 strt_fifo_strb_z2            <= 1'b0;        
		 strt_fifo_strb_z3            <= 1'b0;        
		 time_stamp    	            <= {64{1'b0}};  
		 time_stamp_latch	            <= {64{1'b0}};       
		 fifo_data      	            <= {64{1'b0}};       
			  
		 rreg_Spare_48                <= {36{1'b0}};
		 rreg_hc_addr                 <= {36{1'b0}};
		 rreg_sdc_hc_reg_man       	<= {36{1'b0}};
		 rreg_sdc_cmd           		<= {36{1'b0}};
		 rreg_sdc_blk_size          	<= {36{1'b0}};
		 rreg_auto_data           	   <= {36{1'b0}};
		 rreg_auto_addr           		<= {36{1'b0}};
		 rreg_sdc_trans_mde           <= {36{1'b0}};
		 rreg_sdc_command           	<= {36{1'b0}};
		 rreg_sdc_resp           		<= {36{1'b0}};
		 rreg_sdc_pres_ste           	<= {36{1'b0}};
		 rreg_sdc_clk_cntrl           <= {36{1'b0}};
		 rreg_sdc_norm_int_stat       <= {36{1'b0}};
		 rreg_sdc_err_int_stat        <= {36{1'b0}};
		 rreg_sdc_norm_int_stat_enb	<= {36{1'b0}};
		 rreg_sdc_err_int_stat_enb    <= {36{1'b0}};
		 rreg_sdc_norm_int_sig_enb    <= {36{1'b0}};
		 rreg_sdc_err_int_sig_enb     <= {36{1'b0}};
		 rreg_sdc_adma_sys_addr       <= {36{1'b0}};
		 rreg_status                  <= {36{1'b0}};        
		 rreg_com_err                 <= {12{1'b0}};   
		 rreg_Spare_27                <= {36{1'b0}};
		 rreg_Spare_26                <= {36{1'b0}};
		 rreg_Spare_25                <= {36{1'b0}};
		 rreg_Spare_24                <= {36{1'b0}};
		 rreg_Spare_23                <= {36{1'b0}};
		 rreg_Spare_22                <= {36{1'b0}};
		 rreg_Spare_21                <= {36{1'b0}};
		 rreg_Spare_20                <= {36{1'b0}};
		 rreg_Spare_19                <= {36{1'b0}};
		 rreg_Spare_18                <= {36{1'b0}};
		 rreg_Spare_17                <= {36{1'b0}};
		 rreg_Spare_16                <= {36{1'b0}};
		 rreg_Spare_15                <= {36{1'b0}};
		 rreg_Spare_14                <= {36{1'b0}};
		 rreg_Spare_13                <= {36{1'b0}};
		 rreg_Spare_12                <= {36{1'b0}};
		 rreg_Spare_11                <= {36{1'b0}};
		 rreg_Spare_10                <= {36{1'b0}};
		 rreg_Spare_09                <= {36{1'b0}};
		 rreg_Spare_08                <= {36{1'b0}};
		 rreg_Spare_07                <= {36{1'b0}};
		 rreg_Spare_06                <= {36{1'b0}};
		 rreg_Spare_05                <= {36{1'b0}};
		 rreg_Spare_04                <= {36{1'b0}};
		 rreg_Spare_03                <= {36{1'b0}};
		 rreg_Spare_02                <= {36{1'b0}};
		 rreg_hc_reg           	      <= {36{1'b0}};
       
       rreg_GPRW_60                 <= {36{1'b0}};
       rreg_GPRW_61                 <= {36{1'b0}};
       rreg_GPRW_62                 <= {36{1'b0}};
       rreg_GPRW_63                 <= {36{1'b0}};
       rreg_GPRW_64                 <= {36{1'b0}};
       rreg_GPRW_65                 <= {36{1'b0}};
		 
		 wr_strb_Z1                   <= 1'b0;
		 adc1_error                   <= 1'b0;
		 LogicAnalyzer                <= 16'h0000;
		 rd_data                      <= 36'h000000000;
		 rd_rdy_strb                  <= 1'b0;
		 
		 // For SD Card
		 man_init_sdc_strb		      <= 1'b0;
		 host_tst_cmd_strb		      <= 1'b0;
		 wr_reg_man					      <= 1'b0;
		 data_in_strb      		      <= 1'b0;
		 last_set_of_data_strb        <= 1'b0;
		 sd_data                      <= 36'h000000000;
		 sdc_dat_rdy_z1  			      <= 1'b0;    
		 sdc_dat_rdy_z2  			      <= 1'b0;    
		 puc_data_strb_z1			      <= 1'b0;    
		 puc_data_strb_z2			      <= 1'b0;    
		 puc_data_strb_z3			      <= 1'b0;    
	 //////////////////////////////////////
	end   
  
  //Delayed write strobe by 1 clock
  always@(posedge clk)
  begin
    if (reset) begin    
      wr_strb_Z1 <= 1'b0;
	 end
    else begin
      wr_strb_Z1 <= wr_strb;
	 end
  end
  
	// Create delays
	always@(posedge clk)
	begin
		if (reset) begin    
			sdc_dat_rdy_z1	      <= 1'b0;
			sdc_dat_rdy_z2	      <= 1'b0;
	      strt_fifo_strb_z1    <= 1'b0; 
	      strt_fifo_strb_z2    <= 1'b0; 
	      strt_fifo_strb_z3    <= 1'b0;  
	      puc_data_strb_z1     <= 1'b0; 
	      puc_data_strb_z2     <= 1'b0; 
	      puc_data_strb_z3     <= 1'b0;
		end
		else begin
			sdc_dat_rdy_z1	     <= sdc_dat_rdy;
			sdc_dat_rdy_z2	     <= sdc_dat_rdy_z1;
			strt_fifo_strb_z1	  <= strt_fifo_strb;
			strt_fifo_strb_z2	  <= strt_fifo_strb_z1; 
			strt_fifo_strb_z3	  <= strt_fifo_strb_z2; 
	      puc_data_strb_z1    <= puc_data_strb; 
	      puc_data_strb_z2    <= puc_data_strb_z1;
	      puc_data_strb_z3    <= puc_data_strb_z2;
		end
	end
     
//--------------------------------------------------------
// WRITE REGISTERS
  
  //ZERO IS RESERVED OR SPARE
  
  // Write to wreg_DSM_en
  always@(posedge clk)
	begin
    if (reset) begin
      wreg_ADC1_en <= 1'b0;
      wreg_RTC_meas <= 1'b0;
    end else if (wr_addr == 6'h01 && wr_strb) begin  
      wreg_ADC1_en  <= wr_data[1];             
      wreg_RTC_meas <= wr_data[3];            
    end
  end  

  //SEE SEQUENCE CONTROLLER BELOW FOR 0x02 and 0x03
  
  // Write to wreg_netlist_address
  always@(posedge clk)
	begin
    if (reset)
      wreg_netlist_address <= {36{1'b0}};
    else if (wr_addr == 6'h06 && wr_strb)
      wreg_netlist_address <= wr_data[NL_ADDR_WD-1:0];
  end   
  
  // Write to wreg_netlist_address
  always@(posedge clk)
	begin
    if (reset)
      wreg_netlist_data <= {36{1'b0}};
    else if (wr_addr == 6'h07 && wr_strb)
      wreg_netlist_data <= wr_data[35:0];      
  end     
  
  // Write to wreg_netlist_address
  always@(posedge clk)
	begin
    if (reset)
      net_wr_strb <= 1'b0;
    else if (wr_addr == 6'h07 && wr_strb)
      net_wr_strb <= 1'b1;
    else
      net_wr_strb <= 1'b0;
  end     

  assign net_wr_addr = wreg_netlist_address;
  assign net_wr_data = wreg_netlist_data;

  // Write to wreg_NVM_01
  always@(posedge clk)
	begin
    if (reset)
      wreg_NVM_01 <= 36'h000000000;
    else if (wr_addr == 6'h08 && wr_strb)
      wreg_NVM_01 <= wr_data[35:0];      
  end

  // Write to wreg_NVM_02
  always@(posedge clk)
	begin
    if (reset)
      wreg_NVM_02 <= 30'h00000000;
    else if (wr_addr == 6'h09 && wr_strb)
      wreg_NVM_02 <= wr_data[35:0];      
  end
  
  // Write to wreg_NVM_03
  always@(posedge clk)
	begin
    if (reset)
      wreg_NVM_03 <= 36'h000000000;
    else if (wr_addr == 6'h0A && wr_strb)
      wreg_NVM_03 <= wr_data[35:0];      
  end 
  
  // Write to wreg_NVM_04
  always@(posedge clk)
	begin
    if (reset)
      wreg_NVM_04 <= 36'h000000000;
    else if (wr_addr == 6'h0B && wr_strb)
      wreg_NVM_04 <= wr_data[35:0];      
  end 
  
  // Write to wreg_NVM_05
  always@(posedge clk)
	begin
    if (reset)
      wreg_NVM_05 <= 36'h000000000;
    else if (wr_addr == 6'h0C && wr_strb)
      wreg_NVM_05 <= wr_data[35:0];      
  end  
      
  // Write to wreg_NVM_06
  always@(posedge clk)
	begin
    if (reset)
      wreg_NVM_06 <= 36'h000000000;
    else if (wr_addr == 6'h0D && wr_strb)
      wreg_NVM_06 <= wr_data[35:0];      
  end 
  
  // Write to wreg_COM_Flag
  always@(posedge clk)
	begin
    if (reset)
      wreg_COM_Cntrl <= 2'b00;
    else if (wr_addr == 6'h0E && wr_strb)
      wreg_COM_Cntrl <= wr_data[1:0];      
  end  
  // Write to wreg_RTC_01
  always@(posedge clk)
	begin
    if (reset)
      wreg_RTC_01 <= 36'h000000000;
    else if (wr_addr == 8'h0F && wr_strb)
      wreg_RTC_01 <= wr_data[35:0];      
  end 

  // Write to wreg_RTC_02
  always@(posedge clk)
	begin
    if (reset)
      wreg_RTC_02 <= 24'h000000;
    else if (wr_addr == 8'h10 && wr_strb)
      wreg_RTC_02 <= wr_data[23:0];      
  end 
  
  // Execute strobe to write to RTC.
  // We'll send out wreg_RTC_01 and wreg_RTC_02
  // when we write wreg_RTC_02.
  always@(posedge clk)
	begin
    if (reset)
      wr_rtc_strb <= 1'b0;
    else if ((wr_addr == 8'h10 && wr_strb))
      wr_rtc_strb <= 1'b1;
    else
      wr_rtc_strb <= 1'b0;
  end 

  // Write to wreg_sdc_cmd
  always@(posedge clk)
	begin
    if (reset)
      wreg_sdc_cmd <= 36'h000000000;
    //else if (wr_addr == 8'h11 && wr_strb)
    else if (wr_addr == 6'h11 && wr_strb)
		// Command Register data (00Eh)
      wreg_sdc_cmd <= wr_data[35:0];
    else 
      wreg_sdc_cmd <= wreg_sdc_cmd;      
  end 

	// Create the host_tst_cmd_strb when we get a 
	// write from the TEST comm. port. 
	always@(posedge clk)
	begin
		if (reset)
			host_tst_cmd_strb <= 1'b0;
		else if (wr_addr == 6'h11 && wr_strb)
			host_tst_cmd_strb <= 1'b1;
		else
			host_tst_cmd_strb <= 1'b0;      
	end

  // Write to wreg_Spare_46
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_46 <= 36'h000000000;
    else if (wr_addr == 6'h12 && wr_strb)
      wreg_Spare_46 <= wr_data[35:0];      
  end    
  
  // Write to wreg_hc_addr
  // Write in the host controller address
  // you want to read.
  always@(posedge clk)
	begin
    if (reset)
      wreg_hc_addr <= 36'h000000000;
    else if (wr_addr == 6'h13 && wr_strb)
      wreg_hc_addr <= wr_data[35:0];      
  end 

  // Write to wreg_sdc_hc_reg_man
  // Write to host controller reg. map manually.
  always@(posedge clk)
	begin
    if (reset)
      wreg_sdc_hc_reg_man <= 36'h000000000;
    else if (wr_addr == 6'h14 && wr_strb)
      wreg_sdc_hc_reg_man <= wr_data[35:0]; // from labview
    else 
      wreg_sdc_hc_reg_man <= wreg_sdc_hc_reg_man;      
  end 
  
  // Write to wreg_hc_reg.
  // Write manually to sdc host controller.
  always@(posedge clk)
	begin
    if (reset)
      wreg_hc_reg <= 36'h000000000;
    else if (wr_addr == 6'h3F && wr_strb)
      wreg_hc_reg <= wr_data[35:0];
    else
      wreg_hc_reg <= wreg_hc_reg;      
  end 

   // Write to wreg_sdc_wr_addr
  // SD card address to write to.
  always@(posedge clk)
	begin
    if (reset)
      wreg_sdc_wr_addr <= 36'h000000000;
    else if (wr_addr == 6'h15 && wr_strb)
      wreg_sdc_wr_addr <= wr_data[35:0];      
  end 

  // Write to wreg_sdc_rd_addr
  // SD card address to read from.
  always@(posedge clk)
	begin
    if (reset)
      wreg_sdc_rd_addr <= 36'h000000000;
    else if (wr_addr == 6'h16 && wr_strb)
      wreg_sdc_rd_addr <= wr_data[35:0];      
  end 

   // Write to wreg_strt_data_tf_strb
   // When you strobe wreg_strt_data_tf_strb the command
   // 0x000001800 will be generated automatically.  You
   // don't have to generate the command manually.  You
   // just have to generate the wreg_strt_data_tf_strb strobe.    
   // Command 0x000001800 write one sector to the sd card.
   // Write to wreg_strt_data_tf_strb
   always@(posedge clk)
      begin
         if (reset)
            wreg_strt_data_tf_strb <= 1'b0;
         else if (wr_addr == 6'h17 && wr_strb)
            wreg_strt_data_tf_strb <= 1'b1; 
         else
            wreg_strt_data_tf_strb <= 1'b0;     
      end 
		
	//assign cs_test_vector[0] = wreg_strt_data_tf_strb;  

  // Write to wreg_tf_mode
  always@(posedge clk)
	begin
    if (reset)
      wreg_tf_mode <= 36'h000000000;
    else if (wr_addr == 6'h18 && wr_strb)
      wreg_tf_mode <= wr_data[35:0];      
  end   

  // Write to wreg_cmd_indx
  always@(posedge clk)
	begin
    if (reset)
      wreg_cmd_indx <= 6'h00;
    else if (wr_addr == 6'h19 && wr_strb)
      wreg_cmd_indx <= wr_data[5:0];      
  end   

  // Write to wreg_Spare_38
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_38 <= 36'h000000000;
    else if (wr_addr == 6'h1A && wr_strb)
      wreg_Spare_38 <= wr_data[35:0];      
  end   

  // Write to wreg_Spare_37
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_37 <= 36'h000000000;
    else if (wr_addr == 6'h1B && wr_strb)
      wreg_Spare_37 <= wr_data[35:0];      
  end   

  // Write to wreg_Spare_36
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_36 <= 36'h000000000;
    else if (wr_addr == 6'h1C && wr_strb)
      wreg_Spare_36 <= wr_data[35:0];      
  end   

  // Write to wreg_Spare_35
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_35 <= 36'h000000000;
    else if (wr_addr == 6'h1D && wr_strb)
      wreg_Spare_35 <= wr_data[35:0];      
  end   

  // Write to wreg_Spare_34
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_34 <= 36'h000000000;
    else if (wr_addr == 6'h1E && wr_strb)
      wreg_Spare_34 <= wr_data[35:0];      
  end   

  // Write to wreg_Spare_33
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_33 <= 36'h000000000;
    else if (wr_addr == 6'h1F && wr_strb)
      wreg_Spare_33 <= wr_data[35:0];      
  end   

  // Write to wreg_Spare_32
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_32 <= 36'h000000000;
    else if (wr_addr == 6'h20 && wr_strb)
      wreg_Spare_32 <= wr_data[35:0];      
  end   

  // Write to wreg_Spare_31
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_31 <= 36'h000000000;
    else if (wr_addr == 6'h21 && wr_strb)
      wreg_Spare_31 <= wr_data[35:0];      
  end   

  // Write to wreg_Spare_30
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_30 <= 36'h000000000;
    else if (wr_addr == 6'h22 && wr_strb)
      wreg_Spare_30 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_29
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_29 <= 36'h000000000;
    else if (wr_addr == 6'h23 && wr_strb)
      wreg_Spare_29 <= wr_data[35:0];      
  end         
  
  // Write to wreg_Spare_28
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_28 <= 36'h000000000;
    else if (wr_addr == 6'h24 && wr_strb)
      wreg_Spare_28 <= wr_data[35:0];      
  end       
  
  // Write to wreg_Spare_27
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_27 <= 36'h000000000;
    else if (wr_addr == 6'h25 && wr_strb)
      wreg_Spare_27 <= wr_data[35:0];      
  end       
  
  // Write to wreg_Spare_26
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_26 <= 36'h000000000;
    else if (wr_addr == 6'h26 && wr_strb)
      wreg_Spare_26 <= wr_data[35:0];      
  end     

  // Write to wreg_Spare_25
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_25 <= 36'h000000000;
    else if (wr_addr == 6'h27 && wr_strb)
      wreg_Spare_25 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_24
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_24 <= 36'h000000000;
    else if (wr_addr == 6'h28 && wr_strb)
      wreg_Spare_24 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_23
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_23 <= 36'h000000000;
    else if (wr_addr == 6'h29 && wr_strb)
      wreg_Spare_23 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_22
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_22 <= 36'h000000000;
    else if (wr_addr == 6'h2A && wr_strb)
      wreg_Spare_22 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_21
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_21 <= 36'h000000000;
    else if (wr_addr == 6'h2B && wr_strb)
      wreg_Spare_21 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_20
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_20 <= 36'h000000000;
    else if (wr_addr == 6'h2C && wr_strb)
      wreg_Spare_20 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_19
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_19 <= 36'h000000000;
    else if (wr_addr == 6'h2D && wr_strb)
      wreg_Spare_19 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_18
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_18 <= 36'h000000000;
    else if (wr_addr == 6'h2E && wr_strb)
      wreg_Spare_18 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_17
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_17 <= 36'h000000000;
    else if (wr_addr == 6'h2F && wr_strb)
      wreg_Spare_17 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_16
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_16 <= 36'h000000000;
    else if (wr_addr == 6'h30 && wr_strb)
      wreg_Spare_16 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_15
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_15 <= 36'h000000000;
    else if (wr_addr == 6'h31 && wr_strb)
      wreg_Spare_15 <= wr_data[35:0];      
  end     
    
  // Write to wreg_Spare_12
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_12 <= 36'h000000000;
    else if (wr_addr == 6'h34 && wr_strb)
      wreg_Spare_12 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_11
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_11 <= 36'h000000000;
    else if (wr_addr == 6'h35 && wr_strb)
      wreg_Spare_11 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_10
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_10 <= 36'h000000000;
    else if (wr_addr == 6'h36 && wr_strb)
      wreg_Spare_10 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_09
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_09 <= 36'h000000000;
    else if (wr_addr == 6'h37 && wr_strb)
      wreg_Spare_09 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_08
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_08 <= 36'h000000000;
    else if (wr_addr == 6'h38 && wr_strb)
      wreg_Spare_08 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_07
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_07 <= 36'h000000000;
    else if (wr_addr == 6'h39 && wr_strb)
      wreg_Spare_07 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_06
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_06 <= 36'h000000000;
    else if (wr_addr == 6'h3A && wr_strb)
      wreg_Spare_06 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_05
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_05 <= 36'h000000000;
    else if (wr_addr == 6'h3B && wr_strb)
      wreg_Spare_05 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_04
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_04 <= 36'h000000000;
    else if (wr_addr == 6'h3C && wr_strb)
      wreg_Spare_04 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_03
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_03 <= 36'h000000000;
    else if (wr_addr == 6'h3D && wr_strb)
      wreg_Spare_03 <= wr_data[35:0];      
  end     
  
  // Write to wreg_Spare_02
  always@(posedge clk)
	begin
    if (reset)
      wreg_Spare_02 <= 36'h000000000;
    else if (wr_addr == 6'h3E && wr_strb)
      wreg_Spare_02 <= wr_data[35:0];      
  end     
  
  
// END WRITE REGISTERS  
//--------------------------------------------------------  
  
  
//--------------------------------------------------------  
// READ REGISTERS      


  //Mux registers based on read address.
  always@(rd_addr[5:0],
    rreg_ADC1_NOMUX_CH0,rreg_ADC1_NOMUX_CH1,
    rreg_ADC1_NOMUX_CH2,rreg_ADC1_NOMUX_CH3,
    rreg_ADC1_NOMUX_CH4,rreg_ADC1_NOMUX_CH5,
    rreg_ADC1_NOMUX_CH6,rreg_ADC1_NOMUX_CH7,
    rreg_NVM_01,rreg_NVM_02,rreg_NVM_03,
    rreg_NVM_04,rreg_NVM_05,rreg_NVM_06,
	 rreg_RTC_01,rreg_RTC_02,
    rreg_Spare_48,rreg_hc_addr,rreg_sdc_hc_reg_man,rreg_sdc_cmd,
    rreg_sdc_blk_size,rreg_auto_data,rreg_auto_addr,rreg_sdc_trans_mde,
    rreg_sdc_command,rreg_sdc_resp,rreg_sdc_pres_ste,rreg_sdc_clk_cntrl,
    rreg_sdc_norm_int_stat,rreg_sdc_err_int_stat,rreg_sdc_norm_int_stat_enb,
	 rreg_sdc_err_int_stat_enb,rreg_sdc_norm_int_sig_enb,
	 rreg_sdc_err_int_sig_enb,rreg_sdc_adma_sys_addr,/*rreg_Spare_29,*/    
    rreg_status, rreg_com_err,
    /*rreg_Spare_28,*/rreg_Spare_27,rreg_Spare_26,rreg_Spare_25,
    rreg_Spare_24,rreg_Spare_23,rreg_Spare_22,rreg_Spare_21,
    rreg_Spare_20,rreg_Spare_19,rreg_Spare_18,rreg_Spare_17,
    rreg_Spare_16,rreg_Spare_15,rreg_Spare_14,rreg_Spare_13,
    rreg_Spare_12,rreg_Spare_11,rreg_Spare_10,rreg_Spare_09,
    rreg_Spare_08,rreg_Spare_07,rreg_Spare_06,rreg_Spare_05,
    rreg_Spare_04,rreg_Spare_03,rreg_Spare_02,rreg_hc_reg,rreg_GPRW_60,
    rreg_GPRW_61,rreg_GPRW_62,rreg_GPRW_63,rreg_GPRW_64,rreg_GPRW_65)
  begin
    case (rd_addr[5:0])
      6'h00   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH0};
      6'h01   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH1};
      6'h02   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH2};
      6'h03   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH3};
      6'h04   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH4};
      6'h05   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH5};
      6'h06   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH6};
      6'h07   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH7};
      6'h08   : reg_selected <= rreg_NVM_01;
      6'h09   : reg_selected <= rreg_NVM_02;
      6'h0A   : reg_selected <= rreg_NVM_03;
      6'h0B   : reg_selected <= rreg_NVM_04;
      6'h0C   : reg_selected <= rreg_NVM_05;
      6'h0D   : reg_selected <= rreg_NVM_06;
      6'h0E   : reg_selected <= rreg_Spare_48;
      6'h0F   : reg_selected <= {4'h0,rreg_RTC_01};
      6'h10   : reg_selected <= {12'h000,rreg_RTC_02};
      6'h11   : reg_selected <= rreg_sdc_cmd;
      6'h12   : reg_selected <= rreg_sdc_blk_size;
      6'h13   : reg_selected <= rreg_auto_data;
      6'h14   : reg_selected <= rreg_auto_addr;
      6'h15   : reg_selected <= rreg_sdc_trans_mde;
      6'h16   : reg_selected <= rreg_sdc_command;
      6'h17   : reg_selected <= rreg_sdc_resp;
      6'h18   : reg_selected <= rreg_sdc_pres_ste;
      6'h19   : reg_selected <= rreg_sdc_clk_cntrl;
      6'h1A   : reg_selected <= rreg_sdc_norm_int_stat;
      6'h1B   : reg_selected <= rreg_sdc_err_int_stat;
      6'h1C   : reg_selected <= rreg_sdc_norm_int_stat_enb;
      6'h1D   : reg_selected <= rreg_sdc_err_int_stat_enb;
      6'h1E   : reg_selected <= rreg_sdc_norm_int_sig_enb;
      6'h1F   : reg_selected <= rreg_sdc_err_int_sig_enb;
      6'h20   : reg_selected <= rreg_sdc_adma_sys_addr;
      6'h21   : reg_selected <= rreg_hc_addr;//rreg_Spare_29;
      6'h22   : reg_selected <= rreg_sdc_hc_reg_man;//rreg_Spare_28;
      6'h23   : reg_selected <= rreg_status;
      6'h24   : reg_selected <= {24'h000000,rreg_com_err};
      6'h25   : reg_selected <= rreg_Spare_27;
      6'h26   : reg_selected <= rreg_Spare_26;
      6'h27   : reg_selected <= rreg_Spare_25;
      6'h28   : reg_selected <= rreg_Spare_24;
      6'h29   : reg_selected <= rreg_Spare_23;
      6'h2A   : reg_selected <= rreg_Spare_22;
      6'h2B   : reg_selected <= rreg_Spare_21;
      6'h2C   : reg_selected <= rreg_Spare_20;
      6'h2D   : reg_selected <= rreg_Spare_19;
      6'h2E   : reg_selected <= rreg_Spare_18;
      6'h2F   : reg_selected <= rreg_Spare_17;
      6'h30   : reg_selected <= rreg_Spare_16;
      6'h31   : reg_selected <= rreg_Spare_15;
      6'h32   : reg_selected <= rreg_Spare_14;
      6'h33   : reg_selected <= rreg_Spare_13;
      6'h34   : reg_selected <= rreg_Spare_12;
      6'h35   : reg_selected <= rreg_Spare_11;
      6'h36   : reg_selected <= rreg_Spare_10;
      6'h37   : reg_selected <= rreg_Spare_09;
      6'h38   : reg_selected <= rreg_Spare_08;
      6'h39   : reg_selected <= rreg_Spare_07;
      6'h3A   : reg_selected <= rreg_Spare_06;
      6'h3B   : reg_selected <= rreg_Spare_05;
      6'h3C   : reg_selected <= rreg_Spare_04;
      6'h3D   : reg_selected <= rreg_Spare_03;
      6'h3E   : reg_selected <= rreg_Spare_02;
      6'h3F   : reg_selected <= rreg_hc_reg;
      6'h60   : reg_selected <= rreg_GPRW_60;
      6'h61   : reg_selected <= rreg_GPRW_61;
      6'h62   : reg_selected <= rreg_GPRW_62;
      6'h63   : reg_selected <= rreg_GPRW_63;
      6'h64   : reg_selected <= rreg_GPRW_64;
      6'h65   : reg_selected <= rreg_GPRW_65;
      default : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH0};
    endcase
  end
  
	// Gate the selected register
	// Could edit to capture the sd card registers
	// after a few clocks.  rd_strb only determines
	// which sd card register to read.  It will
	// take a few clocks later to get the data back.
	// Don't forget rd_rdy_strb also.
	always@(posedge clk)
	begin
		if (reset)
			rd_data <= 36'h000000000;
			// if rd_addr is between h10 and h20 wait
			// a few clocks before reading the data.	
		else if (sdc_dat_rdy && ((rd_addr >= 6'h10) || (rd_addr <= 6'h20)))
			rd_data <= reg_selected;   // read again after condition is true    	
		else if (rd_strb)
			rd_data <= reg_selected;      
	end   										 
	
	//-------------------------------------------------------------------------
	// We need to wait a few clocks before we can return data from the
	// sd card controller.
	//-------------------------------------------------------------------------
	defparam waitForSdcCntr.dw 	= 4;
	defparam waitForSdcCntr.max	= 4'hA;	
	//-------------------------------------------------------------------------
	CounterSeq waitForSdcCntr(
		.clk(clk),  
		.reset(reset),	
		.enable(1'b1), 					 
		// we'll start this counter everytime
		// we get a rd_strb.
		.start_strb(rd_strb),   	 	
		.cntr(), 
		.strb(sdc_dat_rdy) 
	);  
  
  //rreg_ADC1_NOMUX_CH0
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_NOMUX_CH0 <= 16'h0000;
    else if (adc1_num[2:0] == 3'b000 && adc1_data_strb)
      rreg_ADC1_NOMUX_CH0 <= adc1_data;
  end  
  
  //rreg_ADC1_NOMUX_CH1
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_NOMUX_CH1 <= 16'h0000;
    else if (adc1_num[2:0] == 3'b001 && adc1_data_strb)
      rreg_ADC1_NOMUX_CH1 <= adc1_data;
  end 

  //rreg_ADC1_NOMUX_CH2
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_NOMUX_CH2 <= 16'h0000;
    else if (adc1_num[2:0] == 3'b010 && adc1_data_strb)
      rreg_ADC1_NOMUX_CH2 <= adc1_data;
  end 

  //rreg_ADC1_NOMUX_CH3
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_NOMUX_CH3 <= 16'h0000;
    else if (adc1_num[2:0] == 3'b011 && adc1_data_strb)
      rreg_ADC1_NOMUX_CH3 <= adc1_data;
  end 

  //rreg_ADC1_NOMUX_CH4
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_NOMUX_CH4 <= 16'h0000;
    else if (adc1_num[2:0] == 3'b100 && adc1_data_strb)
      rreg_ADC1_NOMUX_CH4 <= adc1_data;
  end 

  //rreg_ADC1_NOMUX_CH5
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_NOMUX_CH5 <= 16'h0000;
    else if (adc1_num[2:0] == 3'b101 && adc1_data_strb)
      rreg_ADC1_NOMUX_CH5 <= adc1_data;
  end 

  //rreg_ADC1_NOMUX_CH6
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_NOMUX_CH6 <= 16'h0000;
    else if (adc1_num[2:0] == 3'b110 && adc1_data_strb)
      rreg_ADC1_NOMUX_CH6 <= adc1_data;
  end 
  
  //rreg_ADC1_NOMUX_CH5
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_NOMUX_CH7 <= 16'h0000;
    else if (adc1_num[2:0] == 3'b111 && adc1_data_strb)
      rreg_ADC1_NOMUX_CH7 <= adc1_data;
  end   

  //-----------------------------------------------
  //STATUS REGISTER - MULTI BIT SET
  //
      //rreg_status bit 0 = comm_err[0]
      always@(posedge clk)
      begin
        if (reset || wr_strb_Z1)
          rreg_status[0] <= 1'b0;
        else if (comm_err[0]) begin
          rreg_status[0] <= 1'b1;
        end
      end

      //rreg_status bit 1 = comm_err[1]
      always@(posedge clk)
      begin
        if (reset || wr_strb_Z1)
          rreg_status[1] <= 1'b0;
        else if (comm_err[1]) begin
          rreg_status[1] <= 1'b1;
        end
      end
      
      //rreg_status bit 2 = comm_err[2]
      always@(posedge clk)
      begin
        if (reset || wr_strb_Z1)
          rreg_status[2] <= 1'b0;
        else if (comm_err[2]) begin
          rreg_status[2] <= 1'b1;
        end
      end

      //rreg_status bit 3 = adc1_error
      always@(posedge clk)
      begin
        if (reset || wr_strb_Z1)
          rreg_status[3] <= 1'b0;
        else if (adc1_error) begin
          rreg_status[3] <= 1'b1;
        end
      end

      //rreg_status bit 5:4 = temp status
      always@(posedge clk)
      begin
        if (reset)
          rreg_status[15:4] <= 12'h000;
        else 
          rreg_status[15:4] <= {10'h000,UIC_CABLE_DET_N,SBC_CABLE_DET_N};
      end  
      
      //rreg_status - FPGA Version, cable detect
      always@(posedge clk)
      begin
        if (reset) begin
          rreg_status[35:16] <= 20'h00000;
        end else begin
          rreg_status[31:16] <= FPGA_VERSION;      
          rreg_status[35:32] <= 4'b0000;
        end
      end                     
//-----------------------------------------------      

  //rreg_NVM_01
  always@(posedge clk)
	begin
    if (reset)
      rreg_NVM_01 <= 36'h000000000;
    else 
      rreg_NVM_01 <= wreg_NVM_01;
  end

  //rreg_NVM_02
  always@(posedge clk)
	begin
    if (reset)
      rreg_NVM_02 <= 36'h000000000;
    else 
      rreg_NVM_02 <= wreg_NVM_02;
  end
  
  //rreg_NVM_03
  always@(posedge clk)
	begin
    if (reset)
      rreg_NVM_03 <= 36'h000000000;
    else 
      rreg_NVM_03 <= wreg_NVM_03;
  end
  
  //rreg_NVM_04
  always@(posedge clk)
	begin
    if (reset)
      rreg_NVM_04 <= 36'h000000000;
    else 
      rreg_NVM_04 <= wreg_NVM_04;
  end
  
  //rreg_NVM_05
  always@(posedge clk)
	begin
    if (reset)
      rreg_NVM_05 <= 36'h000000000;
    else 
      rreg_NVM_05 <= wreg_NVM_05;
  end
  
  //rreg_NVM_06
  always@(posedge clk)
	begin
    if (reset)
      rreg_NVM_06 <= 36'h000000000;
    else 
      rreg_NVM_06 <= wreg_NVM_06;
  end  

	//rreg_RTC_01
	always@(posedge clk)
	begin
		if (reset)
			rreg_RTC_01 <= 32'h00000000;
		else 
			rreg_RTC_01 <= rtc_01;
	end

	//rreg_RTC_02
	always@(posedge clk)
	begin
		if (reset)
			rreg_RTC_02 <= 24'h000000;
		else 
			rreg_RTC_02 <= rtc_02;
	end  

  //rreg_com_err
  always@(posedge clk)
	begin
    if (reset || wr_strb_Z1)
      rreg_com_err <= 12'h000;
    else if (comm_err != 12'h000)
      rreg_com_err <= comm_err;
  end  

   // Probe registers for sd card.
	// May not be able to catch these signals
	// because they are strobes.  They may happen
	// between 500 ms, that is why dpak may not be
	// able to catch them.
	// rreg_GPRW_60  Probe to see if wreg_strt_data_tf_strb is stuck.
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_GPRW_60 <= {36{1'b0}};
//		else 
//			rreg_GPRW_60 <= {{35{1'b0}},wreg_strt_data_tf_strb};
//	end  
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_GPRW_60 <= {36{1'b0}};
		else if (wreg_strt_data_tf_strb)
			rreg_GPRW_60 <= {{35{1'b0}},1'b1};
	end  
   
	// rreg_GPRW_61  Probe
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_GPRW_61 <= {36{1'b0}};
//		else 
//			rreg_GPRW_61 <= {{35{1'b0}},strt_fifo_strb};
//	end  
   
	always@(posedge clk)
	begin
		if (reset)
			rreg_GPRW_61 <= {36{1'b0}};
		else if (strt_fifo_strb) 
			rreg_GPRW_61 <= {{35{1'b0}},1'b1};
	end  
	
	// rreg_GPRW_62  Probe
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_GPRW_62 <= {36{1'b0}};
//		else 
//			rreg_GPRW_62 <= {{35{1'b0}},strt_fifo_strb_z2};
//	end  
	
	// rreg_GPRW_62  Probe
	always@(posedge clk)
	begin
		if (reset)
			rreg_GPRW_62 <= {36{1'b0}};
		else if (strt_fifo_strb_z2)
			rreg_GPRW_62 <= {{35{1'b0}},1'b1};
	end  
   
	// rreg_GPRW_63  Probe
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_GPRW_63 <= {36{1'b0}};
//		else 
//			rreg_GPRW_63 <= {{35{1'b0}},puc_data_strb_z2};
//	end  
   
	// rreg_GPRW_63  Probe
	always@(posedge clk)
	begin
		if (reset)
			rreg_GPRW_63 <= {36{1'b0}};
		else if (puc_data_strb_z2) 
			rreg_GPRW_63 <= {{35{1'b0}},1'b1};
	end  
   
	// rreg_GPRW_64  Probe
	always@(posedge clk)
	begin
		if (reset)
			rreg_GPRW_64 <= {36{1'b0}};
		else 
			rreg_GPRW_64 <= fifo_data[35:0];
	end  
   
	// rreg_GPRW_65  Probe
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_GPRW_65 <= {36{1'b0}};
//		else 
//			rreg_GPRW_65 <= {{35{1'b0}},rdy_for_nxt_pkt};
//	end  
   
	// rreg_GPRW_65  Probe
	always@(posedge clk)
	begin
		if (reset)
			rreg_GPRW_65 <= {36{1'b0}};
		else if (rdy_for_nxt_pkt) 
			rreg_GPRW_65 <= {{35{1'b0}},1'b1};
	end  

   // Probing registers for sd card ends.

  //General Purpose Read Write Registers
//  always@(posedge clk)
//  begin
//    if (reset) begin
//      rreg_GPRW_60  <= 36'h000000000;
//      rreg_GPRW_61  <= 36'h000000000;
//      rreg_GPRW_62  <= 36'h000000000;
//      rreg_GPRW_63  <= 36'h000000000;
//      rreg_GPRW_64  <= 36'h000000000;
//      rreg_GPRW_65  <= 36'h000000000;
//    end else begin
//      rreg_GPRW_60  <= {{35{1'b0}},wreg_strt_data_tf_strb};
//      rreg_GPRW_61  <= {{35{1'b0}},strt_fifo_strb};
//      rreg_GPRW_62  <= {{35{1'b0}},strt_fifo_strb_z2};
//      rreg_GPRW_63  <= {{35{1'b0}},puc_data_strb_z2};
//      rreg_GPRW_64  <= fifo_data[35:0];
//      rreg_GPRW_65  <= {{35{1'b0}},rdy_for_nxt_pkt};
//    end
//  end

  //Assign spare reads, spare writes
  always@(posedge clk)
	begin
    if (reset) begin
      rreg_Spare_48 <= 36'h000000000;
      //rreg_hc_addr <= 36'h000000000;
      //rreg_Spare_29 <= 36'h000000000;
      //rreg_Spare_28 <= 36'h000000000;
      rreg_Spare_27 <= 36'h000000000;
      rreg_Spare_26 <= 36'h000000000;
      rreg_Spare_25 <= 36'h000000000;
      rreg_Spare_24 <= 36'h000000000;
      rreg_Spare_23 <= 36'h000000000;
      rreg_Spare_22 <= 36'h000000000;
      rreg_Spare_21 <= 36'h000000000;
      rreg_Spare_20 <= 36'h000000000;
      rreg_Spare_19 <= 36'h000000000;
      rreg_Spare_18 <= 36'h000000000;
      rreg_Spare_17 <= 36'h000000000;
      rreg_Spare_16 <= 36'h000000000;
      rreg_Spare_15 <= 36'h000000000;
      rreg_Spare_14 <= 36'h000000000;
      rreg_Spare_13 <= 36'h000000000;
      rreg_Spare_12 <= 36'h000000000;
      rreg_Spare_11 <= 36'h000000000;
      rreg_Spare_10 <= 36'h000000000;
      rreg_Spare_09 <= 36'h000000000;
      rreg_Spare_08 <= 36'h000000000;
      rreg_Spare_07 <= 36'h000000000;
      rreg_Spare_06 <= 36'h000000000;
      rreg_Spare_05 <= 36'h000000000;
      rreg_Spare_04 <= 36'h000000000;
      rreg_Spare_03 <= 36'h000000000;
      rreg_Spare_02 <= 36'h000000000;
      //rreg_hc_reg <= 36'h000000000;
    end else if (wr_strb_Z1) begin
      rreg_Spare_48 <= 36'h000000000;
      //rreg_hc_addr <= 36'h000000000;
      //rreg_Spare_29 <= wreg_Spare_29;
      //rreg_Spare_28 <= wreg_Spare_28;
      rreg_Spare_27 <= wreg_Spare_27;
      rreg_Spare_26 <= wreg_Spare_26;
      rreg_Spare_25 <= wreg_Spare_25;
      rreg_Spare_24 <= wreg_Spare_24;
      rreg_Spare_23 <= wreg_Spare_23;
      rreg_Spare_22 <= wreg_Spare_22;
      rreg_Spare_21 <= wreg_Spare_21;
      rreg_Spare_20 <= wreg_Spare_20;
      rreg_Spare_19 <= wreg_Spare_19;
      rreg_Spare_18 <= wreg_Spare_18;
      rreg_Spare_17 <= wreg_Spare_17;
      rreg_Spare_16 <= wreg_Spare_16;
      rreg_Spare_15 <= wreg_Spare_15;
      rreg_Spare_14 <= io_state; //wreg_Spare_14;
      rreg_Spare_13 <= alarm_state; //wreg_Spare_13;
      rreg_Spare_12 <= wreg_Spare_12;
      rreg_Spare_11 <= wreg_Spare_11;
      rreg_Spare_10 <= wreg_Spare_10;
      rreg_Spare_09 <= wreg_Spare_09;
      rreg_Spare_08 <= wreg_Spare_08;
      rreg_Spare_07 <= wreg_Spare_07;
      rreg_Spare_06 <= wreg_Spare_06;
      rreg_Spare_05 <= wreg_Spare_05;
      rreg_Spare_04 <= wreg_Spare_04;
      rreg_Spare_03 <= wreg_Spare_03;
      rreg_Spare_02 <= wreg_Spare_02;
      //rreg_hc_reg <= wreg_hc_reg;
    end
  end
// END READ REGISTERS  
//--------------------------------------------------------    
     

//--------------------------------------------------------
// COM FLAG ASSIGNMENT
  assign COM_Cntrl = wreg_COM_Cntrl;
// END COM FLAG
//--------------------------------------------------------

//--------------------------------------------------------
// ADC SAMPLING SCHEDULE AND CONTROL

  
   defparam ADCSchedule_i.dw = 10;              
   defparam ADCSchedule_i.max = 10'h3E8; 
  ADCSchedule ADCSchedule_i
  (    
    .clk(clk),                  // System Clock 
    .reset(reset),              // System Reset
    .enable(wreg_ADC1_en),      // Enable 
    .next_strb(adc1_data_strb), // Strobe data sample complete
    .mux1_sel(),                // MUX 1 Select
    .mux2_sel(),                // MUX 2 Select
    .mux3_sel(),                // MUX 3 Select
    .mux4_sel(),                // MUX 4 Select
    .adc_ch(adc1_num),          // ADC Channel Number
    .adc_addr(adc1_addr),       // ADC Address
    .sample_strb(adc1_smpl_strb)// Strobe to Sample Data
  );

  //--------------------------------------------------------
  // ADC 1 INTERFACE
  ADC_ADS8344_S8 ADC1_Interface_i 
  (
    .clk(clk),                  // System Clock
    .reset(reset),              // System Reset (Syncronous) 
    .enable(wreg_ADC1_en),      // Enable system
    .smpl_strb(adc1_smpl_strb), // Strobe to take a sample
    .mux(adc1_addr),            // Channel Address
    .dout(ADC1_DOUT),           // Dout from ADC
    .busy(ADC1_BUSY),           // Busy from ADC
    .cs_n(ADC1_CS_N),           // Chip Select to ADC
    .dclk(ADC1_CLK),            // Dclk to ADC
    .din(ADC1_DIN),             // Din to ADC
    .data(adc1_data),           // Data sampled
    .data_strb(adc1_data_strb), // Data available strobe
    .cmplt_strb(),              // ADC sequence done
    .error(adc1_busy_err)       // Error from incorrect busy
  );

  //capture any ADC1 busy errors until a cleared by a write
  always@(posedge clk)
	begin
    if (reset)
      adc1_error <= 1'b0;
    else if (wr_strb)
      adc1_error <= 1'b0;  
    else if (adc1_busy_err)
      adc1_error <= 1'b1;
  end
  // END ADC1 INTERFACE
  //--------------------------------------------------------

// END ADC SAMPLING SCHEDULE AND CONTROL
//--------------------------------------------------------

//--------------------------------------------------------  
// REAL TIME CLOCK CONTROLS
  assign MEAS_RTC_BAT = wreg_RTC_meas;
// END REAL TIME CLOCK CONTROLS
//--------------------------------------------------------    


//--------------------------------------------------------
// 
//  SEQUENCE CONTROLLER AND STATE MACHINE

  // Write to wreg_sub_seq_cmd_1
  always@(posedge clk)
	begin
    if (reset)
      wreg_sub_seq_cmd_1 <= 36'h000000000; 
    else if (wr_addr == 6'h02 && wr_strb)
      wreg_sub_seq_cmd_1 <= wr_data[35:0];      
  end   

  // Write to wreg_sub_seq_cmd_2
  always@(posedge clk)
	begin
    if (reset)
      wreg_sub_seq_cmd_2 <= 36'h000000000; 
    else if (wr_addr == 6'h03 && wr_strb)
      wreg_sub_seq_cmd_2 <= wr_data[35:0];      
  end  
  
  assign wreg_sub_seq_cmd = {wreg_sub_seq_cmd_2,wreg_sub_seq_cmd_1}; 
  
  // Execute strobe for sub sequence
  always@(posedge clk)
	begin
    if (reset)
      wr_seq_strb <= 1'b0;
    else if ((wr_addr == 6'h02 && wr_strb))
      wr_seq_strb <= 1'b1;
    else
      wr_seq_strb <= 1'b0;
  end  
  
  // Flag that a subsequence is running, don't allow another
  always@(posedge clk)
	begin
    if (reset)
      wr_seq_strb_Z1 <= 1'b0;
    else
      wr_seq_strb_Z1 <= wr_seq_strb;
  end 
  
  wire [LS-1:0] seq_debug;
  
  // Sequence Controller
  defparam SequenceController_i.BROM_INITIAL_FILE = BROM_INITIAL_FILE;
  defparam SequenceController_i.LS = LS;
  defparam SequenceController_i.NL_ADDR_WD = NL_ADDR_WD;
  SequenceController  SequenceController_i
  (  
    .seq_debug(seq_debug),
    .clk(clk),                                // System Clock 
    .reset(reset),                            // System Reset (Syncronous) 
    .enable(1'b1),                            // System enable 
    .sys_tmr_strb(sys_tmr_strb),              // System Timer Strobe
    .wr_seq_strb(wr_seq_strb_Z1),             // Write sequence strobe or por 
    .wr_seq_run_once(wreg_sub_seq_cmd[LS-1:0]),// Sequence # to run once  6
    .seq_list_en(seq_list_en),                // Flags to enable sequences 6
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that sequence list is done  
    .sub_seq_done_strb(sub_seq_done),         // Signal that sub-sequence is done
    .sub_seq_strb(sub_seq_strb),              // Strobe to run sub sequence 1 
    .sub_seq_addr(sub_seq_addr),              // Address of subsequence to run
    .sub_seq_cnt(sub_seq_cnt)                 // Number of nets in the subsequence  
  );
  
  // State Machine
  defparam StateMachine_IO_i.LS = LS;
  StateMachine_IO  StateMachine_IO_i
  (  
    .clk(clk),                                // System Clock 
    .reset(reset),                            // System Reset (Syncronous) 
    .enable(1'b1),                            // System enable 
    .sys_tmr_strb(sys_tmr_strb),              // System Timer Strobe    
    .estop_pressed(estop_pressed),            // ESTOP pressed
    .uic_command_reg(wreg_Spare_02),          // Bit Command Register From UIC [35:0]     0x3e
    .con_door_status(wreg_Spare_03[3:0]),     // Controller Door Status  [3:0]            0x3d
    .ioc_bprime_done(wreg_Spare_04[18]),      // Bit to indicate that prime is done       0x3c[18]
    .ioc_dprime_done(wreg_Spare_05[18]),      // Bit to indicate that prime is done       0x3b[18]
    .ioc_dprime_en(wreg_Spare_06[18]),        // Bit to indicate that dprime is enables   0x3a[18]
    .ioc_treatment_en(wreg_Spare_07[18]),     // Enable flag to be running treatment      0x39[18]
    .ioc_treatment_done(wreg_Spare_08[18]),   // Flag to indicate that treatment is done  0x38[18]
    .ioc_rinse_en(wreg_Spare_09[18]),         // Flag to enable rinse                     0x37[18]
    .ioc_rinse_done(wreg_Spare_10[18]),       // Flag to indicate rinse is done           0x36[18]
    .ioc_empty_en(wreg_Spare_11[18]),         // Flag to indicate empty                   0x35[18]    
    .saf_alarms(wreg_Spare_27[35:0]),         // Register of safety alarms                0x25 yes spare 27 maps to address 25
    .saf_alarm_status(wreg_Spare_26[20:18]),  // Alarm status                             0x26 [20:18]
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that sequence list is done
    .seq_list_en(seq_list_en),                // Flags to enable sequences    
    .io_state(io_state),                      // IO State Indication
    .alarm_state(alarm_state),                // IO State Indication
    .state_debug(state_debug)
  );
    
//  END SEQUENCE CONTROLLER AND STATE MACHINE
// 
//--------------------------------------------------------

//--------------------------------------------------------
// RTC
	defparam I2C_RTC_i.I2C_ADDRESS  = 8'hDe;    	//  Address for slave I2C RTC
	defparam I2C_RTC_i.BAUD_MASK    = 16'h00C7;	//  Baud Rate Counter  250KHz bus rate
	I2C_RTC I2C_RTC_i
	(  
		//System Inputs
		.clk(clk), 		              	//  System Clock 
		.reset(reset),             	//  System Reset (Syncronous)  
		.enable(1'b1),            	   //  Enable this interface
		.strb_500ms(sys_tmr_strb),   	//  500ms Strobe
	
		// RTC inputs
		// strobe to write information to the RTC.
		// This strobe writes both wreg_RTC_01 and wreg_RTC_02 to the RTC.
		.wr_rtc_strb(wr_rtc_strb),		
		.wreg_RTC_01(wreg_RTC_01),		//  32 bits -- sc(8), mn(8), hr(8), dt(8)
		.wreg_RTC_02(wreg_RTC_02),		//  24 bits -- mo(8), yr(8), dw(8)
	
		// RTC output
		.rtc_01(rtc_01),         		//  This includes sc, mn, hr and dt.
		.rtc_02(rtc_02),         		//  This includes mo, yr and dw.
		.rtc_status(/*rtc_status*/), 	//  RTC sensor status
		.rtc_strb(rtc_strb),     	   //  Strobe that new rtc data is ready
	  
		//I2C two wire interface. 1 = tri-state, 0 = drain at top level
		.I2C_SCL_in(RTC_I2C_SCL_in),  //  Input SCL (As Slave)
		.I2C_SCL_out(RTC_I2C_SCL_out),//  Output SCL (As Master)
		.I2C_SDA_in(RTC_I2C_SDA_in),	//  Input SDA (Master Ack/Nack, Slave Recieve)
		.I2C_SDA_out(RTC_I2C_SDA_out) //  Output SDA (Master/Slave Ack/Nack)
	);
// End of RTC
//--------------------------------------------------------

	// Strobe for time stamp. 
	always@(posedge clk)
	begin
		if (reset)
         time_stamp  <= {64{1'b0}};
		else if (rtc_strb)
			time_stamp  <= {{16{1'b0}},rtc_02[23:16],rtc_01[7:0],rtc_02[15:8], // mo,dt,yr
			                rtc_01[15:8],rtc_01[23:16],rtc_01[31:24]};         // hr,mn,sc
		else
			time_stamp  <= time_stamp;      
	end
	
	// Trigger the sdc initialization procedure manually. 
	always@(posedge clk)
	begin
		if (reset)
			man_init_sdc_strb <= 1'b0;
		else if (wr_addr == 6'h12 && wr_strb)
			man_init_sdc_strb <= 1'b1;
		else
			man_init_sdc_strb <= 1'b0;      
	end

	// Choose which map register to read from the 
	// SD Card host controller. 
	// Read from the TEST comm. port. 
//	always@(posedge clk)
//	begin
//		if (reset)
//			rd_reg_indx_puc <= {12{1'b0}};
//		else if (rd_addr == 6'h12 && rd_strb)
//			rd_reg_indx_puc <= 12'h004;   
//		else if (rd_addr == 6'h13 && rd_strb)
//			rd_reg_indx_puc <= 12'h006;   
//		else if (rd_addr == 6'h14 && rd_strb)
//			rd_reg_indx_puc <= 12'h008;   
//		else if (rd_addr == 6'h15 && rd_strb)
//			rd_reg_indx_puc <= 12'h00C;   
//		else if (rd_addr == 6'h16 && rd_strb)
//			rd_reg_indx_puc <= 12'h00E;   
//		else if (rd_addr == 6'h17 && rd_strb)
//			rd_reg_indx_puc <= 12'h010;   
//		else if (rd_addr == 6'h18 && rd_strb)
//			rd_reg_indx_puc <= 12'h024;   
//		else if (rd_addr == 6'h19 && rd_strb)
//			rd_reg_indx_puc <= 12'h02C;   
//		else if (rd_addr == 6'h1A && rd_strb)
//			rd_reg_indx_puc <= 12'h030;   
//		else if (rd_addr == 6'h1B && rd_strb)
//			rd_reg_indx_puc <= 12'h032;   
//		else if (rd_addr == 6'h1C && rd_strb)
//			rd_reg_indx_puc <= 12'h034;   
//		else if (rd_addr == 6'h1D && rd_strb)
//			rd_reg_indx_puc <= 12'h036;   
//		else if (rd_addr == 6'h1E && rd_strb)
//			rd_reg_indx_puc <= 12'h038;   
//		else if (rd_addr == 6'h1F && rd_strb)
//			rd_reg_indx_puc <= 12'h03A;   
//		else if (rd_addr == 6'h20 && rd_strb)
//			rd_reg_indx_puc <= 12'h058;   
//		else
//			rd_reg_indx_puc <= {12{1'b0}};   
//	end

	//Assign sd card rregs.
	always@(posedge clk)
	begin
		if (reset)
			rreg_hc_addr 	<= 36'h000000000; 
		else
			rreg_hc_addr 	<= wreg_hc_addr;					// 0x000F
	end
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_hc_reg_man 	<= 36'h000000000; 
		else
			rreg_sdc_hc_reg_man 	<= wreg_sdc_hc_reg_man;	// 0x0010
	end
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_cmd 	<= 36'h000000000; 
		else
			rreg_sdc_cmd 	<= wreg_sdc_cmd;					// 0x0011
	end 
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_hc_reg 	<= 36'h000000000; 
		else
			rreg_hc_reg 	<= wreg_hc_reg;
	end    
	
	// Read back from register x0012.
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_blk_size 	<= 36'h000000000; 
		else
			rreg_sdc_blk_size 	<= rd_reg_output_puc;
	end    
	
	// 0x0013, Autonomous data
	always@(posedge clk)
	begin
		if (reset)
			rreg_auto_data 	<= 36'h000000000; 
		else if (aut_rdy_strb)
			rreg_auto_data 	<= aut_rd_data;
		else
			rreg_auto_data 	<= rreg_auto_data;
	end    
	
	// 0x0014, Autonomous Address to read from 
	always@(posedge clk)
	begin
		if (reset)
			rreg_auto_addr 	<= 36'h000000000; 
		else if (aut_rd_strb)
			rreg_auto_addr 	<= {{(36-ADDR_DW){1'b0}},aut_rd_addr}; 
		else
			rreg_auto_addr 	<= rreg_auto_addr; 
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_trans_mde 	<= 36'h000000000; 
		else
			rreg_sdc_trans_mde 	<= wreg_sdc_cmd;
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_command 	<= 36'h000000000; 
		else
			rreg_sdc_command 	<= wreg_sdc_cmd;
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_resp 	<= 36'h000000000; 
		else
			rreg_sdc_resp 	<= wreg_sdc_cmd; 
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_pres_ste 	<= 36'h000000000; 
		else
			rreg_sdc_pres_ste 	<= wreg_sdc_cmd; 
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_clk_cntrl 	<= 36'h000000000; 
		else
			rreg_sdc_clk_cntrl 	<= wreg_sdc_cmd;
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_norm_int_stat 	<= 36'h000000000; 
		else
			rreg_sdc_norm_int_stat 	<= wreg_sdc_cmd;
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_err_int_stat 	<= 36'h000000000; 
		else
			rreg_sdc_err_int_stat 	<= wreg_sdc_cmd;
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_norm_int_stat_enb 	<= 36'h000000000; 
		else
			rreg_sdc_norm_int_stat_enb 	<= wreg_sdc_cmd;
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_err_int_stat_enb 	<= 36'h000000000; 
		else
			rreg_sdc_err_int_stat_enb 	<= wreg_sdc_cmd;
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_norm_int_sig_enb 	<= 36'h000000000; 
		else
			rreg_sdc_norm_int_sig_enb 	<= wreg_sdc_cmd;
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_err_int_sig_enb 	<= 36'h000000000; 
		else
			rreg_sdc_err_int_sig_enb 	<= wreg_sdc_cmd;
	end    
	
	always@(posedge clk)
	begin
		if (reset)
			rreg_sdc_adma_sys_addr 	<= 36'h000000000; 
		else
			rreg_sdc_adma_sys_addr 	<= wreg_sdc_cmd;
	end    
	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_blk_size 	<= 36'h000000000; 
//		else if (rd_addr == 6'h12)
//			// do we need to latch or strobe when
//			// the data is valid?
//			// This data is available a few clocks later.
//			// Too late to show at reg_selected.
//			// It may be availabe if you read it a second time
//			// around.  
//			rreg_sdc_blk_size		<= rd_reg_output_puc;
//		else
//			rreg_sdc_blk_size 	<= rreg_sdc_blk_size;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_auto_data 	<= 36'h000000000; 
//		else if (rd_addr == 6'h13)
//			rreg_auto_data	<= rd_reg_output_puc;
//		else
//			rreg_auto_data 	<= rreg_auto_data;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_auto_addr 	<= 36'h000000000; 
//		else if (rd_addr == 6'h14)
//			rreg_auto_addr	<= rd_reg_output_puc;
//		else
//			rreg_auto_addr 	<= rreg_auto_addr; 
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_trans_mde 	<= 36'h000000000; 
//		else if (rd_addr == 6'h15)
//			rreg_sdc_trans_mde	<= rd_reg_output_puc;
//		else
//			rreg_sdc_trans_mde 	<= rreg_sdc_trans_mde;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_command 	<= 36'h000000000; 
//		else if (rd_addr == 6'h16)
//			rreg_sdc_command	<= rd_reg_output_puc;
//		else
//			rreg_sdc_command 	<= rreg_sdc_command;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_resp 	<= 36'h000000000; 
//		else if (rd_addr == 6'h17)
//			rreg_sdc_resp	<= rd_reg_output_puc;
//		else
//			rreg_sdc_resp 	<= rreg_sdc_resp; 
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_pres_ste 	<= 36'h000000000; 
//		else if (rd_addr == 6'h18)
//			rreg_sdc_pres_ste		<= rd_reg_output_puc;
//		else
//			rreg_sdc_pres_ste 	<= rreg_sdc_pres_ste; 
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_clk_cntrl 	<= 36'h000000000; 
//		else if (rd_addr == 6'h19)
//			rreg_sdc_clk_cntrl	<= rd_reg_output_puc;
//		else
//			rreg_sdc_clk_cntrl 	<= rreg_sdc_clk_cntrl;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_norm_int_stat 	<= 36'h000000000; 
//		else if (rd_addr == 6'h1A)
//			rreg_sdc_norm_int_stat	<= rd_reg_output_puc;
//		else
//			rreg_sdc_norm_int_stat 	<= rreg_sdc_norm_int_stat;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_err_int_stat 	<= 36'h000000000; 
//		else if (rd_addr == 6'h1B)
//			rreg_sdc_err_int_stat	<= rd_reg_output_puc;
//		else
//			rreg_sdc_err_int_stat 	<= rreg_sdc_err_int_stat;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_norm_int_stat_enb 	<= 36'h000000000; 
//		else if (rd_addr == 6'h1C)
//			rreg_sdc_norm_int_stat_enb		<= rd_reg_output_puc;
//		else
//			rreg_sdc_norm_int_stat_enb 	<= rreg_sdc_norm_int_stat_enb;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_err_int_stat_enb 	<= 36'h000000000; 
//		else if (rd_addr == 6'h1D)
//			rreg_sdc_err_int_stat_enb	<= rd_reg_output_puc;
//		else
//			rreg_sdc_err_int_stat_enb 	<= rreg_sdc_err_int_stat_enb;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_norm_int_sig_enb 	<= 36'h000000000; 
//		else if (rd_addr == 6'h1E)
//			rreg_sdc_norm_int_sig_enb	<= rd_reg_output_puc;
//		else
//			rreg_sdc_norm_int_sig_enb 	<= rreg_sdc_norm_int_sig_enb;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_err_int_sig_enb 	<= 36'h000000000; 
//		else if (rd_addr == 6'h1F)
//			rreg_sdc_err_int_sig_enb	<= rd_reg_output_puc;
//		else
//			rreg_sdc_err_int_sig_enb 	<= rreg_sdc_err_int_sig_enb;
//	end    
//	
//	always@(posedge clk)
//	begin
//		if (reset)
//			rreg_sdc_adma_sys_addr 	<= 36'h000000000; 
//		else if (rd_addr == 6'h20)
//			rreg_sdc_adma_sys_addr	<= rd_reg_output_puc;
//		else
//			rreg_sdc_adma_sys_addr 	<= rreg_sdc_adma_sys_addr;
//	end    
	//////////////////////////////////////////////////////////

  // Create wr_reg_man to write data to the h.c. manually.
  always@(posedge clk)
	begin
    if (reset)
      wr_reg_man <= 1'b0;
    else if (wr_addr == 6'h14 && wr_strb)
      wr_reg_man <= 1'b1;
    else if (wr_reg_man_fin)
      wr_reg_man <= 1'b0;	// turns it off after a few clocks 
    else 
      wr_reg_man <= wr_reg_man;      
  end
	
	//-------------------------------------------------------------------------
	// Counter for wr_reg_man latch 
	//-------------------------------------------------------------------------
	defparam wrRegManLtchCntr.dw 	= 4;
	defparam wrRegManLtchCntr.max	= 4'hA;	
	//-------------------------------------------------------------------------
	CounterSeq wrRegManLtchCntr(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		.start_strb(wr_addr == 6'h14 && wr_strb), // start the timing  	 	
		.cntr(), 
		.strb(wr_reg_man_fin) 
	);
	
	// SD Card Module
	//--------------------------------------------------------
   sdc_controller_mod sdc_controller_mod_i(
      .clk(clk),															//								                                    input 			
		.reset(reset),	                                       //                  		                                    input 
		// Send the sdc intialization procedure manually.                                                                       
		.man_init_sdc_strb(man_init_sdc_strb),	               // 0x0012             		                                 input 
		// test cmd strb from host (ie, CMD8), activate by 0x0011 write 
      // This signal accompannies the data signal below.
      // This command only sends out sdc command without data.
      // Cannot use it to send out command with data like command 24d or 25d.
		.host_tst_cmd_strb(host_tst_cmd_strb),		            //                                                          input                                        
		// read host controller register from PUC                                                                               
		.rd_reg_indx_puc(wreg_hc_addr[11:0]),                 // 	                                                      input 
		.rd_reg_output_puc(rd_reg_output_puc),		            // export reg data to puc                                   output
		.wr_reg_man(wr_reg_man), 						            // write reg. manually from puc (0x0014)     	            input
		.wreg_sdc_hc_reg_man(wreg_sdc_hc_reg_man),            // write reg. manually from puc (0x0014)     	            input
		.start_data_tf_strb(wreg_strt_data_tf_strb),	         // from puc or other host                    	            input
		.data_in_strb(data_in_strb),					            // from puc or other host                    	            input
		.last_set_of_data_strb(last_set_of_data_strb),	      // from puc or other host              	                  input
		// data from puc (or other host) per strobe,                                                             
		// also use for test cmd (ie, CMD8) in conjuction with                                                   
		// host_tst_cmd_strb.  For example, command 0x0007.                                                                                  
		.data(wreg_sdc_cmd /*| wreg_sdc_hc_reg_man[15:0]*/),  //		                                                      input
		                                                                                    
		// Following is for System Memory FIFO.	                                          
		.strt_fifo_strb(strt_fifo_strb),	                     // Strobe for first data from puc and latch time stamp      output
		.wr_b_strb(/*strt_fifo_strb_z4 |*/ puc_data_strb_z3), // write puc data to fifo                                   input	
		.fifo_data(fifo_data),			                        // data to be logged.                                       input 
		.rdy_for_nxt_pkt(rdy_for_nxt_pkt),	                  // ready for next packet (fifo_data) from puc.              output
	                                                         // This will continue until we are done with 1024 registers.                                                                          
		// For sd card                                                                            
		.sdc_rd_addr(wreg_sdc_rd_addr[31:0]),	               // sd card read address.	             	                  input
		.sdc_wr_addr(wreg_sdc_wr_addr[31:0]),	               // sd card write address.	             	                  input
		.tf_mode(wreg_tf_mode),                               // sd card transfer mode                                    input
      //.sdc_cmd_indx(wreg_cmd_indx),                         // command index for the sdc command format                 input
      
		.IO_SDC1_CD_WP(IO_SDC1_CD_WP),                                                      
		.IO_SDC1_D0_in(IO_SDC1_D0_in),                                                      
		.IO_SDC1_D0_out(IO_SDC1_D0_out),                                                    
		.IO_SDC1_D1_in(IO_SDC1_D1_in),                                                      
		.IO_SDC1_D1_out(IO_SDC1_D1_out),                                                    
		.IO_SDC1_D2_in(IO_SDC1_D2_in),                                                      
		.IO_SDC1_D2_out(IO_SDC1_D2_out),                                                    
		.IO_SDC1_D3_in(IO_SDC1_D3_in),                                                      
		.IO_SDC1_D3_out(IO_SDC1_D3_out),                                                    
		.IO_SDC1_CLK(IO_SDC1_CLK),                                                          
		.IO_SDC1_CMD_in(IO_SDC1_CMD_in),                                                    
		.IO_SDC1_CMD_out(IO_SDC1_CMD_out)                                                   
		);
		//////////////////////////////////////////////////////////////
	
//	assign cs_test_vector[1] 	   = strt_fifo_strb;
//	assign cs_test_vector[2] 	   = strt_fifo_strb_z2;
//	assign cs_test_vector[3] 	   = puc_data_strb_z2;
//	assign cs_test_vector[39:4]   = fifo_data;
//	assign cs_test_vector[40] 	   = rdy_for_nxt_pkt;
  
//--------------------------------------------------------

   // Capture the time stamp when we get the fifo start strobe.
   // Capture the puc_data whenever we get the strt_fifo_strb or puc_data_strb.
	// We need to capture 1024 words of each registers.  There are 256 registers
	// per fpga.  There are four fpgas.
	always@(posedge clk)
	   begin
         if (reset)
            fifo_data 			<= {64{1'b0}};   
         else if (strt_fifo_strb)
         // latch it to disperse throughout all blocks
            time_stamp_latch 	<= time_stamp; 		      
         // latch for puc_data 3 clocks after strt_fifo_strb 
         // and 2 clocks after puc_data_strb   
         else if (/*strt_fifo_strb_z3 |*/ puc_data_strb_z2)  
            fifo_data 			<= puc_data_dts;  
         else 
            fifo_data 			<= fifo_data;
      end
	
   // Once the puc_data comes out of the GetPUCData module, it will be latched
   // with part of the time stamp information base on the counter index.
   //---------------------------------------------------------------
   // SysTmrStrbe 
   defparam DataCntr_i.dw  = 12;
   defparam DataCntr_i.max = 12'h400; // 1024 addresses              
   //---------------------------------------------------------------
   Counter DataCntr_i
   (
      .clk(clk),              // Clock input 50 MHz 
      .reset(reset),          // GSR
      .enable(puc_data_strb), // strt_fifo_strb will get time stamp of mo.
      .cntr(puc_data_index),  // Counter value
      .strb()                 // strobe to latch date time stamp
   );
	
   // Select which dts part to concatenate to the puc_data.
   // May want to check what needs to be in the sensitivity list.
   always @(puc_data_index[2:0])
      case (puc_data_index[2:0])     
         3'b000: 	puc_data_dts = {28'h0000_0000, puc_data[35:0]};                         // 00
         3'b001: 	puc_data_dts = {time_stamp_latch[47:40], 20'h0_0000, puc_data[35:0]};   // mo
         3'b010: 	puc_data_dts = {time_stamp_latch[39:32], 20'h0_0000, puc_data[35:0]};   // dt
         3'b011: 	puc_data_dts = {time_stamp_latch[31:24], 20'h0_0000, puc_data[35:0]};   // yr
         3'b100: 	puc_data_dts = {time_stamp_latch[23:16], 20'h0_0000, puc_data[35:0]};   // hr
         3'b101: 	puc_data_dts = {time_stamp_latch[15:8],  20'h0_0000, puc_data[35:0]};   // mn
         3'b110: 	puc_data_dts = {time_stamp_latch[7:0],   20'h0_0000, puc_data[35:0]};   // sc
         3'b111: 	puc_data_dts = {28'h0000_0000, puc_data[35:0]};                         // 00
      endcase   
      
   // LOGIC ANALYZER
   always@(posedge clk)
	begin
      if (reset)
         LogicAnalyzer <= 16'h0000;
      else
         LogicAnalyzer <= state_debug; //{3'b000,seq_debug}; //state_debug
   end
// END LOGIC ANALYZER
//--------------------------------------------------------  

//--------------------------------------------------------
// READ READY STROBE IS RD STROBE DELAY Z1
	always@(posedge clk)
	begin
		if (reset)      
			rd_rdy_strb <= 1'b0;
		// if rd_addr is between h11 and h20 
		// use sdc_dat_rdy.
		//else if (sdc_dat_rdy && (rd_addr >= 6'h11 || rd_addr <= 6'h20))
		else if ((rd_addr >= 6'h10) || (rd_addr <= 6'h20))
			rd_rdy_strb <= sdc_dat_rdy_z2;  // three clocks later  
		else
			rd_rdy_strb <= rd_strb;
	end
// END RD READY STRB
//--------------------------------------------------------
    
endmodule
