`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/20/2016 01:52:58 PM
// Design Name: 
// Module Name: multiplyAccumulator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module multiplyAccumulator
#(
  parameter nData = 16,
  parameter datBW = 16,
  parameter outBW = 2 * datBW
)
(
  input   [nData * datBW - 1 : 0]   inA,
  input   [nData * datBW - 1 : 0]   inB,
  input                             clk,
  input                             rst,
  input                             inputUpdated,
  output  reg [outBW - 1 : 0]       mac_out = 0,
  output                            mac_done,
  output  reg                       mac_armed = 1
  
);

  reg [$clog2(nData) : 0] cursor = 0;
//  reg execute = 0;
  wire execute;
  assign mac_done = (cursor >= nData) && (~mac_armed);
  assign execute = (~mac_done) && inputUpdated;
  
  always @(posedge clk) begin
    if (rst) begin
      cursor  <=  0;
      mac_out  <=  {(nData * datBW - 1){1'b0}};
      mac_armed <= 1;
//      execute <= 0;
    end else begin
      if (mac_armed && inputUpdated) begin
        mac_armed <= 0;
//        execute   <= 1;
        cursor    <= 0;
        mac_out   <= 0;
      end else if(execute && ~mac_done) begin
        mac_out <= mac_done ? mac_out : mac_out + inA[cursor * datBW  +: datBW] * inB[cursor * datBW +: datBW];
        cursor <= cursor + 1;
      end
      
      if (mac_done) begin
        mac_armed <= 1;
      end
      
      
    end
  end

endmodule
