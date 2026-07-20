// ============================================================================
// apb_transaction.sv
// Base transaction + 8 directed child classes
// KEY FIX: virtual copy() added to base + all child classes
// ============================================================================

class apb_transaction;

    // ----------------------------------------------------------
    // RAND — Stimulus (master user inputs + simulated slave responses)
    // ----------------------------------------------------------
    rand logic                       transfer;
    rand logic                       write_read;
    rand logic [`addr_width-1:0]     addr_in;
    rand logic [`data_width-1:0]     wdata_in;
    rand logic [(`data_width/8)-1:0] strb_in;

    rand logic [`data_width-1:0]     PRDATA;     // Slave read data injected by driver
    rand logic                       PSLVERR;    // Slave error response
    rand int unsigned                wait_cycles; // How many cycles PREADY is held low

    // ----------------------------------------------------------
    // NON-RAND — Observed APB bus signals (captured by monitor)
    // ----------------------------------------------------------
    logic [`addr_width-1:0]      PADDR;
    logic                        PWRITE;
    logic                        PSEL;
    logic                        PENABLE;
    logic [`data_width-1:0]      PWDATA;
    logic [(`data_width/8)-1:0]  PSTRB;
    logic                        transfer_done;
    logic                        error;

    // ----------------------------------------------------------
    // BASE CONSTRAINTS
    // ----------------------------------------------------------
    constraint c_transfer_active { transfer  == 1; }           // Always initiate a transfer
    constraint c_wait_cycles     { wait_cycles inside {[0:4]}; }
    constraint c_strb_valid      {
        strb_in inside {
            4'b0001, 4'b0010, 4'b0100, 4'b1000,
            4'b0011, 4'b0110, 4'b1100,
            4'b0111, 4'b1110,
            4'b1111
        };
    }

    // ----------------------------------------------------------
    // COPY METHOD (virtual — preserves derived type via polymorphism)
    // Copies all field values into a fresh apb_transaction object
    // ----------------------------------------------------------
    virtual function apb_transaction copy();
        apb_transaction t = new();
        t.transfer    = this.transfer;
        t.write_read  = this.write_read;
        t.addr_in     = this.addr_in;
        t.wdata_in    = this.wdata_in;
        t.strb_in     = this.strb_in;
        t.PRDATA      = this.PRDATA;
        t.PSLVERR     = this.PSLVERR;
        t.wait_cycles = this.wait_cycles;
        return t;
    endfunction

endclass


// ============================================================================
// CHILD TRANSACTION CLASSES — Directed Test Constraints
// Each overrides copy() to preserve its own type through mailboxes
// ============================================================================

// 1. Standard Read/Write — no errors, no wait states, full strobe
class apb_rw_transaction extends apb_transaction;
    constraint c_wait_cycles  { wait_cycles == 0; }
    constraint c_no_error     { PSLVERR == 0; }
    constraint c_full_strobe  { strb_in == 4'b1111; }

    virtual function apb_transaction copy();
        apb_rw_transaction t = new();
        t.transfer = this.transfer; t.write_read = this.write_read;
        t.addr_in  = this.addr_in;  t.wdata_in   = this.wdata_in;
        t.strb_in  = this.strb_in;  t.PRDATA     = this.PRDATA;
        t.PSLVERR  = this.PSLVERR;  t.wait_cycles = this.wait_cycles;
        return t;
    endfunction
endclass


// 2. Wait State Testing — 3 to 10 wait cycles before PREADY
class apb_wait_state_transaction extends apb_transaction;
    constraint c_wait_cycles { wait_cycles inside {[3:10]}; }
    constraint c_full_strobe { strb_in == 4'b1111; }
    constraint c_no_error    { PSLVERR == 0; }

    virtual function apb_transaction copy();
        apb_wait_state_transaction t = new();
        t.transfer = this.transfer; t.write_read = this.write_read;
        t.addr_in  = this.addr_in;  t.wdata_in   = this.wdata_in;
        t.strb_in  = this.strb_in;  t.PRDATA     = this.PRDATA;
        t.PSLVERR  = this.PSLVERR;  t.wait_cycles = this.wait_cycles;
        return t;
    endfunction
endclass


// 3. Error Response Testing — slave asserts PSLVERR=1
class apb_error_transaction extends apb_transaction;
    constraint c_error_active    { PSLVERR == 1; }
    constraint c_error_wait_time { wait_cycles inside {[0:5]}; }

    virtual function apb_transaction copy();
        apb_error_transaction t = new();
        t.transfer = this.transfer; t.write_read = this.write_read;
        t.addr_in  = this.addr_in;  t.wdata_in   = this.wdata_in;
        t.strb_in  = this.strb_in;  t.PRDATA     = this.PRDATA;
        t.PSLVERR  = this.PSLVERR;  t.wait_cycles = this.wait_cycles;
        return t;
    endfunction
endclass


// 4. Byte Strobe Testing — partial byte lane write operations
class apb_strobe_transaction extends apb_transaction;
    constraint c_is_write      { write_read == 1; }
    constraint c_clean_run     { PSLVERR == 0; wait_cycles == 0; }
    constraint c_partial_strobe {
        strb_in inside {
            4'b0001, 4'b0010, 4'b0100, 4'b1000,
            4'b0011, 4'b1100,
            4'b0101, 4'b1010
        };
    }

    virtual function apb_transaction copy();
        apb_strobe_transaction t = new();
        t.transfer = this.transfer; t.write_read = this.write_read;
        t.addr_in  = this.addr_in;  t.wdata_in   = this.wdata_in;
        t.strb_in  = this.strb_in;  t.PRDATA     = this.PRDATA;
        t.PSLVERR  = this.PSLVERR;  t.wait_cycles = this.wait_cycles;
        return t;
    endfunction
endclass


// 5. Address Toggle / Boundary Testing
class apb_toggle_transaction extends apb_transaction;
    constraint c_toggle_patterns {
        addr_in inside {5'b00000, 5'b11111, 5'b01010, 5'b10101};
    }
    constraint c_clean_run { PSLVERR == 0; wait_cycles == 0; }

    virtual function apb_transaction copy();
        apb_toggle_transaction t = new();
        t.transfer = this.transfer; t.write_read = this.write_read;
        t.addr_in  = this.addr_in;  t.wdata_in   = this.wdata_in;
        t.strb_in  = this.strb_in;  t.PRDATA     = this.PRDATA;
        t.PSLVERR  = this.PSLVERR;  t.wait_cycles = this.wait_cycles;
        return t;
    endfunction
endclass


// 6. Data Bus Stress Patterns — all-zero, all-one, alternating
class apb_data_pattern_txn extends apb_transaction;
    constraint c_is_write   { write_read == 1; }
    constraint c_clean_run  { PSLVERR == 0; wait_cycles == 0; }
    constraint c_stress_data {
        wdata_in inside {
            32'h00000000,
            32'hFFFFFFFF,
            32'hAAAAAAAA,
            32'h55555555
        };
    }

    virtual function apb_transaction copy();
        apb_data_pattern_txn t = new();
        t.transfer = this.transfer; t.write_read = this.write_read;
        t.addr_in  = this.addr_in;  t.wdata_in   = this.wdata_in;
        t.strb_in  = this.strb_in;  t.PRDATA     = this.PRDATA;
        t.PSLVERR  = this.PSLVERR;  t.wait_cycles = this.wait_cycles;
        return t;
    endfunction
endclass


// 7. Read Data Coverage — forces PRDATA into specific coverage bins
class apb_read_coverage_transaction extends apb_transaction;
    constraint c_is_read    { write_read == 0; }
    constraint c_clean_run  { PSLVERR == 0; wait_cycles == 0; }
    constraint c_prdata_bins {
        PRDATA inside {[0:63], [64:127], [128:191], [192:255]};
    }

    virtual function apb_transaction copy();
        apb_read_coverage_transaction t = new();
        t.transfer = this.transfer; t.write_read = this.write_read;
        t.addr_in  = this.addr_in;  t.wdata_in   = this.wdata_in;
        t.strb_in  = this.strb_in;  t.PRDATA     = this.PRDATA;
        t.PSLVERR  = this.PSLVERR;  t.wait_cycles = this.wait_cycles;
        return t;
    endfunction
endclass


// 8. Back-to-Back Transfers — transfer=1 always, no idle gaps
class apb_transfer_transaction extends apb_transaction;
    constraint c_transfer  { transfer == 1; }
    constraint c_clean_run { PSLVERR == 0; wait_cycles == 0; }

    virtual function apb_transaction copy();
        apb_transfer_transaction t = new();
        t.transfer = this.transfer; t.write_read = this.write_read;
        t.addr_in  = this.addr_in;  t.wdata_in   = this.wdata_in;
        t.strb_in  = this.strb_in;  t.PRDATA     = this.PRDATA;
        t.PSLVERR  = this.PSLVERR;  t.wait_cycles = this.wait_cycles;
        return t;
    endfunction
endclass
