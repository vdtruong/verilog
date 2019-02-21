//-----------------------------------------------------------------
//  Module:     PUC_C_Controller
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
//-----------------------------------------------------------------
module PUC_C_Controller
#( parameter FPGA_VERSION = 16'h0000,
   parameter BROM_INITIAL_FILE = "C:/FPGA_Design/PAKPUCXXXX/src/BROM_NetLists_XXXX_64_x_36.txt", 
   parameter NL_ADDR_WD = 9,
   parameter LS = 36)
(  
  input               clk,                // System Clock 
  input               reset,              // System Reset (Syncronous)
  input               enable,             // Enable
  input               por_strb,           // Power on reset strobe
  input               sys_tmr_strb,       // System Timer Strobe
  output              sync_strb,          // Output Sync Strobe
  
  input               strb_1us,           // 1 us strobe
  input               strb_100us,         // 100 us strobe  
  input               strb_1ms,           // 1 ms strobe
  input               strb_500ms,         // 500 ms strobe
  input               strb_1s,            // 1 sec
  
  input               rd_strb,            // Read Register Strobe
  input        [7:0]  rd_addr,            // Address to read from 0-64
  input        [7:0]  wr_addr,            // Address to write to 0-64 + 16 rd/wr
  input               wr_strb,            // Write Register Strobe
  input       [35:0]  wr_data,            // Data to write 16 bit data 
  output  reg [35:0]  rd_data,            // Data read 36 bit data   
  
  output       [1:0]  COM_Cntrl,          // Output flag to Actel COM FPGA
  input        [7:0]  comm_err,           // Communication Error
 
  input               ADC1_DOUT,          // Dout from ADC1
  input               ADC1_BUSY,          // Busy from ADC1
  output              ADC1_CS_N,          // Chip Select to ADC1
  output              ADC1_CLK,           // Dclk to ADC1
  output              ADC1_DIN,           // Din to ADC1 
  output              ADC_1_MUXA,         // ADC MUX 1 CHAN A
  output              ADC_1_MUXB,         // ADC MUX 1 CHAN B
  
  input               RA_CABLE_DET_N,     // RAC CONNECTED
  
  input               FAN1_TACH_N,        // FAN 1 Tach feedback mechanism
  output              FAN1_PWM,           // FAN 1 PWM Signal
  input               FAN2_TACH_N,        // FAN 2 Tach feedback mechanism
  output              FAN2_PWM,           // FAN 2 PWM Signal
  
  input               TEMP_ALERT,         // Temperature alert interrupt
  output              TSENSE_TEST,        // BIT test temperature sensor
  input               TEMP_BIT,           // Temperature BIT Fbk
   
  input               I2C_TMP275_SCL_in,  // Input Temp275 SCL
  output              I2C_TMP275_SCL_out, // Output Temp275 SCL
  input               I2C_TMP275_SDA_in,  // Input Temp275 SDA
  output              I2C_TMP275_SDA_out, // Output Temp275 SDA
  
  output              RL_SOL_PWM,         // RAC Lock Solenoid PWM
  output              VC_SOL_PWM,         // Venous Clamp Solenoid PWM
  output              DL_SOL_PWM,         // Door Lock Solenoid PWM  
  
  output              DRS_PWM,            // Door Reference Sensor PWM
  input               DRS_POS,            // Door Reference Sensor Postion Flag
  input               DRS_AMB,            // Door Reference Sensor Ambiant Level  
  
  input               DAC_DOUT,           // DAC Interface Motor Current Limit Dout
  output              DAC_DIN,            // DAC Interface Motor Current Limit Din    
  output              DAC_DCLK,           // DAC Interface Motor Current Limit Clock
  output              DAC_CS_N,           // DAC Interface Motor Current Limit Chip Select
  output              DAC_CLR_N,          // DAC Interface Motor Current Limit Clear  
  
  output              BP_STEP,            // Motor BP Step Command             
  output              BP_DIR,             // Motor BP Direction (Low Clockwise)
  output              BP_M1,              // Motor BP Bit 0 Micro Step Setting
  output              BP_M2,              // Motor BP Bit 1 Micro Step Setting
  output              BP_RESET_N,         // Motor BP Active Low Reset
  output              DP1_STEP,           // Motor DP1 Step Command
  output              DP1_DIR,            // Motor DP1 Direction (Low Clockwise)
  output              DP1_M1,             // Motor DP1 Bit 0 Micro Step Setting
  output              DP1_M2,             // Motor DP1 Bit 1 Micro Step Setting
  output              DP1_RESET_N,        // Motor DP1 Active Low Reset
  output              DP2_STEP,           // Motor DP2 Step Command
  output              DP2_DIR,            // Motor DP2 Direction (Low Clockwise)
  output              DP2_M1,             // Motor DP2 Bit 0 Micro Step Setting
  output              DP2_M2,             // Motor DP2 Bit 1 Micro Step Setting
  output              DP2_RESET_N,        // Motor DP2 Active Low Reset
  output              ELP_STEP,           // Motor ELP Step Command
  output              ELP_DIR,            // Motor ELP Direction (Low Clockwise)
  output              ELP_M1,             // Motor ELP Bit 0 Micro Step Setting
  output              ELP_M2,             // Motor ELP Bit 1 Micro Step Setting
  output              ELP_RESET_N,        // Motor ELP Active Low Reset
  output              HEP_STEP,           // Motor HEP Step Command
  output              HEP_DIR,            // Motor HEP Direction (Low Clockwise)
  output              HEP_M1,             // Motor HEP Bit 0 Micro Step Setting
  output              HEP_M2,             // Motor HEP Bit 1 Micro Step Setting
  output              HEP_RESET_N,        // Motor HEP Active Low Reset
  output              DL_STEP,            // Motor DL Step Command
  output              DL_DIR,             // Motor DL Direction (Low Clockwise)
  output              DL_M1,              // Motor DL Bit 0 Micro Step Setting
  output              DL_M2,              // Motor DL Bit 1 Micro Step Setting
  output              DL_RESET_N,         // Motor DL Active Low Reset 
  
  input               BPR_CHA_C,          // Motor BP  Encoder Channel A
  input               BPR_CHB_C,          // Motor BP  Encoder Channel B
  input               DP1R_CHA_C,         // Motor DP1 Encoder Channel A
  input               DP1R_CHB_C,         // Motor DP1 Encoder Channel B
  input               DP2R_CHA_C,         // Motor DP2 Encoder Channel A
  input               DP2R_CHB_C,         // Motor DP2 Encoder Channel B
  input               HEPR_CHA_C,         // Motor HEP Encoder Channel A
  input               HEPR_CHB_C,         // Motor HEP Encoder Channel B
  input               ELPR_CHA_C,         // Motor ELP Encoder Channel A
  input               ELPR_CHB_C,         // Motor ELP Encoder Channel B
  input               DL_CHA_C,           // Motor DL  Encoder Channel A
  input               DL_CHB_C,           // Motor DL  Encoder Channel B   

  input               CSDL_C_RX1_S_TX1,   // Cross Channel Master Recieve
  output              CSDL_C_TX1_S_RX1,   // Cross Channel Master Transmit 

  input               SUBLINK_C_RX,       // Subsystem Recieve Line  
  output              SUBLINK_C_TX,       // Subsystem Transmit Line
  
  input               sub_seq_done,       // Flag that the sub sequence run has completed. 
  output              sub_seq_strb,       // Strobe to run sub sequence 1 
  output      [NL_ADDR_WD-1:0]  sub_seq_addr,       // Address of subsequence to run
  output      [NL_ADDR_WD-1:0]  sub_seq_cnt,        // Number of nets in the subsequence  
    
  output reg          net_wr_strb,        // Net List
  output      [NL_ADDR_WD-1:0]  net_wr_addr,        // Net Address
  output      [35:0]            net_wr_data,        // Net Data 
  
  output              EXC_C_1BIT_DAC,     // Output 1 bit speaker DAC
  
  output reg [15:0]   LogicAnalyzer       // Logic Analyzer
);


/*-----------------------------------------------------------------------
                             MEMORY/REGISTER MAP
WRITE SPACE:  
  0x0000  Syncronous Timing Write Command    
  0x0001  DAC/ADC Control Register
          Bit[0] : 1 Bit DAC Enable == 1, Disable == 0
          Bit[1] : ADC1 Enable == 1, Disable == 0
          Bit[2] : DRS Enable == 1, Disable == 0
          Bit[3] : DAC Reference Enable == 1, Disable == 0
          Bit[8] : SUB System Communication Enable == 1, Disable == 0
          Bit[9] : CSDL System Communication Enable == 1, Disable == 0
          Bit[35]: System is Initialized
  0x0002  Command Sub System Sequence to run (Sequence Address, Count, Strb)
          Bit[  8:0] :  Address to run sub sequence
          Bit[20:12] :  Number of nets to run
  0x0003  CSDL Wrap
  0x0004  Scale Correction Factor
  0x0005  SPARE
  0x0006  Fan PWM Period in us
  0x0007  Fan PWM On in us
  0x0008  Fan Control Register
          Bit[0] : Fan Enable == 1, Disable == 0
          Bit[1] : Fan Enable == 1, Disable == 0
  0x0009  Temperature Test Control
          Bit[0] : Enable == 1, Disable == 0
  0x000A  Program Net List Address (Auto Increment after write to Data
  0x000B  Program Net List Data (+Strb)
  0x000C  SPARE
  0x000D  SPARE
  0x000E  COM FLAG(S)
          Bit[0] : Route thru to test COMs
          Bit[1] : Spare Discrete to COM FPGA
  0x000F  DSM Frequency
  0x0010  Solenoid RAC Latch PWM Period
  0x0011  Solenoid RAC Latch PWM On Time  
  0x0012  Solenoid RAC Latch Enable  
  0x0013  Solenoid Door Lock PWM Period  
  0x0014  Solenoid Door Lock PWM On Time
  0x0015  Solenoid Door Lock Enable  
  0x0016  Solenoid Venous Clamp PWM Period  
  0x0017  Solenoid Venous Clamp PWM On Time
  0x0018  Solenoid Venous Clamp Enable
  0x0019  SPARE
  0x001a  NVM Write Command
  0x001b  NVM Write Wr Data
  0x001c  Kpuf
  0x001d  Kpufr
  0x001e  Kiufr
  0x001f  Kdufr
  0x0020  DAC CH0 Value (8 bit) dec2hex(floor(Vref*255/2.037))
  0x0021  DAC CH1 Value (8 bit) dec2hex(floor(Vref*255/2.037))
  0x0022  DAC CH2 Value (8 bit) dec2hex(floor(Vref*255/2.037))
  0x0023  DAC CH3 Value (8 bit) dec2hex(floor(Vref*255/2.037))
  0x0024  DAC CH4 Value (8 bit) dec2hex(floor(Vref*255/2.037))
  0x0025  ADM Autonomous DAC writes (SPARE)
  0x0026  DAC CH6 Value (8 bit) dec2hex(floor(Vref*255/2.037))
  0x0027  DAC CH7 Value (8 bit) dec2hex(floor(Vref*255/2.037))
  0x0028  MOTOR BP  bit[4] = dir, bit[1:0] = ustep
  0x0029  MOTOR BP  acceleration * 1E-6 (rpm/us)
  0x002A  MOTOR BP  velocity in rpm (36 bit)
  0x002B  MOTOR BP  bit[0] = enable
  0x002C  MOTOR DP1 bit[4] = dir, bit[1:0] = ustep
  0x002D  MOTOR DP1 acceleration * 1E-6 (rpm/us)
  0x002E  MOTOR DP1 velocity in rpm (36 bit)
  0x002F  MOTOR DP1 bit[0] = enable
  0x0030  MOTOR DP2 bit[4] = dir, bit[1:0] = ustep
  0x0031  MOTOR DP2 acceleration * 1E-6 (rpm/us)
  0x0032  MOTOR DP2 velocity in rpm (36 bit)
  0x0033  MOTOR DP2 bit[0] = enable
  0x0034  MOTOR ELP bit[4] = dir, bit[1:0] = ustep
  0x0035  MOTOR ELP acceleration * 1E-6 (rpm/us)
  0x0036  MOTOR ELP velocity in rpm (36 bit)
  0x0037  MOTOR ELP bit[0] = enable
  0x0038  MOTOR HEP bit[4] = dir, bit[1:0] = ustep
  0x0039  MOTOR HEP acceleration * 1E-6 (rpm/us)
  0x003A  MOTOR HEP velocity in rpm (36 bit)
  0x003B  MOTOR HEP bit[0] = enable
  0x003C  MOTOR ADM Command Open == 0 Close == 1
  0x003D  MOTOR ADM Clear Status Change
  0x003E  SPARE
  0x003F  SPARE
  0x0040  Subsystem RAC operation enable
  0x0041  Subsystem RAC write reg 02
  0x0042  Subsystem RAC write reg 03
  0x0043  Subsystem RAC write reg 04
  0x0044  Subsystem RAC write reg 05
  0x0045  Subsystem RAC write reg 06
  0x0046  Subsystem RAC write reg 07
  0x0047  Subsystem RAC write reg 08
  0x0048  Subsystem RAC write reg 09
  0x0049  Subsystem RAC write reg 10
  0x004A  Subsystem RAC write reg 11
  0x004B  Subsystem RAC write reg 12
  0x004C  Subsystem RAC write reg 13
  0x004D  Subsystem RAC write reg 14
  0x004E  Subsystem RAC write reg 15  
  0x004F  Subsystem RAC write reg 16  
  0x0050  Subsystem CSDL operation enable
  0x0051  Subsystem CSDL write reg 02
  0x0052  Subsystem CSDL write reg 03
  0x0053  Subsystem CSDL write reg 04
  0x0054  Subsystem CSDL write reg 05
  0x0055  Subsystem CSDL write reg 06
  0x0056  Subsystem CSDL write reg 07
  0x0057  Subsystem CSDL write reg 08
  0x0058  Subsystem CSDL write reg 09
  0x0059  Subsystem CSDL write reg 10
  0x005A  Subsystem CSDL write reg 11
  0x005B  Subsystem CSDL write reg 12
  0x005C  Subsystem CSDL write reg 13
  0x005D  Subsystem CSDL write reg 14
  0x005E  Subsystem CSDL write reg 15
  0x005F  Subsystem CSDL write reg 16  
  0x0060  GPRW 60 Monitors Enabled
  0x0061  GPRW 61 Monitors Triggered
  0x0062  GPRW 62 Monitors Masked
  0x0063  GPRW 63 Cmd Enables
  0x0064  GPRW 64 Monitors Tripped Flag Bit[N:0] = s24V,s5V,s1.5V,s1.2V,s3.3V,c24V,c5V,c1.5V,c1.2V,c3.3V
  0x0065  GPRW 65
  0x0066  GPRW 66
  0x0067  GPRW 67 IO State Command (Treatment == 1d, 1e, 1f, 20, 21, 22)
  0x0068  GPRW 68 Blood Flow Rate / RPM Command
  0x0069  GPRW 69 Dialysate Flow Rate / RPM Command
  0x006a  GPRW 6A DP2 Command
  0x006b  GPRW 6B IC Command
  0x006c  GPRW 6C HEP Command
  0x006d  GPRW 6D Temperature Command
  0x006e  GPRW 6E UF Goal
  0x006f  GPRW 6F Treatment Time
  0x0070  GPRW 70  Debug 1
  0x0071  GPRW 71  Debug 2
  0x0072  GPRW 72  Debug 3
  0x0073  GPRW 73  Debug 4
  0x0074  GPRW 74  Debug 5
  0x0075  GPRW 75  Debug 6
  0x0076  GPRW 76  Debug 7
  0x0077  GPRW 77  Debug 8
  0x0078  GPRW 78
  0x0079  GPRW 79
  0x007a  GPRW 7A  UF Removed Update from Loop
  0x007b  GPRW 7B  UF Rate Calculated from Loop
  0x007c  GPRW 7C  Temperature Updated from System
  0x007d  GPRW 7D  Treatment Time Lapsed
  0x007e  GPRW 7E  Treatment Time Remaining
  0x007f  GPRW 7F  Indicated Sequence Running 
END WRITE SPACE

READ REGISTERS:
  0x0000  ADC1 NO MUX CH0 (24V_C_SENSE)
  0x0001  ADC1 NO MUX CH1 (VC_SOL_CURR) 
  0x0002  ADC1 NO MUX CH2 (DL_SOL_CURR)
  0x0003  ADC1 NO MUX CH3 (RL_SOL_CURR)
  0x0004  ADC1 NO MUX CH4 (FAN_CURRENT)
  0x0005  ADC1 NO MUX CH5 (DRS_AMB_ANLG)
  0x0006  SPARE 22
  0x0007  SPARE 21
  0x0008  ADC1 MUX1 A CH0 (24V-C)
  0x0009  ADC1 MUX1 A CH1 (5V-C)
  0x000A  ADC1 MUX1 A CH2 (3.3V-C) 
  0x000B  ADC1 MUX1 A CH3 (1.8V-C)
  0x000C  ADC1 MUX1 B CH0 (1.5V-C)
  0x000D  ADC1 MUX1 B CH1 (1.2V-C)
  0x000E  ADC1 MUX1 B CH2 (GND)
  0x000F  ADC1 MUX1 B CH3 (GND)
  0x0010  BP Motor Encoder
  0x0011  BP Encoder Checking
          Bit [0] : steps are under
          Bit [1] : steps are over
          Bit [2] : Direction
  0x0012  DP1 Motor Encoder
  0x0013  DP1 Encoder Checking
          Bit [0] : steps are under
          Bit [1] : steps are over
          Bit [2] : Direction  
  0x0014  DP2 Motor Encoder
  0x0015  DP2 Encoder Checking
          Bit [0] : steps are under
          Bit [1] : steps are over
          Bit [2] : Direction  
  0x0016  ELP Motor Velocity
  0x0017  ELP Motor Encoder
          Bit [0] : steps are under
          Bit [1] : steps are over
          Bit [2] : Direction
  0x0018  HEP Motor Velocity
  0x0019  HEP Motor Encoder
          Bit [0] : steps are under
          Bit [1] : steps are over
          Bit [2] : Direction
  0x001A  DL Motor Velocity
  0x001B  DL Motor Encoder
          Bit [0] : steps are under
          Bit [1] : steps are over
          Bit [2] : Direction
  0x001C  Blood Flow Rate Feedback  ml/min
  0x001D  Dialysate Rate Feedback   ml/min
  0x001E  UF Rate Feedback          L/hr
  0x001F  SPARE 17
  0x0020  FAN 1 TACH FBK  
  0x0021  FAN 2 TACH FBK  
  0x0022  TEMPERATURE REGISTER
  0x0023  STATUS REGISTER
  0x0024  DOOR REFERENCE STATUS
  0x0025  ADM STATUS CODE [7:0]
  0x0026  SPARE 16
  0x0027  SPARE 15
  0x0028  SPARE 14
  0x0029  SPARE 13
  0x002a  NVM Read 01
  0x002b  NVM Read 02
  0x002c  NVM Read 03
  0x002d  NVM Read 04
  0x002e  NVM Read 05
  0x002f  NVM Read 06
  0x0030  SPARE 12
  0x0031  SPARE 11
  0x0032  SPARE 10
  0x0033  SPARE 09
  0x0034  rreg_Scale_Correction
  0x0035  Kpuf
  0x0036  Kpufr
  0x0037  Kiufr
  0x0038  Kdufr
  0x0039  csdl_motor_vel_dp1_bp
  0x003A  csdl_motor_vel_dp2_elp25
  0x003B  csdl_motor_vel_hep 26
  0x003C  csdl_motor_settings 27
  0x003D  CSDL Wrap
  0x003E  SPARE 02
  0x003F  SPARE 01
  0x0040  subsystem reg 01 
  0x0041  subsystem reg 02 
  0x0042  subsystem reg 03 
  0x0043  subsystem reg 04 
  0x0044  subsystem reg 05 
  0x0045  subsystem reg 06 
  0x0046  subsystem reg 07 
  0x0047  subsystem reg 08 
  0x0048  subsystem reg 09 
  0x0049  subsystem reg 10 
  0x004A  subsystem reg 11 
  0x004B  subsystem reg 12 
  0x004C  subsystem reg 13 
  0x004D  subsystem reg 14 
  0x004E  subsystem reg 15 
  0x004F  subsystem reg 16 
  0x0050  Subsystem CSDL read reg 01
  0x0051  Subsystem CSDL read reg 02
  0x0052  Subsystem CSDL read reg 03
  0x0053  Subsystem CSDL read reg 04
  0x0054  Subsystem CSDL read reg 05
  0x0055  Subsystem CSDL read reg 06
  0x0056  Subsystem CSDL read reg 07
  0x0057  Subsystem CSDL read reg 08
  0x0058  Subsystem CSDL read reg 09
  0x0059  Subsystem CSDL read reg 10
  0x005A  Subsystem CSDL read reg 11
  0x005B  Subsystem CSDL read reg 12
  0x005C  Subsystem CSDL read reg 13
  0x005D  Subsystem CSDL read reg 14
  0x005E  Subsystem CSDL read reg 15
  0x005F  Subsystem CSDL read reg 16  
  0x0060  GPRW 60 Monitors Enabled
  0x0061  GPRW 61 Monitors Triggered
  0x0062  GPRW 62 Monitors Masked
  0x0063  GPRW 63 Cmd Enables
  0x0064  GPRW 64 Monitors Tripped Flag Bit[N:0] = s24V,s5V,s1.5V,s1.2V,s3.3V,c24V,c5V,c1.5V,c1.2V,c3.3V
  0x0065  GPRW 65
  0x0066  GPRW 66 
  0x0067  GPRW 67 IO State Command (Treatment == 1d, 1e, 1f, 20, 21, 22)
  0x0068  GPRW 68 Blood Flow Rate / RPM Command
  0x0069  GPRW 69 Dialysate Flow Rate / RPM Command
  0x006a  GPRW 6A DP2 Command
  0x006b  GPRW 6B IC Command
  0x006c  GPRW 6C HEP Command
  0x006d  GPRW 6D Temperature Command
  0x006e  GPRW 6E UF Goal
  0x006f  GPRW 6F Treatment Time
  0x0070  GPRW 70  Debug 1
  0x0071  GPRW 71  Debug 2
  0x0072  GPRW 72  Debug 3
  0x0073  GPRW 73  Debug 4
  0x0074  GPRW 74  Debug 5
  0x0075  GPRW 75  Debug 6
  0x0076  GPRW 76  Debug 7
  0x0077  GPRW 77  Debug 8
  0x0078  GPRW 78
  0x0079  GPRW 79
  0x007a  GPRW 7A  UF Removed Update from Loop
  0x007b  GPRW 7B  UF Rate Calculated from Loop
  0x007c  GPRW 7C  Temperature Updated from System
  0x007d  GPRW 7D  Treatment Time Lapsed
  0x007e  GPRW 7E  Treatment Time Remaining
  0x007f  GPRW 7F Indicated Sequence Running 
  ------------------------------------------------------------------------*/ 

