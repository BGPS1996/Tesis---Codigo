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
    input  logic rst_pin,    // Botón de la Zybo (R18 según tu .xdc)
    output logic [3:0] leds  // LEDs de diagnóstico
);

    // --- SEÑALES DE RELOJ Y RESET ---
    logic clk_50MHz;
    logic locked;
    logic rst_n;

    clk_wiz_0 u_clocks (
        .clk_in1 (clk_pin),
        .reset   (1'b0),        
        .clk_out1(clk_50MHz),
        .locked  (locked)
    );

    assign rst_n = !rst_pin && locked; 

    // --- SEÑALES DE LOS BUSES ---
    logic [31:0] instr_addr, instr_rdata;
    logic [31:0] data_addr, data_rdata, data_wdata;
    logic        data_req, data_we;
    logic [63:0] hw_timestamp;
    
    // Señales para el Multiplexor de Datos
    logic [31:0] ram_rdata; 
    logic [31:0] ts_rdata_internal; // Dato que sale del bloque del contador
    logic sel_ts;                   

    // --- INSTANCIA DEL IBEX ---
    ibex_top #(
        .PMPEnable        ( 1'b0 ),
        .RV32E            ( 1'b0 ),
        .RV32M            ( ibex_pkg::RV32MFast )
    ) u_core_cpu (
        .clk_i            ( clk_50MHz ),
        .rst_ni           ( rst_n     ),
        .test_en_i        ( 1'b0      ),
        .scan_rst_ni      ( 1'b1      ),
        .hart_id_i        ( 32'h0     ),
        .boot_addr_i      ( 32'h00000000 ), 
        
        .instr_req_o      ( /* Se conecta a la BRAM abajo */ ),
        .instr_addr_o     ( instr_addr ),
        .instr_rdata_i    ( instr_rdata ),
        
        .data_req_o       ( data_req   ),
        .data_addr_o      ( data_addr  ),
        .data_we_o        ( data_we    ),
        .data_wdata_o     ( data_wdata ),
        .data_rdata_i     ( data_rdata ),
        
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

    // --- LÓGICA DE SELECCIÓN Y MULTIPLEXADO ---
    
    // Decodificador: ¿La dirección empieza con 0x8? (0x80000000)
    assign sel_ts = (data_addr[31:28] == 4'h8); 

    // Lógica para determinar qué parte del contador lee el Ibex
    always_comb begin
        ts_rdata_internal = 32'h0; 
        if (data_addr == 32'h80000000) begin
            ts_rdata_internal = hw_timestamp[31:0];  // Parte baja
        end else if (data_addr == 32'h80000004) begin
            ts_rdata_internal = hw_timestamp[63:32]; // Parte alta
        end
    end

    // El Ibex recibe datos de la RAM o del Contador según la dirección
    assign data_rdata = sel_ts ? ts_rdata_internal : ram_rdata;

    // --- INSTANCIA DE LA BRAM ---
    bram_instrucciones u_memoria_sistema (
        // Puerto A: Bus de Instrucciones
        .clka   (clk_50MHz),
        .ena    (1'b1),
        .wea    (4'b0),
        .addra  (instr_addr[13:2]), // Los 12 bits de dirección que pide el IP
        .dina   (32'h0),
        .douta  (instr_rdata),

        // Puerto B: Bus de Datos
        .clkb   (clk_50MHz),
        .enb    (1'b1),
        .web    ({4{data_we && !sel_ts}}), 
        .addrb  (data_addr[13:2]),
        .dinb   (data_wdata),
        .doutb  (ram_rdata)
    );

    assign leds = hw_timestamp[25:22];

endmodule