//-----------------------------------------------------------------
//  Module:     StepperMotorParameters
//  Project:    generic atomic modules
//  Version:    0.01-1
//
//  Description: Determine best current and usteps to use 
//               based on rpm command.
//
//
//-----------------------------------------------------------------
module StepperMotorParameters
#(parameter LIM_USTEP2 = 18'h00028, // above 40 rpm use ustep 2
  parameter LIM_USTEP1 = 18'h00064, // above 100 rpm use ustep 1
  parameter LIM_USTEP0 = 18'h000A0, // above 160 rpm use ustep 0
  parameter DAC_OFFSET = 18'h0000C  // Offset of 12
)
(
  input             clk,                // System Clock
  input             reset,              // System Reset (Syncronous) 
  input             enable,             // Enable toggle
  
  input     [17:0]  rpm_int_vel,        // Commanded RPM upper 18 bits
  input      [7:0]  current_limit,      // Upper limit to hold peak current
  output reg [7:0]  peak_current,       // Peak Current to use
  output reg [1:0]  usteps              // Microsteps to use
);

  wire [17:0] rpm_calc_dac;
  
	initial			
	begin
    peak_current  <= 8'h00;  
    usteps        <= 2'b11;
	end

  //Simple table to determine the usteps to use based on rpm command/fbk
  always@(posedge clk)
  begin 
    if (reset)
      usteps        <= 2'b11;
    else if (enable && rpm_int_vel < LIM_USTEP2)
      usteps        <= 2'b11; 
    else if (enable && rpm_int_vel > LIM_USTEP2 && rpm_int_vel < LIM_USTEP1)
      usteps        <= 2'b10;   
    else if (enable && rpm_int_vel > LIM_USTEP1 && rpm_int_vel < LIM_USTEP0)
      usteps        <= 2'b01;     
    else if (enable && rpm_int_vel > LIM_USTEP0)
      usteps        <= 2'b00;           
  end
  
  
  // Calculate the current by the formula DAC_cmd = rpm*2 + 12; Limit to 255; DAC command of ff or 2.0V
  
  //RPM * 2
  assign rpm_calc_dac = {rpm_int_vel[16:0],1'b0} + DAC_OFFSET;
  
  //RPM*2 + OFFSET Limited to Current Limit
  always@(posedge clk)
  begin 
    if (reset)
        peak_current <= 8'h00;
    else if (rpm_calc_dac > current_limit)
        peak_current <= current_limit;  
    else  
        peak_current <= rpm_calc_dac[7:0];  
  end	
    
  
    
endmodule