//WRITE REGISTERS:  
  //0x0000  System Timing Syncronization Strobe
  reg       wreg_sys_strb;     
  //0x0001  One Bit DAC Control Register
  //        Bit[0] : DSM Enable == 1, Disable == 0    
  reg       wreg_DSM_en;     
  //        Bit[1] : ADC1 Enable == 1, Disable == 0
  reg       wreg_ADC1_en;     
  //        Bit[2] : ADC2 Enable == 1, Disable == 0  
  reg       wreg_DRS_en;     
  //        Bit[3] : DAC Enable == 1, Disable == 0  
  reg       wreg_DAC_en;      
  //        Bit[8] : AIL Enable == 1, Disable == 0  
  reg       wreg_SUB_en;
  //        Bit[9] : AIL Enable == 1, Disable == 0     
  reg       wreg_CSDL_en;
  //        Bit[35]: SYS Enable == 1, Disable == 0  
  reg       wreg_System_en; 
  //0x0002  Command Sub System Sequence to run (Sequence Address, Count, Strb)
  //        Bit[  8:0] :  Address to run sub sequence
  //        Bit[20:12] :  Number of nets to run  
  reg[35:0] wreg_sub_seq_cmd;   
  //0x0003  CSDL Wrap
  reg[35:0] wreg_csdl_wrap;
  //0x0004  
  reg[35:0] wreg_Scale_Correction;
  //0x0005  
  //reg[35:0] wreg_Spare_10;
  //0x0006  Fan PWM Frequency
  reg[7:0]  wreg_Fan_period;    // Bit[15:0] = pwm total period in us
  //0x0007  Fan PWM Duty Cycle
  reg[7:0]  wreg_Fan_pwm;     // Bit[15:0] = pwm on period in us
  //0x0008  Fan Control Register
  //        Bit[0] : Enable == 1, Disable == 0
  reg       wreg_Fan1_en; 
  //        Bit[1] : Enable == 1, Disable == 0
  reg       wreg_Fan2_en; 
  //0x0009  Temperature Test Control
  //        Bit[0] : Enable == 1, Disable == 0  
  reg       wreg_TempTest;
  //0x000A  Program Net List Address 
  reg[8:0]  wreg_netlist_address;
  //0x000B  Program Net List Data (+Strb)
  reg[35:0] wreg_netlist_data;
  //0x000C  
  //reg[35:0] wreg_Spare_09;
  //0x000D  
  //reg[35:0] wreg_Spare_08;
  //0x000E  COM Flags
  //        Bit[0] = Discrete 1 (Switch Actel Pass Thru)
  //        Bit[1] = Discrete 2
  reg [1:0] wreg_COM_Cntrl;
  //0x000F  
  reg[15:0] wreg_DSM_freq;   // Bit[15:0] = clks to move through table. 60 rows in table for 1 cycle. 
  //0x0010  Solenoid RAC Latch PWM Period
  reg[7:0]  wreg_SOL_RL_period;
  //0x0011  Solenoid RAC Latch PWM On Period
  reg[7:0]  wreg_SOL_RL_pwm;
  //0x0012  Solenoid RAC Latch Enable
  reg       wreg_SOL_RL_en;
  //0x0013  Solenoid Door Lock PWM Period
  reg[7:0]  wreg_SOL_DL_period;
  //0x0014  Solenoid Door Lock PWM On Period
  reg[7:0]  wreg_SOL_DL_pwm;
  //0x0015  Solenoid Door Lock Enable
  reg       wreg_SOL_DL_en;
  //0x0016  Solenoid Venous Clamp PWM Period
  reg[7:0]  wreg_SOL_VC_period;
  //0x0017  Solenoid Venous Clamp PWM On Period
  reg[7:0]  wreg_SOL_VC_pwm;
  //0x0018  Solenoid Venous Clamp Enable
  reg       wreg_SOL_VC_en;
  //0x0019  
  //reg[35:0] wreg_Spare_07;
  //0x001A  
  reg[35:0] wreg_NVM_Command;
  //0x001B  
  reg[35:0] wreg_NVM_Wr_Data;
  //0x001C  
  reg[35:0] wreg_Kpuf;
  //0x001D  
  reg[35:0] wreg_Kpufr;
  //0x001E  
  reg[35:0] wreg_Kiufr;
  //0x001F  
  reg[35:0] wreg_Kdufr;
  //0x0020  wreg_DAC_CH0
  wire[7:0] wreg_DAC_CH0;
  //0x0021  wreg_DAC_CH1
  wire[7:0] wreg_DAC_CH1;
  //0x0022  wreg_DAC_CH2
  wire[7:0] wreg_DAC_CH2;
  //0x0023  wreg_DAC_CH3
  reg[7:0] wreg_DAC_CH3;
  //0x0024  wreg_DAC_CH4
  reg[7:0] wreg_DAC_CH4;
  //0x0025  wreg_DAC_CH5
  //reg[7:0] wreg_DAC_CH5;
  //0x0026  wreg_DAC_CH6
  reg[7:0] wreg_DAC_CH6;
  //0x0027  wreg_DAC_CH7
  reg[7:0] wreg_DAC_CH7;
  
  //0x0028 wreg_Motor_BP_ustep    // 2 bits
  reg      wreg_Motor_BP_Dir;
  wire[1:0] wreg_Motor_BP_ustep;
  //0x0029 wreg_Motor_BP_Acc      // 1 bit
  reg[35:0] wreg_Motor_BP_Acc;
  //0x002a wreg_Motor_BP_Vel      //16 bits
  reg[35:0] wreg_Motor_BP_Vel;
  //0x002b wreg_Motor_BP_enable   // 1 bit
  reg      wreg_Motor_BP_enable;
  //0x002c wreg_Motor_DP1_ustep   // 2 bits
  reg      wreg_Motor_DP1_Dir;
  wire[1:0] wreg_Motor_DP1_ustep;
  //0x002d wreg_Motor_DP1_Acc     // 1 bit 
  reg[35:0] wreg_Motor_DP1_Acc;
  //0x002e wreg_Motor_DP1_Vel     //16 bits
  reg[35:0] wreg_Motor_DP1_Vel;
  //0x002f wreg_Motor_DP1_enable  // 1 bit
  reg      wreg_Motor_DP1_enable;
  //0x0030 wreg_Motor_DP2_ustep   // 2 bits
  reg      wreg_Motor_DP2_Dir;
  wire[1:0] wreg_Motor_DP2_ustep;
  //0x0031 wreg_Motor_DP2_Acc     // 1 bit
  reg[35:0] wreg_Motor_DP2_Acc;
  //0x0032 wreg_Motor_DP2_Vel     //16 bits
  reg[35:0]wreg_Motor_DP2_Vel;
  //0x0033 wreg_Motor_DP2_enable  // 1 bit
  reg      wreg_Motor_DP2_enable;
  //0x0034 wreg_Motor_ELP_ustep   // 2 bits
  reg      wreg_Motor_ELP_Dir;
  reg[1:0] wreg_Motor_ELP_ustep;
  //0x0035 wreg_Motor_ELP_Acc     // 1 bit 
  reg[35:0] wreg_Motor_ELP_Acc;
  //0x0036 wreg_Motor_ELP_Vel     //16 bits
  reg[35:0] wreg_Motor_ELP_Vel;
  //0x0037 wreg_Motor_ELP_enable  // 1 bit
  reg      wreg_Motor_ELP_enable;
  //0x0038 wreg_Motor_HEP_ustep   // 2 bits
  reg      wreg_Motor_HEP_Dir;
  reg[1:0] wreg_Motor_HEP_ustep;
  //0x0039 wreg_Motor_HEP_Acc     // 1 bit
  reg[35:0] wreg_Motor_HEP_Acc;
  //0x003a wreg_Motor_HEP_Vel     //16 bits
  reg[35:0]wreg_Motor_HEP_Vel;
  //0x003b wreg_Motor_HEP_enable  // 1 bit
  reg      wreg_Motor_HEP_enable;
  //0x003c ADM Command writes     // 1 bits
  // Bit [0] : 1 == close, 0 = open
  reg      wreg_ADM_open_strb;
  reg      wreg_ADM_close_strb;
  //0x003d 
  reg       wreg_ADM_clr_strb;
  //0x003e 
  //reg[35:0] wreg_Spare_02;
  //0x003f 
  //reg[35:0] wreg_Spare_01;
  //0x0040  
  reg[31:0] subsystem_op_en;
  //0x0041
  reg[35:0] subsystem_wr_02;
  //0x0042
  reg[35:0] subsystem_wr_03;
  //0x0043
  reg[35:0] subsystem_wr_04;
  //0x0044
  reg[35:0] subsystem_wr_05;
  //0x0045
  reg[35:0] subsystem_wr_06;
  //0x0046
  reg[35:0] subsystem_wr_07;
  //0x0047
  reg[35:0] subsystem_wr_08;
  //0x0048
  reg[35:0] subsystem_wr_09;
  //0x0049
  reg[35:0] subsystem_wr_10;
  //0x004A
  reg[35:0] subsystem_wr_11;
  //0x004B
  reg[35:0] subsystem_wr_12;
  //0x004C
  reg[35:0] subsystem_wr_13;
  //0x004D
  reg[35:0] subsystem_wr_14;
  //0x004E
  reg[35:0] subsystem_wr_15;
  //0x004F
  reg[35:0] subsystem_wr_16;
  //0x0050  
  reg[31:0] csdl_op_en;
  //0x0051
  reg[35:0] csdl_wr_02;
  //0x0052
  reg[35:0] csdl_wr_03;
  //0x0053
  reg[35:0] csdl_wr_04;
  //0x0054
  reg[35:0] csdl_wr_05;
  //0x0055
  reg[35:0] csdl_wr_06;
  //0x0056
  reg[35:0] csdl_wr_07;
  //0x0057
  reg[35:0] csdl_wr_08;
  //0x0058
  reg[35:0] csdl_wr_09;
  //0x0059
  reg[35:0] csdl_wr_10;
  //0x005A
  reg[35:0] csdl_wr_11;
  //0x005B
  reg[35:0] csdl_wr_12; 
  //0x005C
  reg[35:0] csdl_wr_13;
  //0x005D
  reg[35:0] csdl_wr_14;
  //0x005E
  reg[35:0] csdl_wr_15;
  //0x005F
  reg[35:0] csdl_wr_16;   
  //0x0060
  reg[35:0] wreg_GPRW_60;
  //0x0061
  reg[35:0] wreg_GPRW_61;
  //0x0062
  reg[35:0] wreg_GPRW_62;
  //0x0063
  reg[35:0] wreg_GPRW_63;
  //0x0064
  reg[35:0] wreg_GPRW_64;
  //0x0065
  reg[35:0] wreg_GPRW_65;
  //0x0066
  reg[35:0] wreg_GPRW_66;
  //0x0067
  reg[35:0] wreg_GPRW_67;
  //0x0068
  reg[35:0] wreg_GPRW_68;
  //0x0069
  reg[35:0] wreg_GPRW_69;
  //0x006A
  reg[35:0] wreg_GPRW_6A;
  //0x006B
  reg[35:0] wreg_GPRW_6B;
  //0x006C
  reg[35:0] wreg_GPRW_6C;
  //0x006D
  reg[35:0] wreg_GPRW_6D;
  //0x006E
  reg[35:0] wreg_GPRW_6E;
  //0x006F
  reg[35:0] wreg_GPRW_6F;
  //0x0070
  reg[35:0] wreg_GPRW_70;
  //0x0071
  reg[35:0] wreg_GPRW_71;
  //0x0072
  reg[35:0] wreg_GPRW_72;
  //0x0073
  reg[35:0] wreg_GPRW_73;
  //0x0074
  reg[35:0] wreg_GPRW_74;
  //0x0075
  reg[35:0] wreg_GPRW_75;
  //0x0076
  reg[35:0] wreg_GPRW_76;
  //0x0077
  reg[35:0] wreg_GPRW_77;
  //0x0078
  reg[35:0] wreg_GPRW_78;
  //0x0079
  reg[35:0] wreg_GPRW_79;
  //0x007A
  reg[35:0] wreg_GPRW_7A;
  //0x007B
  reg[35:0] wreg_GPRW_7B;
  //0x007C
  reg[35:0] wreg_GPRW_7C;
  //0x007D
  reg[35:0] wreg_GPRW_7D;
  //0x007E
  reg[35:0] wreg_GPRW_7E;
  //0x007F
  reg[35:0] wreg_GPRW_7F;
    
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
  //0x0006  SPARE
  //reg[35:0] rreg_Spare_26;
  //0x0007  SPARE
  //reg[35:0] rreg_Spare_25;
  //0x0008  rreg_ADC1_MUX1A_CH0
  reg[15:0] rreg_ADC1_MUX1A_CH0;
  //0x0009  rreg_ADC1_MUX1A_CH1
  reg[15:0] rreg_ADC1_MUX1A_CH1;
  //0x000A  rreg_ADC1_MUX1A_CH2
  reg[15:0] rreg_ADC1_MUX1A_CH2;
  //0x000B  rreg_ADC1_MUX1A_CH3
  reg[15:0] rreg_ADC1_MUX1A_CH3;
  //0x000C  rreg_ADC1_MUX1B_CH0
  reg[15:0] rreg_ADC1_MUX1B_CH0;
  //0x000D  rreg_ADC1_MUX1B_CH1
  reg[15:0] rreg_ADC1_MUX1B_CH1;
  //0x000E  rreg_ADC1_MUX1B_CH2
  reg[15:0] rreg_ADC1_MUX1B_CH2;
  //0x000F  rreg_ADC1_MUX1B_CH3
  reg[15:0] rreg_ADC1_MUX1B_CH3;   
  //0x0010  
  reg[35:0] rreg_BP_Velocity;
  //0x0011  
  reg[2:0] rreg_BP_Encoder;
  //0x0012  
  reg[35:0] rreg_DP1_Velocity;
  //0x0013  
  reg[2:0] rreg_DP1_Encoder;
  //0x0014  
  reg[35:0] rreg_DP2_Velocity;
  //0x0015  
  reg[2:0] rreg_DP2_Encoder;
  //0x0016
  reg[35:0] rreg_ELP_Velocity;
  //0x0017
  reg[2:0] rreg_ELP_Encoder;
  //0x0018
  reg[35:0] rreg_HEP_Velocity;
  //0x0019 
  reg[2:0] rreg_HEP_Encoder;
  //0x001A 
  reg[35:0] rreg_DL_Velocity;
  //0x001B 
  reg[2:0] rreg_DL_Encoder;
  //0x001C  SPARE
  //reg[35:0] rreg_Spare_24;
  //0x001D  SPARE
  //reg[35:0] rreg_Spare_23;
  //0x001E  
  //reg[35:0] rreg_Spare_22;
  //0x001F  
  //reg[35:0] rreg_Spare_21; 
  //0x0020  FAN 1 TACH FBK
  reg[15:0] rreg_Fan1_Tach;  
  //0x0021  FAN 1 TACH FBK
  reg[15:0] rreg_Fan2_Tach;  
  //0x0022  TEMPERATURE
  reg[11:0] rreg_temperature;
  //0x0023  STATUS
  reg[35:0] rreg_status;
  //0x0024  DOOR REFERENCE SENSOR
  reg[1:0]  rreg_DRS;
  //0x0025  rreg_ADM_status
  reg[7:0]  rreg_ADM_status;
  //0x0026  SPARE
  //reg[35:0] rreg_Spare_20;
  //0x0027  SPARE
  //reg[35:0] rreg_Spare_19;
  //0x0028  SPARE
  //reg[35:0] rreg_Spare_18;
  //0x0029  SPARE
  //reg[35:0] rreg_Spare_17;
  //0x002A  
  reg[35:0] rreg_NVM_Command;
  //0x002B  
  reg[35:0] rreg_NVM_Wr_Data;
  //0x002C  
  //reg[35:0] rreg_Spare_16;
  //0x002D  
  //reg[35:0] rreg_Spare_15;
  //0x002E  
  //reg[35:0] rreg_Spare_14;
  //0x002F  
  //reg[35:0] rreg_Spare_13;
  //0x0030  
  //reg[35:0] rreg_Spare_12; 
  //0x0031  
  //reg[35:0] rreg_Spare_11; 
  //0x0032  
  //reg[35:0] rreg_Spare_10; 
  //0x0033  
  //reg[35:0] rreg_Spare_09; 
  //0x0034  
  reg[35:0] rreg_Scale_Correction; 
  //0x0035  
  reg[35:0] rreg_Kpuf; 
  //0x0036  
  reg[35:0] rreg_Kpufr; 
  //0x0037  
  reg[35:0] rreg_Kiufr; 
  //0x0038  
  reg[35:0] rreg_Kdufr; 
  //0x0039  
  reg[35:0] rreg_csdl_motor_vel_dp1_bp; 
  //0x003A  
  reg[35:0] rreg_csdl_motor_vel_dp2_elp; 
  //0x003B  
  reg[35:0] rreg_csdl_motor_vel_hep; 
  //0x003C  
  reg[35:0] rreg_csdl_motor_settings; 
  //0x003D  
  reg[35:0] rreg_csdl_wrap; 
  //0x003E  
  //reg[35:0] rreg_Spare_02; 
  //0x003F  
  //reg[35:0] rreg_Spare_01; 
  //0x0040
  wire[35:0] subsystem_reg_01;
  //0x0041
  wire[35:0] subsystem_reg_02;
  //0x0042
  wire[35:0] subsystem_reg_03;
  //0x0043
  wire[35:0] subsystem_reg_04;
  //0x0044
  wire[35:0] subsystem_reg_05;
  //0x0045
  wire[35:0] subsystem_reg_06;
  //0x0046
  wire[35:0] subsystem_reg_07;
  //0x0047
  wire[35:0] subsystem_reg_08;
  //0x0048
  wire[35:0] subsystem_reg_09;
  //0x0049
  wire[35:0] subsystem_reg_10;
  //0x004A
  wire[35:0] subsystem_reg_11;
  //0x004B
  wire[35:0] subsystem_reg_12;
  //0x004C
  wire[35:0] subsystem_reg_13;
  //0x004D
  wire[35:0] subsystem_reg_14;
  //0x004E
  wire[35:0] subsystem_reg_15;
  //0x004F
  wire[35:0] subsystem_reg_16;
  //0x0050
  wire[35:0] csdl_reg_01;
  //0x0051
  wire[35:0] csdl_reg_02;
  //0x0052
  wire[35:0] csdl_reg_03;
  //0x0053
  wire[35:0] csdl_reg_04;
  //0x0054
  wire[35:0] csdl_reg_05;
  //0x0055
  wire[35:0] csdl_reg_06;
  //0x0056
  wire[35:0] csdl_reg_07;
  //0x0057
  wire[35:0] csdl_reg_08;
  //0x0058
  wire[35:0] csdl_reg_09;
  //0x0059
  wire[35:0] csdl_reg_10;
  //0x005A
  wire[35:0] csdl_reg_11;
  //0x005B
  wire[35:0] csdl_reg_12;
  //0x005C
  wire[35:0] csdl_reg_13;
  //0x005D
  wire[35:0] csdl_reg_14;
  //0x005E
  wire[35:0] csdl_reg_15;
  //0x005F
  wire[35:0] csdl_reg_16;     
  //0x0060
  reg[35:0] rreg_GPRW_60;
  //0x0061
  reg[35:0] rreg_GPRW_61;
  //0x0062
  reg[35:0] rreg_GPRW_62;
  //0x0063
  reg[35:0] rreg_GPRW_63;
  //0x0064
  reg[35:0] rreg_GPRW_64;
  //0x0065
  reg[35:0] rreg_GPRW_65;
  //0x0066
  reg[35:0] rreg_GPRW_66;
  //0x0067
  reg[35:0] rreg_GPRW_67;
  //0x0068
  reg[35:0] rreg_GPRW_68;
  //0x0069
  reg[35:0] rreg_GPRW_69;
  //0x006A
  reg[35:0] rreg_GPRW_6A;
  //0x006B
  reg[35:0] rreg_GPRW_6B;
  //0x006C
  reg[35:0] rreg_GPRW_6C;
  //0x006D
  reg[35:0] rreg_GPRW_6D;
  //0x006E
  reg[35:0] rreg_GPRW_6E;
  //0x006F
  reg[35:0] rreg_GPRW_6F;
  //0x0070
  reg[35:0] rreg_GPRW_70;
  //0x0071
  reg[35:0] rreg_GPRW_71;
  //0x0072
  reg[35:0] rreg_GPRW_72;
  //0x0073
  reg[35:0] rreg_GPRW_73;
  //0x0074
  reg[35:0] rreg_GPRW_74;
  //0x0075
  reg[35:0] rreg_GPRW_75;
  //0x0076
  reg[35:0] rreg_GPRW_76;
  //0x0077
  reg[35:0] rreg_GPRW_77;
  //0x0078
  reg[35:0] rreg_GPRW_78;
  //0x0079
  reg[35:0] rreg_GPRW_79;
  //0x007A
  reg[35:0] rreg_GPRW_7A;
  //0x007B
  reg[35:0] rreg_GPRW_7B;
  //0x007C
  reg[35:0] rreg_GPRW_7C;
  //0x007D
  reg[35:0] rreg_GPRW_7D;
  //0x007E
  reg[35:0] rreg_GPRW_7E;
  //0x007F
  reg[35:0] rreg_GPRW_7F;    
  
  reg[3:0]      bc_strb;    
  reg           wr_strb_Z1;    
  
  reg           ld_freq;   
  reg           ld_Fan;   
  reg           FanPWM1;  
  reg           FanPWM2;  
  
  wire [1:0]    subsystem_err;
  wire [1:0]    csdl_err;
  
  reg [35:0]    reg_selected;  
  
  reg           adc1_error;
  wire [2:0]    adc1_num;
  wire [2:0]    adc1_addr;
  wire [1:0]    mux_num;    
  wire          adc1_smpl_strb;
  wire          adc1_data_strb;
  wire [15:0]   adc1_data;  
  wire          adc1_busy_err;

  wire          Fan_PWM_Signal;
  wire [15:0]   fan1_tach_pps;
  wire [15:0]   fan2_tach_pps;
  
  wire [11:0]   temp_sense;
  wire          temp_status;
  wire          temp_strb;   
     
  reg           ld_sol_rl_pwm;
  reg           ld_sol_dl_pwm;
  reg           ld_sol_vc_pwm;  
  
  wire [35:0]   BP_Velocity;
  wire  [2:0]   BP_Encoder;
  wire [35:0]   DP1_Velocity;
  wire  [2:0]   DP1_Encoder;
  wire [35:0]   DP2_Velocity;
  wire  [2:0]   DP2_Encoder;
  wire [35:0]   ELP_Velocity;
  wire  [2:0]   ELP_Encoder;
  wire [35:0]   HEP_Velocity;
  wire  [2:0]   HEP_Encoder;
  wire [35:0]   DL_Velocity;
  wire  [2:0]   DL_Encoder;  
  
  wire          adm_status_strb;
  wire [2:0]    adm_door_status;
  wire [7:0]    adm_motor_curr;
  wire          adm_stalling;
  
  wire [35:0]   csdl_motor_vel_dp1_bp;
  wire [35:0]   csdl_motor_vel_dp2_elp;
  wire [35:0]   csdl_motor_vel_hep;
  wire [35:0]   csdl_motor_settings;
        
  wire [15:0]   state_debug;
  wire [LS-1:0] seq_debug;
  
  wire          seq_list_done_strb;
  wire [LS-1:0] seq_list_en;  
  
  reg           wr_seq_strb;  
  reg           wr_seq_strb_Z1;  
    
	initial			
	begin    
    wreg_sys_strb           <= 1'b0;
    wreg_DSM_en             <= 1'b1;
    wreg_ADC1_en            <= 1'b1;
    wreg_DRS_en             <= 1'b1;
    wreg_DAC_en             <= 1'b1;
    wreg_SUB_en             <= 1'b0;
    wreg_System_en          <= 1'b0;
    wreg_sub_seq_cmd        <= 36'h000000000;    
    wreg_csdl_wrap          <= 36'h000000000;
    wreg_Scale_Correction   <= 36'h000040000;
    
    wreg_Kpuf               <= 36'h000040000;
    wreg_Kpufr              <= 36'h000040000;
    wreg_Kiufr              <= 36'h000000000;
    wreg_Kdufr              <= 36'h000000000;
    
    
    wreg_Fan_period         <= {8{1'b0}};
    wreg_Fan_pwm            <= {8{1'b0}};
    wreg_Fan1_en            <= 1'b0;
    wreg_Fan2_en            <= 1'b0;
    wreg_TempTest           <= 1'b0;
    wreg_netlist_address    <= 9'h000;
    wreg_netlist_data       <= {36{1'b0}};
    net_wr_strb             <= 1'b0;
    
    wreg_COM_Cntrl          <= 2'b01;
    wreg_DSM_freq           <= {16{1'b0}};
    wreg_SOL_RL_en          <= 1'b0;
    wreg_SOL_RL_period      <= {8{1'b0}};
    wreg_SOL_RL_pwm         <= {8{1'b0}};
    ld_sol_rl_pwm           <= 1'b0;
    wreg_SOL_DL_en          <= 1'b0;
    wreg_SOL_DL_period      <= {8{1'b0}};
    wreg_SOL_DL_pwm         <= {8{1'b0}};
    ld_sol_dl_pwm           <= 1'b0;
    wreg_SOL_VC_en          <= 1'b0;
    wreg_SOL_VC_period      <= {8{1'b0}};
    wreg_SOL_VC_pwm         <= {8{1'b0}};
    ld_sol_vc_pwm           <= 1'b0;
    
    wreg_NVM_Command        <= {36{1'b0}};
    wreg_NVM_Wr_Data        <= {36{1'b0}};
    
//    wreg_DAC_CH0            <= 8'h00;
//    wreg_DAC_CH1            <= 8'h00;
//    wreg_DAC_CH2            <= 8'h00;
    wreg_DAC_CH3            <= 8'h00;
    wreg_DAC_CH4            <= 8'h00;
//    wreg_DAC_CH5            <= 8'h00;
    wreg_DAC_CH6            <= 8'h00;
    wreg_DAC_CH7            <= 8'h00;
    
//    wreg_Motor_BP_ustep     <= 2'b00;
    wreg_Motor_BP_Dir       <= 1'b0;
    wreg_Motor_BP_Acc       <= {36{1'b0}};
    wreg_Motor_BP_Vel       <= {36{1'b0}};
    wreg_Motor_BP_enable    <= 1'b0;
  
//    wreg_Motor_DP1_ustep    <= 2'b00;
    wreg_Motor_DP1_Dir      <= 1'b0;
    wreg_Motor_DP1_Acc      <= {36{1'b0}};
    wreg_Motor_DP1_Vel      <= {36{1'b0}};
    wreg_Motor_DP1_enable   <= 1'b0;
  
//    wreg_Motor_DP2_ustep    <= 2'b00;
    wreg_Motor_DP2_Dir      <= 1'b0;
    wreg_Motor_DP2_Acc      <= {36{1'b0}};
    wreg_Motor_DP2_Vel      <= {36{1'b0}};
    wreg_Motor_DP2_enable   <= 1'b0;
  
    wreg_Motor_ELP_ustep    <= 2'b00;
    wreg_Motor_ELP_Dir      <= 1'b0;
    wreg_Motor_ELP_Acc      <= {36{1'b0}};
    wreg_Motor_ELP_Vel      <= {36{1'b0}};
    wreg_Motor_ELP_enable   <= 1'b0;
  
    wreg_Motor_HEP_ustep    <= 2'b00;
    wreg_Motor_HEP_Dir      <= 1'b0;
    wreg_Motor_HEP_Acc      <= {36{1'b0}};
    wreg_Motor_HEP_Vel      <= {36{1'b0}};
    wreg_Motor_HEP_enable   <= 1'b0;
      
    wreg_ADM_open_strb      <= 1'b0;  
    wreg_ADM_close_strb     <= 1'b0;    
    wreg_ADM_clr_strb       <= 1'b0;        
    
    subsystem_op_en         <= {32{1'b0}};
    subsystem_wr_02         <= {36{1'b0}};
    subsystem_wr_03         <= {36{1'b0}};
    subsystem_wr_04         <= {36{1'b0}};
    subsystem_wr_05         <= {36{1'b0}};
    subsystem_wr_06         <= {36{1'b0}};
    subsystem_wr_07         <= {36{1'b0}};
    subsystem_wr_08         <= {36{1'b0}};
    subsystem_wr_09         <= {36{1'b0}};
    subsystem_wr_10         <= {36{1'b0}};
    subsystem_wr_11         <= {36{1'b0}};
    subsystem_wr_12         <= {36{1'b0}};
    subsystem_wr_13         <= {36{1'b0}};
    subsystem_wr_14         <= {36{1'b0}};
    subsystem_wr_15         <= {36{1'b0}};
    subsystem_wr_16         <= {36{1'b0}};
    
    csdl_op_en              <= {32{1'b0}};
    csdl_wr_02              <= {36{1'b0}};
    csdl_wr_03              <= {36{1'b0}};
    csdl_wr_04              <= {36{1'b0}};
    csdl_wr_05              <= {36{1'b0}};
    csdl_wr_06              <= {36{1'b0}};
    csdl_wr_07              <= {36{1'b0}};
    csdl_wr_08              <= {36{1'b0}};
    csdl_wr_09              <= {36{1'b0}};
    csdl_wr_10              <= {36{1'b0}};
    csdl_wr_11              <= {36{1'b0}};
    csdl_wr_12              <= {36{1'b0}};
    csdl_wr_13              <= {36{1'b0}};
    csdl_wr_14              <= {36{1'b0}};
    csdl_wr_15              <= {36{1'b0}};
    csdl_wr_16              <= {36{1'b0}};
    
    wreg_GPRW_60            <= {36{1'b0}};
    wreg_GPRW_61            <= {36{1'b0}};
    wreg_GPRW_62            <= {36{1'b0}};
    wreg_GPRW_63            <= {36{1'b0}};
    wreg_GPRW_64            <= {36{1'b0}};
    wreg_GPRW_65            <= {36{1'b0}};
    wreg_GPRW_66            <= {36{1'b0}};
    wreg_GPRW_67            <= {36{1'b0}};
    wreg_GPRW_68            <= {36{1'b0}};
    wreg_GPRW_69            <= {36{1'b0}};
    wreg_GPRW_6A            <= {36{1'b0}};
    wreg_GPRW_6B            <= {36{1'b0}};
    wreg_GPRW_6C            <= {36{1'b0}};
    wreg_GPRW_6D            <= {36{1'b0}};
    wreg_GPRW_6E            <= {36{1'b0}};
    wreg_GPRW_6F            <= {36{1'b0}};
    wreg_GPRW_70            <= {36{1'b0}};
    wreg_GPRW_71            <= {36{1'b0}};
    wreg_GPRW_72            <= {36{1'b0}};
    wreg_GPRW_73            <= {36{1'b0}};
    wreg_GPRW_74            <= {36{1'b0}};
    wreg_GPRW_75            <= {36{1'b0}};
    wreg_GPRW_76            <= {36{1'b0}};
    wreg_GPRW_77            <= {36{1'b0}};
    wreg_GPRW_78            <= {36{1'b0}};
    wreg_GPRW_79            <= {36{1'b0}};
    wreg_GPRW_7A            <= {36{1'b0}};
    wreg_GPRW_7B            <= {36{1'b0}};
    wreg_GPRW_7C            <= {36{1'b0}};
    wreg_GPRW_7D            <= {36{1'b0}};
    wreg_GPRW_7E            <= {36{1'b0}};
    wreg_GPRW_7F            <= {36{1'b0}};    
    
    rreg_ADC1_NOMUX_CH0     <= {16{1'b0}};
    rreg_ADC1_NOMUX_CH1     <= {16{1'b0}};
    rreg_ADC1_NOMUX_CH2     <= {16{1'b0}};
    rreg_ADC1_NOMUX_CH3     <= {16{1'b0}};
    rreg_ADC1_NOMUX_CH4     <= {16{1'b0}};
    rreg_ADC1_NOMUX_CH5     <= {16{1'b0}};    
            
    rreg_ADC1_MUX1A_CH0     <= {16{1'b0}};
    rreg_ADC1_MUX1A_CH1     <= {16{1'b0}};
    rreg_ADC1_MUX1A_CH2     <= {16{1'b0}};
    rreg_ADC1_MUX1A_CH3     <= {16{1'b0}};
    rreg_ADC1_MUX1B_CH0     <= {16{1'b0}};
    rreg_ADC1_MUX1B_CH1     <= {16{1'b0}};
    rreg_ADC1_MUX1B_CH2     <= {16{1'b0}};
    rreg_ADC1_MUX1B_CH3     <= {16{1'b0}};
    
    rreg_BP_Velocity        <= {36{1'b0}};
    rreg_BP_Encoder         <= {3{1'b0}};
    rreg_DP1_Velocity       <= {36{1'b0}};
    rreg_DP1_Encoder        <= {3{1'b0}};
    rreg_DP2_Velocity       <= {36{1'b0}};
    rreg_DP2_Encoder        <= {3{1'b0}};
    rreg_ELP_Velocity       <= {36{1'b0}};
    rreg_ELP_Encoder        <= {3{1'b0}};
    rreg_HEP_Velocity       <= {36{1'b0}};
    rreg_HEP_Encoder        <= {3{1'b0}};
    rreg_DL_Velocity        <= {36{1'b0}};
    rreg_DL_Encoder         <= {3{1'b0}};
    
    
    rreg_Fan1_Tach          <= {16{1'b0}};
    rreg_Fan2_Tach          <= {16{1'b0}};
    rreg_temperature        <= 12'h000;
    rreg_status             <= {36{1'b0}};
    rreg_DRS                <= 2'b00;
    rreg_ADM_status         <= 8'h00;             
    
    rreg_NVM_Command        <= {36{1'b0}};
    rreg_NVM_Wr_Data        <= {36{1'b0}};
        
    rreg_csdl_motor_vel_dp1_bp  <= {36{1'b0}};
    rreg_csdl_motor_vel_dp2_elp <= {36{1'b0}};
    rreg_csdl_motor_vel_hep     <= {36{1'b0}};
    rreg_csdl_motor_settings    <= {36{1'b0}};
    rreg_csdl_wrap              <= {36{1'b0}};
    
    rreg_Scale_Correction   <= 36'h000040000;
    
    rreg_Kpuf               <= 36'h000040000;
    rreg_Kpufr              <= 36'h000040000;
    rreg_Kiufr              <= 36'h000000000;
    rreg_Kdufr              <= 36'h000000000;
    
    rreg_GPRW_60            <= {36{1'b0}};
    rreg_GPRW_61            <= {36{1'b0}};
    rreg_GPRW_62            <= {36{1'b0}};
    rreg_GPRW_63            <= {36{1'b0}};
    rreg_GPRW_64            <= {36{1'b0}};
    rreg_GPRW_65            <= {36{1'b0}};
    rreg_GPRW_66            <= {36{1'b0}};
    rreg_GPRW_67            <= {36{1'b0}};
    rreg_GPRW_68            <= {36{1'b0}};
    rreg_GPRW_69            <= {36{1'b0}};
    rreg_GPRW_6A            <= {36{1'b0}};
    rreg_GPRW_6B            <= {36{1'b0}};
    rreg_GPRW_6C            <= {36{1'b0}};
    rreg_GPRW_6D            <= {36{1'b0}};
    rreg_GPRW_6E            <= {36{1'b0}};
    rreg_GPRW_6F            <= {36{1'b0}};
    rreg_GPRW_70            <= {36{1'b0}};
    rreg_GPRW_71            <= {36{1'b0}};
    rreg_GPRW_72            <= {36{1'b0}};
    rreg_GPRW_73            <= {36{1'b0}};
    rreg_GPRW_74            <= {36{1'b0}};
    rreg_GPRW_75            <= {36{1'b0}};
    rreg_GPRW_76            <= {36{1'b0}};
    rreg_GPRW_77            <= {36{1'b0}};
    rreg_GPRW_78            <= {36{1'b0}};
    rreg_GPRW_79            <= {36{1'b0}};
    rreg_GPRW_7A            <= {36{1'b0}};
    rreg_GPRW_7B            <= {36{1'b0}};
    rreg_GPRW_7C            <= {36{1'b0}};
    rreg_GPRW_7D            <= {36{1'b0}};
    rreg_GPRW_7E            <= {36{1'b0}};
    rreg_GPRW_7F            <= {36{1'b0}};     

    wr_seq_strb             <= 1'b0;
    wr_seq_strb_Z1          <= 1'b0;
    
    bc_strb                 <= 4'b0001;   
    wr_strb_Z1              <= 1'b0;
    adc1_error              <= 1'b0;
    ld_freq                 <= 1'b0;
    ld_Fan                  <= 1'b0;
    FanPWM1                 <= 1'b0;
    FanPWM2                 <= 1'b0;           
    LogicAnalyzer           <= 16'h0000;
	end   
  
  //Delayed write strobe by 1 clock
  always@(posedge clk)
  begin
    if (reset)    
      wr_strb_Z1 <= 1'b0;
    else
      wr_strb_Z1 <= wr_strb;
  end
     
//--------------------------------------------------------
// WRITE REGISTERS
  
  // Write to wreg_sys_strb
  always@(posedge clk)
	begin
    if (reset)
      wreg_sys_strb <= 1'b0;
    else if (wr_addr == 8'h00 && wr_strb)
      wreg_sys_strb <= wr_data[0];
    else
      wreg_sys_strb <= 1'b0;
  end  
  
  // Wire the sync strobe to a write to this address
  assign sync_strb = wreg_sys_strb;     
  
  // Load frequency strobe to DSM  
  always@(posedge clk)
	begin
    if (reset)
      ld_freq <= 1'b0;
    else if (wr_addr == 8'h00 && wr_strb)
      ld_freq <= 1'b1;
    else
      ld_freq <= 1'b0;
  end  
  
  // Write to wreg_ Enables
  always@(posedge clk)
	begin
    if (reset) begin
      wreg_DSM_en     <= 1'b1;
      wreg_ADC1_en    <= 1'b1;
      wreg_DRS_en     <= 1'b1;
      wreg_DAC_en     <= 1'b1;
      wreg_SUB_en     <= 1'b0;
      wreg_CSDL_en    <= 1'b0;
      wreg_System_en  <= 1'b0;
    end else if (wr_addr == 8'h01 && wr_strb) begin      
      wreg_DSM_en     <= wr_data[0];
      wreg_ADC1_en    <= wr_data[1];
      wreg_DRS_en     <= wr_data[2];
      wreg_DAC_en     <= wr_data[3];
      wreg_SUB_en     <= wr_data[8];
      wreg_CSDL_en    <= wr_data[9];
      wreg_System_en  <= wr_data[35];
    end
  end  
    
  // Write to wreg_csdl_wrap
  always@(posedge clk)
	begin
    if (reset)
      wreg_csdl_wrap <= 36'h000000000;
    else if (wr_addr == 8'h03 && wr_strb)
      wreg_csdl_wrap <= wr_data[35:0];      
  end   
  
  
  // Write to wreg_Scale_Correction
  always@(posedge clk)
	begin
    if (reset)
      wreg_Scale_Correction <= 36'h000040000;
    else if (wr_addr == 8'h04 && wr_strb)
      wreg_Scale_Correction <= wr_data[35:0];      
  end   
    
  // Write to wreg_Fan_freq
  always@(posedge clk)
	begin
    if (reset)
      wreg_Fan_period <= 8'h00;
    else if (wr_addr == 8'h06 && wr_strb)
      wreg_Fan_period <= wr_data[7:0];      
  end  
  
  // Write to wreg_Fan_pwm
  always@(posedge clk)
	begin
    if (reset)
      wreg_Fan_pwm <= 8'h00;
    else if (wr_addr == 8'h07 && wr_strb)
      wreg_Fan_pwm <= wr_data[7:0];      
  end  
  
  // Load period for FAN
  always@(posedge clk)
	begin
    if (reset)
      ld_Fan <= 1'b0;
    else if (wr_addr == 8'h07 && wr_strb)
      ld_Fan <= 1'b1;
    else
      ld_Fan <= 1'b0;
  end   
  
  // Write to wreg_Fan_en
  always@(posedge clk)
	begin
    if (reset) begin
      wreg_Fan1_en <= 1'b0;
      wreg_Fan2_en <= 1'b0;
    end else if (wr_addr == 8'h08 && wr_strb) begin
      wreg_Fan1_en <= wr_data[0];      
      wreg_Fan2_en <= wr_data[1];      
    end
  end  
  
  // Write to wreg_TempTest
  always@(posedge clk)
	begin
    if (reset)
      wreg_TempTest <= 1'b0;
    else if (wr_addr == 8'h09 && wr_strb)
      wreg_TempTest <= wr_data[0];      
  end   
  
  // Write to wreg_netlist_address
  always@(posedge clk)
	begin
    if (reset)
      wreg_netlist_address <= 1'b0;
    else if (wr_addr == 8'h0A && wr_strb)
      wreg_netlist_address <= wr_data[8:0];
  end   
  
  // Write to wreg_netlist_address
  always@(posedge clk)
	begin
    if (reset)
      wreg_netlist_data <= {36{1'b0}};
    else if (wr_addr == 8'h0B && wr_strb)
      wreg_netlist_data <= wr_data[8:0];      
  end     
  
  // Write to wreg_netlist_address
  always@(posedge clk)
	begin
    if (reset)
      net_wr_strb <= 1'b0;
    else if (wr_addr == 8'h0B && wr_strb)
      net_wr_strb <= 1'b1;
    else
      net_wr_strb <= 1'b0;
  end     

  assign net_wr_addr = wreg_netlist_address;
  assign net_wr_data = wreg_netlist_data;
  
  
  // Write to wreg_COM_Flag
  always@(posedge clk)
	begin
    if (reset)
      wreg_COM_Cntrl <= 2'b01;
    else if (wr_addr == 8'h0E && wr_strb)
      wreg_COM_Cntrl <= wr_data[1:0];      
  end                
  
  // Write to wreg_DSM_freq
  always@(posedge clk)
	begin
    if (reset)
      wreg_DSM_freq <= 16'h0000;
    else if (wr_addr == 8'h0F && wr_strb)
      wreg_DSM_freq <= wr_data[15:0];      
  end   
  
  // Write to wreg_SOL_RL_period
  always@(posedge clk)
	begin
    if (reset)
      wreg_SOL_RL_period <= 16'h0000;
    else if (wr_addr == 8'h10 && wr_strb)
      wreg_SOL_RL_period <= wr_data[7:0];      
  end  
  
  // Write to wreg_SOL_RL_pwm
  always@(posedge clk)
	begin
    if (reset)
      wreg_SOL_RL_pwm <= 16'h0000;
    else if (wr_addr == 8'h11 && wr_strb)
      wreg_SOL_RL_pwm <= wr_data[7:0];      
  end  
  
  // Load period for RL Solenoid
  always@(posedge clk)
	begin
    if (reset)
      ld_sol_rl_pwm <= 1'b0;
    else if (wr_addr == 8'h11 && wr_strb)
      ld_sol_rl_pwm <= 1'b1;
    else
      ld_sol_rl_pwm <= 1'b0;
  end   
  
  // Write to wreg_SOL_RL_en
  always@(posedge clk)
	begin
    if (reset)
      wreg_SOL_RL_en <= 1'b0;
    else if (wr_addr == 8'h12 && wr_strb)
      wreg_SOL_RL_en <= wr_data[0];            
  end  
   
    
  // Write to wreg_SOL_DL_period
  always@(posedge clk)
	begin
    if (reset)
      wreg_SOL_DL_period <= 16'h0000;
    else if (wr_addr == 8'h13 && wr_strb)
      wreg_SOL_DL_period <= wr_data[7:0];      
  end  
  
  // Write to wreg_SOL_DL_pwm
  always@(posedge clk)
	begin
    if (reset)
      wreg_SOL_DL_pwm <= 16'h0000;
    else if (wr_addr == 8'h14 && wr_strb)
      wreg_SOL_DL_pwm <= wr_data[7:0];      
  end  
  
  // Load period for DL Solenoid
  always@(posedge clk)
	begin
    if (reset)
      ld_sol_dl_pwm <= 1'b0;
    else if (wr_addr == 8'h14 && wr_strb)
      ld_sol_dl_pwm <= 1'b1;
    else
      ld_sol_dl_pwm <= 1'b0;
  end   
  
  // Write to wreg_SOL_DL_en
  always@(posedge clk)
	begin
    if (reset)
      wreg_SOL_DL_en <= 1'b0;
    else if (wr_addr == 8'h15 && wr_strb)
      wreg_SOL_DL_en <= wr_data[0];            
  end    
      
  // Write to wreg_SOL_VC_period
  always@(posedge clk)
	begin
    if (reset)
      wreg_SOL_VC_period <= 16'h0000;
    else if (wr_addr == 8'h16 && wr_strb)
      wreg_SOL_VC_period <= wr_data[7:0];      
  end  
  
  // Write to wreg_SOL_VC_pwm
  always@(posedge clk)
	begin
    if (reset)
      wreg_SOL_VC_pwm <= 16'h0000;
    else if (wr_addr == 8'h17 && wr_strb)
      wreg_SOL_VC_pwm <= wr_data[7:0];      
  end  
  
  // Load period for VC Solenoid
  always@(posedge clk)
	begin
    if (reset)
      ld_sol_vc_pwm <= 1'b0;
    else if (wr_addr == 8'h17 && wr_strb)
      ld_sol_vc_pwm <= 1'b1;
    else
      ld_sol_vc_pwm <= 1'b0;
  end   
  
  // Write to wreg_SOL_VC_en
  always@(posedge clk)
	begin
    if (reset)
      wreg_SOL_VC_en <= 1'b0;
    else if (wr_addr == 8'h18 && wr_strb)
      wreg_SOL_VC_en <= wr_data[0];            
  end          
    
  // Write to wreg_NVM_Command
  always@(posedge clk)
	begin
    if (reset)
      wreg_NVM_Command <= 36'h000000000;
    else if (wr_addr == 8'h1A && wr_strb)
      wreg_NVM_Command <= wr_data[35:0];      
  end
    
  // Write to wreg_NVM_Wr_Data
  always@(posedge clk)
	begin
    if (reset)
      wreg_NVM_Wr_Data <= 16'h0000;
    else if (wr_addr == 8'h1B && wr_strb)
      wreg_NVM_Wr_Data <= wr_data[15:0];      
  end
  
  
  // Write to wreg_Kpuf
  always@(posedge clk)
	begin
    if (reset)
      wreg_Kpuf <= 36'h000040000;
    else if (wr_addr == 8'h1C && wr_strb)
      wreg_Kpuf <= wr_data[35:0];      
  end

  // Write to wreg_Kpufr
  always@(posedge clk)
	begin
    if (reset)
      wreg_Kpufr <= 36'h000040000;
    else if (wr_addr == 8'h1D && wr_strb)
      wreg_Kpufr <= wr_data[35:0];      
  end
  
  // Write to wreg_Kiufr
  always@(posedge clk)
	begin
    if (reset)
      wreg_Kiufr <= 36'h000000000;
    else if (wr_addr == 8'h1E && wr_strb)
      wreg_Kiufr <= wr_data[35:0];      
  end
  
  // Write to wreg_Kdufr
  always@(posedge clk)
	begin
    if (reset)
      wreg_Kdufr <= 36'h000000000;
    else if (wr_addr == 8'h1F && wr_strb)
      wreg_Kdufr <= wr_data[35:0];      
  end  
  
//  // Write to wreg_DAC_CH0
//  always@(posedge clk)
//	begin
//    if (reset)
//      wreg_DAC_CH0 <= 8'h00;
//    else if (wr_addr == 8'h20 && wr_strb)
//      wreg_DAC_CH0 <= wr_data[7:0];      
//  end 

//  // Write to wreg_DAC_CH1
//  always@(posedge clk)
//	begin
//    if (reset)
//      wreg_DAC_CH1 <= 8'h00;
//    else if (wr_addr == 8'h21 && wr_strb)
//      wreg_DAC_CH1 <= wr_data[7:0];      
//  end 

//  // Write to wreg_DAC_CH2
//  always@(posedge clk)
//	begin
//    if (reset)
//      wreg_DAC_CH2 <= 8'h00;
//    else if (wr_addr == 8'h22 && wr_strb)
//      wreg_DAC_CH2 <= wr_data[7:0];      
//  end 
  
  // Write to wreg_DAC_CH3
  always@(posedge clk)
	begin
    if (reset)
      wreg_DAC_CH3 <= 8'h00;
    else if (wr_addr == 8'h23 && wr_strb)
      wreg_DAC_CH3 <= wr_data[7:0];      
  end 

  // Write to wreg_DAC_CH4
  always@(posedge clk)
	begin
    if (reset)
      wreg_DAC_CH4 <= 8'h04;
    else if (wr_addr == 8'h24 && wr_strb)
      wreg_DAC_CH4 <= wr_data[7:0];      
  end 
  
//  // Write to wreg_DAC_CH5
//  always@(posedge clk)
//	begin
//    if (reset)
//      wreg_DAC_CH5 <= 8'h00;
//    else if (wr_addr == 8'h25 && wr_strb)
//      wreg_DAC_CH5 <= wr_data[7:0];      
//  end 

  // Write to wreg_DAC_CH6
  always@(posedge clk)
	begin
    if (reset)
      wreg_DAC_CH6 <= 8'h00;
    else if (wr_addr == 8'h26 && wr_strb)
      wreg_DAC_CH6 <= wr_data[7:0];      
  end 
  
  // Write to wreg_DAC_CH7
  always@(posedge clk)
	begin
    if (reset)
      wreg_DAC_CH7 <= 8'h00;
    else if (wr_addr == 8'h27 && wr_strb)
      wreg_DAC_CH7 <= wr_data[7:0];      
  end   


//BP MOTOR REGISTERS
  // Write to wreg_Motor_BP_ustep
//  always@(posedge clk)
//	begin
//    if (reset)
//      wreg_Motor_BP_ustep <= 2'b00;
//    else if (wr_addr == 8'h28 && wr_strb)
//      wreg_Motor_BP_ustep <= wr_data[1:0];      
//  end

  // Write to wreg_Motor_BP_Dir
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_BP_Dir <= 1'b0;
    else if (wr_addr == 8'h28 && wr_strb)
      wreg_Motor_BP_Dir <= wr_data[4];      
  end

  // Write to wreg_Motor_BP_Acc
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_BP_Acc <= 36'h000000000;
    else if (wr_addr == 8'h29 && wr_strb)
      wreg_Motor_BP_Acc <= wr_data[35:0];      
  end

  // Write to wreg_Motor_BP_Vel
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_BP_Vel <= 36'h000000000;
    else if (wr_addr == 8'h2a && wr_strb)
      wreg_Motor_BP_Vel <= wr_data[35:0];      
  end

  // Write to wreg_Motor_BP_enable
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_BP_enable <= 1'b0;
    else if (wr_addr == 8'h2b && wr_strb)
      wreg_Motor_BP_enable <= wr_data[0];      
  end
    

//DP1 MOTOR REGISTERS
//  // Write to wreg_Motor_DP1_ustep
//  always@(posedge clk)
//	begin
//    if (reset)
//      wreg_Motor_DP1_ustep <= 2'b00;
//    else if (wr_addr == 8'h2c && wr_strb)
//      wreg_Motor_DP1_ustep <= wr_data[1:0];      
//  end

  // Write to wreg_Motor_DP1_Dir
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_DP1_Dir <= 1'b0;
    else if (wr_addr == 8'h2c && wr_strb)
      wreg_Motor_DP1_Dir <= wr_data[4];      
  end

  // Write to wreg_Motor_DP1_Acc
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_DP1_Acc <= 36'h000000000;
    else if (wr_addr == 8'h2d && wr_strb)
      wreg_Motor_DP1_Acc <= wr_data[35:0];      
  end

  // Write to wreg_Motor_DP1_Vel
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_DP1_Vel <= 36'h000000000;
    else if (wr_addr == 8'h2e && wr_strb)
      wreg_Motor_DP1_Vel <= wr_data[35:0];      
  end

  // Write to wreg_Motor_DP1_enable
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_DP1_enable <= 1'b0;
    else if (wr_addr == 8'h2f && wr_strb)
      wreg_Motor_DP1_enable <= wr_data[0];      
  end

//DP2 MOTOR REGISTERS
//  // Write to wreg_Motor_DP2_ustep
//  always@(posedge clk)
//	begin
//    if (reset)
//      wreg_Motor_DP2_ustep <= 2'b00;
//    else if (wr_addr == 8'h30 && wr_strb)
//      wreg_Motor_DP2_ustep <= wr_data[1:0];      
//  end

  // Write to wreg_Motor_DP2_Dir
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_DP2_Dir <= 1'b0;
    else if (wr_addr == 8'h30 && wr_strb)
      wreg_Motor_DP2_Dir <= wr_data[4];      
  end

  // Write to wreg_Motor_DP2_Acc
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_DP2_Acc <= 36'h000000000;
    else if (wr_addr == 8'h31 && wr_strb)
      wreg_Motor_DP2_Acc <= wr_data[35:0];      
  end

  // Write to wreg_Motor_DP2_Vel
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_DP2_Vel <= 36'h000000000;
    else if (wr_addr == 8'h32 && wr_strb)
      wreg_Motor_DP2_Vel <= wr_data[35:0];      
  end

  // Write to wreg_Motor_DP2_enable
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_DP2_enable <= 1'b0;
    else if (wr_addr == 8'h33 && wr_strb)
      wreg_Motor_DP2_enable <= wr_data[0];      
  end  

//ELP MOTOR REGISTERS
  // Write to wreg_Motor_ELP_ustep
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_ELP_ustep <= 2'b00;
    else if (wr_addr == 8'h34 && wr_strb)
      wreg_Motor_ELP_ustep <= wr_data[1:0];      
  end

  // Write to wreg_Motor_ELP_Dir
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_ELP_Dir <= 1'b0;
    else if (wr_addr == 8'h34 && wr_strb)
      wreg_Motor_ELP_Dir <= wr_data[4];      
  end

  // Write to wreg_Motor_ELP_Acc
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_ELP_Acc <= 36'h000000000;
    else if (wr_addr == 8'h35 && wr_strb)
      wreg_Motor_ELP_Acc <= wr_data[35:0];      
  end

  // Write to wreg_Motor_ELP_Vel
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_ELP_Vel <= 36'h000000000;
    else if (wr_addr == 8'h36 && wr_strb)
      wreg_Motor_ELP_Vel <= wr_data[35:0];      
  end

  // Write to wreg_Motor_ELP_enable
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_ELP_enable <= 1'b0;
    else if (wr_addr == 8'h37 && wr_strb)
      wreg_Motor_ELP_enable <= wr_data[0];      
  end

//HEP MOTOR REGISTERS
  // Write to wreg_Motor_HEP_ustep
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_HEP_ustep <= 2'b00;
    else if (wr_addr == 8'h38 && wr_strb)
      wreg_Motor_HEP_ustep <= wr_data[1:0];      
  end

  // Write to wreg_Motor_HEP_Dir
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_HEP_Dir <= 1'b0;
    else if (wr_addr == 8'h38 && wr_strb)
      wreg_Motor_HEP_Dir <= wr_data[4];      
  end

  // Write to wreg_Motor_HEP_Acc
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_HEP_Acc <= 36'h000000000;
    else if (wr_addr == 8'h39 && wr_strb)
      wreg_Motor_HEP_Acc <= wr_data[35:0];      
  end

  // Write to wreg_Motor_HEP_Vel
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_HEP_Vel <= 36'h000000000;
    else if (wr_addr == 8'h3a && wr_strb)
      wreg_Motor_HEP_Vel <= wr_data[35:0];      
  end

  // Write to wreg_Motor_HEP_enable
  always@(posedge clk)
	begin
    if (reset)
      wreg_Motor_HEP_enable <= 1'b0;
    else if (wr_addr == 8'h3b && wr_strb)
      wreg_Motor_HEP_enable <= wr_data[0];      
  end
  
//ADM MOTOR REGISTERS
  // write to ADM open strobe
  always@(posedge clk)
	begin
    if (reset)
      wreg_ADM_open_strb  <= 1'b0;
    else if (wr_addr == 8'h3c && wr_strb && ~wr_data[0])
      wreg_ADM_open_strb  <= 1'b1;
    else
      wreg_ADM_open_strb  <= 1'b0;
  end
  
  // write to ADM close strobe
  always@(posedge clk)
	begin
    if (reset)
      wreg_ADM_close_strb  <= 1'b0;
    else if (wr_addr == 8'h3c && wr_strb && wr_data[0])
      wreg_ADM_close_strb  <= 1'b1;
    else
      wreg_ADM_close_strb  <= 1'b0;
  end  
  
  // Write to wreg_ADM_clr_strb
  always@(posedge clk)
	begin
    if (reset)
      wreg_ADM_clr_strb <= 1'b0;
    else if (wr_addr == 8'h3d && wr_strb)
      wreg_ADM_clr_strb <= 1'b1;
    else  
      wreg_ADM_clr_strb <= 1'b0;
  end
    
// Write to subsystem_op_en
  always@(posedge clk)
	begin
    if (reset)
      subsystem_op_en <= 32'h00000000;
    else if (wr_addr == 8'h40 && wr_strb)
      subsystem_op_en <= wr_data[31:0];      
  end

  // Write to subsystem_wr_02
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_02 <= 36'h000000000;
    else if (wr_addr == 8'h41 && wr_strb)
      subsystem_wr_02 <= wr_data[35:0];      
  end  

  // Write to subsystem_wr_03
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_03 <= 36'h000000000;
    else if (wr_addr == 8'h42 && wr_strb)
      subsystem_wr_03 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_04
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_04 <= 36'h000000000;
    else if (wr_addr == 8'h43 && wr_strb)
      subsystem_wr_04 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_05
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_05 <= 36'h000000000;
    else if (wr_addr == 8'h44 && wr_strb)
      subsystem_wr_05 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_06
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_06 <= 36'h000000000;
    else if (wr_addr == 8'h45 && wr_strb)
      subsystem_wr_06 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_07
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_07 <= 36'h000000000;
    else if (wr_addr == 8'h46 && wr_strb)
      subsystem_wr_07 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_08
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_08 <= 36'h000000000;
    else if (wr_addr == 8'h47 && wr_strb)
      subsystem_wr_08 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_09
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_09 <= 36'h000000000;
    else if (wr_addr == 8'h48 && wr_strb)
      subsystem_wr_09 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_10
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_10 <= 36'h000000000;
    else if (wr_addr == 8'h49 && wr_strb)
      subsystem_wr_10 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_11
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_11 <= 36'h000000000;
    else if (wr_addr == 8'h4A && wr_strb)
      subsystem_wr_11 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_12
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_12 <= 36'h000000000;
    else if (wr_addr == 8'h4B && wr_strb)
      subsystem_wr_12 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_13
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_13 <= 36'h000000000;
    else if (wr_addr == 8'h4C && wr_strb)
      subsystem_wr_13 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_14
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_14 <= 36'h000000000;
    else if (wr_addr == 8'h4D && wr_strb)
      subsystem_wr_14 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_15
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_15 <= 36'h000000000;
    else if (wr_addr == 8'h4E && wr_strb)
      subsystem_wr_15 <= wr_data[35:0];      
  end 

  // Write to subsystem_wr_16
  always@(posedge clk)
	begin
    if (reset)
      subsystem_wr_16 <= 36'h000000000;
    else if (wr_addr == 8'h4F && wr_strb)
      subsystem_wr_16 <= wr_data[35:0];      
  end   
    
  // Write to csdl_op_en
  always@(posedge clk)
	begin
    if (reset)
      csdl_op_en <= 32'h00000000;
    else if (wr_addr == 8'h50 && wr_strb)
      csdl_op_en <= wr_data[31:0];      
  end

  // Write to csdl_wr_02
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_02 <= 36'h000000000;
    else if (wr_addr == 8'h51 && wr_strb)
      csdl_wr_02 <= wr_data[35:0];      
  end  

  // Write to csdl_wr_03
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_03 <= 36'h000000000;
    else if (wr_addr == 8'h52 && wr_strb)
      csdl_wr_03 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_04
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_04 <= 36'h000000000;
    else if (wr_addr == 8'h53 && wr_strb)
      csdl_wr_04 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_05
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_05 <= 36'h000000000;
    else if (wr_addr == 8'h54 && wr_strb)
      csdl_wr_05 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_06
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_06 <= 36'h000000000;
    else if (wr_addr == 8'h55 && wr_strb)
      csdl_wr_06 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_07
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_07 <= 36'h000000000;
    else if (wr_addr == 8'h56 && wr_strb)
      csdl_wr_07 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_08
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_08 <= 36'h000000000;
    else if (wr_addr == 8'h57 && wr_strb)
      csdl_wr_08 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_09
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_09 <= 36'h000000000;
    else if (wr_addr == 8'h58 && wr_strb)
      csdl_wr_09 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_10
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_10 <= 36'h000000000;
    else if (wr_addr == 8'h59 && wr_strb)
      csdl_wr_10 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_11
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_11 <= 36'h000000000;
    else if (wr_addr == 8'h5A && wr_strb)
      csdl_wr_11 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_12
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_12 <= 36'h000000000;
    else if (wr_addr == 8'h5B && wr_strb)
      csdl_wr_12 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_13
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_13 <= 36'h000000000;
    else if (wr_addr == 8'h5C && wr_strb)
      csdl_wr_13 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_14
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_14 <= 36'h000000000;
    else if (wr_addr == 8'h5D && wr_strb)
      csdl_wr_14 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_15
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_15 <= 36'h000000000;
    else if (wr_addr == 8'h5E && wr_strb)
      csdl_wr_15 <= wr_data[35:0];      
  end 

  // Write to csdl_wr_16
  always@(posedge clk)
	begin
    if (reset)
      csdl_wr_16 <= 36'h000000000;
    else if (wr_addr == 8'h5F && wr_strb)
      csdl_wr_16 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_60
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_60 <= 36'h000000000;
    else if (wr_addr == 8'h60 && wr_strb)
      wreg_GPRW_60 <= wr_data[35:0];      
  end

  // Write to wreg_GPRW_61
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_61 <= 36'h000000000;
    else if (wr_addr == 8'h61 && wr_strb)
      wreg_GPRW_61 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_62
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_62 <= 36'h000000000;
    else if (wr_addr == 8'h62 && wr_strb)
      wreg_GPRW_62 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_63
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_63 <= 36'h000000000;
    else if (wr_addr == 8'h63 && wr_strb)
      wreg_GPRW_63 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_64
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_64 <= 36'h000000000;
    else if (wr_addr == 8'h64 && wr_strb)
      wreg_GPRW_64 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_65
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_65 <= 36'h000000000;
    else if (wr_addr == 8'h65 && wr_strb)
      wreg_GPRW_65 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_66
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_66 <= 36'h000000000;
    else if (wr_addr == 8'h66 && wr_strb)
      wreg_GPRW_66 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_67
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_67 <= 36'h000000000;
    else if (wr_addr == 8'h67 && wr_strb)
      wreg_GPRW_67 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_68
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_68 <= 36'h000000000;
    else if (wr_addr == 8'h68 && wr_strb)
      wreg_GPRW_68 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_69
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_69 <= 36'h000000000;
    else if (wr_addr == 8'h69 && wr_strb)
      wreg_GPRW_69 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_6A
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_6A <= 36'h000000000;
    else if (wr_addr == 8'h6A && wr_strb)
      wreg_GPRW_6A <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_6B
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_6B <= 36'h000000000;
    else if (wr_addr == 8'h6B && wr_strb)
      wreg_GPRW_6B <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_6C
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_6C <= 36'h000000000;
    else if (wr_addr == 8'h6C && wr_strb)
      wreg_GPRW_6C <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_6D
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_6D <= 36'h000000000;
    else if (wr_addr == 8'h6D && wr_strb)
      wreg_GPRW_6D <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_6E
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_6E <= 36'h000000000;
    else if (wr_addr == 8'h6E && wr_strb)
      wreg_GPRW_6E <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_6F
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_6F <= 36'h000000000;
    else if (wr_addr == 8'h6F && wr_strb)
      wreg_GPRW_6F <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_70
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_70 <= 36'h000000000;
    else if (wr_addr == 8'h70 && wr_strb)
      wreg_GPRW_70 <= wr_data[35:0];      
  end

  // Write to wreg_GPRW_71
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_71 <= 36'h000000000;
    else if (wr_addr == 8'h71 && wr_strb)
      wreg_GPRW_71 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_72
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_72 <= 36'h000000000;
    else if (wr_addr == 8'h72 && wr_strb)
      wreg_GPRW_72 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_73
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_73 <= 36'h000000000;
    else if (wr_addr == 8'h73 && wr_strb)
      wreg_GPRW_73 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_74
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_74 <= 36'h000000000;
    else if (wr_addr == 8'h74 && wr_strb)
      wreg_GPRW_74 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_75
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_75 <= 36'h000000000;
    else if (wr_addr == 8'h75 && wr_strb)
      wreg_GPRW_75 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_76
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_76 <= 36'h000000000;
    else if (wr_addr == 8'h76 && wr_strb)
      wreg_GPRW_76 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_77
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_77 <= 36'h000000000;
    else if (wr_addr == 8'h77 && wr_strb)
      wreg_GPRW_77 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_78
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_78 <= 36'h000000000;
    else if (wr_addr == 8'h78 && wr_strb)
      wreg_GPRW_78 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_79
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_79 <= 36'h000000000;
    else if (wr_addr == 8'h79 && wr_strb)
      wreg_GPRW_79 <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_7A
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_7A <= 36'h000000000;
    else if (wr_addr == 8'h7A && wr_strb)
      wreg_GPRW_7A <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_7B
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_7B <= 36'h000000000;
    else if (wr_addr == 8'h7B && wr_strb)
      wreg_GPRW_7B <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_7C
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_7C <= 36'h000000000;
    else if (wr_addr == 8'h7C && wr_strb)
      wreg_GPRW_7C <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_7D
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_7D <= 36'h000000000;
    else if (wr_addr == 8'h7D && wr_strb)
      wreg_GPRW_7D <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_7E
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_7E <= 36'h000000000;
    else if (wr_addr == 8'h7E && wr_strb)
      wreg_GPRW_7E <= wr_data[35:0];      
  end
  
  // Write to wreg_GPRW_7F
  always@(posedge clk)
	begin
    if (reset)
      wreg_GPRW_7F <= 36'h000000000;
    else if (wr_addr == 8'h7F && wr_strb)
      wreg_GPRW_7F <= wr_data[35:0];      
  end
  
  
// END WRITE REGISTERS  
//--------------------------------------------------------  

  
//--------------------------------------------------------  
// READ REGISTERS      

  //Mux registers based on read address.
  always@(rd_addr[6:0],
    rreg_ADC1_NOMUX_CH0,rreg_ADC1_NOMUX_CH1,
    rreg_ADC1_NOMUX_CH2,rreg_ADC1_NOMUX_CH3,
    rreg_ADC1_NOMUX_CH4,rreg_ADC1_NOMUX_CH5,
    rreg_ADC1_MUX1A_CH0,rreg_ADC1_MUX1A_CH1,
    rreg_ADC1_MUX1A_CH2,rreg_ADC1_MUX1A_CH3,
    rreg_ADC1_MUX1B_CH0,rreg_ADC1_MUX1B_CH1,
    rreg_ADC1_MUX1B_CH2,rreg_ADC1_MUX1B_CH3,
    rreg_csdl_wrap,rreg_Scale_Correction,
    rreg_Kpuf,rreg_Kpufr,rreg_Kiufr,rreg_Kdufr,
    rreg_Fan1_Tach,rreg_Fan2_Tach,rreg_temperature,
    rreg_status,rreg_DRS,rreg_ADM_status,
    rreg_NVM_Command,rreg_NVM_Wr_Data,
    rreg_BP_Velocity,rreg_BP_Encoder,
    rreg_DP1_Velocity,rreg_DP1_Encoder,
    rreg_DP2_Velocity,rreg_DP2_Encoder,
    rreg_ELP_Velocity,rreg_ELP_Encoder,
    rreg_HEP_Velocity,rreg_HEP_Encoder,
    rreg_DL_Velocity,rreg_DL_Encoder,
    rreg_csdl_motor_vel_dp1_bp,rreg_csdl_motor_vel_dp2_elp,
    rreg_csdl_motor_vel_hep,rreg_csdl_motor_settings,
    subsystem_reg_01,subsystem_reg_02,subsystem_reg_03,subsystem_reg_04,
    subsystem_reg_05,subsystem_reg_06,subsystem_reg_07,subsystem_reg_08,
    subsystem_reg_09,subsystem_reg_10,subsystem_reg_11,subsystem_reg_12,
    subsystem_reg_13,subsystem_reg_14,subsystem_reg_15,subsystem_reg_16,
    csdl_reg_01,csdl_reg_02,csdl_reg_03,csdl_reg_04,
    csdl_reg_05,csdl_reg_06,csdl_reg_07,csdl_reg_08,
    csdl_reg_09,csdl_reg_10,csdl_reg_11,csdl_reg_12,
    csdl_reg_13,csdl_reg_14,csdl_reg_15,csdl_reg_16,
    rreg_GPRW_60,rreg_GPRW_61,rreg_GPRW_62,rreg_GPRW_63,rreg_GPRW_64,rreg_GPRW_65,rreg_GPRW_66,rreg_GPRW_67,
    rreg_GPRW_68,rreg_GPRW_69,rreg_GPRW_6A,rreg_GPRW_6B,rreg_GPRW_6C,rreg_GPRW_6D,rreg_GPRW_6E,rreg_GPRW_6F,
    rreg_GPRW_70,rreg_GPRW_71,rreg_GPRW_72,rreg_GPRW_73,rreg_GPRW_74,rreg_GPRW_75,rreg_GPRW_76,rreg_GPRW_77,
    rreg_GPRW_78,rreg_GPRW_79,rreg_GPRW_7A,rreg_GPRW_7B,rreg_GPRW_7C,rreg_GPRW_7D,rreg_GPRW_7E,rreg_GPRW_7F)    
  begin
    case (rd_addr[6:0])
      7'h00   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH0};
      7'h01   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH1};
      7'h02   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH2};
      7'h03   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH3};
      7'h04   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH4};
      7'h05   : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH5};
      7'h06   : reg_selected <= 36'h000000000;
      7'h07   : reg_selected <= 36'h000000000;
      7'h08   : reg_selected <= {20'h00000,rreg_ADC1_MUX1A_CH0};
      7'h09   : reg_selected <= {20'h00000,rreg_ADC1_MUX1A_CH1};
      7'h0A   : reg_selected <= {20'h00000,rreg_ADC1_MUX1A_CH2};
      7'h0B   : reg_selected <= {20'h00000,rreg_ADC1_MUX1A_CH3};
      7'h0C   : reg_selected <= {20'h00000,rreg_ADC1_MUX1B_CH0};
      7'h0D   : reg_selected <= {20'h00000,rreg_ADC1_MUX1B_CH1};
      7'h0E   : reg_selected <= {20'h00000,rreg_ADC1_MUX1B_CH2};
      7'h0F   : reg_selected <= {20'h00000,rreg_ADC1_MUX1B_CH3};
      7'h10   : reg_selected <= rreg_BP_Velocity;
      7'h11   : reg_selected <= {33'h000000000,rreg_BP_Encoder};
      7'h12   : reg_selected <= rreg_DP1_Velocity;
      7'h13   : reg_selected <= {33'h000000000,rreg_DP1_Encoder};
      7'h14   : reg_selected <= rreg_DP2_Velocity;
      7'h15   : reg_selected <= {33'h000000000,rreg_DP2_Encoder};
      7'h16   : reg_selected <= rreg_ELP_Velocity;
      7'h17   : reg_selected <= {33'h000000000,rreg_ELP_Encoder};
      7'h18   : reg_selected <= rreg_HEP_Velocity;
      7'h19   : reg_selected <= {33'h000000000,rreg_HEP_Encoder};
      7'h1A   : reg_selected <= rreg_DL_Velocity;
      7'h1B   : reg_selected <= {33'h000000000,rreg_DL_Encoder};
      7'h1C   : reg_selected <= 36'h000000000;
      7'h1D   : reg_selected <= 36'h000000000;
      7'h1E   : reg_selected <= 36'h000000000;
      7'h1F   : reg_selected <= 36'h000000000;
      7'h20   : reg_selected <= {20'h00000, rreg_Fan1_Tach};
      7'h21   : reg_selected <= {20'h00000, rreg_Fan2_Tach};
      7'h22   : reg_selected <= {24'h000000,rreg_temperature};
      7'h23   : reg_selected <= rreg_status;
      7'h24   : reg_selected <= {34'h000000000, rreg_DRS};
      7'h25   : reg_selected <= {28'h0000000, rreg_ADM_status};
      7'h26   : reg_selected <= 36'h000000000;
      7'h27   : reg_selected <= 36'h000000000;
      7'h28   : reg_selected <= 36'h000000000;
      7'h29   : reg_selected <= 36'h000000000;
      7'h2A   : reg_selected <= rreg_NVM_Command;
      7'h2B   : reg_selected <= rreg_NVM_Wr_Data;
      7'h2C   : reg_selected <= 36'h000000000;
      7'h2D   : reg_selected <= 36'h000000000;
      7'h2E   : reg_selected <= 36'h000000000;
      7'h2F   : reg_selected <= 36'h000000000;
      7'h30   : reg_selected <= 36'h000000000;
      7'h31   : reg_selected <= 36'h000000000;
      7'h32   : reg_selected <= 36'h000000000;
      7'h33   : reg_selected <= 36'h000000000;
      7'h34   : reg_selected <= rreg_Scale_Correction;//36'h000000000;
      7'h35   : reg_selected <= rreg_Kpuf;//36'h000000000;
      7'h36   : reg_selected <= rreg_Kpufr;//36'h000000000;
      7'h37   : reg_selected <= rreg_Kiufr;//36'h000000000;
      7'h38   : reg_selected <= rreg_Kdufr;//36'h000000000;
      7'h39   : reg_selected <= rreg_csdl_motor_vel_dp1_bp;
      7'h3A   : reg_selected <= rreg_csdl_motor_vel_dp2_elp;
      7'h3B   : reg_selected <= rreg_csdl_motor_vel_hep;
      7'h3C   : reg_selected <= rreg_csdl_motor_settings;
      7'h3D   : reg_selected <= rreg_csdl_wrap;
      7'h3E   : reg_selected <= 36'h000000000;
      7'h3F   : reg_selected <= 36'h000000000;
      7'h40   : reg_selected <= subsystem_reg_01;
      7'h41   : reg_selected <= subsystem_reg_02;
      7'h42   : reg_selected <= subsystem_reg_03;
      7'h43   : reg_selected <= subsystem_reg_04;
      7'h44   : reg_selected <= subsystem_reg_05;
      7'h45   : reg_selected <= subsystem_reg_06;
      7'h46   : reg_selected <= subsystem_reg_07;
      7'h47   : reg_selected <= subsystem_reg_08;
      7'h48   : reg_selected <= subsystem_reg_09;
      7'h49   : reg_selected <= subsystem_reg_10;
      7'h4A   : reg_selected <= subsystem_reg_11;
      7'h4B   : reg_selected <= subsystem_reg_12;
      7'h4C   : reg_selected <= subsystem_reg_13;
      7'h4D   : reg_selected <= subsystem_reg_14;
      7'h4E   : reg_selected <= subsystem_reg_15;
      7'h4F   : reg_selected <= subsystem_reg_16;      
      7'h50   : reg_selected <= csdl_reg_01;
      7'h51   : reg_selected <= csdl_reg_02;
      7'h52   : reg_selected <= csdl_reg_03;
      7'h53   : reg_selected <= csdl_reg_04;
      7'h54   : reg_selected <= csdl_reg_05;
      7'h55   : reg_selected <= csdl_reg_06;
      7'h56   : reg_selected <= csdl_reg_07;
      7'h57   : reg_selected <= csdl_reg_08;
      7'h58   : reg_selected <= csdl_reg_09;
      7'h59   : reg_selected <= csdl_reg_10;
      7'h5A   : reg_selected <= csdl_reg_11;
      7'h5B   : reg_selected <= csdl_reg_12;
      7'h5C   : reg_selected <= csdl_reg_13;
      7'h5D   : reg_selected <= csdl_reg_14;
      7'h5E   : reg_selected <= csdl_reg_15;
      7'h5F   : reg_selected <= csdl_reg_16;
      7'h60   : reg_selected <= rreg_GPRW_60; 
      7'h61   : reg_selected <= rreg_GPRW_61; 
      7'h62   : reg_selected <= rreg_GPRW_62; 
      7'h63   : reg_selected <= rreg_GPRW_63; 
      7'h64   : reg_selected <= rreg_GPRW_64; 
      7'h65   : reg_selected <= rreg_GPRW_65; 
      7'h66   : reg_selected <= rreg_GPRW_66; 
      7'h67   : reg_selected <= rreg_GPRW_67; 
      7'h68   : reg_selected <= rreg_GPRW_68; 
      7'h69   : reg_selected <= rreg_GPRW_69; 
      7'h6A   : reg_selected <= rreg_GPRW_6A; 
      7'h6B   : reg_selected <= rreg_GPRW_6B; 
      7'h6C   : reg_selected <= rreg_GPRW_6C; 
      7'h6D   : reg_selected <= rreg_GPRW_6D; 
      7'h6E   : reg_selected <= rreg_GPRW_6E; 
      7'h6F   : reg_selected <= rreg_GPRW_6F; 
      7'h70   : reg_selected <= rreg_GPRW_70; 
      7'h71   : reg_selected <= rreg_GPRW_71; 
      7'h72   : reg_selected <= rreg_GPRW_72; 
      7'h73   : reg_selected <= rreg_GPRW_73; 
      7'h74   : reg_selected <= rreg_GPRW_74; 
      7'h75   : reg_selected <= rreg_GPRW_75; 
      7'h76   : reg_selected <= rreg_GPRW_76; 
      7'h77   : reg_selected <= rreg_GPRW_77; 
      7'h78   : reg_selected <= rreg_GPRW_78; 
      7'h79   : reg_selected <= rreg_GPRW_79; 
      7'h7A   : reg_selected <= rreg_GPRW_7A; 
      7'h7B   : reg_selected <= rreg_GPRW_7B; 
      7'h7C   : reg_selected <= rreg_GPRW_7C; 
      7'h7D   : reg_selected <= rreg_GPRW_7D; 
      7'h7E   : reg_selected <= rreg_GPRW_7E; 
      7'h7F   : reg_selected <= rreg_GPRW_7F;       
      default : reg_selected <= {20'h00000,rreg_ADC1_NOMUX_CH0};
    endcase
  end
  
  // Gate the selected register
  always@(posedge clk)
	begin
    if (reset)
      rd_data <= 35'h000000000;
    else if (rd_strb)
      rd_data <= reg_selected;      
  end     
  
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
    
  //rreg_ADC1_MUX1A_CH0 (24V-C)
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_MUX1A_CH0 <= 16'h0000;
    else if (mux_num == 2'b00 && adc1_num == 3'b110 && adc1_data_strb)
      rreg_ADC1_MUX1A_CH0 <= adc1_data;
  end  

  //rreg_ADC1_MUX1A_CH1 (5V-C)
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_MUX1A_CH1 <= 16'h0000;
    else if (mux_num == 2'b01 && adc1_num == 3'b110 && adc1_data_strb)
      rreg_ADC1_MUX1A_CH1 <= adc1_data;
  end  
  
  //rreg_ADC1_MUX1A_CH2 (3.3V-C)
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_MUX1A_CH2 <= 16'h0000;
    else if (mux_num == 2'b10 && adc1_num == 3'b110 && adc1_data_strb)
      rreg_ADC1_MUX1A_CH2 <= adc1_data;
  end  

  //rreg_ADC1_MUX1A_CH3 (1.8V-C)
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_MUX1A_CH3 <= 16'h0000;
    else if (mux_num == 2'b11 && adc1_num == 3'b110 && adc1_data_strb)
      rreg_ADC1_MUX1A_CH3 <= adc1_data;
  end  
  
  //rreg_ADC1_MUX1B_CH0 (1.5V-C)
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_MUX1B_CH0 <= 16'h0000;
    else if (mux_num == 2'b00 && adc1_num == 3'b111 && adc1_data_strb)
      rreg_ADC1_MUX1B_CH0 <= adc1_data;
  end

  //rreg_ADC1_MUX1B_CH1 (1.2V-C)
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_MUX1B_CH1 <= 16'h0000;
    else if (mux_num == 2'b01 && adc1_num == 3'b111 && adc1_data_strb)
      rreg_ADC1_MUX1B_CH1 <= adc1_data;
  end
  
  //rreg_ADC1_MUX1B_CH2 (GND)
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_MUX1B_CH2 <= 16'h0000;
    else if (mux_num == 2'b10 && adc1_num == 3'b111 && adc1_data_strb)
      rreg_ADC1_MUX1B_CH2 <= adc1_data;
  end

    //rreg_ADC1_MUX1B_CH3 (GND)
  always@(posedge clk)
	begin
    if (reset)
      rreg_ADC1_MUX1B_CH3 <= 16'h0000;
    else if (mux_num == 2'b11 && adc1_num == 3'b111 && adc1_data_strb)
      rreg_ADC1_MUX1B_CH3 <= adc1_data;
  end


  //rreg_BP_Velocity
  always@(posedge clk)
	begin
    if (reset)
      rreg_BP_Velocity <= 36'h000000000;
    else 
      rreg_BP_Velocity <= BP_Velocity;
  end 
  
  //rreg_BP_Encoder
  always@(posedge clk)
	begin
    if (reset)
      rreg_BP_Encoder <= 3'b000;
    else 
      rreg_BP_Encoder <= BP_Encoder;
  end   

  //rreg_DP1_Velocity
  always@(posedge clk)
	begin
    if (reset)
      rreg_DP1_Velocity <= 36'h000000000;
    else 
      rreg_DP1_Velocity <= DP1_Velocity;
  end 
  
  //rreg_DP1_Encoder
  always@(posedge clk)
	begin
    if (reset)
      rreg_DP1_Encoder <= 3'b000;
    else 
      rreg_DP1_Encoder <= DP1_Encoder;
  end   
    
  //rreg_DP2_Velocity
  always@(posedge clk)
	begin
    if (reset)
      rreg_DP2_Velocity <= 36'h000000000;
    else 
      rreg_DP2_Velocity <= DP2_Velocity;
  end 
  
  //rreg_DP2_Encoder
  always@(posedge clk)
	begin
    if (reset)
      rreg_DP2_Encoder <= 3'b000;
    else 
      rreg_DP2_Encoder <= DP2_Encoder;
  end     
  
  //rreg_ELP_Velocity
  always@(posedge clk)
	begin
    if (reset)
      rreg_ELP_Velocity <= 36'h000000000;
    else 
      rreg_ELP_Velocity <= ELP_Velocity;
  end 
  
  //rreg_ELP_Encoder
  always@(posedge clk)
	begin
    if (reset)
      rreg_ELP_Encoder <= 3'b000;
    else 
      rreg_ELP_Encoder <= ELP_Encoder;
  end     
  
  //rreg_HEP_Velocity
  always@(posedge clk)
	begin
    if (reset)
      rreg_HEP_Velocity <= 36'h000000000;
    else 
      rreg_HEP_Velocity <= HEP_Velocity;
  end 
  
  //rreg_HEP_Encoder
  always@(posedge clk)
	begin
    if (reset)
      rreg_HEP_Encoder <= 3'b000;
    else 
      rreg_HEP_Encoder <= HEP_Encoder;
  end     
  
  //rreg_DL_Velocity
  always@(posedge clk)
	begin
    if (reset)
      rreg_DL_Velocity <= 36'h000000000;
    else 
      rreg_DL_Velocity <= DL_Velocity;
  end 
  
  //rreg_DL_Encoder
  always@(posedge clk)
	begin
    if (reset)
      rreg_DL_Encoder <= 3'b000;
    else 
      rreg_DL_Encoder <= DL_Encoder;
  end   
               
  //rreg_Fan1_Tach
  always@(posedge clk)
	begin
    if (reset)
      rreg_Fan1_Tach <= 16'h0000;
    else 
      rreg_Fan1_Tach <= fan1_tach_pps;
  end
  
  //rreg_Fan2_Tach
  always@(posedge clk)
	begin
    if (reset)
      rreg_Fan2_Tach <= 16'h0000;
    else 
      rreg_Fan2_Tach <= fan2_tach_pps;
  end
              
      
  //rreg_temperature
  always@(posedge clk)
	begin
    if (reset)
      rreg_temperature <= 12'h000;
    else if (temp_strb) 
      rreg_temperature <= temp_sense;
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
        if (reset || wr_strb_Z1)
          rreg_status[15:4] <= 12'h000;
        else if (temp_strb) begin
          rreg_status[15:4] <= {csdl_err,subsystem_err,comm_err[6:1],TEMP_ALERT,temp_status};
        end
      end
      
      //rreg_status - FPGA Version, cable detect 
      always@(posedge clk)
      begin
        if (reset) begin
          rreg_status[35:16] <= 20'h00000;
        end else begin
          rreg_status[31:16] <= FPGA_VERSION;      
          rreg_status[35:32] <= {wreg_System_en,TEMP_BIT,wreg_DAC_en,RA_CABLE_DET_N};
        end
      end 

//-----------------------------------------------      

  // rreg_DRS
  always@(posedge clk)
	begin
    if (reset) begin
      rreg_DRS <= 2'b00;
    end else if (strb_1us) begin
      rreg_DRS[0] <= DRS_POS;
      rreg_DRS[1] <= DRS_AMB;
    end
  end   

  // rreg_ADM_Status
  always@(posedge clk)
	begin
    if (reset || wreg_ADM_clr_strb) begin
      rreg_ADM_status <= 8'h00;
    end else if (adm_status_strb) begin
      rreg_ADM_status <= adm_door_status;
    end
  end   
  
  //Encode motor commands to be read over the CSDL for the safety side to evaluate with
  assign csdl_motor_vel_dp1_bp  = {wreg_Motor_DP1_Vel[35:18],wreg_Motor_BP_Vel[35:18]};
  assign csdl_motor_vel_dp2_elp = {wreg_Motor_DP2_Vel[35:18],wreg_Motor_ELP_Vel[35:18]};
  assign csdl_motor_vel_hep     =  wreg_Motor_HEP_Vel;
  assign csdl_motor_settings    = {wreg_Motor_HEP_enable,wreg_Motor_HEP_Dir,wreg_Motor_DP2_ustep,
                                   wreg_Motor_ELP_enable,wreg_Motor_ELP_Dir,wreg_Motor_DP2_ustep,
                                   wreg_Motor_DP2_enable,wreg_Motor_DP2_Dir,wreg_Motor_DP2_ustep,
                                   wreg_Motor_DP1_enable,wreg_Motor_DP1_Dir,wreg_Motor_DP1_ustep,
                                   wreg_Motor_BP_enable,wreg_Motor_BP_Dir,wreg_Motor_BP_ustep}; 
  
  //rreg_csdl_motor_vel_dp1_bp
  always@(posedge clk)
	begin
    if (reset)
      rreg_csdl_motor_vel_dp1_bp <= 36'h000000000;
    else 
      rreg_csdl_motor_vel_dp1_bp <= csdl_motor_vel_dp1_bp;
  end   

  //rreg_csdl_motor_vel_dp2_elp
  always@(posedge clk)
	begin
    if (reset)
      rreg_csdl_motor_vel_dp2_elp <= 36'h000000000;
    else 
      rreg_csdl_motor_vel_dp2_elp <= csdl_motor_vel_dp2_elp;
  end   

  //rreg_csdl_motor_vel_hep
  always@(posedge clk)
	begin
    if (reset)
      rreg_csdl_motor_vel_hep <= 36'h000000000;
    else 
      rreg_csdl_motor_vel_hep <= csdl_motor_vel_hep;
  end   

  //rreg_csdl_motor_settings
  always@(posedge clk)
	begin
    if (reset)
      rreg_csdl_motor_settings <= 36'h000000000;
    else 
      rreg_csdl_motor_settings <= csdl_motor_settings;
  end       

  //rreg_csdl_motor_settings
  always@(posedge clk)
	begin
    if (reset)
      rreg_csdl_motor_settings <= 36'h000000000;
    else 
      rreg_csdl_motor_settings <= csdl_motor_settings;
  end   
  
  // rreg_csdl_wrap
  always@(posedge clk)
	begin
    if (reset)
      rreg_csdl_wrap <= 36'h000000000;
    else 
      rreg_csdl_wrap <= wreg_csdl_wrap;
  end     
  
  // rreg_NVM_Command
  always@(posedge clk)
	begin
    if (reset)
      rreg_NVM_Command <= 36'h000000000;
    else
      rreg_NVM_Command <= wreg_NVM_Command;      
  end 

  // rreg_NVM_02
  always@(posedge clk)
	begin
    if (reset)
      rreg_NVM_Wr_Data <= 36'h000000000;
    else
      rreg_NVM_Wr_Data <= wreg_NVM_Wr_Data;      
  end        
  
  // rreg_Scale_Correction
  always@(posedge clk)
	begin
    if (reset)
      rreg_Scale_Correction <= 36'h000040000;
    else
      rreg_Scale_Correction <= wreg_Scale_Correction;      
  end              
  
  // Write to rreg_Kpuf
  always@(posedge clk)
	begin
    if (reset)
      rreg_Kpuf <= 36'h000040000;
    else
      rreg_Kpuf <= wreg_Kpuf;      
  end

  // Write to rreg_Kpufr
  always@(posedge clk)
	begin
    if (reset)
      rreg_Kpufr <= 36'h000040000;
    else
      rreg_Kpufr <= wreg_Kpufr;      
  end
  
  // Write to rreg_Kiufr
  always@(posedge clk)
	begin
    if (reset)
      rreg_Kiufr <= 36'h000000000;
    else
      rreg_Kiufr <= wreg_Kiufr;      
  end
  
  // Write to rreg_Kdufr
  always@(posedge clk)
	begin
    if (reset)
      rreg_Kdufr <= 36'h000000000;
    else
      rreg_Kdufr <= wreg_Kdufr;      
  end    
  
        
  //General Purpose Read Write Registers
  always@(posedge clk)
	begin
    if (reset) begin      
      rreg_GPRW_60  <= 36'h000000000;
      rreg_GPRW_61  <= 36'h000000000;
      rreg_GPRW_62  <= 36'h000000000;
      rreg_GPRW_63  <= 36'h000000000;
      rreg_GPRW_64  <= 36'h000000000;
      rreg_GPRW_65  <= 36'h000000000;
      rreg_GPRW_66  <= 36'h000000000;
      rreg_GPRW_67  <= 36'h000000000;
      rreg_GPRW_68  <= 36'h000000000;
      rreg_GPRW_69  <= 36'h000000000;
      rreg_GPRW_6A  <= 36'h000000000;
      rreg_GPRW_6B  <= 36'h000000000;
      rreg_GPRW_6C  <= 36'h000000000;
      rreg_GPRW_6D  <= 36'h000000000;
      rreg_GPRW_6E  <= 36'h000000000;
      rreg_GPRW_6F  <= 36'h000000000;
      rreg_GPRW_70  <= 36'h000000000;
      rreg_GPRW_71  <= 36'h000000000;
      rreg_GPRW_72  <= 36'h000000000;
      rreg_GPRW_73  <= 36'h000000000;
      rreg_GPRW_74  <= 36'h000000000;
      rreg_GPRW_75  <= 36'h000000000;
      rreg_GPRW_76  <= 36'h000000000;
      rreg_GPRW_77  <= 36'h000000000;
      rreg_GPRW_78  <= 36'h000000000;
      rreg_GPRW_79  <= 36'h000000000;
      rreg_GPRW_7A  <= 36'h000000000;
      rreg_GPRW_7B  <= 36'h000000000;
      rreg_GPRW_7C  <= 36'h000000000;
      rreg_GPRW_7D  <= 36'h000000000;
      rreg_GPRW_7E  <= 36'h000000000;
      rreg_GPRW_7F  <= 36'h000000000;      
    end else begin
      rreg_GPRW_60  <= wreg_GPRW_60;
      rreg_GPRW_61  <= wreg_GPRW_61;
      rreg_GPRW_62  <= wreg_GPRW_62;
      rreg_GPRW_63  <= wreg_GPRW_63;
      rreg_GPRW_64  <= wreg_GPRW_64;
      rreg_GPRW_65  <= wreg_GPRW_65;
      rreg_GPRW_66  <= wreg_GPRW_66;
      rreg_GPRW_67  <= wreg_GPRW_67;
      rreg_GPRW_68  <= wreg_GPRW_68;
      rreg_GPRW_69  <= wreg_GPRW_69;
      rreg_GPRW_6A  <= wreg_GPRW_6A;
      rreg_GPRW_6B  <= wreg_GPRW_6B;
      rreg_GPRW_6C  <= wreg_GPRW_6C;
      rreg_GPRW_6D  <= wreg_GPRW_6D;
      rreg_GPRW_6E  <= wreg_GPRW_6E;
      rreg_GPRW_6F  <= wreg_GPRW_6F;
      rreg_GPRW_70  <= wreg_GPRW_70;
      rreg_GPRW_71  <= wreg_GPRW_71;
      rreg_GPRW_72  <= wreg_GPRW_72;
      rreg_GPRW_73  <= wreg_GPRW_73;
      rreg_GPRW_74  <= wreg_GPRW_74;
      rreg_GPRW_75  <= wreg_GPRW_75;
      rreg_GPRW_76  <= wreg_GPRW_76;
      rreg_GPRW_77  <= wreg_GPRW_77;
      rreg_GPRW_78  <= wreg_GPRW_78;
      rreg_GPRW_79  <= wreg_GPRW_79;
      rreg_GPRW_7A  <= wreg_GPRW_7A;
      rreg_GPRW_7B  <= wreg_GPRW_7B;
      rreg_GPRW_7C  <= wreg_GPRW_7C;
      rreg_GPRW_7D  <= wreg_GPRW_7D;
      rreg_GPRW_7E  <= wreg_GPRW_7E;
      rreg_GPRW_7F  <= wreg_GPRW_7F;            
    end
  end   

  
  
// END READ REGISTERS  
//--------------------------------------------------------    
     
//--------------------------------------------------------
// 4 STROBE CONTROL CYCLE

  // cycle 1 bit through 4 bits.
  always@(posedge clk)
	begin
    if (reset) begin
      bc_strb[3:0] <= 4'b0001;
    end else begin
      bc_strb[3:1] <= bc_strb[2:0];
      bc_strb[0]   <= bc_strb[3];
    end
  end  
//-------------------------------------------------------- 
          
     
//--------------------------------------------------------
// FAN CONTROLLER

  // FAN PWM Controller
  PWMController FanController_i
  (  
    .clk(clk),                            // System Clock 
    .reset(reset),                        // System Reset
    .strb_1us(strb_1us),                  // One micro second strobe
    .enable(wreg_Fan1_en | wreg_Fan2_en), // Enable Fan  
    .pwm_cmd_cyc(wreg_Fan_period),        // 1us counts for PWM total period [5:0]
    .pwm_cmd_on(wreg_Fan_pwm),            // 1us counts for PWM on period {5:0]
    .strb_load(ld_Fan),                   // Strobe to load PWM commands
    .out_pwm(Fan_PWM_Signal)              // Output FAN PWM Signal
  ); 
  
  //Invert the PWM from FAN #1 to FAN #2  
  always@(posedge clk)
  begin
    if (reset) begin
      FanPWM1 <= 1'b0;
      FanPWM2 <= 1'b0;
    end else begin
      FanPWM1 <=  Fan_PWM_Signal & wreg_Fan1_en;
      FanPWM2 <=  Fan_PWM_Signal & wreg_Fan2_en;
    end  
  end
  
  //FAN1 PWM Signal
  assign FAN1_PWM = FanPWM1;
  
  //FAN2 PWM Signal
  assign FAN2_PWM = FanPWM2;
  
  //FAN #1 Tachometer Feedback
  Tachometer  Tachometer_i1
  (  
    .clk(clk),                      // System Clock 
    .reset(reset),                  // System Reset
    .strb_100us(strb_100us),        // One hundred micro second strobe
    .strb_1s(strb_1s),              // One second strobe
    .enable(enable),                // Enable Fan  
    .tach_fbk(FAN1_TACH_N),         // TACH FBK Pulse
    .tach_vel(fan1_tach_pps)        // Fan velocity fdbk in revs/us
  );
    
  //FAN #2 Tachometer Feedback
  Tachometer  Tachometer_i2
  (  
    .clk(clk),                      // System Clock 
    .reset(reset),                  // System Reset
    .strb_100us(strb_100us),        // One hundred micro second strobe
    .strb_1s(strb_1s),              // One second strobe
    .enable(enable),                // Enable Fan  
    .tach_fbk(FAN2_TACH_N),         // TACH FBK Pulse
    .tach_vel(fan2_tach_pps)        // Fan velocity fdbk in revs/us
  );
  
// END FAN CONTROLLER
//-------------------------------------------------------- 
      
      
//--------------------------------------------------------
// 1 BIT DAC
// parameter FREQ_RATE = 16'h01A0; //dec2hex(floor(1/(2E3*60*20E-9)))
  WaveformSynth WaveformSynth_i
  (
    .clk(clk),                      // System Clock
    .reset(reset),                  // System Reset
    .enable(wreg_DSM_en),           // Enable
    .en_smpl(bc_strb[0]),           // Enable output sampling rate cntrl
    .ld_freq(ld_freq),              // Load signal for frequency count
    .freq_cnt(wreg_DSM_freq),       // 15 bit value specify count for frequency
    .wv_type(2'b00),                // 2 bit value specifies waveform type
    .p_strb(),                      // Strobe to indicate peak of waveform (Not Used)   
    .n_strb(),                      // Flag to indicate waveform is negative (Not Used)
    .ac_bit(EXC_C_1BIT_DAC)         // Output dsm bit
  );  
// END 1 BIT DAC
//--------------------------------------------------------

//--------------------------------------------------------
// COM FLAG ASSIGNMENT
  assign COM_Cntrl = wreg_COM_Cntrl;
// END COM FLAG
//--------------------------------------------------------

//--------------------------------------------------------
// ADC SAMPLING SCHEDULE AND CONTROL

  
   defparam ADCSchedule_i.dw = 12;              
   defparam ADCSchedule_i.max = 12'hF9E; 
  ADCSchedule ADCSchedule_i
  (    
    .clk(clk),                  // System Clock 
    .reset(reset),              // System Reset
    .enable(wreg_ADC1_en),      // Enable 
    .next_strb(adc1_data_strb), // Strobe data sample complete
    .mux1_sel(),                // MUX 1 Select
    .mux2_sel(),                // MUX 2 Select
    .mux3_sel(),                // MUX 3 Select
    .mux4_sel(mux_num),         // MUX 4 Select
    .adc_ch(adc1_num),          // ADC Channel Number
    .adc_addr(adc1_addr),       // ADC Address
    .sample_strb(adc1_smpl_strb)// Strobe to Sample Data
  );
  
  assign ADC_1_MUXA = mux_num[0];
  assign ADC_1_MUXB = mux_num[1];

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
// TEMPERATURE SENSOR 
 
  defparam I2C_Tmp275_i.I2C_ADDRESS  = 8'h9e;         //  Address for slave I2C Temp sensor
  defparam I2C_Tmp275_i.I2C_CONFIG   = 8'h7e;         //  Configuration data for sensor 
  defparam I2C_Tmp275_i.I2C_UTEMP    = 12'h4b0;       //  Upper temperature limit for alarm 75C
  defparam I2C_Tmp275_i.I2C_LTEMP    = 12'h000;       //  Lower temperature limit for alarm 0C
  defparam I2C_Tmp275_i.BAUD_MASK    = 16'h00C7;      //  Baud Rate Counter  250KHz bus rate
  I2C_Tmp275  I2C_Tmp275_i(  
    .clk(clk),                                        //  System Clock 
    .reset(reset),                                    //  System Reset (Syncronous)  
    .enable(enable),                                  //  Enable this interface
    .strb_500ms(strb_500ms),                          //  500ms Strobe
    .temp_sense(temp_sense),                          //  Temperature read from sensor
    .temp_status(temp_status),                        //  Temperature sensor status
    .temp_strb(temp_strb),                            //  Strobe that new temp data is ready
    .I2C_SCL_in(I2C_TMP275_SCL_in),                   //  Input SCL (As Slave)
    .I2C_SCL_out(I2C_TMP275_SCL_out),                 //  Output SCL (As Master)
    .I2C_SDA_in(I2C_TMP275_SDA_in),                   //  Input SDA (Master Ack/Nack, Slave Recieve)
    .I2C_SDA_out(I2C_TMP275_SDA_out)                  //  Output SDA (Master/Slave Ack/Nack)
  );
  
  assign TSENSE_TEST = wreg_TempTest;
  
// END TEMPERATURE SENSOR    
//--------------------------------------------------------  

//--------------------------------------------------------
// SOLENOID CONTROLLERS

  // Solenoid RAC Latch PWM Controller
  PWMController PWMController_RL_i
  (  
    .clk(clk),                            // System Clock 
    .reset(reset),                        // System Reset
    .strb_1us(strb_1us),                  // One micro second strobe
    .enable(wreg_SOL_RL_en),              // Enable PWM output
    .pwm_cmd_cyc(wreg_SOL_RL_period),     // 1us counts for PWM total period [7:0]
    .pwm_cmd_on(wreg_SOL_RL_pwm),         // 1us counts for PWM on period [7:0]
    .strb_load(ld_sol_rl_pwm),            // Strobe to load PWM commands
    .out_pwm(RL_SOL_PWM)                  // Output RAC Latch PWM Signal
  ); 
  
  // Solenoid Door Lock PWM Controller
  PWMController PWMController_DL_i
  (  
    .clk(clk),                            // System Clock 
    .reset(reset),                        // System Reset
    .strb_1us(strb_1us),                  // One micro second strobe
    .enable(wreg_SOL_DL_en),              // Enable PWM output
    .pwm_cmd_cyc(wreg_SOL_DL_period),     // 1us counts for PWM total period [7:0]
    .pwm_cmd_on(wreg_SOL_DL_pwm),         // 1us counts for PWM on period [7:0]
    .strb_load(ld_sol_dl_pwm),            // Strobe to load PWM commands
    .out_pwm(DL_SOL_PWM)                  // Output Door Lock PWM Signal
  );   

  // Solenoid Venous Clamp PWM Controller
  PWMController PWMController_VC_i
  (  
    .clk(clk),                            // System Clock 
    .reset(reset),                        // System Reset
    .strb_1us(strb_1us),                  // One micro second strobe
    .enable(wreg_SOL_VC_en),              // Enable PWM output
    .pwm_cmd_cyc(wreg_SOL_VC_period),     // 1us counts for PWM total period [7:0]
    .pwm_cmd_on(wreg_SOL_VC_pwm),         // 1us counts for PWM on period [7:0]
    .strb_load(ld_sol_vc_pwm),            // Strobe to load PWM commands
    .out_pwm(VC_SOL_PWM)                  // Output Venous Clamp PWM Signal
  );   
    
// END SOLENOID CONTROLLERS
//--------------------------------------------------------
 
 
//-------------------------------------------------------- 
// DOOR REFERENCE SENSOR
 
  // Door Reference Sensor is Linear Potentiometer
  // ADC counts 0AXX-FXXX over 1 inch  
  assign DRS_PWM = wreg_DRS_en;
    
// END DOOR REFERENCE SENSOR
//-------------------------------------------------------- 
 

//-------------------------------------------------------- 
// DOOR REFERENCE SENSOR

  // Unit Under Test port map
  DAC_LTC1665 DAC_LTC1665_i
  (
    .clk(clk),                  // System Clock
    .reset(reset),              // System Reset (Syncronous) 
    .enable(wreg_DAC_en),       // Enable toggle
    .dac_clear(wreg_DAC_en),    // Clear DAC outputs
    .strb_clk(strb_1us),        // DAC Clock Rate
    .data_ch0(wreg_DAC_CH0),    // Output data for Ch0
    .data_ch1(wreg_DAC_CH1),    // Output data for Ch1
    .data_ch2(wreg_DAC_CH2),    // Output data for Ch2
    .data_ch3(wreg_DAC_CH3),    // Output data for Ch3
    .data_ch4(wreg_DAC_CH4),    // Output data for Ch4
    .data_ch5(adm_motor_curr),  // Output data for Ch5 ADM Motor Current
    .data_ch6(wreg_DAC_CH6),    // Output data for Ch6
    .data_ch7(wreg_DAC_CH7),    // Output data for Ch7
    .clr_n(DAC_CLR_N),          // Clear Output to DAC
    .cs_n(DAC_CS_N),            // Chip Select to DAC
    .sclk(DAC_DCLK),            // Sclk to DAC
    .din(DAC_DIN)               // Din to DAC
  );

// DAC CURRENT LIMIT
//-------------------------------------------------------- 


//-------------------------------------------------------- 
// MOTOR DRIVERS

  //------------------------------------------------------
  // BP MOTOR
  defparam StepperMotor_BP_i.Kscale = 36'h00019BFCC;   // (18/80)*(60/(2*200*20E-9))*2^-18; (return with bit 8 as bit 0)  
  StepperMotor StepperMotor_BP_i
  (
    .clk(clk),                          // System Clock
    .reset(reset),                      // System Reset (Syncronous) 
    .strb_1us(strb_1us),                // 1 us strobe to formulate profile
    .strb_1ms(strb_1ms),                // 1 ms timer to handle start conditions out of reset
    .strb_500ms(strb_500ms),            // 500 ms strobe to timeout enable if commanded off for more than 3 seconds
    .cmd_enable(wreg_Motor_BP_enable),  // Commanded Motor Enable  
    .acceleration(wreg_Motor_BP_Acc),   // Acceleration rpm/us
    .velocity(wreg_Motor_BP_Vel),       // Velocity in rpms (16 bit integer
    .direction(wreg_Motor_BP_Dir),      // Bit to specify direction (1 = clockwise)
    .usteps(wreg_Motor_BP_ustep),       // Table to specify microsteps (1, 1/2, 1/4, 1/16)    
    .motor_steps(BP_STEP),              // Motor step command waveform
    .motor_dir(BP_DIR),                 // Motor direction command
    .motor_m1(BP_M1),                   // Bit 1 of microstep setting
    .motor_m2(BP_M2),                   // Bit 2 of microstep setting
    .motor_reset_n(BP_RESET_N)          // Motor reset active low   
  );
    
  defparam Encoder_BP_i.STEP_DEBOUNCE  = 20'h009C3;        //     Time in 20ns counts to debounce encoder signals (50 us)
  defparam Encoder_BP_i.STEP_ERR_COUNT = 36'h0000C0000;    //     Count allowed to be off within a window before declaring a stall or uncmd motion       
  defparam Encoder_BP_i.STEP_VEL_SCALE = 26'h07270DF;      //     For encoder 360 use: 7270DF dec2hex(floor((18/80)*(60/360)*4/20E-9-1))
  defparam Encoder_BP_i.STEP_01_WEIGHT = 36'h000073333;    // 1.0 For 360/200 ratio 000073333 : DoubleToHex( (360/( 1.0*200)), 36, 18)
  defparam Encoder_BP_i.STEP_02_WEIGHT = 36'h000039999;    // 2.0 For 360/200 ratio 000039999 : DoubleToHex( (360/( 2.0*200)), 36, 18)
  defparam Encoder_BP_i.STEP_04_WEIGHT = 36'h00001CCCC;    // 4.0 For 360/200 ratio 00001CCCC : DoubleToHex( (360/( 4.0*200)), 36, 18)
  defparam Encoder_BP_i.STEP_16_WEIGHT = 36'h000007333;    //16.0 For 360/200 ratio 000007333 : DoubleToHex( (360/(16.0*200)), 36, 18)  
  Encoder Encoder_BP_i
  (  
    .clk(clk),                        // System Clock 
    .reset(reset),                    // System Reset
    .enable(1'b1),                    // Enable encoder
    .encoder_a(BPR_CHA_C),            // Encoder a feedback 
    .encoder_b(BPR_CHB_C),            // Encoder b feedback
    .usteps(wreg_Motor_BP_ustep),     // usteps commanded
    .cmd_step(BP_STEP),               // steps being sent to motor driver    
    .encoder_velocity(BP_Velocity),   // Calculated Veocity
    .encoder_dir(BP_Encoder[2]),      // Calculated direction of encoder movement    
    .steps_over(BP_Encoder[1]),       // Flag that steps are over commanded amount
    .steps_under(BP_Encoder[0])       // Flag that steps are under commanded amount
  );              
  
    
  defparam StepperMotorParameters_BP_i.LIM_USTEP2 = 18'h00028; // above 40 rpm use ustep 2
  defparam StepperMotorParameters_BP_i.LIM_USTEP1 = 18'h00064; // above 100 rpm use ustep 1
  defparam StepperMotorParameters_BP_i.LIM_USTEP0 = 18'h000A0; // above 160 rpm use ustep 0
  defparam StepperMotorParameters_BP_i.DAC_OFFSET = 18'h0000C; // Offset of 12
  StepperMotorParameters  StepperMotorParameters_BP_i
  (
    .clk(clk),                              // System Clock
    .reset(reset),                          // System Reset (Syncronous) 
    .enable(1'b1),                          // Enable toggle
    .rpm_int_vel(wreg_Motor_BP_Vel[35:18]), // Commanded RPM upper 18 bits
    .current_limit(8'hff),                  // Upper limit to hold peak current
    .peak_current(wreg_DAC_CH0),            // Peak Current to use
    .usteps(wreg_Motor_BP_ustep)            // Microsteps to use
  );
  
  // END BP MOTOR
  //------------------------------------------------------ 


  //------------------------------------------------------
  // DP1 MOTOR       
  defparam StepperMotor_DP1_i.Kscale = 36'h00019BFCC;   // (18/80)*(60/(2*200*20E-9))*2^-18; (return with bit 8 as bit 0)  
  StepperMotor StepperMotor_DP1_i
  (
    .clk(clk),                          // System Clock
    .reset(reset),                      // System Reset (Syncronous) 
    .strb_1us(strb_1us),                // 1 us strobe to formulate profile
    .strb_1ms(strb_1ms),                // 1 ms timer to handle start conditions out of reset
    .strb_500ms(strb_500ms),            // 500 ms strobe to timeout enable if commanded off for more than 3 seconds
    .cmd_enable(wreg_Motor_DP1_enable), // Commanded Motor Enable  
    .acceleration(wreg_Motor_DP1_Acc),  // Acceleration rpm/us
    .velocity(wreg_Motor_DP1_Vel),      // Velocity in rpms (16 bit integer
    .direction(wreg_Motor_DP1_Dir),     // Bit to specify direction (1 = clockwise)
    .usteps(wreg_Motor_DP1_ustep),      // Table to specify microsteps (1, 1/2, 1/4, 1/16)
    .motor_steps(DP1_STEP),             // Motor step command waveform
    .motor_dir(DP1_DIR),                // Motor direction command
    .motor_m1(DP1_M1),                  // Bit 1 of microstep setting
    .motor_m2(DP1_M2),                  // Bit 2 of microstep setting
    .motor_reset_n(DP1_RESET_N)         // Motor reset active low   
  );
  
  defparam Encoder_DP1_i.STEP_DEBOUNCE  = 20'h009C3;        //     Time in 20ns counts to debounce encoder signals (50 us)
  defparam Encoder_DP1_i.STEP_ERR_COUNT = 36'h0000C0000;    //     Count allowed to be off within a window before declaring a stall or uncmd motion   
  defparam Encoder_DP1_i.STEP_VEL_SCALE = 26'h07270DF;      //     For encoder 360 use: 7270DF dec2hex(floor((18/80)*(60/360)*4/20E-9-1))
  defparam Encoder_DP1_i.STEP_01_WEIGHT = 36'h000073333;    // 1.0 For 360/200 ratio 000073333 : DoubleToHex( (360/( 1.0*200)), 36, 18)
  defparam Encoder_DP1_i.STEP_02_WEIGHT = 36'h000039999;    // 2.0 For 360/200 ratio 000039999 : DoubleToHex( (360/( 2.0*200)), 36, 18)
  defparam Encoder_DP1_i.STEP_04_WEIGHT = 36'h00001CCCC;    // 4.0 For 360/200 ratio 00001CCCC : DoubleToHex( (360/( 4.0*200)), 36, 18)
  defparam Encoder_DP1_i.STEP_16_WEIGHT = 36'h000007333;    //16.0 For 360/200 ratio 000007333 : DoubleToHex( (360/(16.0*200)), 36, 18)  
  Encoder Encoder_DP1_i
  (  
    .clk(clk),                        // System Clock 
    .reset(reset),                    // System Reset
    .enable(1'b1),                    // Enable encoder
    .encoder_a(DP1R_CHA_C),           // Encoder a feedback 
    .encoder_b(DP1R_CHB_C),           // Encoder b feedback
    .usteps(wreg_Motor_DP1_ustep),    // usteps commanded
    .cmd_step(DP1_STEP),              // steps being sent to motor driver    
    .encoder_velocity(DP1_Velocity),  // Calculated Veocity
    .encoder_dir(DP1_Encoder[2]),     // Calculated direction of encoder movement    
    .steps_over(DP1_Encoder[1]),      // Flag that steps are over commanded amount
    .steps_under(DP1_Encoder[0])      // Flag that steps are under commanded amount
  );
  
  defparam StepperMotorParameters_DP1_i.LIM_USTEP2 = 18'h00028; // above 40 rpm use ustep 2
  defparam StepperMotorParameters_DP1_i.LIM_USTEP1 = 18'h00064; // above 100 rpm use ustep 1
  defparam StepperMotorParameters_DP1_i.LIM_USTEP0 = 18'h000A0; // above 160 rpm use ustep 0
  defparam StepperMotorParameters_DP1_i.DAC_OFFSET = 18'h0000C; // Offset of 12
  StepperMotorParameters  StepperMotorParameters_DP1_i
  (
    .clk(clk),                              // System Clock
    .reset(reset),                          // System Reset (Syncronous) 
    .enable(1'b1),                          // Enable toggle
    .rpm_int_vel(wreg_Motor_DP1_Vel[35:18]),// Commanded RPM upper 18 bits
    .current_limit(8'hff),                  // Upper limit to hold peak current
    .peak_current(wreg_DAC_CH1),            // Peak Current to use
    .usteps(wreg_Motor_DP1_ustep)           // Microsteps to use
  ); 
  
  // END DP1 MOTOR
  //------------------------------------------------------  


  //------------------------------------------------------
  // DP2 MOTOR
  defparam StepperMotor_DP2_i.Kscale = 36'h00019BFCC;   // (18/80)*(60/(2*200*20E-9))*2^-18; (return with bit 8 as bit 0)    
  StepperMotor StepperMotor_DP2_i
  (
    .clk(clk),                          // System Clock
    .reset(reset),                      // System Reset (Syncronous) 
    .strb_1us(strb_1us),                // 1 us strobe to formulate profile
    .strb_1ms(strb_1ms),                // 1 ms timer to handle start conditions out of reset
    .strb_500ms(strb_500ms),            // 500 ms strobe to timeout enable if commanded off for more than 3 seconds
    .cmd_enable(wreg_Motor_DP2_enable), // Commanded Motor Enable  
    .acceleration(wreg_Motor_DP2_Acc),  // Acceleration rpm/us
    .velocity(wreg_Motor_DP2_Vel),      // Velocity in rpms (16 bit integer
    .direction(wreg_Motor_DP2_Dir),     // Bit to specify direction (1 = clockwise)
    .usteps(wreg_Motor_DP2_ustep),      // Table to specify microsteps (1, 1/2, 1/4, 1/16)
    .motor_steps(DP2_STEP),             // Motor step command waveform
    .motor_dir(DP2_DIR),                // Motor direction command
    .motor_m1(DP2_M1),                  // Bit 1 of microstep setting
    .motor_m2(DP2_M2),                  // Bit 2 of microstep setting
    .motor_reset_n(DP2_RESET_N)         // Motor reset active low   
  );
  
  
  defparam Encoder_DP2_i.STEP_DEBOUNCE  = 20'h009C3;        //     Time in 20ns counts to debounce encoder signals (50 us)
  defparam Encoder_DP2_i.STEP_ERR_COUNT = 36'h0000C0000;    //     Count allowed to be off within a window before declaring a stall or uncmd motion   
  defparam Encoder_DP2_i.STEP_VEL_SCALE = 26'h07270DF;      //     For encoder 360 use: 7270DF dec2hex(floor((18/80)*(60/360)*4/20E-9-1))
  defparam Encoder_DP2_i.STEP_01_WEIGHT = 36'h000073333;    // 1.0 For 360/200 ratio 000073333 : DoubleToHex( (360/( 1.0*200)), 36, 18)
  defparam Encoder_DP2_i.STEP_02_WEIGHT = 36'h000039999;    // 2.0 For 360/200 ratio 000039999 : DoubleToHex( (360/( 2.0*200)), 36, 18)
  defparam Encoder_DP2_i.STEP_04_WEIGHT = 36'h00001CCCC;    // 4.0 For 360/200 ratio 00001CCCC : DoubleToHex( (360/( 4.0*200)), 36, 18)
  defparam Encoder_DP2_i.STEP_16_WEIGHT = 36'h000007333;    //16.0 For 360/200 ratio 000007333 : DoubleToHex( (360/(16.0*200)), 36, 18)  
  Encoder Encoder_DP2_i
  (  
    .clk(clk),                        // System Clock 
    .reset(reset),                    // System Reset
    .enable(1'b1),                    // Enable encoder
    .encoder_a(DP2R_CHA_C),           // Encoder a feedback 
    .encoder_b(DP2R_CHB_C),           // Encoder b feedback
    .usteps(wreg_Motor_DP2_ustep),    // usteps commanded
    .cmd_step(DP2_STEP),              // steps being sent to motor driver    
    .encoder_velocity(DP2_Velocity),  // Calculated Veocity
    .encoder_dir(DP2_Encoder[2]),     // Calculated direction of encoder movement    
    .steps_over(DP2_Encoder[1]),      // Flag that steps are over commanded amount
    .steps_under(DP2_Encoder[0])      // Flag that steps are under commanded amount
  );   
 
  defparam StepperMotorParameters_DP2_i.LIM_USTEP2 = 18'h00028; // above 40 rpm use ustep 2
  defparam StepperMotorParameters_DP2_i.LIM_USTEP1 = 18'h00064; // above 100 rpm use ustep 1
  defparam StepperMotorParameters_DP2_i.LIM_USTEP0 = 18'h000A0; // above 160 rpm use ustep 0
  defparam StepperMotorParameters_DP2_i.DAC_OFFSET = 18'h0000C; // Offset of 12
  StepperMotorParameters  StepperMotorParameters_DP2_i
  (
    .clk(clk),                              // System Clock
    .reset(reset),                          // System Reset (Syncronous) 
    .enable(1'b1),                          // Enable toggle
    .rpm_int_vel(wreg_Motor_DP2_Vel[35:18]),// Commanded RPM upper 18 bits
    .current_limit(8'hff),                  // Upper limit to hold peak current
    .peak_current(wreg_DAC_CH2),            // Peak Current to use
    .usteps(wreg_Motor_DP2_ustep)           // Microsteps to use
  );   
  
  // END DP1 MOTOR
  //------------------------------------------------------   

  //------------------------------------------------------
  // ELP MOTOR
  defparam StepperMotor_ELP_i.Kscale = 36'h00019BFCC;   // (18/80)*(60/(2*200*20E-9))*2^-18; (return with bit 8 as bit 0)    
  StepperMotor StepperMotor_ELP_i
  (
    .clk(clk),                          // System Clock
    .reset(reset),                      // System Reset (Syncronous) 
    .strb_1us(strb_1us),                // 1 us strobe to formulate profile
    .strb_1ms(strb_1ms),                // 1 ms timer to handle start conditions out of reset
    .strb_500ms(strb_500ms),            // 500 ms strobe to timeout enable if commanded off for more than 3 seconds
    .cmd_enable(wreg_Motor_ELP_enable), // Commanded Motor Enable  
    .acceleration(wreg_Motor_ELP_Acc),  // Acceleration rpm/us
    .velocity(wreg_Motor_ELP_Vel),      // Velocity in rpms (16 bit integer)
    .direction(wreg_Motor_ELP_Dir),     // Bit to specify direction (1 = clockwise)
    .usteps(wreg_Motor_ELP_ustep),      // Table to specify microsteps (1, 1/2, 1/4, 1/16)    
    .motor_steps(ELP_STEP),             // Motor step command waveform
    .motor_dir(ELP_DIR),                // Motor direction command
    .motor_m1(ELP_M1),                  // Bit 1 of microstep setting
    .motor_m2(ELP_M2),                  // Bit 2 of microstep setting
    .motor_reset_n(ELP_RESET_N)         // Motor reset active low   
  );
  
  defparam Encoder_ELP_i.STEP_DEBOUNCE  = 20'h009C3;        //     Time in 20ns counts to debounce encoder signals (50 us)
  defparam Encoder_ELP_i.STEP_ERR_COUNT = 36'h0000C0000;    //     Count allowed to be off within a window before declaring a stall or uncmd motion  
  defparam Encoder_ELP_i.STEP_VEL_SCALE = 26'h07270DF;      //     For encoder 360 use: 7270DF dec2hex(floor((18/80)*(60/360)*4/20E-9-1))
  defparam Encoder_ELP_i.STEP_01_WEIGHT = 36'h000073333;    // 1.0 For 360/200 ratio 000073333 : DoubleToHex( (360/( 1.0*200)), 36, 18)
  defparam Encoder_ELP_i.STEP_02_WEIGHT = 36'h000039999;    // 2.0 For 360/200 ratio 000039999 : DoubleToHex( (360/( 2.0*200)), 36, 18)
  defparam Encoder_ELP_i.STEP_04_WEIGHT = 36'h00001CCCC;    // 4.0 For 360/200 ratio 00001CCCC : DoubleToHex( (360/( 4.0*200)), 36, 18)
  defparam Encoder_ELP_i.STEP_16_WEIGHT = 36'h000007333;    //16.0 For 360/200 ratio 000007333 : DoubleToHex( (360/(16.0*200)), 36, 18) 
  Encoder Encoder_ELP_i
  (  
    .clk(clk),                        // System Clock 
    .reset(reset),                    // System Reset
    .enable(1'b1),                    // Enable encoder
    .encoder_a(ELPR_CHA_C),           // Encoder a feedback 
    .encoder_b(ELPR_CHB_C),           // Encoder b feedback
    .usteps(wreg_Motor_ELP_ustep),    // usteps commanded
    .cmd_step(ELP_STEP),              // steps being sent to motor driver    
    .encoder_velocity(ELP_Velocity),  // Calculated Veocity
    .encoder_dir(ELP_Encoder[2]),     // Calculated direction of encoder movement    
    .steps_over(ELP_Encoder[1]),      // Flag that steps are over commanded amount
    .steps_under(ELP_Encoder[0])      // Flag that steps are under commanded amount
  );  
  
  // END ELP MOTOR
  //------------------------------------------------------  

  //------------------------------------------------------
  // HEP MOTOR
  defparam StepperMotor_HEP_i.Kscale = 36'h0007270E0;   // (60/(2*200*20E-9))*2^-18; (return with bit 8 as bit 0)    
  StepperMotor StepperMotor_HEP_i
  (
    .clk(clk),                          // System Clock
    .reset(reset),                      // System Reset (Syncronous) 
    .strb_1us(strb_1us),                // 1 us strobe to formulate profile
    .strb_1ms(strb_1ms),                // 1 ms timer to handle start conditions out of reset
    .strb_500ms(strb_500ms),            // 500 ms strobe to timeout enable if commanded off for more than 3 seconds
    .cmd_enable(wreg_Motor_HEP_enable), // Commanded Motor Enable  
    .acceleration(wreg_Motor_HEP_Acc),  // Acceleration rpm/us
    .velocity(wreg_Motor_HEP_Vel),      // Velocity in rpms (16 bit integer
    .direction(wreg_Motor_HEP_Dir),     // Bit to specify direction (1 = clockwise)
    .usteps(wreg_Motor_HEP_ustep),      // Table to specify microsteps (1, 1/2, 1/4, 1/16)    
    .motor_steps(HEP_STEP),             // Motor step command waveform
    .motor_dir(HEP_DIR),                // Motor direction command
    .motor_m1(HEP_M1),                  // Bit 1 of microstep setting
    .motor_m2(HEP_M2),                  // Bit 2 of microstep setting
    .motor_reset_n(HEP_RESET_N)         // Motor reset active low   
  );
  
  defparam Encoder_HEP_i.STEP_DEBOUNCE  = 20'h009C3;        //     Time in 20ns counts to debounce encoder signals (50 us)
  defparam Encoder_HEP_i.STEP_ERR_COUNT = 36'h0000C0000;    //     Count allowed to be off within a window before declaring a stall or uncmd motion
  defparam Encoder_HEP_i.STEP_VEL_SCALE = 26'h1FCA054;      //     For encoder 360 use: 1FCA054 dec2hex(floor((60/360)*4/20E-9-1))
  defparam Encoder_HEP_i.STEP_01_WEIGHT = 36'h000073333;    // 1.0 For 360/200 ratio 000073333 : DoubleToHex( (360/( 1.0*200)), 36, 18)
  defparam Encoder_HEP_i.STEP_02_WEIGHT = 36'h000039999;    // 2.0 For 360/200 ratio 000039999 : DoubleToHex( (360/( 2.0*200)), 36, 18)
  defparam Encoder_HEP_i.STEP_04_WEIGHT = 36'h00001CCCC;    // 4.0 For 360/200 ratio 00001CCCC : DoubleToHex( (360/( 4.0*200)), 36, 18)
  defparam Encoder_HEP_i.STEP_16_WEIGHT = 36'h000007333;    //16.0 For 360/200 ratio 000007333 : DoubleToHex( (360/(16.0*200)), 36, 18) 
  Encoder Encoder_HEP_i
  (  
    .clk(clk),                          // System Clock 
    .reset(reset),                      // System Reset
    .enable(1'b1),                      // Enable encoder
    .encoder_a(HEPR_CHA_C),             // Encoder a feedback 
    .encoder_b(HEPR_CHB_C),             // Encoder b feedback
    .usteps(wreg_Motor_HEP_ustep),      // usteps commanded
    .cmd_step(HEP_STEP),                // steps being sent to motor driver    
    .encoder_velocity(HEP_Velocity),    // Calculated Veocity
    .encoder_dir(HEP_Encoder[2]),       // Calculated direction of encoder movement    
    .steps_over(HEP_Encoder[1]),        // Flag that steps are over commanded amount
    .steps_under(HEP_Encoder[0])        // Flag that steps are under commanded amount
  );   
  
  // END HEP MOTOR
  //------------------------------------------------------ 
  
  //------------------------------------------------------
  // ADM CONTROLLER         
  ADM_Controller  ADM_Controller_i
  (
    .clk(clk),                                // System Clock
    .reset(reset),                            // System Reset (Syncronous) 
    .strb_1us(strb_1us),                      // 1 us strobe to formulate profile
    .strb_1ms(strb_1ms),                      // 1 ms timer to handle start conditions out of reset
    .strb_500ms(strb_500ms),                  // 500 ms strobe to timeout enable 
//    .ADM_STALL_EN(wreg_Spare_01[35]),
//    .ADM_USTEP(wreg_Spare_01[1:0]),           //= 2'b11,          // 1 ustep
//    .ADM_CUR_LOW(wreg_Spare_01[15:8]),        //= 8'h64,          // 0.8 Volts  
//    .ADM_CUR_HIGH(wreg_Spare_01[23:16]),      //= 8'h96,          // 1.2 Volts
//    .ADM_VEL_START(wreg_Spare_02),            //= 36'h000140000,  // 5
//    .ADM_VEL_MID(wreg_Spare_03),              //= 36'h000500000,  // 20
//    .ADM_VEL_END(wreg_Spare_04),              //= 36'h000140000,  // 5
//    .ADM_OPEN_FLAG(wreg_Spare_05[15:0]),      //= 16'h0f00,       // 0f00
//    .ADM_OPEN_RANGE(wreg_Spare_05[31:16]),    //= 16'h2000,       // 2000
//    .ADM_CLOSED_RANGE(wreg_Spare_06[15:0]),   //= 16'ha000,       // a000
//    .ADM_MID_RANGE(wreg_Spare_06[31:16]),     //= 16'h5000,       // 5000  
//    .ADM_ACCELERATION(36'h00000001A),         //= 36'h00000001A   // 100 rpm/us        
    .strb_open(wreg_ADM_open_strb),           // Strobe to open the door
    .strb_close(wreg_ADM_close_strb),         // Strobe to close the door  
    .adm_position(rreg_ADC1_NOMUX_CH5),       // Linear door position  
    .adm_stalling(adm_stalling),              // ADM Stalling
    .strb_status(adm_status_strb),            // Strobe feedback that door has changed
    .door_status(adm_door_status),            // Status indicating door position    
    .motor_curr(adm_motor_curr),              // Motor Current to DAC  
    .motor_steps(DL_STEP),                    // Motor step command waveform
    .motor_dir(DL_DIR),                       // Motor direction command
    .motor_m1(DL_M1),                         // Bit 1 of microstep setting
    .motor_m2(DL_M2),                         // Bit 2 of microstep setting
    .motor_reset_n(DL_RESET_N)                // Motor reset active low       
  );
  
  defparam Encoder_ADM_i.STEP_DEBOUNCE  = 20'h009C3;        //     Time in 20ns counts to debounce encoder signals (50 us)
  defparam Encoder_ADM_i.STEP_ERR_COUNT = 36'h000100000;    //     Count allowed to be off within a window before declaring a stall or uncmd motion
  defparam Encoder_ADM_i.STEP_VEL_SCALE = 26'h1FCA054;      //     For encoder 360 use: 1FCA054 dec2hex(floor((60/360)*4/20E-9-1))
  defparam Encoder_ADM_i.STEP_01_WEIGHT = 36'h000073333;    // 1.0 For 360/200 ratio 000073333 : DoubleToHex( (360/( 1.0*200)), 36, 18)
  defparam Encoder_ADM_i.STEP_02_WEIGHT = 36'h000039999;    // 2.0 For 360/200 ratio 000039999 : DoubleToHex( (360/( 2.0*200)), 36, 18)
  defparam Encoder_ADM_i.STEP_04_WEIGHT = 36'h00001CCCC;    // 4.0 For 360/200 ratio 00001CCCC : DoubleToHex( (360/( 4.0*200)), 36, 18)
  defparam Encoder_ADM_i.STEP_16_WEIGHT = 36'h000007333;    //16.0 For 360/200 ratio 000007333 : DoubleToHex( (360/(16.0*200)), 36, 18) 
  Encoder Encoder_ADM_i
  (  
    .clk(clk),                          // System Clock 
    .reset(reset),                      // System Reset
    .enable(1'b1),                      // Enable encoder
    .encoder_a(DL_CHA_C),               // Encoder a feedback 
    .encoder_b(DL_CHB_C),               // Encoder b feedback
    .usteps(2'b00),                     // usteps commanded
    .cmd_step(DL_STEP),                 // steps being sent to motor driver    
    .encoder_velocity(DL_Velocity),     // Calculated Veocity
    .encoder_dir(DL_Encoder[2]),        // Calculated direction of encoder movement    
    .steps_over(DL_Encoder[1]),         // Flag that steps are over commanded amount
    .steps_under(DL_Encoder[0])         // Flag that steps are under commanded amount
  );   
  
  assign adm_stalling = (DL_Encoder[0] | DL_Encoder[1]);
  
  // END ADM CONTROLLER
  //------------------------------------------------------ 
   
// END MOTOR DRIVERS
//--------------------------------------------------------

//--------------------------------------------------------
// SUBSYSTEM RAC COMMUNICATION
  defparam SubSystem_RAC_i.WR_LOC_01      = 16'h0000;   // 0 Write Subsystem Location 01
  defparam SubSystem_RAC_i.WR_LOC_02      = 16'h0014;   // 1 Write Subsystem VO
  defparam SubSystem_RAC_i.WR_LOC_03      = 16'h0018;   // 2 Write Subsystem HO
  defparam SubSystem_RAC_i.WR_LOC_04      = 16'h001a;   // 3 Write Subsystem FL
  defparam SubSystem_RAC_i.WR_LOC_05      = 16'h0010;   // 4 Write Subsystem FPR
  defparam SubSystem_RAC_i.WR_LOC_06      = 16'h0011;   // 5 Write Subsystem FPW
  defparam SubSystem_RAC_i.WR_LOC_07      = 16'h0012;   // 6 Write Subsystem HPR
  defparam SubSystem_RAC_i.WR_LOC_08      = 16'h0013;   // 7 Write Subsystem HDC
  defparam SubSystem_RAC_i.WR_LOC_09      = 16'h001b;   // 8 Write Subsystem SC
  defparam SubSystem_RAC_i.WR_LOC_10      = 16'h0009;   // Write Subsystem Location 10
  defparam SubSystem_RAC_i.WR_LOC_11      = 16'h000A;   // Write Subsystem Location 11
  defparam SubSystem_RAC_i.WR_LOC_12      = 16'h000B;   // Write Subsystem Location 12
  defparam SubSystem_RAC_i.WR_LOC_13      = 16'h000C;   // Write Subsystem Location 13
  defparam SubSystem_RAC_i.WR_LOC_14      = 16'h000D;   // Write Subsystem Location 14
  defparam SubSystem_RAC_i.WR_LOC_15      = 16'h000E;   // Write Subsystem Location 15
  defparam SubSystem_RAC_i.WR_LOC_16      = 16'h000F;   // Write Subsystem Location 16
  defparam SubSystem_RAC_i.RD_LOC_01      = 16'h0000;   // Read  Subsystem Location 01
  defparam SubSystem_RAC_i.RD_LOC_02      = 16'h0015;   // Read  Subsystem VER
  defparam SubSystem_RAC_i.RD_LOC_03      = 16'h0017;   // Read  Subsystem LSV
  defparam SubSystem_RAC_i.RD_LOC_04      = 16'h0016;   // Read  Subsystem ELS
  defparam SubSystem_RAC_i.RD_LOC_05      = 16'h0019;   // Read  Subsystem VT0
  defparam SubSystem_RAC_i.RD_LOC_06      = 16'h000B;   // Read  Subsystem RAF
  defparam SubSystem_RAC_i.RD_LOC_07      = 16'h001c;   // Read  Subsystem ST5
  defparam SubSystem_RAC_i.RD_LOC_08      = 16'h0007;   // Read  Subsystem Location 08
  defparam SubSystem_RAC_i.RD_LOC_09      = 16'h0008;   // Read  Subsystem Location 09
  defparam SubSystem_RAC_i.RD_LOC_10      = 16'h0009;   // Read  Subsystem Location 10
  defparam SubSystem_RAC_i.RD_LOC_11      = 16'h000A;   // Read  Subsystem Location 11
  defparam SubSystem_RAC_i.RD_LOC_12      = 16'h000B;   // Read  Subsystem Location 12
  defparam SubSystem_RAC_i.RD_LOC_13      = 16'h000C;   // Read  Subsystem Location 13
  defparam SubSystem_RAC_i.RD_LOC_14      = 16'h000D;   // Read  Subsystem Location 14
  defparam SubSystem_RAC_i.RD_LOC_15      = 16'h000E;   // Read  Subsystem Location 15
  defparam SubSystem_RAC_i.RD_LOC_16      = 16'h000F;   // Read  Subsystem Location 16 
  //  COM PORT SUBLINK MASTER 460800, 8, E, 1
  defparam SubSystem_RAC_i.BAUD_MASK      = 16'h006B;
  defparam SubSystem_RAC_i.BAUD_QUALIFY   = 16'h0049;
  defparam SubSystem_RAC_i.PARITY_BIT     = 1'b1;
  defparam SubSystem_RAC_i.ECHO_ON        = 1'b0;
  defparam SubSystem_RAC_i.EXTEND_DATA    = 1'b0;
  defparam SubSystem_RAC_i.USE_LUT        = 1'b1;

  
  SubSystemInterfaceCT  SubSystem_RAC_i 
  (  
    .clk(clk),                                  // System Clock 
    .reset(reset),                              // System Reset
    .sys_tmr_strb(sys_tmr_strb),                // System Timer Strobe
    .enable(wreg_SUB_en),                       // System enable
    .rx_en(1'b1),  	                            // Recieve enable
    .rx(SUBLINK_C_RX),  		                    // Data recieve bit  
    .tx(SUBLINK_C_TX),                          // Tx bit to send out on pin
    .tx_en(),                                   // Tx enable signal          
    .subsystem_op_en(subsystem_op_en),          // Subsystem enable bit map 16 wr, 16 rd 
    .subsystem_wr_02(subsystem_wr_02),          // Subsystem write data 02
    .subsystem_wr_03(subsystem_wr_03),          // Subsystem write data 03
    .subsystem_wr_04(subsystem_wr_04),          // Subsystem write data 04
    .subsystem_wr_05(subsystem_wr_05),          // Subsystem write data 05
    .subsystem_wr_06(subsystem_wr_06),          // Subsystem write data 06
    .subsystem_wr_07(subsystem_wr_07),          // Subsystem write data 07
    .subsystem_wr_08(subsystem_wr_08),          // Subsystem write data 08
    .subsystem_wr_09(subsystem_wr_09),          // Subsystem write data 09
    .subsystem_wr_10(subsystem_wr_10),          // Subsystem write data 10
    .subsystem_wr_11(subsystem_wr_11),          // Subsystem write data 11
    .subsystem_wr_12(subsystem_wr_12),          // Subsystem write data 12
    .subsystem_wr_13(subsystem_wr_13),          // Subsystem write data 13
    .subsystem_wr_14(subsystem_wr_14),          // Subsystem write data 14
    .subsystem_wr_15(subsystem_wr_15),          // Subsystem write data 15
    .subsystem_wr_16(subsystem_wr_16),          // Subsystem write data 16
    .subsystem_reg_01(subsystem_reg_01),        // Subsystem register 01
    .subsystem_reg_02(subsystem_reg_02),        // Subsystem register 02
    .subsystem_reg_03(subsystem_reg_03),        // Subsystem register 03
    .subsystem_reg_04(subsystem_reg_04),        // Subsystem register 04
    .subsystem_reg_05(subsystem_reg_05),        // Subsystem register 05
    .subsystem_reg_06(subsystem_reg_06),        // Subsystem register 06
    .subsystem_reg_07(subsystem_reg_07),        // Subsystem register 07
    .subsystem_reg_08(subsystem_reg_08),        // Subsystem register 08
    .subsystem_reg_09(subsystem_reg_09),        // Subsystem register 09
    .subsystem_reg_10(subsystem_reg_10),        // Subsystem register 10
    .subsystem_reg_11(subsystem_reg_11),        // Subsystem register 11
    .subsystem_reg_12(subsystem_reg_12),        // Subsystem register 12
    .subsystem_reg_13(subsystem_reg_13),        // Subsystem register 13
    .subsystem_reg_14(subsystem_reg_14),        // Subsystem register 14
    .subsystem_reg_15(subsystem_reg_15),        // Subsystem register 15
    .subsystem_reg_16(subsystem_reg_16),        // Subsystem register 16  
    .error(subsystem_err)                       // Error in com (rx packet, parity)  
  );  
    
// 
//--------------------------------------------------------


//--------------------------------------------------------
// SUBSYSTEM CSDL COMMUNICATION
  defparam SubSystem_CSDL_i.WR_LOC_01     = 16'h003f;   // Write Subsystem Location 01
  defparam SubSystem_CSDL_i.WR_LOC_02     = 16'h003f;   // Write Subsystem Location 02
  defparam SubSystem_CSDL_i.WR_LOC_03     = 16'h003f;   // Write Subsystem Location 03
  defparam SubSystem_CSDL_i.WR_LOC_04     = 16'h003f;   // Write Subsystem Location 04
  defparam SubSystem_CSDL_i.WR_LOC_05     = 16'h003f;   // Write Subsystem Location 05
  defparam SubSystem_CSDL_i.WR_LOC_06     = 16'h003f;   // Write Subsystem Location 06
  defparam SubSystem_CSDL_i.WR_LOC_07     = 16'h003f;   // Write Subsystem Location 07
  defparam SubSystem_CSDL_i.WR_LOC_08     = 16'h003f;   // Write Subsystem Location 08
  defparam SubSystem_CSDL_i.WR_LOC_09     = 16'h003f;   // Write Subsystem Location 09
  defparam SubSystem_CSDL_i.WR_LOC_10     = 16'h003f;   // Write Subsystem Location 10
  defparam SubSystem_CSDL_i.WR_LOC_11     = 16'h003f;   // Write Subsystem Location 11
  defparam SubSystem_CSDL_i.WR_LOC_12     = 16'h003f;   // Write Subsystem Location 12
  defparam SubSystem_CSDL_i.WR_LOC_13     = 16'h003f;   // Write Subsystem Location 13
  defparam SubSystem_CSDL_i.WR_LOC_14     = 16'h003f;   // Write Subsystem Location 14
  defparam SubSystem_CSDL_i.WR_LOC_15     = 16'h003f;   // Write Subsystem Location 15
  defparam SubSystem_CSDL_i.WR_LOC_16     = 16'h003f;   // Write Subsystem Location 16
  defparam SubSystem_CSDL_i.RD_LOC_01     = 16'h0023;   // 50 Read Control Status ID register
  defparam SubSystem_CSDL_i.RD_LOC_02     = 16'h0061;   // 51 Safety Alarms Tripped
  defparam SubSystem_CSDL_i.RD_LOC_03     = 16'h0044;   // 52 Safety Side Scale Value
  defparam SubSystem_CSDL_i.RD_LOC_04     = 16'h0000;   // 53 
  defparam SubSystem_CSDL_i.RD_LOC_05     = 16'h0000;   // 54 
  defparam SubSystem_CSDL_i.RD_LOC_06     = 16'h0000;   // 55 Read 24V-C
  defparam SubSystem_CSDL_i.RD_LOC_07     = 16'h0001;   // 56 Read 5V-C
  defparam SubSystem_CSDL_i.RD_LOC_08     = 16'h0002;   // 57 Read 3.3V-C
  defparam SubSystem_CSDL_i.RD_LOC_09     = 16'h0003;   // 58 Read 1.8V-C
  defparam SubSystem_CSDL_i.RD_LOC_10     = 16'h0004;   // 59 Read 1.5V-C
  defparam SubSystem_CSDL_i.RD_LOC_11     = 16'h0005;   // 5A Read 1.2V-C
  defparam SubSystem_CSDL_i.RD_LOC_12     = 16'h0024;   // 5B Venous Clamp Position
  defparam SubSystem_CSDL_i.RD_LOC_13     = 16'h0006;   // 5C Door Position Sensor A
  defparam SubSystem_CSDL_i.RD_LOC_14     = 16'h0007;   // 5D Door Position Sensor B
  defparam SubSystem_CSDL_i.RD_LOC_15     = 16'h003C;   // 5E
  defparam SubSystem_CSDL_i.RD_LOC_16     = 16'h0022;   // 5F Communication Wrap
    //  COM PORT SUBLINK MASTER 921600, 8, E, 1
  defparam SubSystem_CSDL_i.BAUD_MASK     = 16'h0035;
  defparam SubSystem_CSDL_i.BAUD_QUALIFY  = 16'h0024;
  defparam SubSystem_CSDL_i.PARITY_BIT    = 1'b1;
  defparam SubSystem_CSDL_i.ECHO_ON       = 1'b0;
  defparam SubSystem_CSDL_i.EXTEND_DATA   = 1'b1;
  defparam SubSystem_CSDL_i.USE_LUT       = 1'b0;
  
  SubSystemInterface  SubSystem_CSDL_i 
  (  
    .clk(clk),                                  // System Clock 
    .reset(reset),                              // System Reset
    .sys_tmr_strb(sys_tmr_strb),                // System Timer Strobe
    .enable(wreg_CSDL_en),                      // System enable
    .rx_en(1'b1),  	                            // Recieve enable
    .rx(CSDL_C_RX1_S_TX1),  		                // Data recieve bit  
    .tx(CSDL_C_TX1_S_RX1),                      // Tx bit to send out on pin
    .tx_en(),                                   // Tx enable signal          
    .subsystem_op_en(csdl_op_en),               // Subsystem enable bit map 16 wr, 16 rd 
    .subsystem_wr_02(csdl_wr_02),               // Subsystem write data 02
    .subsystem_wr_03(csdl_wr_03),               // Subsystem write data 03
    .subsystem_wr_04(csdl_wr_04),               // Subsystem write data 04
    .subsystem_wr_05(csdl_wr_05),               // Subsystem write data 05
    .subsystem_wr_06(csdl_wr_06),               // Subsystem write data 06
    .subsystem_wr_07(csdl_wr_07),               // Subsystem write data 07
    .subsystem_wr_08(csdl_wr_08),               // Subsystem write data 08
    .subsystem_wr_09(csdl_wr_09),               // Subsystem write data 09
    .subsystem_wr_10(csdl_wr_10),               // Subsystem write data 10
    .subsystem_wr_11(csdl_wr_11),               // Subsystem write data 11
    .subsystem_wr_12(csdl_wr_12),               // Subsystem write data 12
    .subsystem_wr_13(csdl_wr_13),               // Subsystem write data 13
    .subsystem_wr_14(csdl_wr_14),               // Subsystem write data 14
    .subsystem_wr_15(csdl_wr_15),               // Subsystem write data 15
    .subsystem_wr_16(csdl_wr_16),               // Subsystem write data 16    
    .subsystem_reg_01(csdl_reg_01),             // Subsystem register 01
    .subsystem_reg_02(csdl_reg_02),             // Subsystem register 02
    .subsystem_reg_03(csdl_reg_03),             // Subsystem register 03
    .subsystem_reg_04(csdl_reg_04),             // Subsystem register 04
    .subsystem_reg_05(csdl_reg_05),             // Subsystem register 05
    .subsystem_reg_06(csdl_reg_06),             // Subsystem register 06
    .subsystem_reg_07(csdl_reg_07),             // Subsystem register 07
    .subsystem_reg_08(csdl_reg_08),             // Subsystem register 08
    .subsystem_reg_09(csdl_reg_09),             // Subsystem register 09
    .subsystem_reg_10(csdl_reg_10),             // Subsystem register 10
    .subsystem_reg_11(csdl_reg_11),             // Subsystem register 11
    .subsystem_reg_12(csdl_reg_12),             // Subsystem register 12
    .subsystem_reg_13(csdl_reg_13),             // Subsystem register 13
    .subsystem_reg_14(csdl_reg_14),             // Subsystem register 14
    .subsystem_reg_15(csdl_reg_15),             // Subsystem register 15
    .subsystem_reg_16(csdl_reg_16),             // Subsystem register 16  
    .error(csdl_err)                            // Error in com (rx packet, parity)  
  );  
    
// 
//--------------------------------------------------------


//--------------------------------------------------------  
//  SEQUENCE CONTROLLER AND STATE MACHINE

  // Write to wreg_sub_seq_addr
  always@(posedge clk)
	begin
    if (reset)
      wreg_sub_seq_cmd <= 36'h000000000; 
    else if (wr_addr == 8'h02 && wr_strb)
      wreg_sub_seq_cmd <= wr_data[35:0];      
  end   
  
  // Execute strobe for sub sequence
  always@(posedge clk)
	begin
    if (reset)
      wr_seq_strb <= 1'b0;
    else if ((wr_addr == 8'h02 && wr_strb))
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
    .wr_seq_run_once(wreg_sub_seq_cmd[LS-1:0]),// Sequence # to run once  
    .seq_list_en(seq_list_en),                // Flags to enable sequences 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that sequence list is done  
    .sub_seq_done_strb(sub_seq_done),         // Signal that sub-sequence is done
    .sub_seq_strb(sub_seq_strb),              // Strobe to run sub sequence  
    .sub_seq_addr(sub_seq_addr),              // Address of subsequence to run
    .sub_seq_cnt(sub_seq_cnt)                 // Number of nets in the subsequence  
  );
  
  // State Machine
  defparam StateMachine_Control_i.LS = LS;
  StateMachine_Control  StateMachine_Control_i
  (  
    .clk(clk),                                // System Clock 
    .reset(reset),                            // System Reset (Syncronous) 
    .enable(1'b1),                            // System enable 
    .sys_tmr_strb(sys_tmr_strb),              // System Timer Strobe        
    .monitor_enables(wreg_GPRW_60),           // Use GPRW_60 for monitor enable flags.
    .monitor_mask(wreg_GPRW_62),              // use GPRW_62 to mask monitors  
    .cmd_enables(wreg_GPRW_63),               // use GPRW_63 to command enables
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that sequence list is done
    .seq_list_en(seq_list_en),                // Flags to enable sequences    
    .state_debug(state_debug)
  );
    
//  END SEQUENCE CONTROLLER AND STATE MACHINE
// 
//--------------------------------------------------------



//--------------------------------------------------------
// LOGIC ANALYZER
  always@(posedge clk)
	begin
    if (reset)
      LogicAnalyzer <= 16'h0000;
    else
      LogicAnalyzer <= state_debug;
  end
// END LOGIC ANALYZER
//--------------------------------------------------------  
    
endmodule
