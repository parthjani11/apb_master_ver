`include "defines.svh"

interface apb_if(input bit PCLK, input bit PRESETn);

    logic [`addr_width-1:0]      PADDR;
    logic                        PSEL;
    logic                        PENABLE;
    logic                        PWRITE;
    logic [`data_width-1:0]      PWDATA;
    logic [(`data_width/8)-1:0]  PSTRB;

    logic [`data_width-1:0]      PRDATA;
    logic                        PREADY;
    logic                        PSLVERR;

    logic                        transfer;
    logic                        write_read;
    logic [`addr_width-1:0]      addr_in;
    logic [`data_width-1:0]      wdata_in;
    logic [(`data_width/8)-1:0]  strb_in;

    logic [`data_width-1:0]      rdata_out;
    logic                        transfer_done;
    logic                        error;

    clocking cb_driver @(posedge PCLK);
        default input #1ns output #1ns;
        input  PADDR, PWDATA, PSTRB;
        input  PSEL, PENABLE, PWRITE;
        input  transfer_done, error;
        input  PRESETn;
        output PRDATA, PREADY, PSLVERR;
        output transfer, write_read;
        output addr_in, wdata_in, strb_in;
    endclocking

    clocking cb_monitor @(posedge PCLK);
        default input #1ns;
        input  PADDR, PWDATA, PSTRB;
        input  PSEL, PENABLE, PWRITE;
        input  PRDATA, PREADY, PSLVERR;
        input  transfer, write_read;
        input  addr_in, wdata_in, strb_in;
        input  transfer_done, error;
        input  PRESETn;
    endclocking

    modport DRV (clocking cb_driver);
    modport MON (clocking cb_monitor);

    property p_reset_deassert;
        @(posedge PCLK) (!PRESETn) |=> (!PSEL && !PENABLE && !transfer_done && !error);
    endproperty
    a_reset_deassert: assert property(p_reset_deassert) 
        else $error("[SVA FAIL] Group 1: FSM did not initialize to IDLE cleanly after PRESETn deassertion.");

    property p_idle_no_transfer;
        @(posedge PCLK) disable iff (!PRESETn)
        (!PSEL && !PENABLE && !transfer) |=> (!PSEL && !PENABLE);
    endproperty
    a_idle_no_transfer: assert property(p_idle_no_transfer) 
        else $error("[SVA FAIL] Group 2: APB bus did not remain in IDLE while transfer=0.");

    property p_psel_asserts_on_transfer;
        @(posedge PCLK) disable iff (!PRESETn)
        (!PSEL && !PENABLE && transfer) |=> (PSEL && !PENABLE);
    endproperty
    a_psel_asserts_on_transfer: assert property(p_psel_asserts_on_transfer) 
        else $error("[SVA FAIL] Group 3: PSEL failed to assert on the cycle after transfer request in IDLE.");

    property p_psel_stable_during_wait;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY) |=> PSEL;
    endproperty
    a_psel_stable_during_wait: assert property(p_psel_stable_during_wait) 
        else $error("[SVA FAIL] Group 3: PSEL deasserted prematurely during a wait state (PREADY=0).");

    property p_psel_deasserts_after_completion;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PREADY && !transfer) |=> (!PSEL);
    endproperty
    a_psel_deasserts_after_completion: assert property(p_psel_deasserts_after_completion) 
        else $error("[SVA FAIL] Group 3: PSEL failed to deassert after transaction completion (FSM must return to IDLE).");

    property p_psel_asserts_after_completion;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PREADY && transfer) |=> (PSEL);
    endproperty
    a_psel_asserts_after_completion: assert property(p_psel_asserts_after_completion) 
        else $error("[SVA FAIL] Group 3: PSEL failed to assert after transaction completion (FSM must return to setup).");

    property p_penable_exactly_1_cycle;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !PENABLE) |=> (PSEL && PENABLE);
    endproperty
    a_penable_exactly_1_cycle: assert property(p_penable_exactly_1_cycle) 
        else $error("[SVA FAIL] Group 4: PENABLE did not assert exactly 1 cycle after PSEL (SETUP to ACCESS).");

    property p_penable_stable_during_wait;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY) |=> PENABLE;
    endproperty
    a_penable_stable_during_wait: assert property(p_penable_stable_during_wait) 
        else $error("[SVA FAIL] Group 4: PENABLE deasserted prematurely during a wait state (PREADY=0).");

    property p_penable_deasserts_after_completion;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PREADY) |=> (!PENABLE);
    endproperty
    a_penable_deasserts_after_completion: assert property(p_penable_deasserts_after_completion) 
        else $error("[SVA FAIL] Group 4: PENABLE failed to deassert after PREADY=1 completion edge.");

    // ---------------------------------------------------------
    // GROUP 5/6/9/11: Payload Stability (SETUP and ACCESS phases)
    // ---------------------------------------------------------
    property p_pwrite_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !(PENABLE && PREADY)) |=> ##1 $stable(PWRITE);
    endproperty
    a_pwrite_stable: assert property(p_pwrite_stable) 
        else $error("[SVA FAIL] Group 5: PWRITE changed mid-transaction.");

    property p_paddr_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !(PENABLE && PREADY)) |=> ##1 $stable(PADDR);
    endproperty
    a_paddr_stable: assert property(p_paddr_stable) 
        else $error("[SVA FAIL] Group 6: PADDR changed mid-transaction.");

    property p_pwdata_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PWRITE && !(PENABLE && PREADY)) |=> ##1 $stable(PWDATA);
    endproperty
    a_pwdata_stable: assert property(p_pwdata_stable) 
        else $error("[SVA FAIL] Group 9: PWDATA changed mid-write transaction.");

    property p_pstrb_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PWRITE && !(PENABLE && PREADY)) |=> ##1 $stable(PSTRB);
    endproperty
    a_pstrb_stable: assert property(p_pstrb_stable) 
        else $error("[SVA FAIL] Group 11: PSTRB changed mid-write transaction.");

    property p_pstrb_zero_during_read;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !PWRITE) |-> (PSTRB == 0);
    endproperty
    a_pstrb_zero_during_read: assert property(p_pstrb_zero_during_read) 
        else $error("[SVA FAIL] Group 11: PSTRB must be 4'b0000 during read operations.");

    property p_transfer_done_on_completion;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PREADY) |=> (transfer_done == 1);
    endproperty
    a_transfer_done_on_completion: assert property(p_transfer_done_on_completion) 
        else $error("[SVA FAIL] Group 12: transfer_done did not assert following PREADY=1.");

    property p_transfer_done_pulse_width;
        @(posedge PCLK) disable iff (!PRESETn)
        (transfer_done) |=> (!transfer_done);
    endproperty
    a_transfer_done_pulse_width: assert property(p_transfer_done_pulse_width) 
        else $error("[SVA FAIL] Group 12: transfer_done pulse stretched beyond 1 PCLK cycle.");

    property p_error_set_on_pslverr;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PREADY && PSLVERR) |=> (error == 1);
    endproperty
    a_error_set_on_pslverr: assert property(p_error_set_on_pslverr) 
        else $error("[SVA FAIL] Group 13: error output failed to assert following PSLVERR=1.");

    property p_error_cleared_on_idle;
        @(posedge PCLK) disable iff (!PRESETn)
        (error) |=> (!error);
    endproperty
    a_error_cleared_on_idle: assert property(p_error_cleared_on_idle) 
        else $error("[SVA FAIL] Group 13: error output failed to clear on FSM return to IDLE (pulse exceeded 1 cycle).");

    property p_controls_not_unknown;
        @(posedge PCLK) disable iff (!PRESETn)
        !$isunknown({PSEL, PENABLE, PWRITE});
    endproperty
    a_controls_not_unknown: assert property(p_controls_not_unknown)
        else $error("[SVA FAIL] Group 14: APB Control signals floated to 'x' or 'z'.");

    property p_pready_not_unknown;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE) |-> !$isunknown(PREADY);
    endproperty
    a_pready_not_unknown: assert property(p_pready_not_unknown)
        else $error("[SVA FAIL] Group 14: PREADY floated to 'x' or 'z' during ACCESS phase.");

endinterface
