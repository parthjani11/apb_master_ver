// ============================================================================
// apb_test.sv
// KEY FIX: Base test uses build() + start() separately
//          test_regression calls env.build() ONCE then env.start() 6×
//          Each phase calls scb.reset_counts() for clean per-phase reporting
//          No more env.run() calling $finish on Phase 1 and killing the rest
// ============================================================================

// ----------------------------------------------------------------------------
// Base Test — fully random, base transaction constraints
// ----------------------------------------------------------------------------
class apb_test;
    virtual apb_if vif;
    apb_env        env;

    function new(virtual apb_if vif);
        this.vif = vif;
    endfunction

    virtual task run();
        env = new(vif);
        env.build();
        env.start();
    endtask
endclass


// ----------------------------------------------------------------------------
// Directed: Wait State Test
// ----------------------------------------------------------------------------
class test_wait_state extends apb_test;
    apb_wait_state_transaction trans_wait;

    function new(virtual apb_if vif);
        super.new(vif);
    endfunction

    task run();
        env = new(vif);
        env.build();
        trans_wait = new();
        env.gen.blueprint = trans_wait;
        env.start();
    endtask
endclass


// ----------------------------------------------------------------------------
// Directed: Byte Strobe Test
// ----------------------------------------------------------------------------
class test_strobe extends apb_test;
    apb_strobe_transaction trans_strobe;

    function new(virtual apb_if vif);
        super.new(vif);
    endfunction

    task run();
        env = new(vif);
        env.build();
        trans_strobe = new();
        env.gen.blueprint = trans_strobe;
        env.start();
    endtask
endclass


// ----------------------------------------------------------------------------
// Directed: Error Response Test
// ----------------------------------------------------------------------------
class test_error extends apb_test;
    apb_error_transaction trans_error;

    function new(virtual apb_if vif);
        super.new(vif);
    endfunction

    task run();
        env = new(vif);
        env.build();
        trans_error = new();
        env.gen.blueprint = trans_error;
        env.start();
    endtask
endclass


// ----------------------------------------------------------------------------
// Regression Container — 6 directed phases back-to-back
//   env.build() called ONCE (creates one set of mailboxes and components)
//   env.start() called per phase (all components loop num_transactions each)
//   scb.reset_counts() called before each phase for per-phase summary
// ----------------------------------------------------------------------------
class test_regression extends apb_test;

    apb_rw_transaction              trans_rw;
    apb_wait_state_transaction      trans_wait;
    apb_error_transaction           trans_error;
    apb_strobe_transaction          trans_strobe;
    apb_data_pattern_txn            trans_data;
    apb_read_coverage_transaction   trans_read_cov;

    function new(virtual apb_if vif);
        super.new(vif);
    endfunction

    task run();
        env = new(vif);
        env.build();

        // Phase 1: Standard Read/Write (no errors, no wait states)
        $display("\n[REGRESSION] ===== PHASE 1: Standard RW =====");
        trans_rw = new();
        env.gen.blueprint = trans_rw;
        env.scb.reset_counts();
        env.start();

        // Phase 2: Wait State Testing (3–10 cycle delays)
        $display("\n[REGRESSION] ===== PHASE 2: Wait States =====");
        trans_wait = new();
        env.gen.blueprint = trans_wait;
        env.scb.reset_counts();
        env.start();

        // Phase 3: Error Response Testing
        $display("\n[REGRESSION] ===== PHASE 3: Error Responses =====");
        trans_error = new();
        env.gen.blueprint = trans_error;
        env.scb.reset_counts();
        env.start();

        // Phase 4: Byte Strobe Testing
        $display("\n[REGRESSION] ===== PHASE 4: Byte Strobes =====");
        trans_strobe = new();
        env.gen.blueprint = trans_strobe;
        env.scb.reset_counts();
        env.start();

        // Phase 5: Data Bus Stress Patterns
        $display("\n[REGRESSION] ===== PHASE 5: Data Patterns =====");
        trans_data = new();
        env.gen.blueprint = trans_data;
        env.scb.reset_counts();
        env.start();

        // Phase 6: Read Data Coverage Bins
        $display("\n[REGRESSION] ===== PHASE 6: Read Coverage =====");
        trans_read_cov = new();
        env.gen.blueprint = trans_read_cov;
        env.scb.reset_counts();
        env.start();

        $display("\n[REGRESSION] ===== ALL 6 PHASES COMPLETE =====\n");
    endtask

endclass
