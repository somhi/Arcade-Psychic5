//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module Arcade_Psychic5_MiST
(
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
`ifdef GX150
	input		  KEY0,
	output        LED1,
`endif
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	input         HDMI_INT,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

`ifndef POSEIDON
	output        AUDIO_L,
	output        AUDIO_R,
`endif
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif

`ifdef NEPTUNOPLUS
    // SD card
	// output       SD_CS,
	input           SD_SCK,     //SD_SCK is being driven by middleboard
	// output       SD_MOSI,
	input           SD_MISO,

    // forward JAMMA DB9 data
    output          JOY_CLK,
    output          JOY_LOAD,
    input           JOY_DATA,
    output          JOY_SELECT,
    input           XJOY_CLK,
    input           XJOY_LOAD,
    output          XJOY_DATA,
`endif

	input         UART_RX,
	output        UART_TX
);


`ifdef GX150
wire   debug;
assign LED = ~debug;
assign LED1 =  ~ioctl_downl;
`endif

`ifdef NEPTUNOPLUS
// SD card  (driven by middleboard)
wire   spi_do_int;
assign spi_do_int = SPI_SS4 ? 1'bz : SD_MISO;
assign SPI_DO = spi_do_int;

// JAMMA interface
reg joy_select = 1'b1;
always @(posedge XJOY_LOAD) begin
	joy_select <= ~joy_select | ~XJOY_CLK;
end
assign JOY_CLK    = XJOY_CLK;
assign JOY_LOAD   = XJOY_LOAD;
assign XJOY_DATA  = JOY_DATA;
assign JOY_SELECT = joy_select;
`endif

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

// remove this if the 2nd chip is actually used
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 1;
assign SDRAM2_DQMH = 1;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif


//`define DEBUG


///////////////////////////////////////////////////////////
//////  PLL
////

wire            CLK60M;
wire            pll_locked;

pll_mist pll(
    .inclk0                     (CLOCK_27                   ),
    .areset                     (1'b0                       ),
    .c0                         (CLK60M                     ),
// `ifndef POSEIDON
    .c1                         (SDRAM_CLK                  ),
// `endif
    .locked                     (pll_locked                 )
);

// `ifdef POSEIDON
// assign SDRAM_CLK = ~CLK60M;
// `endif

//
///////////////////////   MiST FRAMEWORK   ///////////////////////
//

// Status Bit Map:
//             Upper                             Lower              
// 0         1         2         3          4         5         6   
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV WXYZabcdefghijklmnopqrstuvwxyz
// X xXXXxXX X XX XX  XXX X XXXX    xxx


`include "build_id.v" 
localparam CONF_STR = {
    "ikacore_Psychic5;;",
    `SEP
	"F,ROMARC,Load ROM/ARC;",
	"O2,Rotate Controls,Off,On;",
    "P1,Video Settings;",
    //"P1-;",
    // "P1O7,Aspect ratio,original,full screen;",
    // "P1OA,VGA Scaler,off,on;",
`ifdef DUAL_SDRAM
	"P1OWX,Orientation,Vertical,Clockwise,Anticlockwise;",
	"P1OY,Rotation filter,Off,On;",
// `else
//     "P1O8,Orientation,vertical,horizontal;",
`endif		
	"P1O34,Scanlines,Off,25%,50%,75%;",
	"P1O5,Blending,Off,On;",
    "P1ON,Flip,normal,flip;",
    "P1OCD,Refresh rate,original,NTSC-friendly,custom;",
    "P1OFG,H refresh rate adj,0,2,4,6;",
    "P1OJL,V refresh rate adj,0,1,2,3,4,5,6,7;",
    "P1OPS,V position,original,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7;",	
	`SEP
	"O6,Joystick Swap,Off,On;",
    `SEP
    "DIP;",
    `SEP
    "R0,Reset and close OSD;",
    // "J1,Attack,Jump,Test,Service,Coin,Start;",
    // "jn,A,B,Start,Select,R,L;",
    "V,v",`BUILD_DATE 
};


wire    [63:0]  status; //status bits
wire    [1:0]   buttons; //hardware button
wire  	[1:0] 	switches;
wire    [31:0]  joystick_0;
wire    [31:0]  joystick_1;
wire        	scandoublerD;
wire        	ypbpr;
wire       		no_csync;
wire        key_strobe;
wire        key_pressed;
wire  [7:0] key_code;
`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

// wire [6:0] core_mod;
wire        rotate    = status[2];
wire  [1:0] scanlines = status[4:3];
wire        blend     = status[5];
wire        joyswap   = status[6];
wire  [1:0] rotate_screen = status[33:32];
wire        rotate_filter = status[34];
reg   [1:0] orientation;  // TODO


// wire            forced_scandoubler; //?
// wire    [21:0]  gamma_bus;

// wire direct_video;
// wire new_vmode;

// hps_io #(.CONF_STR(CONF_STR)) hps_io
// (
//     .clk_sys                    (CLK60M                     ),
//     .HPS_BUS                    (HPS_BUS                    ),
//     .EXT_BUS                    (                           ),

//     .buttons                    (buttons                    ),
//     .status                     (status                     ),
//     .status_in                  (128'h0                     ),

//     .status_menumask            ({15'd0, status[13]}        ),
//     .direct_video               (direct_video               ),
//     .new_vmode                  (new_vmode                  ), 

//     .forced_scandoubler         (forced_scandoubler         ),
//     .gamma_bus                  (gamma_bus                  ),

//     .ioctl_download             (ioctl_download             ),
//     .ioctl_upload               (                           ),
//     .ioctl_upload_req           (1'b0                       ),
//     .ioctl_wr                   (ioctl_wr                   ),
//     .ioctl_addr                 (ioctl_addr                 ),
//     .ioctl_dout                 (ioctl_data                 ),
//     .ioctl_din                  (                           ),
//     .ioctl_index                (ioctl_index                ),
//     .ioctl_wait                 (ioctl_wait                 ),
    
//     .joystick_0                 (joystick_0                 ),
//     .joystick_1                 (joystick_1                 )
// );




user_io #(
	.STRLEN(($size(CONF_STR)>>3)),
	.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD),
	.FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
	.clk_sys        (CLK60M         ),
	.conf_str       (CONF_STR       ),
