//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//  Module:     Counter
//
//  Description: Implements a counter with output value and strobe
//               when counter reaches maximum value.
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
module Counter 
#( parameter dw = 12,           // Counter width definition
   parameter max = 12'hFFF)     // Counter max value definition
(  
  input               clk,      // System Clock 
  input               reset,    // System Reset (Syncronous)
  input               enable,   // Enable Counter 
  
  output  reg[dw-1:0] cntr,     // Counter value
  output  reg         strb      // 1 Clk Strb when Counter == max
);
    
  //Initialize sequential logic
	initial			
	begin
		cntr <= {dw{1'b0}}; 
      strb <= 1'b0;
	end

	//General Counter
  // Resets on GSR or when counter reaches max parameter
  // Increments counter every clock when enabled
	always@(posedge clk)
	begin
    if (reset || cntr[dw-1:0] == max)    
      cntr <= {dw{1'b0}}; 	// next clock	  
    else if (enable)  
		  cntr <= cntr + 1'b1;		                       
	end	
  
  // Counter/Timer Strobe
  // Asserts strobe for 1 clk period when cntr = max param
	always@(posedge clk)
	begin
    if (reset)
      strb <= 1'b0;		    
    else if (cntr == max)
      strb <= 1'b1;        // next clock
    else
      strb <= 1'b0;    
	end  
    
endmodule
