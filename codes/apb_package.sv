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