`ifndef NEPTUNOPLUS
	.SPI_CLK        (SPI_SCK        ),
`else
	.SPI_CLK		(SPI_SS4 ? SPI_SCK : SD_SCK ),
`endif	
	.SPI_SS_IO      (CONF_DATA0     ),
	.SPI_MISO       (SPI_DO         ),
	.SPI_MOSI       (SPI_DI         ),
	.buttons        (buttons        ),
	.switches       (switches       ),
	.scandoubler_disable (scandoublerD ),
	.ypbpr          (ypbpr          ),
	.no_csync       (no_csync       ),
`ifdef USE_HDMI
	.i2c_start      (i2c_start      ),
	.i2c_read       (i2c_read       ),
	.i2c_addr       (i2c_addr       ),
	.i2c_subaddr    (i2c_subaddr    ),
	.i2c_dout       (i2c_dout       ),
	.i2c_din        (i2c_din        ),
	.i2c_ack        (i2c_ack        ),
	.i2c_end        (i2c_end        ),
`endif
 // .core_mod       (core_mod       ),
	.key_strobe     (key_strobe     ),
	.key_pressed    (key_pressed    ),
	.key_code       (key_code       ),
	.joystick_0     (joystick_0     ),
	.joystick_1     (joystick_1     ),
	.status         (status         )
	);

wire        ioctl_downl;
wire [7:0]  ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [7:0]  ioctl_dout;

wire        ioctl_wait;     /////////// TODO

data_io #(.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD)) data_io(
	.clk_sys       ( CLK60M       ),
	`ifndef NEPTUNOPLUS
	.SPI_SCK       ( SPI_SCK      ),
	`else
	.SPI_SCK	   ( SPI_SS4 ? SPI_SCK : SD_SCK ),
	`endif	
	.SPI_SS2       ( SPI_SS2      ),
	.SPI_SS4       ( SPI_SS4      ),
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	.ioctl_download( ioctl_downl  ),
	.ioctl_index   ( ioctl_index  ),
	.ioctl_wr      ( ioctl_wr     ),
	.ioctl_addr    ( ioctl_addr   ),
	.ioctl_dout    ( ioctl_dout   )
);


