# 5.    Transfer request to go "down" when the only available transfers are for "down".
#       Expect an instance of Assigned Vessel to be created, no water adjustment is necessary
#       to make a transit lane be available for a down transfer. The transfer completes
#       after the water adjustments are made.
namespace eval test_5 {
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

        # Starting conditions are that all transit lanes are available as "up".
        # Just update all the Transit Lane instances to be down.
        relvar update ::wets::Transit_Lane tl {[tuple extract $tl Wets] eq $configuration} {
            tuple update $tl Available_transfer_direction down
        }
    }

    proc trigger {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        ::vessel_mgmt asyncCreationReceiver Vessel [list License VS-00]\
            Start_transfer $configuration down

        # Wait until an assigned vessel is created. This will be VS-00.
        set waiting [waitForSync]
        set license [dict get $waiting License]
        if {[dict get $waiting License] eq "VS-00"} {
            log::debug "$test_phase: $license is assigned a transit lane"
        } else {
            log::error "expected assigned vessel to be VS-00, got: $license"
        }
    }

    proc reset {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # wait until the VS-00 is deleted
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
        # Return the Transit Lane instances to their default "up" available transfer direction
        relvar update ::wets::Transit_Lane tl {[tuple extract $tl Wets] eq $configuration} {
            tuple update $tl Available_transfer_direction up
        }
    }
}
