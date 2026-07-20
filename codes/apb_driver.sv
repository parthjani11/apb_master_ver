class apb_driver;

    virtual apb_if                  vif;
    mailbox #(apb_transaction)      mbx_g2d;    // From generator
    mailbox #(apb_transaction)      mbx_d2rm;   // To reference model
    apb_transaction                 drv_trans;  // Used by covergroup

    
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
            mbx_g2d.get(req);
            drv_trans = req;

            @(vif.cb_driver);
            vif.cb_driver.transfer   <= req.transfer;
            vif.cb_driver.write_read <= req.write_read;
            vif.cb_driver.addr_in    <= req.addr_in;
            vif.cb_driver.wdata_in   <= req.wdata_in;
            vif.cb_driver.strb_in    <= req.strb_in;
            vif.cb_driver.PREADY     <= 0;

            @(vif.cb_driver);
            while (!(vif.cb_driver.PSEL && vif.cb_driver.PENABLE)) begin
                @(vif.cb_driver);
            end

            if (req.wait_cycles > 0) begin
                vif.cb_driver.PREADY <= 0;
                repeat(req.wait_cycles) @(vif.cb_driver);
            end

            vif.cb_driver.PREADY  <= 1;
            vif.cb_driver.PRDATA  <= req.PRDATA;
            vif.cb_driver.PSLVERR <= req.PSLVERR;

            @(vif.cb_driver);
            vif.cb_driver.transfer <= 0;
            vif.cb_driver.PREADY   <= 0;
            vif.cb_driver.PRDATA   <= 0;
            vif.cb_driver.PSLVERR  <= 0;

            mbx_d2rm.put(req);

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
