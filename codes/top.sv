`include "defines.svh"
// NOTE: apb_if.sv and apb_package.sv must be compiled before this file
//       apb_master.sv (RTL DUT) must also be compiled before elaboration

module top();

    import apb_package::*;

    // ----------------------------------------------------------
    // Clock and Reset signals
    // ----------------------------------------------------------
    logic PCLK;
    logic PRESETn;

    // ----------------------------------------------------------
    // Clock generation — 50 MHz (20ns period)
    // ----------------------------------------------------------
    initial begin
        PCLK = 0;
        forever #10 PCLK = ~PCLK;
    end

    // ----------------------------------------------------------
    // Reset generation — Active-Low PRESETn
    //   PRESETn = 0 immediately at time 0 (reset asserted)
    //   Released after 10 clock cycles (200ns)
    // ----------------------------------------------------------
    initial begin
        PRESETn = 0;                      // Assert reset from time 0
        repeat(10) @(posedge PCLK);      // Hold for 10 cycles
        PRESETn = 1;                      // Deassert reset
    end

    // ----------------------------------------------------------
    // Interface instantiation
    // ----------------------------------------------------------
    apb_if intrf(PCLK, PRESETn);

    // ----------------------------------------------------------
    // DUT instantiation
    // NOTE: apb_master.sv must be provided separately
    //       Ports must match the actual RTL exactly
    // ----------------------------------------------------------
    apb_master DUV (
        .PCLK         (PCLK),
        .PRESETn      (PRESETn),
        .transfer     (intrf.transfer),
        .write_read   (intrf.write_read),
        .addr_in      (intrf.addr_in),
        .wdata_in     (intrf.wdata_in),
        .strb_in      (intrf.strb_in),
        .PREADY       (intrf.PREADY),
        .PRDATA       (intrf.PRDATA),
        .PSLVERR      (intrf.PSLVERR),
        .PADDR        (intrf.PADDR),
        .PWRITE       (intrf.PWRITE),
        .PSEL         (intrf.PSEL),
        .PENABLE      (intrf.PENABLE),
        .PWDATA       (intrf.PWDATA),
        .PSTRB        (intrf.PSTRB),
        .transfer_done(intrf.transfer_done),
        .error        (intrf.error)
    );

    // ----------------------------------------------------------
    // Test handles
    // t2, t3, t4 are available for standalone directed runs
    // reg_tb runs all phases
    // ----------------------------------------------------------
    apb_test        t1;
    test_wait_state t2;
    test_strobe     t3;
    test_error      t4;
    test_regression reg_tb;

    initial begin
        t1     = new(intrf);
        t2     = new(intrf);
        t3     = new(intrf);
        t4     = new(intrf);
        reg_tb = new(intrf);
	
        // Wait for reset to deassert before driving any stimulus
        wait(PRESETn == 1);
       // #50;

        // Run full regression (6 phases)
        reg_tb.run();
	PRESETn = 0;              // 1?0 toggle (missing in coverage)
        repeat(5) @(posedge PCLK);
        PRESETn = 1;              // 0?1 toggle again

        #200;
        $finish();
    end

endmodule
