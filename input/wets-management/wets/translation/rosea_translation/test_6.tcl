# 6.    Transfer request for a duplicate Vessel.
#       Expect the request to be denied.
namespace eval test_6 {
    set service [string trimleft [namespace parent] :]::test_6
    set logger [::logger::init $service]
    set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
            "colorConsole" : "console"}]
    ::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
            -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}
    ::logger::import -all -namespace log $service
    log::setlevel $::options(level)

    namespace import ::ral::*
    namespace import ::ralutil::*
    namespace path [linsert [namespace path] 0 [namespace parent]]

    proc setup {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # Request a single Vessel to transfer up
        ::vessel_mgmt asyncCreationReceiver Vessel [list License VS-00]\
            Start_transfer $configuration up

        # Wait for the vessel to be assigned
        set assigned [waitForSync]
        log::debug "$assigned waiting to move"
    }

    proc trigger {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # Wait for the vessel to enter the Waiting To Move state
        set dup [waitForSync]
        log::debug "$dup: [dict get $dup __State]"

        # Request a transfer for the same vessel.
        ::vessel_mgmt asyncControlReceiver Vessel [list License VS-00]\
            Start_transfer $configuration up

        # Wait for the vessel to enter the Duplicate Request state
        set dup [waitForSync]
        log::debug "$dup: [dict get $dup __State]"

        # Wait for the vessel to transition back to Waiting To Move
        set dup [waitForSync]
        log::debug "$dup: [dict get $dup __State]"
    }

    proc reset {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # Wait for Vessel VS-00 to be deleted in the wets domain after the transfer has happened.
        set deleted [waitForSync]
        set license [dict get $deleted License]
        if {$license eq "VS-00"} {
            log::debug "reset: $license transfer is completed"
        } else {
            error "expected VS-00 to be deleted, got '$license'"
        }
    }

    proc finalize {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # Wait for Vessel VS-00 to be deleted in the vessel_mgmt domain after the transfer has happened.
        set deleted [waitForSync]
        set license [dict get $deleted License]
        if {$license eq "VS-00"} {
            log::debug "reset: $license transfer is completed"
        } else {
            error "expected VS-00 to be deleted, got '$license'"
        }
    }
}
