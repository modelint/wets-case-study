# Bridge between Wets and Mechanical Management domains

package require ral
package require ralutil

namespace eval ::wets::wormhole {
    set logger [::logger::initNamespace [namespace current]]
    set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
            "colorConsole" : "console"}]
    ::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
            -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}

    log::setlevel $::options(level)

    namespace import ::ral::*
    namespace import ::ralutil::*

    # Request wormholes

    namespace export W4_open_valve
    # valve_id is a tuple containing the identifier for the valve to open
    proc W4_open_valve {valve_id transit_lane_gate_id response_event} {
        set bridge_mapping [relvar restrictone ::wets_mech_bridge::BridgeTable\
            wets_class Valve wets_identifier $valve_id]
        if {[relation isempty $bridge_mapping]} {
            log::warn "failed to find Wets valve with ID, \"$valve_id\""
        } else {
            log::debug \n[relformat $bridge_mapping "W4_open_valve mapping for $valve_id"]
            relation assign $bridge_mapping mech_class mech_identifier
            set transfer_vector [list $transit_lane_gate_id $response_event]
            ::mechanical_mgmt asyncControlReceiver\
                $mech_class $mech_identifier run_out $transfer_vector
        }
    }
    namespace export W9_close_valve
    proc  W9_close_valve {valve_id transit_lane_gate_id response_event} {
        set bridge_mapping [relvar restrictone ::wets_mech_bridge::BridgeTable\
            wets_class Valve wets_identifier $valve_id]
        if {[relation isempty $bridge_mapping]} {
            log::warn "failed to find Wets valve with ID, \"$valve_id\""
        } else {
            log::debug \n[relformat $bridge_mapping "W9_close_valve mapping for $valve_id"]
            relation assign $bridge_mapping mech_class mech_identifier
            set transfer_vector [list $transit_lane_gate_id $response_event]
            ::mechanical_mgmt asyncControlReceiver\
                $mech_class $mech_identifier run_in $transfer_vector
        }
    }

    namespace export W5_monitor_culvert_flow
    proc W5_monitor_culvert_flow {culvert_id transit_lane_gate_id response_event} {
        set bridge_mapping [relvar restrictone ::wets_mech_bridge::BridgeTable\
            wets_class Culvert wets_identifier $culvert_id]
        if {[relation isempty $bridge_mapping]} {
            log::warn "failed to find Wets culvert with id, \"$culvert_id\""
        } else {
            log::debug \n[relformat $bridge_mapping "W5_monitor_culvert_flow mapping for $culvert_id"]
            relation assign $bridge_mapping mech_class mech_identifier
            set transfer_vector [list $transit_lane_gate_id $response_event]
            ::mechanical_mgmt asyncControlReceiver\
                $mech_class $mech_identifier monitor $transfer_vector
        }
    }

    namespace export W6_open_gate
    proc W6_open_gate {gate_id transit_lane_gate_id response_event} {
        set bridge_mapping [relvar restrictone ::wets_mech_bridge::BridgeTable\
            wets_class Gate wets_identifier $gate_id]
        if {[relation isempty $bridge_mapping]} {
            log::warn "failed to find Wets gate with id, \"$gate_id\""
        } else {
            log::debug \n[relformat $bridge_mapping "W6_open_gate mapping for $gate_id"]
            relation assign $bridge_mapping mech_class mech_identifier
            set transfer_vector [list $transit_lane_gate_id $response_event]
            ::mechanical_mgmt asyncControlReceiver\
                $mech_class $mech_identifier run_out $transfer_vector
        }
    }

    namespace export W8_close_gate
    proc W8_close_gate {gate_id transit_lane_gate_id response_event} {
        set bridge_mapping [relvar restrictone ::wets_mech_bridge::BridgeTable\
            wets_class Gate wets_identifier $gate_id]
        if {[relation isempty $bridge_mapping]} {
            log::warn "failed to find Wets gate with id, \"$gate_id\""
        } else {
            log::debug \n[relformat $bridge_mapping "W8_close_gate mapping for $gate_id"]
            relation assign $bridge_mapping mech_class mech_identifier
            set transfer_vector [list $transit_lane_gate_id $response_event]
            ::mechanical_mgmt asyncControlReceiver\
                $mech_class $mech_identifier run_in $transfer_vector
        }
    }

    namespace export W7_move_past_gate
    proc W7_move_past_gate {vessel_id gate_id transit_lane_gate_id response_event} {
        set transfer_vector [list $transit_lane_gate_id $response_event]
        ::vessel_mgmt asyncControlReceiver\
            Vessel $vessel_id Move_through_gate $gate_id $transfer_vector
    }

    # Response Wormholes

    namespace export W1_request_denied
    proc W1_request_denied {transfer_vector} {
        lassign $transfer_vector xfer_identifier xfer_event
        ::vessel_mgmt asyncControlReceiver\
            Vessel\
            $xfer_identifier\
            $xfer_event
    }


    namespace export W2_request_granted
    proc W2_request_granted {transfer_vector} {
        lassign $transfer_vector xfer_identifier xfer_event
        ::vessel_mgmt asyncControlReceiver\
            Vessel\
            $xfer_identifier\
            $xfer_event
    }

    namespace export W3_transfer_completed
    proc W3_transfer_completed {transfer_vector} {
        lassign $transfer_vector xfer_identifier xfer_event
        ::vessel_mgmt asyncControlReceiver\
            Vessel\
            $xfer_identifier\
            $xfer_event
    }

    namespace ensemble create
}

