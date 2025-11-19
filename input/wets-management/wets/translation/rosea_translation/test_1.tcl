# 1.    Transfer request from a new vessel with no available Transit Lane
#       Expect an instance of Waiting Vessel to be created
namespace eval test_1 {
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

    proc setup {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # The goal is to drive the system to the state where no transit lane
        # is available and a request for a new transfer arrives.
        # This means we must create transfer request for each transit lane.
        # After that, the next transfer request will have to wait.
        set lane_count [pipe {
            relvar restrictone [namespace parent]::Wets_Configuration Name $configuration |
            relation extract ~ Lane_count
        }]
        for {set lane 0} {$lane < $lane_count} {incr lane} {
            set license [format {VS-%02d} $lane]
            ::vessel_mgmt asyncCreationReceiver Vessel [list License $license]\
                Start_transfer $configuration up
        }

        # Wait for each vessel to be assigned a transit lane
        for {set lane 0} {$lane < $lane_count} {incr lane} {
            set assigned [waitForSync]
            log::debug "$assigned assigned a transit lane"
        }
    }

    proc trigger {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        ::vessel_mgmt asyncCreationReceiver Vessel [list License VS-99]\
            Start_transfer $configuration up

        # Wait until a waiting vessel is created. This will be VS-99.
        set waiting [waitForSync]
        set license [dict get $waiting License]
        if {[dict get $waiting License] eq "VS-99"} {
            log::debug "$test_phase: $license is assigned a transit lane"
        } else {
            log::error "expected waiting vessel to be VS-99, got: $license"
        }
    }

    proc reset {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # wait until the VS-99 is assigned
        set assigned [waitForSync]
        set license [dict get $assigned License]
        if {$license eq "VS-99"} {
            log::debug "reset: $license is assigned a transit lane"
        } else {
            error "expected VS-99 to be assigned, got 'license'"
        }

        set deleted [waitForSync]
        set license [dict get $deleted License]
        if {$license eq "VS-99"} {
            log::debug "reset: $license transfer is completed"
        } else {
            error "expected VS-99 to be deleted, got '$license'"
        }
    }

    proc finalize {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # Wait for Vessel VS-99 to be deleted in the vessel_mgmt domain after the transfer has happened.
        set deleted [waitForSync]
        set license [dict get $deleted License]
        if {$license eq "VS-99"} {
            log::debug "reset: $license transfer is completed"
        } else {
            error "expected VS-99 to be deleted, got '$license'"
        }
    }
}
