# Vessel management domain
# This domain handles coordination with the Wets domain
# to manage vessel transit through the wets system

set ::vessel_mgmt {
    class Vessel {
        attribute License string -id 1
        attribute Status string -default ready -check {
            $Status eq "ready" || $Status eq "waiting" || $Status eq "moving"
        }
        attribute Move_duration int -default 100; # time to move through gate in ms
        attribute Randomize_timing boolean -default false
        attribute Min_move_duration int -default 2000
        attribute Max_move_duration int -default 5000
        attribute Transfer_vector list -default [list]

        statemodel {
            initialstate Requesting_Transfer

            transition @ - Start_transfer -> Requesting_Transfer

            state Requesting_Transfer {wets_id direction} {
                wormhole VM01_request_transfer\
                    $wets_id $direction [identifier $self] Request_granted Request_denied Transfer_complete
            }
            transition Requesting_Transfer - Start_transfer -> Requesting_Transfer
            transition Requesting_Transfer - Request_granted -> Waiting_To_Move
            transition Requesting_Transfer - Request_denied -> Transfer_Aborted

            state Waiting_To_Move {} {
                updateAttribute $self Status waiting
            }
            transition Waiting_To_Move - Move_through_gate -> Moving
            transition Waiting_To_Move - Cancel_transfer -> Canceling
            transition Waiting_To_Move - Start_transfer -> Duplicate_Request

            state Moving {gate transfer_vector} {
                updateAttribute $self\
                    Status moving\
                    Transfer_vector $transfer_vector
                if {[readAttribute $self Randomize_timing]} {
                    withAttribute $self Move_duration Min_move_duration Max_move_duration {
                        set Move_duration [randomInRange $Min_move_duration $Max_move_duration]
                    }
                }
                delaysignal [readAttribute $self Move_duration] $self Passed_gate
            }
            transition Moving - Passed_gate -> Move_Completed
            transition Moving - Cancel_transfer -> IG

            state Move_Completed {} {
                updateAttribute $self Status waiting
                wormhole VM02_move_completed\
                    [tuple get [relation tuple [lindex $self 1]]]\
                    [readAttribute $self Transfer_vector]
            }
            transition Move_Completed - Move_through_gate -> Moving
            transition Move_Completed - Transfer_complete -> Transfer_Completed
            transition Move_Completed - Cancel_transfer -> IG

            state Duplicate_Request {wets_id direction} {
                log::debug "duplicate transfer request"
                wormhole VM01_request_transfer\
                    $wets_id $direction [identifier $self] Request_granted Request_denied Transfer_complete
            }
            transition Duplicate_Request - Request_denied -> Waiting_To_Move

            state Transfer_Completed {} {}

            state Transfer_Aborted {} {
                log::error "transfer request for [readAttribute $self License] denied"
            }

            state Canceling {wets_id} {
                wormhole VM03_request_removal\
                    $wets_id [identifier $self] Request_granted Request_denied
            }
            transition Canceling - Request_granted -> Transfer_Removed
            transition Canceling - Request_denied -> Waiting_To_Move

            state Transfer_Removed {} {
                log::debug "transfer removal for [readAttribute $self License] granted"
            }

            terminal Transfer_Aborted Transfer_Completed Transfer_Removed
        }
    }

    # identifier is a tuple value which identifies an instance
    operation asyncControlReceiver {class_name identifier event_name args} {
        set inst [$class_name findById {*}$identifier]
        if {[isEmptyRef $inst]} {
            set msg "failed to find $class_name instance, $identifier"
            log::error $msg
            throw NO_SUCH_INSTANCE $msg
        }
        signal $inst $event_name {*}$args
    }

    # async receiver for creation events
    operation asyncCreationReceiver {class_name attributes event_name args} {
        set existing [$class_name findById License [dict get $attributes License]]
        if {[isEmptyRef $existing]} {
            $class_name createasync $event_name $args {*}$attributes
        } else {
            log::notice "attempt to create duplicate $class_name with $attributes"
        }
    }
}
