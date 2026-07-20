// ============================================================================
// apb_driver.sv
// Role: Drives master user inputs (transfer/addr/wdata/strb/write_read)
//       and simulates slave responses (PREADY/PRDATA/PSLVERR)
// KEY FIX: Changed from forever loop to finite for loop (num_transactions)
//          Allows fork...join in env.start() to terminate cleanly
//          Driver puts to ref model AFTER transfer completes (correct ordering)
// ============================================================================

class apb_driver;

    virtual apb_if                  vif;
    mailbox #(apb_transaction)      mbx_g2d;    // From generator
    mailbox #(apb_transaction)      mbx_d2rm;   // To reference model
    apb_transaction                 drv_trans;  // Used by covergroup

    // ----------------------------------------------------------
    // Input-side Functional Coverage
    // ----------------------------------------------------------
    covergroup drv_cg;
        DIRECTION: coverpoint drv_trans.write_read {
            bins WRITE = {1};
            bins READ  = {0};
        }
        ADDRESS: coverpoint drv_trans.addr_in {
            bins addr_min = {0};
            bins addr_mid = {[1:30]};
            bins addr_max = {31};
        }
        WAIT_CYCLES: coverpoint drv_trans.wait_cycles {
            bins no_wait    = {0};
            bins short_wait = {[1:4]};
            bins long_wait  = {[5:10]};
        }
        ERROR_INJECT: coverpoint drv_trans.PSLVERR {
            bins no_error  = {0};
            bins has_error = {1};
        }
        STROBE: coverpoint drv_trans.strb_in {
            bins full_word   = {4'b1111};
            bins partial [3] = {[4'b0001:4'b1110]};
        }
        WR_x_ERR: cross DIRECTION, ERROR_INJECT;
    endgroup

    function new(virtual apb_if vif,
                 mailbox #(apb_transaction) mbx_g2d,
                 mailbox #(apb_transaction) mbx_d2rm);
        this.vif     = vif;
        this.mbx_g2d = mbx_g2d;
        this.mbx_d2rm = mbx_d2rm;
        drv_cg = new();
    endfunction

    task start();
        apb_transaction req;

        // Ensure reset has released before driving any stimulus
        wait(vif.PRESETn);
        repeat(2) @(vif.cb_driver);

        for (int i = 0; i < `num_transactions; i++) begin

            // -------------------------------------------------
            // 1. Fetch next transaction from generator
            // -------------------------------------------------
            mbx_g2d.get(req);
            drv_trans = req;

            // -------------------------------------------------
            // 2. Drive master user inputs on next clock edge
            //    PREADY held low — slave not yet ready
            // -------------------------------------------------
            @(vif.cb_driver);
            vif.cb_driver.transfer   <= req.transfer;
            vif.cb_driver.write_read <= req.write_read;
            vif.cb_driver.addr_in    <= req.addr_in;
            vif.cb_driver.wdata_in   <= req.wdata_in;
            vif.cb_driver.strb_in    <= req.strb_in;
            vif.cb_driver.PREADY     <= 0;

            // -------------------------------------------------
            // 3. Wait for APB master to enter ACCESS phase
            //    DUT: SETUP (PSEL=1, PENABLE=0) → ACCESS (PSEL=1, PENABLE=1)
            //    Typically 2 cycles after transfer=1 is driven
            // -------------------------------------------------
            @(vif.cb_driver);
            while (!(vif.cb_driver.PSEL && vif.cb_driver.PENABLE)) begin
                @(vif.cb_driver);
            end

            // -------------------------------------------------
            // 4. Apply wait states — keep PREADY=0 for wait_cycles
            // -------------------------------------------------
            if (req.wait_cycles > 0) begin
                vif.cb_driver.PREADY <= 0;
                repeat(req.wait_cycles) @(vif.cb_driver);
            end

            // -------------------------------------------------
            // 5. Assert PREADY=1 — slave completes the transfer
            //    For reads: inject PRDATA; for errors: assert PSLVERR
            // -------------------------------------------------
            vif.cb_driver.PREADY  <= 1;
            vif.cb_driver.PRDATA  <= req.PRDATA;
            vif.cb_driver.PSLVERR <= req.PSLVERR;

            // -------------------------------------------------
            // 6. Hold for one cycle so DUT can sample the response
            // -------------------------------------------------
            @(vif.cb_driver);

            // -------------------------------------------------
            // 7. Deassert all outputs — return bus to IDLE
            // -------------------------------------------------
            vif.cb_driver.transfer <= 0;
            vif.cb_driver.PREADY   <= 0;
            vif.cb_driver.PRDATA   <= 0;
            vif.cb_driver.PSLVERR  <= 0;

            // -------------------------------------------------
            // 8. Forward completed transaction to reference model
            //    Done AFTER transfer completes so timing matches monitor
            // -------------------------------------------------
            mbx_d2rm.put(req);

            // -------------------------------------------------
            // 9. Sample coverage and log
            // -------------------------------------------------
            drv_cg.sample();

            $display("[DRV @%0t] TXN#%03d | %s | ADDR=%0h | WDATA=%0h | STRB=%0b | WAIT=%0d | ERR=%0b | COV=%.1f%%",
                $time, i,
                req.write_read ? "WR" : "RD",
                req.addr_in, req.wdata_in, req.strb_in,
                req.wait_cycles, req.PSLVERR,
                drv_cg.get_coverage());
        end
    endtask

endclass
