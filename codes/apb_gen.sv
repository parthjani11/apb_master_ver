// ============================================================================
// apb_gen.sv
// KEY FIX: Removed gen_ended event — env.start() uses fork...join
//          with finite loops so event-based termination is not needed
// ============================================================================

class apb_gen;

    apb_transaction               blueprint;
    mailbox #(apb_transaction)    mbx_g2d;

    function new(mailbox #(apb_transaction) mbx_g2d);
        this.mbx_g2d = mbx_g2d;
        blueprint    = new();       // Construct a default base transaction
    endfunction

    task start();
        for (int i = 0; i < `num_transactions; i++) begin

            assert(blueprint.randomize() == 1) else
                $fatal(1, "[GEN] Randomization FAILED at TXN#%0d", i);

            // Put a deep copy — NOT the blueprint handle itself
            // Prevents aliasing: next randomize() must not corrupt already-sent packets
            mbx_g2d.put(blueprint.copy());

            $display("[GEN @%0t] TXN#%03d | %s | ADDR=%0h | WDATA=%0h | STRB=%0b | WAIT=%0d | PSLVERR=%0b",
                $time, i,
                blueprint.write_read ? "WR" : "RD",
                blueprint.addr_in,
                blueprint.wdata_in,
                blueprint.strb_in,
                blueprint.wait_cycles,
                blueprint.PSLVERR);
        end
    endtask

endclass
