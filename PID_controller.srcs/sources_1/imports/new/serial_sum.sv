`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/23/2016 10:11:10 AM
// Design Name: 
// Module Name: serial_sum
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


module serial_sum
#(
parameter nMAC = 50,
parameter datBW = 16,
parameter outBW = 32
)
    (
      input [outBW * nMAC - 1: 0]   mac_output,
      input                         inputUpdated,
      input                         clk,
      input                         rst,
      output reg [outBW - 1:0]      mac_sum = 0,
      output                        sum_finished
    );
    
    reg [$clog2(nMAC)  : 0] n = 0;
//    wire execute;
    assign sum_finished = (n>=nMAC);
//    assign execute = ~sum_finished && inputUpdated;

    reg               execute     = 0;
    reg [outBW - 1:0] new_result  = 0;
    
    // Clear things when ever the input is updated (MAC outputs)
    // And set execute flag to true (1)
    always @(posedge inputUpdated) begin
      if(rst) begin
        execute <= 0;
      end else begin
        execute     <= 1;
        new_result  <= 0;
        n           <= 0;
      end
    end
    
    always @(posedge sum_finished) begin
      execute <= 0;
      mac_sum <= new_result;
    end
    
    
    always @(posedge clk) begin
      if(rst) begin
        mac_sum     <= 0;
        n           <= 0;
        new_result  <= 0;
      
      end else if(execute && ~sum_finished) begin
        n           <= n + 1;
        new_result  <= new_result + mac_output[n * outBW +: outBW];
        
      end      
    end
    


   
endmodule
