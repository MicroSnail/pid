/**
 * $Id: red_pitaya_pid.v 961 2014-01-21 11:40:39Z matej.oblak $
 *
 * @brief Red Pitaya MIMO PID controller.
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */



/**
 * GENERAL DESCRIPTION:
 *
 * Multiple input multiple output controller.
 *
 *
 *                 /-------\       /-----------\
 *   CHA -----+--> | PID11 | ------| SUM & SAT | ---> CHA
 *            |    \-------/       \-----------/
 *            |                            ^
 *            |    /-------\               |
 *            ---> | PID21 | ----------    |
 *                 \-------/           |   |
 *                                     |   |
 *  INPUT                              |   |         OUTPUT
 *                                     |   |
 *                 /-------\           |   |
 *            ---> | PID12 | --------------
 *            |    \-------/           |    
 *            |                        ˇ
 *            |    /-------\       /-----------\
 *   CHB -----+--> | PID22 | ------| SUM & SAT | ---> CHB
 *                 \-------/       \-----------/
 *
 *
 * MIMO controller is build from four equal submodules, each can have 
 * different settings.
 *
 * Each output is sum of two controllers with different input. That sum is also
 * saturated to protect from wrapping.
 * 
 */



module red_pitaya_pid (
   // signals
   input                 clk_i           ,  //!< processing clock
   input                 rstn_i          ,  //!< processing reset - active low
   input      [ 14-1: 0] dat_a_i         ,  //!< input data CHA
   input      [ 14-1: 0] dat_b_i         ,  //!< input data CHB
   output     [ 14-1: 0] dat_a_o         ,  //!< output data CHA
   output     [ 14-1: 0] dat_b_o         ,  //!< output data CHB
   //Ki, Kp enabled switches;
   input                 KiEnabled       , 
   input                 KpEnabled       ,   
   // system bus
   input      [ 32-1: 0] sys_addr        ,  //!< bus address
   input      [ 32-1: 0] sys_wdata       ,  //!< bus write data
   input      [  4-1: 0] sys_sel         ,  //!< bus write byte select
   input                 sys_wen         ,  //!< bus write enable
   input                 sys_ren         ,  //!< bus read enable
   output reg [ 32-1: 0] sys_rdata       ,  //!< bus read data
   output reg            sys_err         ,  //!< bus error indicator
   output reg            sys_ack            //!< bus acknowledge signal
   
   // physical buttons for resets
);

localparam  PSR = 0;  //12         ; old values
localparam  ISR = 0;  //18         ; old values
localparam  DSR = 0;  //10         ; old values

//---------------------------------------------------------------------------------
//  PID 11

wire [ 14-1: 0] pid_11_out   ;
wire [ 14-1: 0] switchableSetpoint;
reg             sp_manual    ; // 
reg  [ 14-1: 0] set_11_sp    ;
reg  [ 14-1: 0] set_11_kp    ;
reg  [ 14-1: 0] set_11_ki    ;
reg  [ 14-1: 0] set_11_kd    ;
reg             set_11_irst  ;

reg  [32-14-1:0] kp_boost; // see memory location at the end
reg  [15-1:0]    dc_offset;
reg  [14-1:0]    ki_shift;


assign switchableSetpoint = sp_manual ? set_11_sp : dat_b_i;

wire [15-1 : 0] errorMon;