// reg [1:0] video_status;
// always @(posedge CLK60M) begin
//     if (video_status != status[13:12]) begin
//         video_status <= status[13:12];
//         new_vmode <= ~new_vmode;
//     end
// end


///////////////////////////////////////////////////////////
//////  CORE
////

wire            hsync_n, vsync_n;
wire            hblank_n, vblank_n;
wire    [3:0]   video_r, video_g, video_b; //need to use color conversion LUT

wire    [15:0]  sound;
wire            pxcen;
// wire            master_reset = status[0] | buttons[1];
wire            master_reset = status[0] | buttons[1] | !KEY0 | !pll_locked ;

wire            flip = status[23];
wire    [1:0]   pxcntr_adjust_mode = status[13:12];
wire    [1:0]   pxcntr_adjust_h = status[16:15];
wire    [2:0]   pxcntr_adjust_v = status[21:19];
wire    [3:0]   vpos_adjust = status[28:25];

// assign          AUDIO_L = sound;
// assign          AUDIO_R = sound;

Psychic5_emu gameboard_top (
    .i_EMU_MCLK                 (CLK60M                     ),
    .i_EMU_INITRST              (1'b0                       ),  	// RESET
    .i_EMU_SOFTRST              (1'b0		                ),		// master_reset

    .o_HSYNC_n                  (hsync_n                    ),
    .o_VSYNC_n                  (vsync_n                    ),
    .o_HBLANK_n                 (hblank_n                   ),
    .o_VBLANK_n                 (vblank_n                   ),

    .o_VIDEO_R                  (video_r                    ),
    .o_VIDEO_G                  (video_g                    ),
    .o_VIDEO_B                  (video_b                    ),

    .o_SOUND                    (sound                      ),

    .o_PXCEN                    (pxcen                      ),

    .i_JOYSTICK0                (joystick_0                 ),
    .i_JOYSTICK1                (joystick_1                 ),

    .i_EMU_FLIP                 (flip                       ),
    .i_EMU_VPOS_ADJ             (vpos_adjust                ),
    .i_EMU_PXCNTR_ADJ_MODE      (pxcntr_adjust_mode         ),
    .i_EMU_PXCNTR_ADJ_H         (pxcntr_adjust_h            ),
    .i_EMU_PXCNTR_ADJ_V         (pxcntr_adjust_v            ),

    .ioctl_index                (ioctl_index                ),
    .ioctl_download             (ioctl_downl                ),
    .ioctl_addr                 (ioctl_addr                 ),
    .ioctl_data                 (ioctl_dout                 ),
    .ioctl_wr                   (ioctl_wr                   ),
    .ioctl_wait                 (ioctl_wait                 ),

    .sdram_dq                   (SDRAM_DQ                   ),
    .sdram_a                    (SDRAM_A                    ),
    .sdram_dqml                 (SDRAM_DQML                 ),
    .sdram_dqmh                 (SDRAM_DQMH                 ),
    .sdram_ba                   (SDRAM_BA                   ),
    .sdram_nwe                  (SDRAM_nWE                  ),
    .sdram_ncas                 (SDRAM_nCAS                 ),
    .sdram_nras                 (SDRAM_nRAS                 ),
    .sdram_ncs                  (SDRAM_nCS                  ),
    .sdram_cke                  (SDRAM_CKE                  ),

`ifdef GX150
    .debug                      (debug                      )
`else
    .debug                      (LED                        )
`endif		

);



///////////////////////////////////////////////////////////
//////  SCALER
////

// assign VGA_F1 = 0;
// assign VGA_SCALER = status[10];
// assign VGA_DISABLE = 0;
// assign HDMI_FREEZE = 0;
// assign FB_FORCE_BLANK = 0;
// assign HDMI_BLACKOUT = 0;

//                   eval dv-----------|  eval fs----------|    eval horiz----| vert-|
// assign VIDEO_ARX = direct_video ? 8'd4 : status[7] ? 8'd16 : status[8] ? 8'd4 : 8'd3;
// assign VIDEO_ARY = direct_video ? 8'd3 : status[7] ? 8'd9  : status[8] ? 8'd3 : 8'd4;

// arcade_video #(256,12) arcade_video (
//     .clk_video                  (CLK60M                     ),
//     .ce_pix                     (pxcen                      ),
     
//     .RGB_in                     ({video_r, video_g, video_b}),
//     .HBlank                     (~hblank_n                  ),
//     .VBlank                     (~vblank_n                  ),
//     .HSync                      (~hsync_n                   ),
//     .VSync                      (~vsync_n                   ),

//     .CLK_VIDEO                  (CLK_VIDEO                  ),
//     .CE_PIXEL                   (CE_PIXEL                   ),
//     .VGA_R                      (VGA_R                      ),
//     .VGA_G                      (VGA_G                      ),
//     .VGA_B                      (VGA_B                      ),
//     .VGA_HS                     (VGA_HS                     ),
//     .VGA_VS                     (VGA_VS                     ),
//     .VGA_DE                     (VGA_DE                     ),
//     .VGA_SL                     (VGA_SL                     ),

//     .fx                         (status[5:3]                ), //3bit
//     .forced_scandoubler         (forced_scandoubler         ),
//     .gamma_bus                  (gamma_bus                  ) //22bit
// );

// assign          FB_FORCE_BLANK = 1'b0;
// reg             rotate_ccw = 1'b1;
// wire            no_rotate = direct_video | status[7] | status[8];
// wire            video_rotated;
// screen_rotate screen_rotate ( .* );



mist_dual_video #(.COLOR_DEPTH(5),.SD_HCNT_WIDTH(10), .OUT_COLOR_DEPTH(VGA_BITS), .USE_BLANKS(1'b1), .BIG_OSD(BIG_OSD)) mist_video(
	.clk_sys(CLK60M),
`ifndef NEPTUNOPLUS
	.SPI_SCK(SPI_SCK),
`else
	.SPI_SCK( SPI_SS4 ? SPI_SCK : SD_SCK ),
`endif		
	.SPI_SS3(SPI_SS3),
	.SPI_DI(SPI_DI),
	.R(video_r),
	.G(video_g),
	.B(video_b),
	.HBlank(~hblank_n),
	.VBlank(~vblank_n),
	.HSync(~hsync_n),
	.VSync(~vsync_n),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
// `ifdef USE_HDMI
// 	.HDMI_R         ( HDMI_R           ),
// 	.HDMI_G         ( HDMI_G           ),
// 	.HDMI_B         ( HDMI_B           ),
// 	.HDMI_VS        ( HDMI_VS          ),
// 	.HDMI_HS        ( HDMI_HS          ),
// 	.HDMI_DE        ( HDMI_DE          ),
// `endif
// `ifdef DUAL_SDRAM
// 	.clk_sdram      ( CLK60M           ),
// 	.sdram_init     ( ~pll2_locked     ),
// 	.SDRAM_A        ( SDRAM2_A         ),
// 	.SDRAM_DQ       ( SDRAM2_DQ        ),
// 	.SDRAM_DQML     ( SDRAM2_DQML      ),
// 	.SDRAM_DQMH     ( SDRAM2_DQMH      ),
// 	.SDRAM_nWE      ( SDRAM2_nWE       ),
// 	.SDRAM_nCAS     ( SDRAM2_nCAS      ),
// 	.SDRAM_nRAS     ( SDRAM2_nRAS      ),
// 	.SDRAM_nCS      ( SDRAM2_nCS       ),
// 	.SDRAM_BA       ( SDRAM2_BA        ),
// `endif
	.no_csync(no_csync),
	.rotate({orientation[1],rotate}),			// TODO
	.rotate_screen  ( rotate_screen    ),
	.rotate_hfilter ( rotate_filter    ),
	.rotate_vfilter ( rotate_filter    ),
	.ce_divider(4'd9), // pix clock = 60/10
	.blend(blend),
	.scandoubler_disable(scandoublerD),
	// scanlines (00-none 01-25% 10-50% 11-75%)   	//only works if scandoubler enabled
	.scanlines(scanlines),
	.ypbpr(ypbpr)
	);



// mist_video #(.COLOR_DEPTH(5),.SD_HCNT_WIDTH(10), .OUT_COLOR_DEPTH(VGA_BITS), .USE_BLANKS(1'b1), .BIG_OSD(BIG_OSD)) mist_video(
// 	.clk_sys(CLK60M),
// `ifndef NEPTUNOPLUS
// 	.SPI_SCK(SPI_SCK),
// `else
// 	.SPI_SCK( SPI_SS4 ? SPI_SCK : SD_SCK ),
// `endif		
// 	.SPI_SS3(SPI_SS3),
// 	.SPI_DI(SPI_DI),
// 	.R(video_r),
// 	.G(video_g),
// 	.B(video_b),
// 	.HBlank(~hblank_n),
// 	.VBlank(~vblank_n),
// 	.HSync(~hsync_n),
// 	.VSync(~vsync_n),
// 	.VGA_R(VGA_R),
// 	.VGA_G(VGA_G),
// 	.VGA_B(VGA_B),
// 	.VGA_VS(VGA_VS),
// 	.VGA_HS(VGA_HS),

// 	.no_csync(no_csync),
// 	.rotate(2'b11),
// 	.ce_divider(4'd9), // pix clock = 60/10
// 	.blend(blend),
// 	.scandoubler_disable(1'b0),
// 	// scanlines (00-none 01-25% 10-50% 11-75%)   	//only works if scandoubler enabled
// 	.scanlines(scanlines),
// 	.ypbpr(ypbpr)
// 	);


// `ifdef USE_HDMI
// i2c_master #(60_000_000) i2c_master (
// 	.CLK         (CLK60M),

// 	.I2C_START   (i2c_start),
// 	.I2C_READ    (i2c_read),
// 	.I2C_ADDR    (i2c_addr),
// 	.I2C_SUBADDR (i2c_subaddr),
// 	.I2C_WDATA   (i2c_dout),
// 	.I2C_RDATA   (i2c_din),
// 	.I2C_END     (i2c_end),
// 	.I2C_ACK     (i2c_ack),

// 	//I2C bus
// 	.I2C_SCL     (HDMI_SCL),
//  	.I2C_SDA     (HDMI_SDA)
// );

// 	assign HDMI_PCLK = CLK60M;
// `endif

`ifndef POSEIDON
dac #(16) dacl(
	.clk_i(CLK60M),
	.res_n_i(1),
	.dac_i({~sound[15], sound[14:0]}),
	.dac_o(AUDIO_L)
	);

dac #(16) dacr(
	.clk_i(CLK60M),
	.res_n_i(1),
	.dac_i({~sound[15], sound[14:0]}),
	.dac_o(AUDIO_R)
	);	
`endif

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(CLK60M),
	.clk_rate(32'd60_000_000),
	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),
	.left_chan(sound),
	.right_chan(sound)
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge CLK60M) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif (
	.rst_i(1'b0),
	.clk_i(CLK60M),
	.clk_rate_i(32'd60_000_000),
	.spdif_o(SPDIF),
	.sample_i({sound, sound})
);
`endif

// Common inputs
wire m_up1, m_down1, m_left1, m_right1, m_up1B, m_down1B, m_left1B, m_right1B;
wire m_up2, m_down2, m_left2, m_right2, m_up2B, m_down2B, m_left2B, m_right2B;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;
wire [11:0] m_fire1, m_fire2;

arcade_inputs #(.START1(10), .START2(12), .COIN1(11)) inputs (
	.clk         ( CLK60M      ),
	.key_strobe  ( key_strobe  ),
	.key_pressed ( key_pressed ),
	.key_code    ( key_code    ),
	.joystick_0  ( joystick_0  ),
	.joystick_1  ( joystick_1  ),
	.rotate      ( rotate      ),
	.orientation ( orientation ^ {1'b0, |rotate_screen} ),
	.joyswap     ( joyswap     ),
	.oneplayer   ( 1'b0        ),
	.controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
	.player1     ( {m_up1B, m_down1B, m_left1B, m_right1B, m_fire1, m_up1, m_down1, m_left1, m_right1} ),
	.player2     ( {m_up2B, m_down2B, m_left2B, m_right2B, m_fire2, m_up2, m_down2, m_left2, m_right2} )
);

endmodule

