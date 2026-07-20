// ============================================================================
// apb_env.sv
// KEY FIX: build() and start() are separate tasks
//          No $finish — simulation control stays in top.sv
//          fork...join (blocking) works because ALL components now use
//          finite for loops (num_transactions iterations each)
//          After join, scb.print_summary() is called automatically per phase
// ============================================================================

class apb_env;

    // ----------------------------------------------------------
    // Component handles
    // ----------------------------------------------------------
    apb_gen             gen;
    apb_driver          drv;
    apb_monitor         mon;
    apb_reference_model rm;
    apb_scoreboard      scb;

    // ----------------------------------------------------------
    // Communication mailboxes
    // ----------------------------------------------------------
    mailbox #(apb_transaction)  mbx_g2d;    // Generator  → Driver
    mailbox #(apb_transaction)  mbx_d2rm;   // Driver     → Reference Model
    mailbox #(apb_transaction)  mbx_rm2s;   // Ref Model  → Scoreboard
    mailbox #(apb_transaction)  mbx_m2s;    // Monitor    → Scoreboard

    virtual apb_if vif;

    function new(virtual apb_if vif);
        this.vif = vif;
    endfunction

    // ----------------------------------------------------------
    // build() — instantiate mailboxes and all components
    //           Call ONCE before the first env.start()
    // ----------------------------------------------------------
    task build();
        mbx_g2d  = new();
        mbx_d2rm = new();
        mbx_rm2s = new();
        mbx_m2s  = new();

        gen = new(mbx_g2d);
        drv = new(vif, mbx_g2d, mbx_d2rm);
        mon = new(vif, mbx_m2s);
        rm  = new(mbx_d2rm, mbx_rm2s);
        scb = new(mbx_rm2s, mbx_m2s);
    endtask

    // ----------------------------------------------------------
    // start() — fork all five component tasks and BLOCK until
    //           all num_transactions iterations complete
    //           Can be called multiple times per env (regression phases)
    //           scoreboard.reset_counts() should be called before each
    //           call if per-phase clean reporting is desired
    // ----------------------------------------------------------
    task start();
        fork
            gen.start();    // Generates num_transactions stimulus packets
            drv.start();    // Drives num_transactions APB transfers
            mon.start();    // Captures num_transactions completed transfers
            rm.start();     // Computes num_transactions expected results
            scb.start();    // Compares num_transactions expected vs actual
        join
        // join unblocks only when ALL five tasks finish
        // scb.start() itself calls print_summary() before returning
    endtask

endclass