namespace eval ::mechanical_mgmt::wormhole {
    set logger [::logger::initNamespace [namespace current]]
    set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
            "colorConsole" : "console"}]
    ::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
            -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}

    log::setlevel $::options(level)

    namespace import ::ral::*
    namespace import ::ralutil::*

    # Response wormholes

    namespace export MM1_motor_extent_reached
    proc MM1_motor_extent_reached {transfer_vector} {
        lassign $transfer_vector xfer_identifier xfer_event
        ::wets asyncControlReceiver\
            Transit_Lane_Gate\
            $xfer_identifier\
            $xfer_event
    }

    namespace export MM2_zero_flow_sensed
    proc MM2_zero_flow_sensed {transfer_vector} {
        lassign $transfer_vector xfer_identifier xfer_event
        ::wets asyncControlReceiver\
            Transit_Lane_Gate\
            $xfer_identifier\
            $xfer_event
    }

    namespace ensemble create
}

namespace eval ::vessel_mgmt::wormhole {
    set logger [::logger::initNamespace [namespace current]]
    set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
            "colorConsole" : "console"}]
    ::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
            -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}

    log::setlevel $::options(level)

    namespace import ::ral::*
    namespace import ::ralutil::*

    # Request wormholes

    namespace export VM01_request_transfer
    proc VM01_request_transfer {
        wets_id direction vessel_id granted_event denied_event complete_event
    } {
        set granted_transfer_vector [list $vessel_id $granted_event]
        set denied_transfer_vector [list $vessel_id $denied_event]
        set completed_transfer_vector [list $vessel_id $complete_event]
        set license [lindex $vessel_id 1]
        ::wets asyncControlReceiver\
            Wets [list Name $wets_id] Transfer_request\
                $license $direction\
                $granted_transfer_vector $denied_transfer_vector $completed_transfer_vector
    }

    namespace export VM03_request_removal
    proc VM03_request_removal {
        wets_id vessel_id granted_event denied_event
    } {
        set granted_transfer_vector [list $vessel_id $granted_event]
        set denied_transfer_vector [list $vessel_id $denied_event]
        set license [lindex $vessel_id 1]
        ::wets asyncControlReceiver\
            Wets [list Name $wets_id] Removal_request $license\
                $granted_transfer_vector $denied_transfer_vector
    }

    # Response wormholes
    namespace export VM02_move_completed
    proc VM02_move_completed {vessel_id transfer_vector} {
        lassign $transfer_vector xfer_identifier xfer_event
        ::wets asyncControlReceiver\
            Transit_Lane_Gate\
            $xfer_identifier\
            $xfer_event
    }

    namespace ensemble create
}

