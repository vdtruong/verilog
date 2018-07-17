//-----------------------------------------------------------------
//  Module:     CounterAdj
//  Project:    generic atomic modules
//  Version:    0.01-1
//
//  Description: Implements a counter with output value and strobe
//               when counter reaches the programmed value
//
//
//-----------------------------------------------------------------
module CounterAdj 
#( parameter dw = 16)            // Counter width definition
(  
  input               clk,       // System Clock 
  input               reset,     // Syncrounous reset
  input               enable,    // Enable Counter 
  input               load_limit,// Signal to load the counter limit
  input [dw-1:0]      cntr_limit,// Enable Counter
  
  output  reg[dw-1:0] cntr,      // Counter value
  output  reg         strb       // 1 Clk Strb when Counter == max
);

  reg[dw-1:0]         cntr_max;
  reg                 cntr_loaded;
  
  //Initialize sequential logic
  initial			
  begin
    cntr_max <= {dw{1'b0}};
    cntr_loaded <= 1'b0;
    cntr <= {dw{1'b0}}; 
    strb <= 1'b0;
  end

  //Handle Loading the counter.
  always@(posedge clk)
	begin
    if (reset) begin
      cntr_max <= {dw{1'b0}};
    end
    else if (load_limit & cntr_limit > {dw{1'b0}}) begin
      cntr_max <= cntr_limit;
    end
  end
  
  //Value must be greater than 0.
  always@(posedge clk)
	begin
    if (reset) begin
      cntr_loaded <= 1'b0;
    end
    else if (load_limit & cntr_limit > {dw{1'b0}}) begin
      cntr_loaded <= 1'b1;
    end
    else if (load_limit) begin
      cntr_loaded <= 1'b0; 
    end
  end  
  
  //Counter with enable. reset at programmed limit and strobe.
  always@(posedge clk)
	begin
    if (reset | load_limit) begin
      cntr <= {dw{1'b0}};
      strb <= 1'b0;
    end
    else if (enable & cntr_loaded) begin
      if (cntr == cntr_max) begin
        cntr <= {dw{1'b0}};
        strb <= 1'b1;
      end
      else begin
        cntr <= cntr + 1'b1;
        strb <= 1'b0;
      end
    end
    else begin
      strb <= 1'b0;
    end
  end

    
endmodule
