`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/30/2016 09:57:40 AM
// Design Name: 
// Module Name: FIR_filter
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


module FIR_filter
  #(
      parameter DW = 16,            //data width
      parameter out_DW = 2*DW,      //output width
      parameter nDatMAC= 32,        //number of data each MAC handle
      parameter nMAC = 50           //number of MACs
  )
  (
    input       [DW - 1 : 0]                datIn,
    output reg  [out_DW - 1 : 0]            datOut,
    input                                   clk,
    // System bus
    input      [ 32-1:0] sys_addr   ,  // bus address
    input      [ 32-1:0] sys_wdata  ,  // bus write data
    input      [  4-1:0] sys_sel    ,  // bus write byte select
    input                sys_wen    ,  // bus write enable
    input                sys_ren    ,  // bus read enable
    output reg [ 32-1:0] sys_rdata  ,  // bus read data
    output reg           sys_err    ,  // bus error indicator
    output reg           sys_ack       // bus acknowledge signal    
  );

    // total number of sample/ size of the sample array is
    // (nDatMAC * nMAC)
    // The total number of bits in the flatten array then 
    // is given by (nDatMAC * nMAC * dataBitwidth)
    localparam totalNBits = nDatMAC * DW * nMAC;
    localparam totalNSamples = nDatMAC * nMAC;
    localparam nBits_MAC  = nDatMAC * DW;
//-------------------End of parameters-----------------//



    reg   [totalNBits - 1 : 0]      flatCoeff = 0;
//    reg   [dataBitwidth * nData - 1 : 0]  flatSample;
    reg   [out_DW * nMAC - 1 : 0]   mac_out_storage = 0;
    wire  [out_DW * nMAC - 1 : 0]   mac_direct_out;
    wire   [out_DW - 1 : 0]         mac_sum;
    wire  [nMAC - 1: 0]             mac_armed;
    wire  [nMAC - 1: 0]             mac_done;
    wire                            sum_finished;
    wire                            sum_armed;

//------Sampler----------------------------------------//
    reg   [totalNBits - 1 : 0]  flatSample  = 0;
    reg                         sampled     = 0;
    wire  [DW - 1 : 0]          newSample;
    wire                        rst_sampler = 0;
    
    always @(posedge clk) begin
      if (&mac_armed & ~sampled) begin 
        flatSample <= {newSample, flatSample[totalNBits - 1 : DW]};
        sampled <= 1;
      end else if (&mac_done) begin
        sampled <= 0;
      end
    end

//------Sampler end------------------------------------//

//-----------MAC output storage -----------------------//
//    reg mac_out_ready = 0;
    reg mac_out_storage_updated = 0;
    
    always @(posedge clk) begin    
      // Only update the MAC results if mac_done is 
      // flagged and the storage is not updated
      // storage_updated flag need to be reset somewhere
      if(mac_done && ~mac_out_storage_updated ) begin 
        mac_out_storage <= mac_direct_out;
//        mac_out_ready   <= 1;
        mac_out_storage_updated <= 1;
      end else if (sum_finished) begin
        mac_out_storage_updated <= 0;
      end
    end
//-----------MAC output storage end--------------------//


//----Instantiate multiple MACs -----------------------//
  multiplyAccumulator 
  #(
    .nData(nDatMAC),
    .datBW(DW), 
    .outBW(out_DW)
  ) MACs [nMAC-1 : 0]
    (
      .inA(flatCoeff),
      .inB(flatSample),
      .inputUpdated(sampled),
      .clk(clk),
      .rst(1'b0),
      .mac_done(mac_done),
      .mac_armed(mac_armed),
      .mac_out(mac_direct_out)
    );        
//----Instantiate multiple MACs end--------------------//

//------MAC sum----------------------------------------//
  serial_sum #(.nMAC(nMAC), .datBW(DW), .outBW(out_DW))
    inst_serial_sum 
      (
         .mac_output(mac_out_storage),
         .inputUpdated(mac_out_storage_updated),
         .clk(clk),
         .rst(0),
         .mac_sum(mac_sum),
         .sum_finished(sum_finished)
      );
//------MAC sum end------------------------------------//

endmodule
