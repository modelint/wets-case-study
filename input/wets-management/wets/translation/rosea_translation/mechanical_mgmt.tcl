# Rosea translation of the mechical management domain.
# This domain handles the mechanical aspects of the WETS system
# such as gates, valves, and culvert flow sensors

set ::mechanical_mgmt {
    class Motor {
        attribute name string -id 1
        attribute run_time int -default 100 ; # milliseconds
        attribute transfer_vector list -default [list]

        statemodel {
            initialstate In

            state In {} {
                wormhole MM1_motor_extent_reached [readAttribute $self transfer_vector]
            }
            transition In - run_in -> In
            transition In - run_out -> Running_Out

            state Running_Out {transfer_vector} {
                updateAttribute $self transfer_vector $transfer_vector
                delaysignal [readAttribute $self run_time] $self extent_reached
            }
            transition Running_Out - extent_reached -> Out
            transition Running_Out - run_out -> IG

            state Out {} {
                wormhole MM1_motor_extent_reached [readAttribute $self transfer_vector]
            }
            transition Out - run_out -> Out
            transition Out - run_in -> Running_In

            state Running_In {transfer_vector} {
                updateAttribute $self transfer_vector $transfer_vector
                delaysignal [readAttribute $self run_time] $self extent_reached
            }
            transition Running_In - extent_reached -> In
            transition Running_In - run_in -> IG
        }
    }

    class Flow_Sensor {
        attribute name string -id 1
        attribute delay_time int -default 100 ; # milliseconds
        attribute transfer_vector list -default [list]

        statemodel {
            initialstate Idle

            state Idle {} {
                # W5_zero_flow_sensed sensor_name transfer_vector
                wormhole MM2_zero_flow_sensed [readAttribute $self transfer_vector]

            }
            transition Idle - monitor -> Sensing
            transition Idle - flow_zero -> IG

            state Sensing {transfer_vector} {
                updateAttribute $self transfer_vector $transfer_vector
                delaysignal [readAttribute $self delay_time] $self flow_zero
            }
            transition Sensing - flow_zero -> Idle
            transition Sensing - monitor -> IG
        }
    }

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

set ::mechanical_mgmt_pop {
    class Motor {
        name    } {
        Gate-M01
        Gate-M02
        Gate-M03
        Gate-M04
        Gate-M05
        Gate-M06
        Gate-M07
        Gate-M08
        Gate-M09
        Gate-M10
        Gate-M11
        Gate-M12
        Gate-M13
        Gate-M14
        Gate-M15
        Gate-M16
        Gate-M17
        Gate-M18
        Gate-M19
        Gate-M20
        Gate-M21
        Gate-M22
        Gate-M23
        Gate-M24
        Gate-M25
        Gate-M26
        Gate-M27
        Gate-M28
        Gate-M29
        Gate-M30
        Gate-M31
        Gate-M32
        Gate-M33
        Gate-M34
        Gate-M35
        Gate-M36
        Gate-M37
        Gate-M38
        Gate-M39
        Gate-M40
        Gate-M41
        Gate-M42
        Gate-M43
        Gate-M44
        Gate-M45
        Gate-M46
        Gate-M47
        Gate-M48
        Gate-M49
        Gate-M50
        Gate-M51
        Gate-M52
        Gate-M53
        Gate-M54
        Valve-M01
        Valve-M02
        Valve-M03
        Valve-M04
        Valve-M05
        Valve-M06
        Valve-M07
        Valve-M08
        Valve-M09
        Valve-M10
        Valve-M11
        Valve-M12
        Valve-M13
        Valve-M14
        Valve-M15
        Valve-M16
        Valve-M17
        Valve-M18
        Valve-M19
        Valve-M20
        Valve-M21
        Valve-M22
        Valve-M23
        Valve-M24
        Valve-M25
        Valve-M26
        Valve-M27
        Valve-M28
        Valve-M29
        Valve-M30
        Valve-M31
        Valve-M32
        Valve-M33
        Valve-M34
        Valve-M35
        Valve-M36
        Valve-M37
        Valve-M38
        Valve-M39
        Valve-M40
        Valve-M41
        Valve-M42
        Valve-M43
        Valve-M44
        Valve-M45
        Valve-M46
        Valve-M47
        Valve-M48
        Valve-M49
        Valve-M50
        Valve-M51
        Valve-M52
        Valve-M53
        Valve-M54
    }
    class Flow_Sensor {
        name    } {
        Sensor-F01
        Sensor-F02
        Sensor-F03
        Sensor-F04
        Sensor-F05
        Sensor-F06
        Sensor-F07
        Sensor-F08
        Sensor-F09
        Sensor-F10
        Sensor-F11
        Sensor-F12
        Sensor-F13
        Sensor-F14
        Sensor-F15
        Sensor-F16
        Sensor-F17
        Sensor-F18
        Sensor-F19
        Sensor-F20
        Sensor-F21
        Sensor-F22
        Sensor-F23
        Sensor-F24
        Sensor-F25
        Sensor-F26
        Sensor-F27
        Sensor-F28
        Sensor-F29
        Sensor-F30
        Sensor-F31
        Sensor-F32
        Sensor-F33
        Sensor-F34
        Sensor-F35
        Sensor-F36
        Sensor-F37
        Sensor-F38
        Sensor-F39
        Sensor-F40
        Sensor-F41
        Sensor-F42
        Sensor-F43
        Sensor-F44
        Sensor-F45
        Sensor-F46
        Sensor-F47
        Sensor-F48
        Sensor-F49
        Sensor-F50
        Sensor-F51
        Sensor-F52
        Sensor-F53
        Sensor-F54
    }
}
