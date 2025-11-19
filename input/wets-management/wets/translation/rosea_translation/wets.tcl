# Rosea translation of Mike Lee's WETS domain model

set ::wets {
    class Wets {
        attribute Name string -id 1
        attribute Last_waiting_position int -default 0

        statemodel {
            initialstate Idle
            defaulttrans CH

            state Idle {} {}
            transition Idle - Transfer_request -> Service_Transfer_Request
            transition Idle - Removal_request -> Service_Removal_Request
            transition Idle - Transfer_completed -> Service_Transfer_Completed

##############
# // Make sure this isn't a redundant request by first attempting
# // to find a vessel with the same license number
# identical vessel .= Vessel(License == ^new license)
# identical vessel?
#     // If there is vessel with the same license number, reject this request
#     Request denied(vessel license: ^new license) -> VESSEL :
#     // If not, then increment the Last waiting position
#     {
#         ++Last waiting position 
#         // Now see if there are any available transit lanes
#         available transit lanes ..= /R1/Transit Lane( ! /R4/Assigned Vessel )
#         available transit lanes?
#            // There are available transit lanes, see if there is one the same available
#            // transfer direction as the requested direction
#            {
#                 chosen transit lane .= available transit lanes(1, available transfer direction : ^direction)
#                 // If there isn't one in the same direction, just use one of the available ones
#                 !chosen transit lane? chosen transit lane .= available transit lanes(1)
#                 // Get the first gate for traversing the chosen transit lane in the requested direction.
#                 / If requested direction is up, then first gate will be downstream, otherwise it will be upstream.
#                 ^direction == _up?
#                     first gate .= chosen transit lane/R5/Transit Lane Gate/OR7/downstream/~| :
#                     first gate .= chosen transit lane/R5/Transit Lane Gate/OR7/upstream/~|
#                 // Create an Assigned Vessel and establish relationships
#                 new vessel .= *Vessel(License: ^new license, Transfer direction: ^direction)
#                   &R2 *Assigned Vessel( Status: _moving) &R4 chosen transit lane
#                 // Create the associative class Active Gate Move 
#                 *Active Gate Move &R10 new vessel/R2/Assigned Vessel, first gate
#                 // Send an event to the transit lane to let it know it has a vessel to move
#                 Vessel assigned -> chosen transit lane
#             } : {
#               // No Transit Lanes are available, so create a Waiting Vessel and establish relationships
#               *Vessel(License: ^new license, Transfer direction: ^direction)
#                   &R2 *Waiting Vessel(Waiting position: me.Last waiting position) &R3 me
#             }
#         // Send an event to the requesting vessel to let it know that its request has been granted
#         Request granted(vessel license: ^new license) -> VESSEL
#     }
# //  Go back to the Idle state and wait for more work
# Continue -> me
##############

            state Service_Transfer_Request {new_license direction granted_tv denied_tv completed_tv} {
                set identical_vessel [Vessel findById License $new_license]
                if {[isNotEmptyRef $identical_vessel]} {
                    # W1/Response Wormhole/Request-denied($new_license)
                    wormhole W1_request_denied $denied_tv
                } else {
                    set transit_lanes [findRelated $self ~R1]
                    set assigned_transit_lanes [findRelated [Assigned_Vessel findAll] R4]
                    set available_transit_lanes [refMinus $transit_lanes $assigned_transit_lanes]

                    if {[isNotEmptyRef $available_transit_lanes]} {
                        set right_dir [Transit_Lane findWhere {$Available_transfer_direction eq $direction}]
                        set chosen_transit_lane [limitRef [refIntersect $available_transit_lanes $right_dir]]
                        if {[isEmptyRef $chosen_transit_lane]} {
                            set chosen_transit_lane [limitRef $available_transit_lanes]
                        }
                        set tl_gates [findRelated $chosen_transit_lane {~R5 Transit_Lane_Gate}]
                        if {$direction eq "up"} {
                            # first gate going up is the first gate down stream
                            set first_gate [Transit_Lane_Gate Downstream_head $tl_gates]
                        } else {
                            # first gate going down is the first gate up stream
                            set first_gate [Transit_Lane_Gate Upstream_head $tl_gates]
                        }
                        Vessel create\
                            License $new_license\
                            Transfer_direction $direction\
                            Completed_transfer_vector $completed_tv
                        Assigned_Vessel create\
                            License $new_license\
                            Transit_lane [readAttribute $chosen_transit_lane Name]\
                            Status moving
                        Active_Gate_Move create\
                            Transit_lane [readAttribute $chosen_transit_lane Name]\
                            Position [readAttribute $first_gate Position]
                        signal $chosen_transit_lane Vessel_assigned
                    } else {
                        Vessel create\
                            License $new_license\
                            Transfer_direction $direction\
                            Completed_transfer_vector $completed_tv
                        withAttribute $self Last_waiting_position {
                            Waiting_Vessel create\
                                License $new_license\
                                Wets [readAttribute $self Name]\
                                Waiting_position $Last_waiting_position
                            incr Last_waiting_position
                        }
                    }
                    # W2/Response Wormhole/Request-granted($new_license)
                    wormhole W2_request_granted $granted_tv
                }
                signal $self Continue
            }
            transition Service_Transfer_Request - Transfer_request -> IG
            transition Service_Transfer_Request - Removal_request -> IG
            transition Service_Transfer_Request - Transfer_completed -> IG
            transition Service_Transfer_Request - Continue -> Idle

##############
# // See if this vessel is waiting.
# identical vessel .= Waiting Vessel(License == ^old license)
# !identical vessel?
#     // There is not a waiting vessel with this license number so
#     // send the requestor a request denied.
#     Request denied(vessel license: ^old license) -> VESSEL :
#     {
#     // This vessel is waiting, so send it a Request granted event
#     // and delete it and its super type.
#         Request granted(license: ^old license) -> VESSEL
#         !*Vessel(License: ^old license), Waiting Vessel(License: ^old license)
#     }
# //  Go back to the Idle state and wait for more work.
# Continue -> me
##############

            state Service_Removal_Request {old_license granted_tv denied_tv} {
                set waiting_vessel [Waiting_Vessel findById License $old_license]
                if {[isEmptyRef $waiting_vessel]} {
                    # W1/Response Wormhole/Request-denied($old_license)
                    wormhole W1_request_denied $denied_tv
                } else {
                    delete [findRelated $waiting_vessel R2]
                    delete $waiting_vessel
                    # W2/Response Wormhole/Request-granted($old_license)
                    wormhole W2_request_granted $granted_tv
                }
                signal $self Continue
            }
            transition Service_Removal_Request - Transfer_request -> IG
            transition Service_Removal_Request - Removal_request -> IG
            transition Service_Removal_Request - Transfer_completed -> IG
            transition Service_Removal_Request - Continue -> Idle

############## 0.10
# // Send the  Vessel a Transfer completed event
# Transfer completed (vessel license : ^completed license) -> VESSEL
# // Next delete the associated class Active Gate Move followed by deleting
# // the Supertype Vessel and associated subtype Assigned Vessel.
# !*/R4/R10Active Gate Move
# !*Vessel(License: ^completed license), Assigned Vessel(License: ^completed license)
# // Now get the earliest waiting vessel
# earliest waiting vessel .= me/R3/OR9/earlier/~|
# earliest waiting vessel?
#     // There is an earliest waiting vessel
#     {
#         // First, get the earliest waiting vessel's requested direction
#         requested direction = earliest waiting vessel/R2/Vessel.Transfer direction
#         // Get the first gate for traversing the chosen transit lane in the requested direction.
#         // If requested direction is up, then first gate will be downstream, otherwise it will be upstream.
#         requested direction == .up?
#             first gate .= ^free transit lane/R5/Transit Lane Gate/OR7/downstream/~| :
#             first gate .= ^free transit lane/R5/Transit Lane Gate/OR7/upstream/~|
#         // Migrate the Waiting Vessel to an Assigned Vessel.
#         earliest waiting vessel >> Assigned Vessel(Status: _moving) &R4 ^free transit lane
#         // Create the associative object Active Gate Move
#         *Active Gate Move &R10 ^free transit lane/R4/Assigned Vessel, first gate
#         //  Send an event to the transit lane to let it know it has a vessel to move.
#         Vessel assigned -> ^free transit lane
#     } :
#     // There is no earliest waiting vessel so reset the Last waiting position
#     Last waiting position = 0
# //  Go back to the Idle state and wait for more work
# Continue -> me
##############

            state Service_Transfer_Completed {free_transit_lane completed_license} {
                set assigned_vessel [Assigned_Vessel findById License $completed_license]
                set vessel [findRelated $assigned_vessel R2]
                # W3/Response Wormhole/Transfer-completed($completed_license)
                wormhole W3_transfer_completed [readAttribute $vessel Completed_transfer_vector]

                set gate_move [findRelated $assigned_vessel {R10 Active_Gate_Move}]
                delete $gate_move
                delete $assigned_vessel
                delete $vessel

                set earliest_waiting_vessel [instop $self earliest_waiting]
                if {[isNotEmptyRef $earliest_waiting_vessel]} {
                    set requested_direction\
                        [readAttribute [findRelated $earliest_waiting_vessel R2] Transfer_direction]
                    set tl_gates [findRelated $free_transit_lane {~R5 Transit_Lane_Gate}]
                    if {$requested_direction eq "up"} {
                        set first_gate [Transit_Lane_Gate Downstream_head $tl_gates]
                    } else {
                        set first_gate [Transit_Lane_Gate Upstream_head $tl_gates]
                    }
                    Assigned_Vessel create\
                        License [readAttribute $earliest_waiting_vessel License]\
                        Transit_lane [readAttribute $free_transit_lane Name]\
                        Status moving
                    delete $earliest_waiting_vessel
                    Active_Gate_Move create\
                        Transit_lane [readAttribute $free_transit_lane Name]\
                        Position [readAttribute $first_gate Position]

                    signal $free_transit_lane Vessel_assigned
                } else {
                    updateAttribute $self Last_waiting_position 0
                }

                signal $self Continue
            }
            transition Service_Transfer_Completed - Transfer_request -> IG
            transition Service_Transfer_Completed - Removal_request -> IG
            transition Service_Transfer_Completed - Transfer_completed -> IG
            transition Service_Transfer_Completed - Continue -> Idle
        }

        instop earliest_waiting {} {
            set waiting_vessels [findRelated $self ~R3]
            if {[isEmptyRef $waiting_vessels]} {
                return [Waiting_Vessel emptyRef]
            }
            set earliest_license [pipe {
                deRef $waiting_vessels |
                relation rank ~ -ascending Waiting_position Pos_Rank |
                relation restrictwith ~ {$Pos_Rank <= 1} |
                relation project ~ License |
                relation extract ~ License
            }]
            return [Waiting_Vessel findById License $earliest_license]
        }
    }

    class Transit_Lane {
        attribute Name string -id 1
        attribute Wets string
        attribute Available_transfer_direction string\
            -check {$Available_transfer_direction eq "up" || $Available_transfer_direction eq "down"}

        reference R1 Wets -link {Wets Name}

        statemodel {
            initialstate Idle
            defaulttrans CH

            # empty
            state Idle {} {
            }
            transition Idle - Vessel_assigned -> Assess_Water_Level

##############
# // See if the Assigned Vessel's transfer direction is the same as this
# // Transit Lane's Available transfer direction
# (/R4/R2/Vessel.Transfer direction == Available transfer direction)?
# // Same transfer direction, so no water adjustments to do. Start transfer.
#     Start transfer -> me :
# // Different transfer directions, so we need to:
# //1 - Change the Available transfer direction for this Transit Lane
# Available transfer direction == _up?
#     Available transfer direction = _down :
#     Available transfer direction = _up
# //2 - Get the set of Adjustment Steps to do this
# adjustment step set .. = /R11/Adjustment Step (transit lane : Name ;
#   Adjustment direction : Available transfer direction)
# //3 - Get the first step in this set
# starting step .= adjustment step set/OR13/before/~|
# //4 - Create the associative class Active Step
# *Active Step &R12 me, starting step
# //5 - Then go do the Active Step adjustment
# Make adjustments -> me
##############

            state Assess_Water_Level {} {
                set assigned_vessel [findRelated $self ~R4]
                set vessel [findRelated $assigned_vessel R2]
                withAttribute $self Available_transfer_direction {
                    assignAttribute $vessel Transfer_direction
                    if {$Transfer_direction eq $Available_transfer_direction} {
                        signal $self Start_transfer
                    } else {
                        set Available_transfer_direction\
                            [expr {$Available_transfer_direction eq "up" ? "down" : "up"}]
                        set starting_step [instop $self Starting_step]
                        Active_Step create\
                            Transit_lane [readAttribute $starting_step Transit_lane]\
                            Adjustment_direction [readAttribute $starting_step Adjustment_direction]\
                            Step_number [readAttribute $starting_step Step_number]

                        signal $self Make_adjustments
                    }
                }
            }
            transition Assess_Water_Level - Make_adjustments -> Request_Gate_Adjustment
            transition Assess_Water_Level - Start_transfer -> Request_Gate_Move

##############
# // Get the gate needing to do a move
# move gate .= /R4/R10/Transit Lane Gate
# Move vessel -> move gate
##############
            state Request_Gate_Move {} {
                set move_gate [findRelated $self ~R4 R10]
                signal $move_gate Move_vessel
            }
            transition Request_Gate_Move - Move_complete -> Assess_Transfer_Complete

##############
# // Tell the gate for the Active Step to adjust its level.
# Adjust level -> /R12/Adjustment Step/R14/Transit Lane Gate
##############
            state Request_Gate_Adjustment {} {
                set adjust_gate [findRelated $self ~R4 R10]
                signal $adjust_gate Adjust_level
            }
            transition Request_Gate_Adjustment - Adjust_complete -> Assess_Adjustment_Complete

##############
# // 1 - Get the next Transit Lane Gate to be adjusted
# //     and delete the old one.
# next step .= /R12/Adjustment Step/OR13/after
# !*/R12/Active Step
# // 2 - Do we have a next step?
# next step?
# //3A - We have a next step create a new Active Step and go do it
# {
#     *Active Step &R12 me, next step
#     Continue adjustments -> me
# } :
# //3B - We don't have a next step, start the transfer
# {   Start transfer -> me}
##############

            state Assess_Adjustment_Complete {} {
                set active_step [findRelated $self {~R12 Active_Step}]
                set current_step [findRelated $active_step ~R12]
                assignAttribute $current_step\
                    {Step_number current_step_number}\
                    {Adjustment_direction current_adjustment_direction}
                set next_step [findRelatedWhere $self ~R11 {
                    $Adjustment_direction eq $current_adjustment_direction &&
                    $Step_number == ($current_step_number + 1)
                }]
                delete $active_step
                if {[isNotEmptyRef $next_step]} {
                    assignAttribute $next_step Transit_lane Adjustment_direction Step_number
                    Active_Step create\
                        Transit_lane $Transit_lane\
                        Adjustment_direction $Adjustment_direction\
                        Step_number $Step_number
                    signal $self Continue_adjustment
                } else {
                    signal $self Start_transfer
                }
            }
            transition Assess_Adjustment_Complete - Continue_adjustment -> Request_Gate_Adjustment
            transition Assess_Adjustment_Complete - Start_transfer -> Request_Gate_Move

##############
# // Get the last Transit Lane Gate moved past
# last transit lane gate .= /R4/R10/Transit Lane Gate
# // Get the next Transit Lane Gate in the vessel's transfer direction
# /R4/R2/Vessel.Transfer direction == _up?
# // Going up, next gate will bw upstream 
#     next transit lane gate .= last transit lane gate/OR7/upstream :
# //Going down, next gate will be downstream
#     next transit lane gate .= last transit lane gate/OR7/downstream
# // Is there a next transit lane gate or are we finished?
# next transit lane gate?  
# // Yes we have one, relate the vessel to this new gate via R10 and the
# // associative class Active Gate Move and continue transfer
# {
#     *Active Gate Move &R10 /R4/Assigned Vessel, next transit lane gate
#     Continue transfer -> me 
# } : 
# {
# // No, we don't have one, the last gate move must have completed the vessel's transfer.
# // Report transfer completed to Wets and return to idle state.
#     Transfer completed (free transit lane : me, completed license : /R4/R2/Vessel.License) -> /R1/Wets
#     Finished transfer -> me
# }
##############
            state Assess_Transfer_Complete {} {
                set assigned_vessel [findRelated $self ~R4]
                set last_transit_lane_gate [findRelated $assigned_vessel R10]
                assignAttribute $last_transit_lane_gate {Position last_position}
                set vessel [findRelated $assigned_vessel R2]
                assignAttribute $vessel Transfer_direction

                if {$Transfer_direction eq "up"} {
                    set next_position [expr {$last_position + 1}]
                    set next_transit_lane_gate [findRelatedWhere $self {{~R5 Transit_Lane_Gate}} {
                        $Position == $next_position
                    }]
                } else {
                    # going down
                    set next_position [expr {$last_position - 1}]
                    set next_transit_lane_gate [findRelatedWhere $self {{~R5 Transit_Lane_Gate}} {
                        $Position == $next_position
                    }]
                }
                log::debug "next_transit_lane_gate: $next_transit_lane_gate"

                if {[isNotEmptyRef $next_transit_lane_gate]} {
                    set active_gate_move [findRelated $assigned_vessel {R10 Active_Gate_Move}]
                    R10 reference $active_gate_move $next_transit_lane_gate
                    signal $self Continue_transfer
                } else {
                    set vessel [findRelated $assigned_vessel R2]
                    assignAttribute $vessel
                    set wets [findRelated $self R1]
                    signal $wets Transfer_completed $self $License
                    signal $self Finished_transfer
                }
            }
            transition Assess_Transfer_Complete - Continue_transfer -> Request_Gate_Move
            transition Assess_Transfer_Complete - Finished_transfer -> Idle
        }

        # This instance op calculates the first step in the OR13 ordinal association
        instop Starting_step {} {
            assignAttribute $self Available_transfer_direction
            set adjustment_steps [findRelatedWhere $self ~R11 {
                $Adjustment_direction eq $Available_transfer_direction
            }]
            set starting_step [pipe {
                deRef $adjustment_steps |
                relation rank ~ -ascending Step_number Step_rank |
                relation restrictwith ~ {$Step_rank <= 1} |
                relation project ~ Transit_lane Adjustment_direction Step_number
            }]
            return [Adjustment_Step findById {*}[tuple get [relation tuple $starting_step]]]
        }
    }

    class Gate {
        attribute Name string -id 1
        attribute Culvert string
        attribute Status string -default closed -check {
            $Status eq "open" || $Status eq "opening" || $Status eq "closed" || $Status eq "closing"
        }

        reference R6 Culvert -link {Culvert Name}
    }

    class Culvert {
        attribute Name string -id 1
        attribute Valve string

        reference R8 Valve -link {Valve Name}
    }

    class Valve {
        attribute Name string -id 1
        attribute Status string -default closed -check {
            $Status eq "open" || $Status eq "opening" || $Status eq "closed" || $Status eq "closing"
        }
    }

    # Transit Lane Gate participates in an ordinal reflexive association.
    # The association is a "sequential" association, i.e. a list.
    # We implement this by using a number and a couple of class operations
    # to find the beginning and end by simply finding the smallest and
    # largest value of the Transit position attribute.
    class Transit_Lane_Gate {
        attribute Gate string -id 1
        attribute Transit_lane string -id 2
        attribute Position int -id 2 -default 0

        reference R5 Gate -link {Gate Name}
        reference R5 Transit_Lane -link {Transit_lane Name}

        statemodel {
            initialstate Secured_At_Rest
            defaulttrans CH

##############
# empty
##############
            state Secured_At_Rest {} {}
            transition Secured_At_Rest - Move_vessel -> Open_Valve
            transition Secured_At_Rest - Adjust_level -> Open_Valve_Adjust

##############
# // Direct my valve to open
# Transit Lane Gate.Open valve()
##############
            state Open_Valve {} {
                # W4/Request Wormhole/Open valve(self->Gate->Culvert->Valve.Name, self.Gate(Valve opened))
                set valve_to_open [findRelated $self ~R5 R6 R8]
                wormhole W4_open_valve\
                    [identifier $valve_to_open]\
                    [identifier $self]\
                    Valve_opened
            }
            transition Open_Valve - Valve_opened -> Wait_For_Zero_Flow

##############
# // Direct my valve to open
# Transit Lane Gate.Open valve()
##############
            state Open_Valve_Adjust {} {
                # W4/Request Wormhole/Open valve(self->Gate->Culvert->Valve.Name, self.Gate(Valve opened))
                set valve_to_open [findRelated $self ~R5 R6 R8]
                wormhole W4_open_valve\
                    [identifier $valve_to_open]\
                    [identifier $self]\
                    Valve_opened
            }
            transition Open_Valve_Adjust - Valve_opened -> Wait_For_Zero_Flow_Adjust

##############
# // Direct my culvert to notify me when the flow through it
# // from the open valve is zero
# Transit Lane Gate.Wait for zero flow()
##############
            state Wait_For_Zero_Flow {} {
                # W5/Request Wormhole/Monitor_culvert_flow(self->Gate->Culvert, self.Gate(Flow zero))
                set culvert_to_monitor [findRelated $self ~R5 R6]
                wormhole W5_monitor_culvert_flow\
                    [identifier $culvert_to_monitor]\
                    [identifier $self]\
                    Flow_zero
            }
            transition Wait_For_Zero_Flow - Flow_zero -> Open_Gate

##############
# // Direct my culvert to notify me when the flow through it
# // from the open valve is zero
# Transit Lane Gate.Wait for zero flow()
##############
            state Wait_For_Zero_Flow_Adjust {} {
                # W5/Request Wormhole/Monitor_culvert_flow(self->Gate->Culvert, self.Gate(Flow zero))
                set culvert_to_monitor [findRelated $self ~R5 R6]
                wormhole W5_monitor_culvert_flow\
                    [identifier $culvert_to_monitor]\
                    [identifier $self]\
                    Flow_zero
            }
            transition Wait_For_Zero_Flow_Adjust - Flow_zero -> Close_Valve_Adjust

##############
# // Direct this gate, with an open valve and no water flow through its culvert, to open
# Open (gate name : me.Gate) -> GATE
##############
            state Open_Gate {} {
                # W6/Request Wormhole/Open gate(self/R5/Gate.Name, self.Gate(Gate opened))
                set gate_to_open [findRelated $self ~R5]
                wormhole W6_open_gate\
                    [identifier $gate_to_open]\
                    [identifier $self]\
                    Gate_opened
            }
            transition Open_Gate - Gate_opened -> Move_Vessel

##############
# // Change my vessel status to "moving" and direct it to move past this gate
# /R10/Assigned Vessel.status = _moving
# My vessel license = /R10/Assigned vessel.License
# Move past gate (vessel license : My vessel license, transit lane gate name : me.Gate) -> VESSEL
##############
            state Move_Vessel {} {
                set assigned_vessel [findRelated $self ~R10]
                updateAttribute $assigned_vessel Status moving
                # W7/Request Wormhole/Move past gate(
                #       self/R10/Assigned Vessel.License, self/R5/Gate.Name, self.Gate(Moved past gate))
                set gate_id [identifier $self]
                set gate_to_pass [findRelated $self ~R5]
                wormhole W7_move_past_gate\
                    [identifier $assigned_vessel]\
                    [identifier $gate_to_pass]\
                    [identifier $self]\
                    Moved_past_gate
            }
            transition Move_Vessel - Moved_past_gate -> Close_Gate

##############
# // Change my vessel status to "secured" and direct this gate to close.
# /R10/Awaiting Vessel.status = _secured
# Close (gate name : me.Gate) -> GATE
##############
            state Close_Gate {} {
                set assigned_vessel [findRelated $self ~R10]
                updateAttribute $assigned_vessel Status secured
                # W8/Request Wormhole/Close gate(self/R5/Gate.Name, self.Gate(Gate closed))
                set gate_to_close [findRelated $self ~R5]
                wormhole W8_close_gate\
                    [identifier $gate_to_close]\
                    [identifier $self]\
                    Gate_closed
            }
            transition Close_Gate - Gate_closed -> Close_Valve

##############
# // Direct my valve to close
# Transit Lane Gate. Close valve()
##############
            state Close_Valve {} {
                # W9/Request Wormhole/Close valve(self->Gate->Culvert->Valve.Name, self.Gate(Valve closed))
                set valve_to_close [findRelated $self ~R5 R6 R8]
                wormhole W9_close_valve\
                    [identifier $valve_to_close]\
                    [identifier $self]\
                    Valve_closed
            }
            transition Close_Valve - Valve_closed -> Complete_Move

##############
# // Direct my valve to close
# Transit Lane Gate. Close valve()
##############
            state Close_Valve_Adjust {} {
                # W9/Request Wormhole/Close valve(self->Gate->Culvert->Valve.Name, self.Gate(Valve closed))
                set valve_to_close [findRelated $self ~R5 R6 R8]
                wormhole W9_close_valve\
                    [identifier $valve_to_close]\
                    [identifier $self]\
                    Valve_closed
            }
            transition Close_Valve_Adjust - Valve_closed -> Complete_Adjust

##############
# // Notify my Transit Lane that the requested move has been completed.
# My transit lane := /R5/Transit Lane
# Move completed () -> My transit lane
##############
            state Complete_Move {} {
                set transit_lane [findRelated $self R5]
                signal $transit_lane Move_complete
                signal $self Move_completed
            }
            transition Complete_Move - Move_completed -> Secured_At_Rest

##############
# // Notify my Transit Lane that the requested move has been completed.
# My transit lane := /R5/Transit Lane
# Adjust completed () -> My transit lane
##############
            state Complete_Adjust {} {
                set transit_lane [findRelated $self R5]
                signal $transit_lane Adjust_complete
                signal $self Adjust_completed
            }
            transition Complete_Adjust - Adjust_completed -> Secured_At_Rest
        }

        # These two class operations were introduced into the translation
        # to handle the OR7 association traversal. Note that OR7 does not
        # appear as a formal association. This association is used as a
        # sequential relation and the only operations present in the
        # state activities happen at the head or tail. The Transit Position
        # attribute is used to keep the order implied by the association.
        # The values of Transit Position are ordered by the initial instance
        # population and do not change at run time since we don't create
        # Transit Lanes or Gates at runtime.
        classop Downstream_head {transit_lane_ref} {
            set tl_values [deRef $transit_lane_ref]
            set down_gate_pos [pipe {
                deRef $transit_lane_ref |
                relation rank ~ -ascending Position Pos_Rank |
                relation restrictwith ~ {$Pos_Rank <= 1}
            }]
            log::debug \n[relformat $down_gate_pos "down gate pos"]
            relation assign $down_gate_pos Transit_lane Position
            return [Transit_Lane_Gate findById Transit_lane $Transit_lane Position $Position]
        }

        classop Upstream_head {transit_lane_ref} {
            set tl_values [deRef $transit_lane_ref]
            set down_gate_pos [pipe {
                deRef $transit_lane_ref |
                relation rank ~ -descending Position Pos_Rank |
                relation restrictwith ~ {$Pos_Rank <= 1}
            }]
            log::debug \n[relformat $down_gate_pos "down gate pos"]
            relation assign $down_gate_pos Transit_lane Position
            return [Transit_Lane_Gate findById Transit_lane $Transit_lane Position $Position]
        }

        instop Open_valve {} {
        }

        instop Close_valve {} {
        }

        instop Wait_for_zero_flow {} {
        }
    }

    class Vessel {
        attribute License string -id 1
        attribute Transfer_direction string -check {
            $Transfer_direction eq "up" || $Transfer_direction eq "down"
        }
        attribute Completed_transfer_vector list -default [list]
    }

    class Assigned_Vessel {
        attribute License string -id 1
        attribute Transit_lane string -id 2
        attribute Status string -check {
            $Status eq "moving" || $Status eq "secured"
        }

        reference R2 Vessel -link License
        reference R4 Transit_Lane -link {Transit_lane Name}
    }

    class Waiting_Vessel {
        attribute License string -id 1
        attribute Wets string -id 2 ; # N.B. class model missing this as a secondary identifier attribute
        attribute Waiting_position int -id 2

        reference R2 Vessel -link License
        reference R3 Wets -link {Wets Name}

        # Waiting Vessel participates in an ordinal reflexive association, OR9.
        # The association is a "sequential" association, i.e. a list.
        # We implement this by using the Waiting Position attribute.
        # The state activities are only interested in finding the head of the
        # implied list. The values of Waiting Position are managed by the
        # Wets class to insure that they are monotonically increasing.
        # Note this function can return NULL which indicates that there
        # are no Waiting Vessel instances for this Wets.
        classop earliest {wets_ref} {
        }
    }

    class Adjustment_Step {
        attribute Transit_lane string -id 1
        attribute Adjustment_direction string -id 1 -check {
            $Adjustment_direction eq "up" || $Adjustment_direction eq "down"
        }
        attribute Step_number int -id 1
        attribute Gate_position int

        reference R11 Transit_Lane -link {Transit_lane Name}
        reference R14 Transit_Lane_Gate -link Transit_lane -link {Gate_position Position} -refid 2
    }

    class Active_Step {
        attribute Transit_lane string -id 1
        attribute Adjustment_direction string -check {
            $Adjustment_direction eq "up" || $Adjustment_direction eq "down"
        }
        attribute Step_number int

        reference R12 Transit_Lane -link {Transit_lane Name}
        reference R12 Adjustment_Step -link Transit_lane -link Adjustment_direction -link Step_number
    }

    class Active_Gate_Move {
        attribute Transit_lane string -id 1
        attribute Position int

        reference R10 Assigned_Vessel -link Transit_lane -refid 2
        reference R10 Transit_Lane_Gate -link Transit_lane -link Position -refid 2
    }

    association R1 Transit_Lane +--1 Wets

    generalization R2 Vessel\
        Waiting_Vessel Assigned_Vessel

    association R3 Waiting_Vessel *--1 Wets

    association R4 Assigned_Vessel ?--1 Transit_Lane

    association R5 Gate +--1 Transit_Lane -associator Transit_Lane_Gate

    association R6 Gate 1--1 Culvert

    association R8 Culvert 1--1 Valve

    association R10 Assigned_Vessel ?--? Transit_Lane_Gate -associator Active_Gate_Move

    association R11 Adjustment_Step +--1 Transit_Lane

    association R12 Adjustment_Step ?--? Transit_Lane -associator Active_Step

    association R14 Adjustment_Step +--1 Transit_Lane_Gate

    # identifier is a list of attribute name/attribute value
    operation asyncControlReceiver {class_name identifier event_name args} {
        set inst [$class_name findById {*}$identifier]
        if {[isEmptyRef $inst]} {
            set msg "failed to find $class_name instance, $identifier"
            log::error $msg
            throw NO_SUCH_INSTANCE $msg
        }
        signal $inst $event_name {*}$args
    }
}

