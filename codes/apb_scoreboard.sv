class apb_scoreboard;

    mailbox #(apb_transaction)  mbx_rm2s;   // Expected from reference model
    mailbox #(apb_transaction)  mbx_m2s;    // Actual from monitor

    int match_count;
    int mismatch_count;
    int total_count;

    typedef struct {
        time                         fail_time;
        string                       operation;
        logic [`addr_width-1:0]      exp_paddr;
        logic [`addr_width-1:0]      act_paddr;
        logic [`data_width-1:0]      exp_data;
        logic [`data_width-1:0]      act_data;
        logic                        exp_pslverr;
        logic                        act_pslverr;
        logic                        exp_error;
        logic                        act_error;
        string                       fail_reason;
    } fail_record_t;

    fail_record_t failed_q[$];

    function new(mailbox #(apb_transaction) mbx_rm2s,
                 mailbox #(apb_transaction) mbx_m2s);
        this.mbx_rm2s      = mbx_rm2s;
        this.mbx_m2s       = mbx_m2s;
        this.match_count   = 0;
        this.mismatch_count = 0;
        this.total_count   = 0;
    endfunction

    // Call before each phase in regression to get per-phase clean reporting
    function void reset_counts();
        match_count    = 0;
        mismatch_count = 0;
        total_count    = 0;
        failed_q.delete();
    endfunction

    task start();
        for (int i = 0; i < `num_transactions; i++) begin
            apb_transaction exp_tx, act_tx;

            // Concurrently fetch from both mailboxes
            // Neither side should stall the other
            fork
                mbx_rm2s.get(exp_tx);
                mbx_m2s.get(act_tx);
            join

            compare(exp_tx, act_tx, i);
            total_count++;
        end

        print_summary();
    endtask

    task compare(apb_transaction exp, apb_transaction act, int idx);
        bit    pass = 1;
        string fail_reason = "";
        fail_record_t f_rec;

        // 1. Always check: address and direction
        if (exp.PADDR !== act.PADDR) begin
            pass = 0;
            fail_reason = $sformatf("PADDR exp=%0h act=%0h", exp.PADDR, act.PADDR);
        end

        if (exp.PWRITE !== act.PWRITE) begin
            pass = 0;
            fail_reason = $sformatf("%s | PWRITE exp=%0b act=%0b",
                                     fail_reason, exp.PWRITE, act.PWRITE);
        end

        // 2. Write-specific: check PWDATA and PSTRB
        if (exp.PWRITE == 1) begin
            if (exp.PWDATA !== act.PWDATA) begin
                pass = 0;
                fail_reason = $sformatf("%s | PWDATA exp=%0h act=%0h",
                                         fail_reason, exp.PWDATA, act.PWDATA);
            end
            if (exp.PSTRB !== act.PSTRB) begin
                pass = 0;
                fail_reason = $sformatf("%s | PSTRB exp=%0b act=%0b",
                                         fail_reason, exp.PSTRB, act.PSTRB);
            end
        end

        // 3. Read-specific: check PRDATA captured by monitor
        if (exp.PWRITE == 0) begin
            if (exp.PRDATA !== act.PRDATA) begin
                pass = 0;
                fail_reason = $sformatf("%s | PRDATA exp=%0h act=%0h",
                                         fail_reason, exp.PRDATA, act.PRDATA);
            end
        end

        // 4. Always check: error propagation
        if (exp.PSLVERR !== act.PSLVERR) begin
            pass = 0;
            fail_reason = $sformatf("%s | PSLVERR exp=%0b act=%0b",
                                     fail_reason, exp.PSLVERR, act.PSLVERR);
        end

        if (exp.error !== act.error) begin
            pass = 0;
            fail_reason = $sformatf("%s | error exp=%0b act=%0b",
                                     fail_reason, exp.error, act.error);
        end

        // 5. Log result
        if (pass) begin
            match_count++;
            $display("[SCB @%0t] PASS TXN#%03d | %s | PADDR=%0h | DATA=%0h",
                $time, idx,
                act.PWRITE ? "WR" : "RD",
                act.PADDR,
                act.PWRITE ? act.PWDATA : act.PRDATA);
        end else begin
            mismatch_count++;
            f_rec.fail_time   = $time;
            f_rec.operation   = act.PWRITE ? "WR" : "RD";
            f_rec.exp_paddr   = exp.PADDR;
            f_rec.act_paddr   = act.PADDR;
            f_rec.exp_data    = exp.PWRITE ? exp.PWDATA : exp.PRDATA;
            f_rec.act_data    = act.PWRITE ? act.PWDATA : act.PRDATA;
            f_rec.exp_pslverr = exp.PSLVERR;
            f_rec.act_pslverr = act.PSLVERR;
            f_rec.exp_error   = exp.error;
            f_rec.act_error   = act.error;
            f_rec.fail_reason = fail_reason;
            failed_q.push_back(f_rec);

            $error("[SCB @%0t] FAIL TXN#%03d | %s | PADDR=%0h | Reason: %s",
                $time, idx,
                f_rec.operation,
                act.PADDR,
                fail_reason);
        end
    endtask

    task print_summary();
        $display("\n==================================================================");
        $display("                  APB SCOREBOARD PHASE SUMMARY                  ");
        $display("==================================================================");
        $display("  Transactions Checked : %0d", total_count);
        $display("  Matches              : %0d", match_count);
        $display("  Mismatches           : %0d", mismatch_count);

        if (mismatch_count > 0) begin
            $display("\n------------------------------------------------------------------");
            $display("                  FAILED TRANSACTION LOG                        ");
            $display("------------------------------------------------------------------");
            $display("| TIME      | OP | EXP_ADDR | ACT_ADDR | EXP_DATA | ACT_DATA | PSLVERR |");
            $display("------------------------------------------------------------------");
            foreach (failed_q[i]) begin
                $display("| %0t | %s | %0h | %0h | %0h | %0h | exp=%0b act=%0b |",
                    failed_q[i].fail_time,
                    failed_q[i].operation,
                    failed_q[i].exp_paddr,
                    failed_q[i].act_paddr,
                    failed_q[i].exp_data,
                    failed_q[i].act_data,
                    failed_q[i].exp_pslverr,
                    failed_q[i].act_pslverr);
            end
            $display("------------------------------------------------------------------");
            $display("  *** PHASE RESULT : FAIL ***\n");
        end else begin
            $display("  *** PHASE RESULT : PASS — All transactions matched ***\n");
        end
        $display("==================================================================\n");
    endtask

endclass
