// =============================================================================
// Module      : frame_buffer
// Purpose     : Wrapper around Xilinx Block Memory Generator True Dual-Port
//               BRAM IP.  Port A is the write port (camera, PCLK domain);
//               Port B is the read port (VGA display, pixel_clk domain).
//               The BRAM IP is asynchronous dual-port — Xilinx handles the
//               internal metastability for same-address collision.
//
// Memory Spec:
//   Depth = 76,800 (320 × 240 pixels)
//   Width = 16 bits (RGB565: {R[4:0], G[5:0], B[4:0]})
//   Total = 1,228,800 bits (fits in Basys3's 1,800 Kbits BRAM)
//
// Clock Domain:
//   clka — cam_pclk (write side)
//   clkb — pixel_clk (read side)
//
// Ports (match Xilinx BRAM IP port names):
//   clka, ena, wea, addra, dina  — Port A (write from camera)
//   clkb, enb, addrb, doutb     — Port B (read to display)
// =============================================================================

module frame_buffer (
    // Port A — Write (camera, PCLK domain)
    input  wire        clka,
    input  wire        ena,
    input  wire        wea,
    input  wire [16:0] addra,
    input  wire [15:0] dina,

    // Port B — Read (VGA display, pixel_clk domain)
    input  wire        clkb,
    input  wire        enb,
    input  wire [16:0] addrb,
    output wire [15:0] doutb
);

`ifdef SIMULATION
    // -----------------------------------------------------------------------
    // Behavioural model for simulation (not synthesisable as BRAM)
    // -----------------------------------------------------------------------
    reg [15:0] mem [0:76799];

    integer k;
    // Initialise memory — only in sim; initial blocks excluded from RTL
    initial begin
        for (k = 0; k < 76800; k = k + 1)
            mem[k] = 16'd0;
    end

    // Port A — write
    always @(posedge clka) begin
        if (ena && wea)
            mem[addra] <= dina;
    end

    // Port B — read (1 cycle latency)
    reg [15:0] doutb_reg;
    always @(posedge clkb) begin
        if (enb)
            doutb_reg <= mem[addrb];
    end
    assign doutb = doutb_reg;

`else
    // -----------------------------------------------------------------------
    // Xilinx Block Memory Generator IP instantiation
    // IP Name: blk_mem_gen_0
    // Settings (configure in Vivado IP Catalog):
    //   Memory Type      : True Dual Port RAM
    //   Port A Width     : 16
    //   Port A Depth     : 76800
    //   Port B Width     : 16
    //   Port B Depth     : 76800
    //   Operating Mode A : Write First
    //   Operating Mode B : Read First
    //   Enable Port Type : Always Enabled (or use ena/enb)
    //   Output Register  : Port B output register enabled (adds 1 cycle latency)
    //   Initialization   : All zeros
    //   Interface        : Native
    // -----------------------------------------------------------------------
    blk_mem_gen_0 u_bram (
        // Port A
        .clka  (clka),
        .ena   (ena),
        .wea   (wea),
        .addra (addra),
        .dina  (dina),
        .douta (),        // unused

        // Port B
        .clkb  (clkb),
        .enb   (enb),
        .web   (1'b0),    // Port B is read-only
        .addrb (addrb),
        .dinb  (16'd0),
        .doutb (doutb)
    );
`endif

endmodule

