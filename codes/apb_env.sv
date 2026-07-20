
class apb_env;

    apb_gen             gen;
    apb_driver          drv;
    apb_monitor         mon;
    apb_reference_model rm;
    apb_scoreboard      scb;

    mailbox #(apb_transaction)  mbx_g2d;    // Generator  → Driver
    mailbox #(apb_transaction)  mbx_d2rm;   // Driver     → Reference Model
    mailbox #(apb_transaction)  mbx_rm2s;   // Ref Model  → Scoreboard
    mailbox #(apb_transaction)  mbx_m2s;    // Monitor    → Scoreboard

    virtual apb_if vif;

    function new(virtual apb_if vif);
        this.vif = vif;
    endfunction

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

    task start();
        fork
            gen.start();    // Generates num_transactions stimulus packets
            drv.start();    // Drives num_transactions APB transfers
            mon.start();    // Captures num_transactions completed transfers
            rm.start();     // Computes num_transactions expected results
            scb.start();    // Compares num_transactions expected vs actual
        join
        
    endtask

endclass