namespace eval ::wets_mech_bridge {
    namespace import ::ral::*
    namespace import ::ralutil::*

    relvar create BridgeTable {
        wets_class string
        wets_identifier list
        mech_class string
        mech_identifier list
    } {wets_class wets_identifier} {mech_class mech_identifier}

    relvar insert BridgeTable {
        wets_class Valve wets_identifier {Name V1} mech_class Motor mech_identifier {name Valve-M01}
    } {
        wets_class Culvert wets_identifier {Name C1} mech_class Flow_Sensor mech_identifier {name Sensor-F01}
    } {
        wets_class Gate wets_identifier {Name G1} mech_class Motor mech_identifier {name Gate-M01}
    } {
        wets_class Valve wets_identifier {Name V2} mech_class Motor mech_identifier {name Valve-M02}
    } {
        wets_class Culvert wets_identifier {Name C2} mech_class Flow_Sensor mech_identifier {name Sensor-F02}
    } {
        wets_class Gate wets_identifier {Name G2} mech_class Motor mech_identifier {name Gate-M02}
    } {
        wets_class Valve wets_identifier {Name V3} mech_class Motor mech_identifier {name Valve-M03}
    } {
        wets_class Culvert wets_identifier {Name C3} mech_class Flow_Sensor mech_identifier {name Sensor-F03}
    } {
        wets_class Gate wets_identifier {Name G3} mech_class Motor mech_identifier {name Gate-M03}
    } {
        wets_class Valve wets_identifier {Name V4} mech_class Motor mech_identifier {name Valve-M04}
    } {
        wets_class Culvert wets_identifier {Name C4} mech_class Flow_Sensor mech_identifier {name Sensor-F04}
    } {
        wets_class Gate wets_identifier {Name G4} mech_class Motor mech_identifier {name Gate-M04}
    } {
        wets_class Valve wets_identifier {Name V5} mech_class Motor mech_identifier {name Valve-M05}
    } {
        wets_class Culvert wets_identifier {Name C5} mech_class Flow_Sensor mech_identifier {name Sensor-F05}
    } {
        wets_class Gate wets_identifier {Name G5} mech_class Motor mech_identifier {name Gate-M05}
    } {
        wets_class Valve wets_identifier {Name V6} mech_class Motor mech_identifier {name Valve-M06}
    } {
        wets_class Culvert wets_identifier {Name C6} mech_class Flow_Sensor mech_identifier {name Sensor-F06}
    } {
        wets_class Gate wets_identifier {Name G6} mech_class Motor mech_identifier {name Gate-M06}
    } {
        wets_class Valve wets_identifier {Name V7} mech_class Motor mech_identifier {name Valve-M07}
    } {
        wets_class Culvert wets_identifier {Name C7} mech_class Flow_Sensor mech_identifier {name Sensor-F07}
    } {
        wets_class Gate wets_identifier {Name G7} mech_class Motor mech_identifier {name Gate-M07}
    } {
        wets_class Valve wets_identifier {Name V8} mech_class Motor mech_identifier {name Valve-M08}
    } {
        wets_class Culvert wets_identifier {Name C8} mech_class Flow_Sensor mech_identifier {name Sensor-F08}
    } {
        wets_class Gate wets_identifier {Name G8} mech_class Motor mech_identifier {name Gate-M08}
    } {
        wets_class Valve wets_identifier {Name V9} mech_class Motor mech_identifier {name Valve-M09}
    } {
        wets_class Culvert wets_identifier {Name C9} mech_class Flow_Sensor mech_identifier {name Sensor-F09}
    } {
        wets_class Gate wets_identifier {Name G9} mech_class Motor mech_identifier {name Gate-M09}
    } {
        wets_class Valve wets_identifier {Name V10} mech_class Motor mech_identifier {name Valve-M10}
    } {
        wets_class Culvert wets_identifier {Name C10} mech_class Flow_Sensor mech_identifier {name Sensor-F10}
    } {
        wets_class Gate wets_identifier {Name G10} mech_class Motor mech_identifier {name Gate-M10}
    } {
        wets_class Valve wets_identifier {Name V11} mech_class Motor mech_identifier {name Valve-M11}
    } {
        wets_class Culvert wets_identifier {Name C11} mech_class Flow_Sensor mech_identifier {name Sensor-F11}
    } {
        wets_class Gate wets_identifier {Name G11} mech_class Motor mech_identifier {name Gate-M11}
    } {
        wets_class Valve wets_identifier {Name V12} mech_class Motor mech_identifier {name Valve-M12}
    } {
        wets_class Culvert wets_identifier {Name C12} mech_class Flow_Sensor mech_identifier {name Sensor-F12}
    } {
        wets_class Gate wets_identifier {Name G12} mech_class Motor mech_identifier {name Gate-M12}
    } {
        wets_class Valve wets_identifier {Name V13} mech_class Motor mech_identifier {name Valve-M13}
    } {
        wets_class Culvert wets_identifier {Name C13} mech_class Flow_Sensor mech_identifier {name Sensor-F13}
    } {
        wets_class Gate wets_identifier {Name G13} mech_class Motor mech_identifier {name Gate-M13}
    } {
        wets_class Valve wets_identifier {Name V14} mech_class Motor mech_identifier {name Valve-M14}
    } {
        wets_class Culvert wets_identifier {Name C14} mech_class Flow_Sensor mech_identifier {name Sensor-F14}
    } {
        wets_class Gate wets_identifier {Name G14} mech_class Motor mech_identifier {name Gate-M14}
    } {
        wets_class Valve wets_identifier {Name V15} mech_class Motor mech_identifier {name Valve-M15}
    } {
        wets_class Culvert wets_identifier {Name C15} mech_class Flow_Sensor mech_identifier {name Sensor-F15}
    } {
        wets_class Gate wets_identifier {Name G15} mech_class Motor mech_identifier {name Gate-M15}
    } {
        wets_class Valve wets_identifier {Name V16} mech_class Motor mech_identifier {name Valve-M16}
    } {
        wets_class Culvert wets_identifier {Name C16} mech_class Flow_Sensor mech_identifier {name Sensor-F16}
    } {
        wets_class Gate wets_identifier {Name G16} mech_class Motor mech_identifier {name Gate-M16}
    } {
        wets_class Valve wets_identifier {Name V17} mech_class Motor mech_identifier {name Valve-M17}
    } {
        wets_class Culvert wets_identifier {Name C17} mech_class Flow_Sensor mech_identifier {name Sensor-F17}
    } {
        wets_class Gate wets_identifier {Name G17} mech_class Motor mech_identifier {name Gate-M17}
    } {
        wets_class Valve wets_identifier {Name V18} mech_class Motor mech_identifier {name Valve-M18}
    } {
        wets_class Culvert wets_identifier {Name C18} mech_class Flow_Sensor mech_identifier {name Sensor-F18}
    } {
        wets_class Gate wets_identifier {Name G18} mech_class Motor mech_identifier {name Gate-M18}
    } {
        wets_class Valve wets_identifier {Name V19} mech_class Motor mech_identifier {name Valve-M19}
    } {
        wets_class Culvert wets_identifier {Name C19} mech_class Flow_Sensor mech_identifier {name Sensor-F19}
    } {
        wets_class Gate wets_identifier {Name G19} mech_class Motor mech_identifier {name Gate-M19}
    } {
        wets_class Valve wets_identifier {Name V20} mech_class Motor mech_identifier {name Valve-M20}
    } {
        wets_class Culvert wets_identifier {Name C20} mech_class Flow_Sensor mech_identifier {name Sensor-F20}
    } {
        wets_class Gate wets_identifier {Name G20} mech_class Motor mech_identifier {name Gate-M20}
    } {
        wets_class Valve wets_identifier {Name V21} mech_class Motor mech_identifier {name Valve-M21}
    } {
        wets_class Culvert wets_identifier {Name C21} mech_class Flow_Sensor mech_identifier {name Sensor-F21}
    } {
        wets_class Gate wets_identifier {Name G21} mech_class Motor mech_identifier {name Gate-M21}
    } {
        wets_class Valve wets_identifier {Name V22} mech_class Motor mech_identifier {name Valve-M22}
    } {
        wets_class Culvert wets_identifier {Name C22} mech_class Flow_Sensor mech_identifier {name Sensor-F22}
    } {
        wets_class Gate wets_identifier {Name G22} mech_class Motor mech_identifier {name Gate-M22}
    } {
        wets_class Valve wets_identifier {Name V23} mech_class Motor mech_identifier {name Valve-M23}
    } {
        wets_class Culvert wets_identifier {Name C23} mech_class Flow_Sensor mech_identifier {name Sensor-F23}
    } {
        wets_class Gate wets_identifier {Name G23} mech_class Motor mech_identifier {name Gate-M23}
    } {
        wets_class Valve wets_identifier {Name V24} mech_class Motor mech_identifier {name Valve-M24}
    } {
        wets_class Culvert wets_identifier {Name C24} mech_class Flow_Sensor mech_identifier {name Sensor-F24}
    } {
        wets_class Gate wets_identifier {Name G24} mech_class Motor mech_identifier {name Gate-M24}
    } {
        wets_class Valve wets_identifier {Name V25} mech_class Motor mech_identifier {name Valve-M25}
    } {
        wets_class Culvert wets_identifier {Name C25} mech_class Flow_Sensor mech_identifier {name Sensor-F25}
    } {
        wets_class Gate wets_identifier {Name G25} mech_class Motor mech_identifier {name Gate-M25}
    } {
        wets_class Valve wets_identifier {Name V26} mech_class Motor mech_identifier {name Valve-M26}
    } {
        wets_class Culvert wets_identifier {Name C26} mech_class Flow_Sensor mech_identifier {name Sensor-F26}
    } {
        wets_class Gate wets_identifier {Name G26} mech_class Motor mech_identifier {name Gate-M26}
    } {
        wets_class Valve wets_identifier {Name V27} mech_class Motor mech_identifier {name Valve-M27}
    } {
        wets_class Culvert wets_identifier {Name C27} mech_class Flow_Sensor mech_identifier {name Sensor-F27}
    } {
        wets_class Gate wets_identifier {Name G27} mech_class Motor mech_identifier {name Gate-M27}
    } {
        wets_class Valve wets_identifier {Name V28} mech_class Motor mech_identifier {name Valve-M28}
    } {
        wets_class Culvert wets_identifier {Name C28} mech_class Flow_Sensor mech_identifier {name Sensor-F28}
    } {
        wets_class Gate wets_identifier {Name G28} mech_class Motor mech_identifier {name Gate-M28}
    } {
        wets_class Valve wets_identifier {Name V29} mech_class Motor mech_identifier {name Valve-M29}
    } {
        wets_class Culvert wets_identifier {Name C29} mech_class Flow_Sensor mech_identifier {name Sensor-F29}
    } {
        wets_class Gate wets_identifier {Name G29} mech_class Motor mech_identifier {name Gate-M29}
    } {
        wets_class Valve wets_identifier {Name V30} mech_class Motor mech_identifier {name Valve-M30}
    } {
        wets_class Culvert wets_identifier {Name C30} mech_class Flow_Sensor mech_identifier {name Sensor-F30}
    } {
        wets_class Gate wets_identifier {Name G30} mech_class Motor mech_identifier {name Gate-M30}
    } {
        wets_class Valve wets_identifier {Name V31} mech_class Motor mech_identifier {name Valve-M31}
    } {
        wets_class Culvert wets_identifier {Name C31} mech_class Flow_Sensor mech_identifier {name Sensor-F31}
    } {
        wets_class Gate wets_identifier {Name G31} mech_class Motor mech_identifier {name Gate-M31}
    } {
        wets_class Valve wets_identifier {Name V32} mech_class Motor mech_identifier {name Valve-M32}
    } {
        wets_class Culvert wets_identifier {Name C32} mech_class Flow_Sensor mech_identifier {name Sensor-F32}
    } {
        wets_class Gate wets_identifier {Name G32} mech_class Motor mech_identifier {name Gate-M32}
    } {
        wets_class Valve wets_identifier {Name V33} mech_class Motor mech_identifier {name Valve-M33}
    } {
        wets_class Culvert wets_identifier {Name C33} mech_class Flow_Sensor mech_identifier {name Sensor-F33}
    } {
        wets_class Gate wets_identifier {Name G33} mech_class Motor mech_identifier {name Gate-M33}
    } {
        wets_class Valve wets_identifier {Name V34} mech_class Motor mech_identifier {name Valve-M34}
    } {
        wets_class Culvert wets_identifier {Name C34} mech_class Flow_Sensor mech_identifier {name Sensor-F34}
    } {
        wets_class Gate wets_identifier {Name G34} mech_class Motor mech_identifier {name Gate-M34}
    } {
        wets_class Valve wets_identifier {Name V35} mech_class Motor mech_identifier {name Valve-M35}
    } {
        wets_class Culvert wets_identifier {Name C35} mech_class Flow_Sensor mech_identifier {name Sensor-F35}
    } {
        wets_class Gate wets_identifier {Name G35} mech_class Motor mech_identifier {name Gate-M35}
    } {
        wets_class Valve wets_identifier {Name V36} mech_class Motor mech_identifier {name Valve-M36}
    } {
        wets_class Culvert wets_identifier {Name C36} mech_class Flow_Sensor mech_identifier {name Sensor-F36}
    } {
        wets_class Gate wets_identifier {Name G36} mech_class Motor mech_identifier {name Gate-M36}
    } {
        wets_class Valve wets_identifier {Name V37} mech_class Motor mech_identifier {name Valve-M37}
    } {
        wets_class Culvert wets_identifier {Name C37} mech_class Flow_Sensor mech_identifier {name Sensor-F37}
    } {
        wets_class Gate wets_identifier {Name G37} mech_class Motor mech_identifier {name Gate-M37}
    } {
        wets_class Valve wets_identifier {Name V38} mech_class Motor mech_identifier {name Valve-M38}
    } {
        wets_class Culvert wets_identifier {Name C38} mech_class Flow_Sensor mech_identifier {name Sensor-F38}
    } {
        wets_class Gate wets_identifier {Name G38} mech_class Motor mech_identifier {name Gate-M38}
    } {
        wets_class Valve wets_identifier {Name V39} mech_class Motor mech_identifier {name Valve-M39}
    } {
        wets_class Culvert wets_identifier {Name C39} mech_class Flow_Sensor mech_identifier {name Sensor-F39}
    } {
        wets_class Gate wets_identifier {Name G39} mech_class Motor mech_identifier {name Gate-M39}
    } {
        wets_class Valve wets_identifier {Name V40} mech_class Motor mech_identifier {name Valve-M40}
    } {
        wets_class Culvert wets_identifier {Name C40} mech_class Flow_Sensor mech_identifier {name Sensor-F40}
    } {
        wets_class Gate wets_identifier {Name G40} mech_class Motor mech_identifier {name Gate-M40}
    } {
        wets_class Valve wets_identifier {Name V41} mech_class Motor mech_identifier {name Valve-M41}
    } {
        wets_class Culvert wets_identifier {Name C41} mech_class Flow_Sensor mech_identifier {name Sensor-F41}
    } {
        wets_class Gate wets_identifier {Name G41} mech_class Motor mech_identifier {name Gate-M41}
    } {
        wets_class Valve wets_identifier {Name V42} mech_class Motor mech_identifier {name Valve-M42}
    } {
        wets_class Culvert wets_identifier {Name C42} mech_class Flow_Sensor mech_identifier {name Sensor-F42}
    } {
        wets_class Gate wets_identifier {Name G42} mech_class Motor mech_identifier {name Gate-M42}
    } {
        wets_class Valve wets_identifier {Name V43} mech_class Motor mech_identifier {name Valve-M43}
    } {
        wets_class Culvert wets_identifier {Name C43} mech_class Flow_Sensor mech_identifier {name Sensor-F43}
    } {
        wets_class Gate wets_identifier {Name G43} mech_class Motor mech_identifier {name Gate-M43}
    } {
        wets_class Valve wets_identifier {Name V44} mech_class Motor mech_identifier {name Valve-M44}
    } {
        wets_class Culvert wets_identifier {Name C44} mech_class Flow_Sensor mech_identifier {name Sensor-F44}
    } {
        wets_class Gate wets_identifier {Name G44} mech_class Motor mech_identifier {name Gate-M44}
    } {
        wets_class Valve wets_identifier {Name V45} mech_class Motor mech_identifier {name Valve-M45}
    } {
        wets_class Culvert wets_identifier {Name C45} mech_class Flow_Sensor mech_identifier {name Sensor-F45}
    } {
        wets_class Gate wets_identifier {Name G45} mech_class Motor mech_identifier {name Gate-M45}
    } {
        wets_class Valve wets_identifier {Name V46} mech_class Motor mech_identifier {name Valve-M46}
    } {
        wets_class Culvert wets_identifier {Name C46} mech_class Flow_Sensor mech_identifier {name Sensor-F46}
    } {
        wets_class Gate wets_identifier {Name G46} mech_class Motor mech_identifier {name Gate-M46}
    } {
        wets_class Valve wets_identifier {Name V47} mech_class Motor mech_identifier {name Valve-M47}
    } {
        wets_class Culvert wets_identifier {Name C47} mech_class Flow_Sensor mech_identifier {name Sensor-F47}
    } {
        wets_class Gate wets_identifier {Name G47} mech_class Motor mech_identifier {name Gate-M47}
    } {
        wets_class Valve wets_identifier {Name V48} mech_class Motor mech_identifier {name Valve-M48}
    } {
        wets_class Culvert wets_identifier {Name C48} mech_class Flow_Sensor mech_identifier {name Sensor-F48}
    } {
        wets_class Gate wets_identifier {Name G48} mech_class Motor mech_identifier {name Gate-M48}
    } {
        wets_class Valve wets_identifier {Name V49} mech_class Motor mech_identifier {name Valve-M49}
    } {
        wets_class Culvert wets_identifier {Name C49} mech_class Flow_Sensor mech_identifier {name Sensor-F49}
    } {
        wets_class Gate wets_identifier {Name G49} mech_class Motor mech_identifier {name Gate-M49}
    } {
        wets_class Valve wets_identifier {Name V50} mech_class Motor mech_identifier {name Valve-M50}
    } {
        wets_class Culvert wets_identifier {Name C50} mech_class Flow_Sensor mech_identifier {name Sensor-F50}
    } {
        wets_class Gate wets_identifier {Name G50} mech_class Motor mech_identifier {name Gate-M50}
    } {
        wets_class Valve wets_identifier {Name V51} mech_class Motor mech_identifier {name Valve-M51}
    } {
        wets_class Culvert wets_identifier {Name C51} mech_class Flow_Sensor mech_identifier {name Sensor-F51}
    } {
        wets_class Gate wets_identifier {Name G51} mech_class Motor mech_identifier {name Gate-M51}
    } {
        wets_class Valve wets_identifier {Name V52} mech_class Motor mech_identifier {name Valve-M52}
    } {
        wets_class Culvert wets_identifier {Name C52} mech_class Flow_Sensor mech_identifier {name Sensor-F52}
    } {
        wets_class Gate wets_identifier {Name G52} mech_class Motor mech_identifier {name Gate-M52}
    } {
        wets_class Valve wets_identifier {Name V53} mech_class Motor mech_identifier {name Valve-M53}
    } {
        wets_class Culvert wets_identifier {Name C53} mech_class Flow_Sensor mech_identifier {name Sensor-F53}
    } {
        wets_class Gate wets_identifier {Name G53} mech_class Motor mech_identifier {name Gate-M53}
    } {
        wets_class Valve wets_identifier {Name V54} mech_class Motor mech_identifier {name Valve-M54}
    } {
        wets_class Culvert wets_identifier {Name C54} mech_class Flow_Sensor mech_identifier {name Sensor-F54}
    } {
        wets_class Gate wets_identifier {Name G54} mech_class Motor mech_identifier {name Gate-M54}
    } {
        wets_class Valve wets_identifier {Name V55} mech_class Motor mech_identifier {name Valve-M55}
    }
}
