//-----------------------------------------------------------------
//  Module:     CounterSeq
//  Project:    generic atomic modules
//  Version:    0.01-1
//
//  Description: Implements a counter with output value and strobe
//               when counter reaches maximum value it stops
//
//
//-----------------------------------------------------------------
module CounterSeq 
#( parameter dw = 12,             // Counter width definition
   parameter max = 12'h00F)       // Counter max value definition
(  
  input               clk,        // System Clock 
  input               reset,      // System Reset (Syncronous)
  input               enable,     // Enable Counter
  input               start_strb, // Strobe to start counter
  
  output  reg[dw-1:0] cntr,       // Counter value
  output  reg         strb        // 1 Clk Strb when Counter == max
);
      
  reg   cntr_en;                  // Enable for counter

  //Initialize sequential logic
	initial			
	begin
		cntr <= {dw{1'b0}}; 
    strb <= 1'b0;
    cntr_en <= 1'b0;
	end

	//General Counter
  // Resets on GSR or when counter reaches max parameter
  // Increments counter every clock when enabled
	always@(posedge clk)
	begin
    if (reset || start_strb)    
      cntr <= {dw{1'b0}}; 		  
    else if (enable && cntr_en)  
		  cntr <= cntr + 1'b1;		                       
	end	
  
  // Counter/Timer Strobe
  // Asserts strobe for 1 clk period when cntr = max param
	always@(posedge clk)
	begin
    if (reset)
      strb <= 1'b0;
    else if (cntr == max && enable && cntr_en)
      strb <= 1'b1;
    else
      strb <= 1'b0;
	end  
  
  // Counter/Timer Enable  
	always@(posedge clk)
	begin
    if (reset)
      cntr_en <= 1'b0;
    else if (start_strb)
      cntr_en <= 1'b1;
    else if (strb)
      cntr_en <= 1'b0;
	end  
    
endmodule
