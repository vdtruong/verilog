//-----------------------------------------------------------------
//  Module:     FifoController
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
//
//
//-----------------------------------------------------------------
module FifoController
#(parameter WIDTH = 10)
(
  input                   clk,        // System Clock
  input                   reset,      // System Reset
  input                   enable,     // Enable Fifo   
  input                   rd_a_strb,  // Read Strobe to empty
  input                   wr_b_strb,  // Write Strobe to fill
  output reg [WIDTH-1:0]  addr_a,     // output address
  output reg [WIDTH-1:0]  addr_b,     // input address
  output reg              fifo_empty, // flag that fifo is empty
  output reg              fifo_full,  // flag that fifo is full
  output reg              fifo_half   // flag that fifo is half full
);
  
  reg [WIDTH-1:0] buffer_cnt;
  
  //Initialize
	initial			
	begin
    buffer_cnt  <= {WIDTH{1'b0}};
    addr_a      <= {WIDTH{1'b0}};
    addr_b      <= {WIDTH{1'b0}};
    fifo_empty  <= 1'b1;
    fifo_full   <= 1'b0;
    fifo_half   <= 1'b0;    
	end
    
	// Handle Read Address
  always @(posedge clk) begin
    if (reset)
      addr_a <= {WIDTH{1'b0}};
    else if (rd_a_strb && ~fifo_empty)
      addr_a <= addr_a + 1'b1;
  end

	// Handle Write Address
  always @(posedge clk) begin
    if (reset)
      addr_b <= {WIDTH{1'b0}};
    else if (wr_b_strb && ~fifo_full)
      addr_b <= addr_b + 1'b1;
  end
  
  // Keep track of items in buffer
  always @(posedge clk) begin
    if (reset)
      buffer_cnt <= {WIDTH{1'b0}};
    else if (wr_b_strb && ~fifo_full)
      buffer_cnt <= buffer_cnt + 1'b1;
    else if (rd_a_strb && ~fifo_empty)
      buffer_cnt <= buffer_cnt - 1'b1;      
  end
    
	// Fifo Empty
  always @(posedge clk) begin
    if (reset)
      fifo_empty <= 1'b1;
    else if (buffer_cnt == {WIDTH{1'b0}})
      fifo_empty <= 1'b1;
    else
      fifo_empty <= 1'b0;
  end
  
	// Fifo Full
  always @(posedge clk) begin
    if (reset)
      fifo_full <= 1'b0;
    else if (buffer_cnt == {WIDTH{1'b1}})
      fifo_full <= 1'b1;
    else
      fifo_full <= 1'b0;
  end  
  
	// Fifo Half Full
  always @(posedge clk) begin
    if (reset)
      fifo_half <= 1'b0;
    else if (buffer_cnt >= {1'b1,{WIDTH-1{1'b0}}})
      fifo_half <= 1'b1;
    else
      fifo_half <= 1'b0;
  end    
  
    
endmodule
