# 2.    Transfer request for a Vessel going "up. There are no other Vessels competing.
#       Expect an instance of Assigned Vessel to be created
namespace eval test_2 {
    set service [string trimleft [namespace parent] :]::test_1
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

    proc trigger {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # Everything is ready, request a single Vessel to transfer up
        ::vessel_mgmt asyncCreationReceiver Vessel [list License VS-00]\
            Start_transfer $configuration up

        # Wait for the vessel to be assigned a transit lane
        set assigned [waitForSync]
        log::debug "$assigned assigned a transit lane"
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
