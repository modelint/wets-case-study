# 8.    Remove request when there is a Waiting Vessel with the proper License value.
#       Expect the request is granted and the Vessel removed.
namespace eval test_8 {
    set service [string trimleft [namespace parent] :]::test_8
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

        # The setup is to create transfer requests for all transit lanes in a
        # configuration. After all transit lanes have an Assigned Vessel, the
        # next transfer request will have to wait.
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

        # Request a transfer for VS-99. This will cause the vessel to wait.
        ::vessel_mgmt asyncCreationReceiver Vessel [list License VS-99]\
            Start_transfer $configuration up

        # Wait until VS-99 is made waiting
        set waiting [waitForSync]
        set license [dict get $waiting License]
        if {[dict get $waiting License] eq "VS-99"} {
            log::debug "$test_phase: $license transitioned state"
        } else {
            log::error "expected assigned vessel to be VS-99, got: $license"
        }
    }

    proc trigger {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # Wait until VS-99 transitions to the Waiting To Move state
        for {set done false} {!$done} {} {
            set waiting [waitForSync]
            set license [dict get $waiting License]
            if {[dict get $waiting License] eq "VS-99"} {
                log::debug "$test_phase: $license transitioned state"
            } else {
                log::error "expected assigned vessel to be VS-00, got: $license"
            }
            switch -exact -- [dict get $waiting __State] {
                Waiting_To_Move {
                    log::debug "changed state to Waiting_To_Move"
                    set done true
                }
                default {
                    log::warn "unexpected state transition: [dict get $waiting __State]"
                }
            }
        }


        # Attempt to remove VS-99. This will succeed since VS-99 is waiting.
        ::vessel_mgmt asyncControlReceiver Vessel [list License VS-99]\
            Cancel_transfer $configuration

        # Wait on VS-99 transitions to Canceling and then to Transfer_Removed
        for {set done false} {!$done} {} {
            set waiting [waitForSync]
            set license [dict get $waiting License]
            if {[dict get $waiting License] eq "VS-99"} {
                log::debug "$test_phase: $license transitioned state"
            } else {
                log::error "expected assigned vessel to be VS-99, got: $license"
            }
            set new_state [dict get $waiting __State]
            log::debug "changed state to $new_state"
            switch -exact -- $new_state {
                Canceling {
                }
                Transfer_Removed {
                    set done true
                }
                default {
                    log::warn "unexpected state transition: $new_state"
                }
            }
        }
    }

    proc reset {test_case configuration test_phase} {
        log::info "$test_phase, test case: '$test_case', configuration: '$configuration'"

        # After VS-99 is removed, VS-00 continues on to complete the transfer.
        # Wait until the VS-00 is deleted in the wets domain
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
