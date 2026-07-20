// ============================================================================
// apb_monitor.sv
// Role: Passively observes the APB bus and DUT output signals
//       Captures one transaction per completed APB transfer
//       (PSEL=1 && PENABLE=1 && PREADY=1)
// KEY FIX: Changed from forever loop to finite for loop (num_transactions)
//          Added capture of transfer_done and error (previously missing)
//          Added output-side functional coverage
// ============================================================================

class apb_monitor;

    virtual apb_if                  vif;
    mailbox #(apb_transaction)      mbx_m2s;    // To scoreboard
    apb_transaction                 mon_trans;  // Used by covergroup

    // ----------------------------------------------------------
    // Output-side Functional Coverage
    // ----------------------------------------------------------
    covergroup mon_cg;
        PWRITE_OBS: coverpoint mon_trans.PWRITE {
            bins write = {1};
            bins read  = {0};
        }
        PRDATA_RANGES: coverpoint mon_trans.PRDATA {
            bins zero     = {0};
            bins low      = {[1:63]};
            bins mid_low  = {[64:127]};
            bins mid_high = {[128:191]};
            bins high     = {[192:255]};
            bins upper    = {[256:32'hFFFF_FFFF]};
        }
        PSLVERR_OBS: coverpoint mon_trans.PSLVERR {
            bins no_error  = {0};
            bins has_error = {1};
        }
        ERROR_OBS: coverpoint mon_trans.error {
            bins no_error   = {0};
            bins error_seen = {1};
        }
        DONE_OBS: coverpoint mon_trans.transfer_done {
            bins done = {1};
        }
        PADDR_BOUNDARY: coverpoint mon_trans.PADDR {
            bins addr_min = {0};
            bins addr_mid = {[1:30]};
            bins addr_max = {31};
        }
        ERR_x_WR: cross PSLVERR_OBS, PWRITE_OBS;
    endgroup

    function new(virtual apb_if vif, mailbox #(apb_transaction) mbx_m2s);
        this.vif     = vif;
        this.mbx_m2s = mbx_m2s;
        mon_cg = new();
    endfunction

    task start();
        for (int i = 0; i < `num_transactions; i++) begin
            apb_transaction captured;

            // -------------------------------------------------
            // Wait for APB transfer completion point:
            // PSEL=1 && PENABLE=1 && PREADY=1 simultaneously
            // This is the exact cycle the DUT samples the bus
            // -------------------------------------------------
            @(vif.cb_monitor);
            while (!(vif.cb_monitor.PSEL &&
                     vif.cb_monitor.PENABLE &&
                     vif.cb_monitor.PREADY)) begin
                @(vif.cb_monitor);
            end

            // -------------------------------------------------
            // Capture full bus state at transfer completion
            // -------------------------------------------------
            captured = new();

            // APB Master bus outputs
            captured.PADDR         = vif.cb_monitor.PADDR;
            captured.PWRITE        = vif.cb_monitor.PWRITE;
            captured.PWDATA        = vif.cb_monitor.PWDATA;
            captured.PSTRB         = vif.cb_monitor.PSTRB;

            // Slave bus outputs
            captured.PRDATA        = vif.cb_monitor.PRDATA;
            captured.PSLVERR       = vif.cb_monitor.PSLVERR;

            // User interface passthrough (for cross-checking)
            captured.write_read    = vif.cb_monitor.write_read;
            captured.addr_in       = vif.cb_monitor.addr_in;

            // DUT completion/status outputs
	    @(vif.cb_monitor);
            captured.transfer_done = vif.cb_monitor.transfer_done;
            captured.error         = vif.cb_monitor.error;

            mon_trans = captured;

            // Push to scoreboard
            mbx_m2s.put(captured);

            // Sample output coverage
            mon_cg.sample();

            $display("[MON @%0t] TXN#%03d | %s | PADDR=%0h | PWDATA=%0h | PRDATA=%0h | ERR=%0b | DONE=%0b | COV=%.1f%%",
                $time, i,
                captured.PWRITE ? "WR" : "RD",
                captured.PADDR,
                captured.PWDATA,
                captured.PRDATA,
                captured.PSLVERR,
                captured.transfer_done,
                mon_cg.get_coverage());
        end
    endtask

endclass
