`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UNRN
// Engineer: Sotomayor P.B. Gabriel
// 
// Create Date: 10.03.2026 13:40:40
// Design Name: Zybo_ibex_top
// Module Name: zybo_ibex_top
// Project Name: Reporter
// Target Devices: Encapsulated soft-core
// Tool Versions: 1
// Description: Encapsulated the soft-core to avoid open pins errors. 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module zybo_ibex_top (
    input  logic clk_pin,    // Pin de 125MHz de la Zybo
    input  logic rst_pin,    // Botón de la Zybo (normalmente High o Low según jumper)
    output logic [3:0] leds  // LEDs de diagnóstico
);

    // --- SEÑALES DE RELOJ Y RESET ---
    logic clk_50MHz;
    logic locked;
    logic rst_n;

    // Instancia del Clock Wizard
    clk_wiz_0 u_clocks (
        .clk_in1 (clk_pin),
        .reset   (1'b0),        
        .clk_out1(clk_50MHz),
        .locked  (locked)
    );


    assign rst_n = !rst_pin && locked; 

    // --- SEÑALES DEL BUS DE DATOS ---
    logic [31:0] instr_addr, instr_rdata;
    logic [31:0] data_addr, data_rdata, data_wdata;
    logic        data_req, data_we;
    logic [63:0] hw_timestamp;

    // --- INSTANCIA DEL IBEX (UNIFICADA) ---
    ibex_top #(
        .PMPEnable        ( 1'b0 ),
        .RV32E            ( 1'b0 ),
        .RV32M            ( ibex_pkg::RV32MFast )
    ) u_core_cpu ( // Cambié el nombre para evitar conflictos
        .clk_i            ( clk_50MHz ),
        .rst_ni           ( rst_n     ),
        .test_en_i        ( 1'b0      ),
        .scan_rst_ni      ( 1'b1      ),
        .hart_id_i        ( 32'h0     ),
        .boot_addr_i      ( 32'h00000000 ), 
        
        // Bus de Instrucciones
        .instr_req_o      ( /* Conectar a BRAM */ ),
        .instr_addr_o     ( instr_addr ),
        .instr_rdata_i    ( instr_rdata ),
        
        // Bus de Datos
        .data_req_o       ( data_req   ),
        .data_addr_o      ( data_addr  ),
        .data_we_o        ( data_we    ),
        .data_wdata_o     ( data_wdata ),
        .data_rdata_i     ( data_rdata ),
        
        // Señales mínimas para que no falle la síntesis
        .irq_software_i   ( 1'b0 ),
        .irq_timer_i      ( 1'b0 ),
        .irq_external_i   ( 1'b0 ),
        .irq_nm_i         ( 1'b0 ),
        .debug_req_i      ( 1'b0 ),
        .fetch_enable_i   ( 1'b1 )
    );

    // --- CONTADOR DE TIMESTAMP (HARDWARE PURO) ---
    always_ff @(posedge clk_50MHz or negedge rst_n) begin
        if (!rst_n) begin
            hw_timestamp <= 64'h0;
        end else begin
            hw_timestamp <= hw_timestamp + 1'b1;
        end
    end

    // --- LÓGICA DE LECTURA DEL TIMESTAMP ---
    // Mapeo el contador a una dirección de memoria (ejemplo: 0x80000000)
    always_comb begin
        data_rdata = 32'h0; // Valor por defecto
        if (data_addr == 32'h80000000) begin
            data_rdata = hw_timestamp[31:0];  // Parte baja
        end else if (data_addr == 32'h80000004) begin
            data_rdata = hw_timestamp[63:32]; // Parte alta
        end
    end

    assign leds = hw_timestamp[25:22];

endmodule