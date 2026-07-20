class apb_reference_model;

    mailbox #(apb_transaction)  mbx_d2rm;   // From driver
    mailbox #(apb_transaction)  mbx_rm2s;   // To scoreboard

    function new(mailbox #(apb_transaction) mbx_d2rm,
                 mailbox #(apb_transaction) mbx_rm2s);
        this.mbx_d2rm = mbx_d2rm;
        this.mbx_rm2s = mbx_rm2s;
    endfunction

    task start();
        for (int i = 0; i < `num_transactions; i++) begin
            apb_transaction req;
            apb_transaction expected;

            mbx_d2rm.get(req);
            expected = new();

            if (req.write_read == 1) begin
                expected.PWDATA = req.wdata_in;
                expected.PSTRB  = req.strb_in;
                expected.PRDATA = 32'hx;       // Don't-care for writes
            end

            if (req.write_read == 0) begin
                expected.PWDATA = 32'hx;       // Don't-care for reads
                expected.PSTRB  = 4'hx;        // Don't-care for reads
                expected.PRDATA = req.PRDATA;  // What driver injected as slave data
            end

            expected.PSLVERR       = req.PSLVERR;
            expected.error         = req.PSLVERR; // DUT error output mirrors slave PSLVERR
            expected.transfer_done = 1;           // Transfer always completes (with or without error)

            mbx_rm2s.put(expected);

            $display("[REF @%0t] TXN#%03d | %s | EXP_PADDR=%0h | EXP_PWDATA=%0h | EXP_PRDATA=%0h | EXP_ERR=%0b",
                $time, i,
                req.write_read ? "WR" : "RD",
                expected.PADDR,
                expected.PWDATA,
                expected.PRDATA,
                expected.error);
        end
    endtask

endclass
