// ============================================================================
// apb_package.sv — NEW FILE (was missing entirely from original project)
// Includes all class files in strict dependency order:
//   transaction → gen → driver → monitor → ref_model → scoreboard → env → test
// apb_if.sv is NOT included here — interfaces are modules, not classes,
// and must be compiled before this package as a separate compilation unit
// ============================================================================

package apb_package;

    `include "defines.svh"          // Macros — global preprocessor scope

    `include "apb_transaction.sv"   // Base + 8 child transaction classes
    `include "apb_gen.sv"           // Generator
    `include "apb_driver.sv"        // Driver
    `include "apb_monitor.sv"       // Monitor
    `include "apb_reference_model.sv" // Reference model
    `include "apb_scoreboard.sv"    // Scoreboard
    `include "apb_env.sv"           // Environment
    `include "apb_test.sv"          // Test classes

endpackage

// ============================================================================
// COMPILATION ORDER NOTE (for Makefile / vcs / questa run script):
//   Step 1: defines.svh      (included by both apb_if.sv and this package)
//   Step 2: apb_if.sv        (interface module — standalone compile)
//   Step 3: apb_package.sv   (this file — imports everything above)
//   Step 4: apb_master.sv    (RTL DUT — must be available separately)
//   Step 5: top.sv           (imports apb_package, instantiates interface + DUT)
// ============================================================================