set ::wets_pop {
    class Wets {
        Name    } {
        Wets_1
        Wets_2
        Wets_3
        Wets_4
        Wets_5
        Wets_6
        Wets_7
        Wets_8
        Wets_9
    }
    class Transit_Lane {
        Name                Wets            Available_transfer_direction} {
        Center_Wets_1_2     Wets_1          up
        Center_Wets_1_3     Wets_2          up
        Center_Wets_1_4     Wets_3          up
        Left_Wets_2_2       Wets_4          up
        Right_Wets_2_2      Wets_4          up
        Left_Wets_2_3       Wets_5          up
        Right_Wets_2_3      Wets_5          up
        Left_Wets_2_4       Wets_6          up
        Right_Wets_2_4      Wets_6          up
        Left_Wets_3_2       Wets_7          up
        Center_Wets_3_2     Wets_7          up
        Right_Wets_3_2      Wets_7          up
        Left_Wets_3_3       Wets_8          up
        Center_Wets_3_3     Wets_8          up
        Right_Wets_3_3      Wets_8          up
        Left_Wets_3_4       Wets_9          up
        Center_Wets_3_4     Wets_9          up
        Right_Wets_3_4      Wets_9          up
    }
    class Transit_Lane_Gate {
        Gate    Position        Transit_lane } {
        G1      1 		Center_Wets_1_2
        G2      2 		Center_Wets_1_2
        G3      1 		Center_Wets_1_3
        G4      2 		Center_Wets_1_3
        G5      3 		Center_Wets_1_3
        G6      1 		Center_Wets_1_4
        G7      2 		Center_Wets_1_4
        G8      3 		Center_Wets_1_4
        G9      4 		Center_Wets_1_4
        G10     1 		Left_Wets_2_2
        G11     2 		Left_Wets_2_2
        G12     1 		Right_Wets_2_2
        G13     2 		Right_Wets_2_2
        G14     1 		Left_Wets_2_3
        G15     2 		Left_Wets_2_3
        G16     3 		Left_Wets_2_3
        G17     1 		Right_Wets_2_3
        G18     2 		Right_Wets_2_3
        G19     3 		Right_Wets_2_3
        G20     1 		Left_Wets_2_4
        G21     2 		Left_Wets_2_4
        G22     3 		Left_Wets_2_4
        G23     4 		Left_Wets_2_4
        G24     1 		Right_Wets_2_4
        G25     2 		Right_Wets_2_4
        G26     3 		Right_Wets_2_4
        G27     4 		Right_Wets_2_4
        G28     1 		Left_Wets_3_2
        G29     2 		Left_Wets_3_2
        G30     1 		Center_Wets_3_2
        G31     2 		Center_Wets_3_2
        G32     1 		Right_Wets_3_2
        G33     2 		Right_Wets_3_2
        G34     1 		Left_Wets_3_3
        G35     2 		Left_Wets_3_3
        G36     3 		Left_Wets_3_3
        G37     1 		Center_Wets_3_3
        G38     2 		Center_Wets_3_3
        G39     3 		Center_Wets_3_3
        G40     1 		Right_Wets_3_3
        G41     2 		Right_Wets_3_3
        G42     3 		Right_Wets_3_3
        G43     1 		Left_Wets_3_4
        G44     2 		Left_Wets_3_4
        G45     3 		Left_Wets_3_4
        G46     4 		Left_Wets_3_4
        G47     1 		Center_Wets_3_4
        G48     2 		Center_Wets_3_4
        G49     3 		Center_Wets_3_4
        G50     4 		Center_Wets_3_4
        G51     1 		Right_Wets_3_4
        G52     2 		Right_Wets_3_4
        G53     3 		Right_Wets_3_4
        G54     4 		Right_Wets_3_4
    }
    # There are 54 gates, culverts and valves
    class Gate {
        Name        Culvert} {
        G1          C1
        G2          C2
        G3          C3
        G4          C4
        G5          C5
        G6          C6
        G7          C7
        G8          C8
        G9          C9
        G10         C10
        G11         C11
        G12         C12
        G13         C13
        G14         C14
        G15         C15
        G16         C16
        G17         C17
        G18         C18
        G19         C19
        G20         C20
        G21         C21
        G22         C22
        G23         C23
        G24         C24
        G25         C25
        G26         C26
        G27         C27
        G28         C28
        G29         C29
        G30         C30
        G31         C31
        G32         C32
        G33         C33
        G34         C34
        G35         C35
        G36         C36
        G37         C37
        G38         C38
        G39         C39
        G40         C40
        G41         C41
        G42         C42
        G43         C43
        G44         C44
        G45         C45
        G46         C46
        G47         C47
        G48         C48
        G49         C49
        G50         C50
        G51         C51
        G52         C52
        G53         C53
        G54         C54
    }
    class Culvert {
        Name       Valve} {
        C1         V1
        C2         V2
        C3         V3
        C4         V4
        C5         V5
        C6         V6
        C7         V7
        C8         V8
        C9         V9
        C10        V10
        C11        V11
        C12        V12
        C13        V13
        C14        V14
        C15        V15
        C16        V16
        C17        V17
        C18        V18
        C19        V19
        C20        V20
        C21        V21
        C22        V22
        C23        V23
        C24        V24
        C25        V25
        C26        V26
        C27        V27
        C28        V28
        C29        V29
        C30        V30
        C31        V31
        C32        V32
        C33        V33
        C34        V34
        C35        V35
        C36        V36
        C37        V37
        C38        V38
        C39        V39
        C40        V40
        C41        V41
        C42        V42
        C43        V43
        C44        V44
        C45        V45
        C46        V46
        C47        V47
        C48        V48
        C49        V49
        C50        V50
        C51        V51
        C52        V52
        C53        V53
        C54        V54
    }
    class Valve {
        Name    } {
        V1
        V2
        V3
        V4
        V5
        V6
        V7
        V8
        V9
        V10
        V11
        V12
        V13
        V14
        V15
        V16
        V17
        V18
        V19
        V20
        V21
        V22
        V23
        V24
        V25
        V26
        V27
        V28
        V29
        V30
        V31
        V32
        V33
        V34
        V35
        V36
        V37
        V38
        V39
        V40
        V41
        V42
        V43
        V44
        V45
        V46
        V47
        V48
        V49
        V50
        V51
        V52
        V53
        V54
    }
    class Adjustment_Step {
        Transit_lane        Adjustment_direction    Step_number     Gate_position } {
        Center_Wets_1_2     up                      1               2
        Center_Wets_1_2     down                    1               1
        Center_Wets_1_3     up                      1               3
        Center_Wets_1_3     up                      2               2
        Center_Wets_1_3     up                      3               3
        Center_Wets_1_3     down                    1               1
        Center_Wets_1_3     down                    2               2
        Center_Wets_1_3     down                    3               1
        Center_Wets_1_4     up                      1               4
        Center_Wets_1_4     up                      2               3
        Center_Wets_1_4     up                      3               2
        Center_Wets_1_4     up                      4               4
        Center_Wets_1_4     up                      5               3
        Center_Wets_1_4     up                      6               4
        Center_Wets_1_4     down                    1               1
        Center_Wets_1_4     down                    2               2
        Center_Wets_1_4     down                    3               1
        Center_Wets_1_4     down                    4               3
        Center_Wets_1_4     down                    5               2
        Center_Wets_1_4     down                    6               1
        Left_Wets_2_2       up                      1               2
        Left_Wets_2_2       down                    1               1
        Right_Wets_2_2      up                      1               2
        Right_Wets_2_2      down                    1               1
        Left_Wets_2_3       up                      1               3
        Left_Wets_2_3       up                      2               2
        Left_Wets_2_3       up                      3               3
        Left_Wets_2_3       down                    1               1
        Left_Wets_2_3       down                    2               2
        Left_Wets_2_3       down                    3               1
        Right_Wets_2_3      up                      1               3
        Right_Wets_2_3      up                      2               2
        Right_Wets_2_3      up                      3               3
        Right_Wets_2_3      down                    1               1
        Right_Wets_2_3      down                    2               2
        Right_Wets_2_3      down                    3               1
        Left_Wets_2_4       up                      1               4
        Left_Wets_2_4       up                      2               3
        Left_Wets_2_4       up                      3               2
        Left_Wets_2_4       up                      4               4
        Left_Wets_2_4       up                      5               3
        Left_Wets_2_4       up                      6               4
        Left_Wets_2_4       down                    1               1
        Left_Wets_2_4       down                    2               2
        Left_Wets_2_4       down                    3               1
        Left_Wets_2_4       down                    4               3
        Left_Wets_2_4       down                    5               2
        Left_Wets_2_4       down                    6               1
        Right_Wets_2_4      up                      1               4
        Right_Wets_2_4      up                      2               3
        Right_Wets_2_4      up                      3               2
        Right_Wets_2_4      up                      4               4
        Right_Wets_2_4      up                      5               3
        Right_Wets_2_4      up                      6               4
        Right_Wets_2_4      down                    1               1
        Right_Wets_2_4      down                    2               2
        Right_Wets_2_4      down                    3               1
        Right_Wets_2_4      down                    4               3
        Right_Wets_2_4      down                    5               2
        Right_Wets_2_4      down                    6               1
        Left_Wets_3_2       up                      1               2
        Left_Wets_3_2       down                    1               1
        Center_Wets_3_2     up                      1               2
        Center_Wets_3_2     down                    1               1
        Right_Wets_3_2      up                      1               2
        Right_Wets_3_2      down                    1               1
        Left_Wets_3_3       up                      1               3
        Left_Wets_3_3       up                      2               2
        Left_Wets_3_3       up                      3               3
        Left_Wets_3_3       down                    1               1
        Left_Wets_3_3       down                    2               2
        Left_Wets_3_3       down                    3               1
        Center_Wets_3_3     up                      1               3
        Center_Wets_3_3     up                      2               2
        Center_Wets_3_3     up                      3               3
        Center_Wets_3_3     down                    1               1
        Center_Wets_3_3     down                    2               2
        Center_Wets_3_3     down                    3               1
        Right_Wets_3_3      up                      1               3
        Right_Wets_3_3      up                      2               2
        Right_Wets_3_3      up                      3               3
        Right_Wets_3_3      down                    1               1
        Right_Wets_3_3      down                    2               2
        Right_Wets_3_3      down                    3               1
        Left_Wets_3_4       up                      1               4
        Left_Wets_3_4       up                      2               3
        Left_Wets_3_4       up                      3               2
        Left_Wets_3_4       up                      4               4
        Left_Wets_3_4       up                      5               3
        Left_Wets_3_4       up                      6               4
        Left_Wets_3_4       down                    1               1
        Left_Wets_3_4       down                    2               2
        Left_Wets_3_4       down                    3               1
        Left_Wets_3_4       down                    4               3
        Left_Wets_3_4       down                    5               2
        Left_Wets_3_4       down                    6               1
        Center_Wets_3_4     up                      1               4
        Center_Wets_3_4     up                      2               3
        Center_Wets_3_4     up                      3               2
        Center_Wets_3_4     up                      4               4
        Center_Wets_3_4     up                      5               3
        Center_Wets_3_4     up                      6               4
        Center_Wets_3_4     down                    1               1
        Center_Wets_3_4     down                    2               2
        Center_Wets_3_4     down                    3               1
        Center_Wets_3_4     down                    4               3
        Center_Wets_3_4     down                    5               2
        Center_Wets_3_4     down                    6               1
        Right_Wets_3_4      up                      1               4
        Right_Wets_3_4      up                      2               3
        Right_Wets_3_4      up                      3               2
        Right_Wets_3_4      up                      4               4
        Right_Wets_3_4      up                      5               3
        Right_Wets_3_4      up                      6               4
        Right_Wets_3_4      down                    1               1
        Right_Wets_3_4      down                    2               2
        Right_Wets_3_4      down                    3               1
        Right_Wets_3_4      down                    4               3
        Right_Wets_3_4      down                    5               2
        Right_Wets_3_4      down                    6               1
    }
}
