# 1.    Transfer request from a new vessel with no available Transit Lane
#       Expect an instance of Waiting Vessel to be created
namespace eval test_9 {
    set service [string trimleft [namespace parent] :]::test_9
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
        # This just ensures that the default starting conditions are indeed in place.
        relvar update ::wets::Transit_Lane tl {[tuple extract $tl Wets] eq $configuration} {
            tuple update $tl Available_transfer_direction up
        }

        # The goal is to drive the system to the state where no transit lane
        # is available and a request for a new transfer arrives.
        # This means we must create transfer request for each transit lane.
        # After that, the next transfer request will have to wait.
        set lane_count [getLaneCount $configuration]
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

        # New transfer request. VS-99 will have to wait because all the transit
        # lanes have been assigne.
        ::vessel_mgmt asyncCreationReceiver Vessel [list License VS-99]\
            Start_transfer $configuration up
    }

    proc reset {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # Wait until all the assigned vessels are deleted by the Vessel Management domain
        while {true} {
            set sync_trace [waitForSync]
            set license [dict get $sync_trace License]
            log::debug "reset: $license was deleted in the Vessel Managment domain"
            if {$license eq "VS-99"} {
                break
            }
        }
    }
}
