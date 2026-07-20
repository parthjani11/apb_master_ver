`include "defines.svh"

module top();

    import apb_package::*;

    logic PCLK;
    logic PRESETn;

    initial begin
        PCLK = 0;
        forever #10 PCLK = ~PCLK;
    end

    initial begin
        PRESETn = 0;                      // Assert reset from time 0
        repeat(10) @(posedge PCLK);      // Hold for 10 cycles
        PRESETn = 1;                      // Deassert reset
    end

    apb_if intrf(PCLK, PRESETn);

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

    
    test_regression reg_tb;

    initial begin
       
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