red_pitaya_pid_block #(
  .PSR (  PSR   ),
  .ISR (  ISR   ),
  .DSR (  DSR   )      
) i_pid11 (
   // data
  .clk_i        (  clk_i          ),  // clock
  .rstn_i       (  rstn_i         ),  // reset - active low
  .dat_i        (  dat_a_i        ),  // input data
  .dat_o        (  pid_11_out     ),  // output data


   // settings
//  .set_sp_i     (  set_11_sp      ),                    // set point
  .set_sp_i     (   switchableSetpoint),
  .ki_shift     (   ki_shift          ),                  
  .set_kp_i     (  (KpEnabled ? set_11_kp : 14'b0    ) ),  // Kp
  .kp_boost     (   kp_boost          ),
  .dc_offset    (   dc_offset         ),
  .set_ki_i     (  (KiEnabled ? set_11_ki : 14'b0    ) ),  // Ki
  .set_kd_i     (  set_11_kd          ),                   // Kd
  .int_rst_i    (  (KiEnabled ? set_11_irst : 1'b1)),       // integrator reset
  .errorMon_o     (errorMon)  // Monitor error signal
);



//---------------------------------------------------------------------------------
//  OLD cross PID registers etc.

wire [ 14-1: 0] pid_21_out   ;
reg  [ 14-1: 0] set_21_sp    ;
reg  [ 14-1: 0] set_21_kp    ;
reg  [ 14-1: 0] set_21_ki    ;
reg  [ 14-1: 0] set_21_kd    ;
reg             set_21_irst  ;

wire [ 14-1: 0] pid_12_out   ;
reg  [ 14-1: 0] set_12_sp    ;
reg  [ 14-1: 0] set_12_kp    ;
reg  [ 14-1: 0] set_12_ki    ;
reg  [ 14-1: 0] set_12_kd    ;
reg             set_12_irst  ;

wire [ 14-1: 0] pid_22_out   ;
reg  [ 14-1: 0] set_22_sp    ;
reg  [ 14-1: 0] set_22_kp    ;
reg  [ 14-1: 0] set_22_ki    ;
reg  [ 14-1: 0] set_22_kd    ;
reg             set_22_irst  ;
 

//---------------------------------------------------------------------------------
//  Sum and saturation

wire [ 15-1: 0] out_1_sum   ;
reg  [ 14-1: 0] out_1_sat   ;
wire [ 15-1: 0] out_2_sum   ;
reg  [ 14-1: 0] out_2_sat   ;

reg adderEnabled = 1'b0; // If enabled, channel 2 input will be added to the output 1
reg [14-1:0] sweepGain;


//assign out_1_sum = $signed(pid_11_out) + $signed(pid_12_out);
assign out_2_sum = $signed((errorMon << 1));

assign out_1_sum = $signed(pid_11_out) + (adderEnabled ? ($signed(sweepGain) * $signed(dat_b_i)) : 0);

always @(posedge clk_i) begin
   if (rstn_i == 1'b0) begin
      out_1_sat <= 14'd0 ;
      out_2_sat <= 14'd0 ;
   end
   else begin
      if (out_1_sum[15-1:15-2]==2'b01) // postitive sat
         out_1_sat <= 14'h1FFF ;
//      else if (out_1_sum[15-1:15-2]==2'b10) // negative sat
//         out_1_sat <= 14'h2000 ;
      else if (out_1_sum[15-1] == 1'b1) // negative
         out_1_sat <= 14'h0 ; // if negative make it 0
      else
         out_1_sat <= out_1_sum[14-1:0] ;

      if (out_2_sum[15-1:15-2]==2'b01) // postitive sat
         out_2_sat <= 14'h1FFF ;
      else if (out_2_sum[15-1:15-2]==2'b10) // negative sat
         out_2_sat <= 14'h2000 ;
      else
         out_2_sat <= out_2_sum[14-1:0] ;
   end
end

assign dat_a_o = out_1_sat ;
assign dat_b_o = out_2_sat ;

//---------------------------------------------------------------------------------
//
//  System bus connection

always @(posedge clk_i) begin
   if (rstn_i == 1'b0) begin
      set_11_sp    <=   14'd0 ;
      set_11_kp    <=   14'd0 ;
      set_11_ki    <=   14'd0 ;
      set_11_kd    <=   14'd0 ;
      set_11_irst  <=    1'b1 ;
      kp_boost     <=   17'b1 ;
      sp_manual    <=    1'b1 ;
      dc_offset    <=   14'b1 ;
      adderEnabled <=    1'b0 ;
      sweepGain    <=   14'b0 ;
      ki_shift     <=   14'b1 ; // intetralTerm = Integrated / ki_shift
   end
   else begin
      if (sys_wen) begin
         if (sys_addr[19:0]==16'h0)    {set_22_irst,set_21_irst,set_12_irst,set_11_irst} <= sys_wdata[ 4-1:0] ;

         if (sys_addr[19:0]==16'h10)    set_11_sp     <= sys_wdata[14-1:0] ;
         if (sys_addr[19:0]==16'h14)    set_11_kp     <= sys_wdata[14-1:0] ;
         if (sys_addr[19:0]==16'h18)    set_11_ki     <= sys_wdata[14-1:0] ;
         if (sys_addr[19:0]==16'h1C)    set_11_kd     <= sys_wdata[14-1:0] ;
         if (sys_addr[19:0]==16'h50)    sp_manual     <= sys_wdata[14-1:0] ; // sp_manual = 1 to use manual set point
         if (sys_addr[19:0]==16'h54)    kp_boost      <= sys_wdata[32-14-1:0] ; // Kp_boost * kp
         if (sys_addr[19:0]==16'h58)    dc_offset     <= sys_wdata[15-1:0] ; // DC offset 
         if (sys_addr[19:0]==16'h5C)    adderEnabled  <= sys_wdata[15-1:0] ; // PID_out + sweep
         if (sys_addr[19:0]==16'h60)    sweepGain     <= sys_wdata[15-1:0] ; //
         if (sys_addr[19:0]==16'h64)    ki_shift      <= sys_wdata[14-1:0] ; // Ki divider
      end
   end
end

wire sys_en;
assign sys_en = sys_wen | sys_ren;

always @(posedge clk_i)
if (rstn_i == 1'b0) begin
   sys_err <= 1'b0 ;
   sys_ack <= 1'b0 ;
end else begin
   sys_err <= 1'b0 ;

   casez (sys_addr[19:0])
      20'h00 : begin sys_ack <= sys_en;          sys_rdata <= {{32- 4{1'b0}}, set_22_irst,set_21_irst,set_12_irst,set_11_irst}       ; end 

      20'h10 : begin sys_ack <= sys_en;          sys_rdata <= {{32-14{1'b0}}, set_11_sp}          ; end 
      20'h14 : begin sys_ack <= sys_en;          sys_rdata <= {{32-14{1'b0}}, set_11_kp}          ; end 
      20'h18 : begin sys_ack <= sys_en;          sys_rdata <= {{32-14{1'b0}}, set_11_ki}          ; end 
      20'h1C : begin sys_ack <= sys_en;          sys_rdata <= {{32-14{1'b0}}, set_11_kd}          ; end 
  
      20'h50 : begin sys_ack <= sys_en;          sys_rdata <= {{32-1{1'b0}}, sp_manual}           ; end
      20'h54 : begin sys_ack <= sys_en;          sys_rdata <= {{32-18{1'b0}}, kp_boost}           ; end
      20'h58 : begin sys_ack <= sys_en;          sys_rdata <= {{32-15{1'b0}}, dc_offset}          ; end
      20'h5C : begin sys_ack <= sys_en;          sys_rdata <= {{32-1{1'b0}}, adderEnabled}        ; end
      20'h60 : begin sys_ack <= sys_en;          sys_rdata <= {{32-14{1'b0}}, sweepGain}          ; end
      20'h64 : begin sys_ack <= sys_en;          sys_rdata <= {{32-14{1'b0}}, ki_shift}         ; end
     default : begin sys_ack <= sys_en;          sys_rdata <=  32'h0                              ; end
   endcase
end

endmodule
