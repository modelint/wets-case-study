# test runner for Wet integration test

namespace eval ::test_mgmt {
    set service [string trimleft [namespace current] :]
    set logger [::logger::init $service]
    set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
            "colorConsole" : "console"}]
    ::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
            -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}
    ::logger::import -all -namespace log $service
    log::setlevel $::options(level)

    namespace import ::ral::*
    namespace import ::ralutil::*

    log::setlevel $::options(level)

    # Model
    relvar create Test_Case {
        Name string
        Summary string
    } {Name}

    relvar create Wets_Configuration {
        Name string
        Lane_count int
        Gate_count int
    } {Name}

    relvar create Tested_Configuration {
        Test_case string
        Configuration string
    } {Test_case Configuration}

    relvar create Test_Phase {
        Name string
        Phase_order int
    } {Name} {Phase_order}

    relvar create Test_Section {
        Test_case string
        Configuration string
        Test_phase string
        Test_process string
    } {Test_case Configuration Test_phase}

    relvar create Section_Trace {
        Test_case string
        Configuration string
        Test_phase string
        Trace_number int
    } {Test_case Configuration Test_phase Trace_number}

    relvar create Trace_Composition {
        Test_case string
        Configuration string
        Test_phase string
        Trace_number int
        Trace_spec int
    } {Test_case Configuration Test_phase Trace_number Trace_spec}

    relvar create Trace_Spec {
        Spec_id int
        Domain string
        Class string
        Operation string
        Filters list
    } {Spec_id}

    relvar create Expected_Capture {
        Test_case string
        Configuration string
        Capture_order int
        Result dict
        Trace_spec int
    } {Test_case Configuration Capture_order}

    relvar create Actual_Capture {
        Test_case string
        Configuration string
        Capture_order int
        Result dict
        Trace_spec int
    } {Test_case Configuration Capture_order}

    relvar create Model_State_Transition {
        Domain string
        Class string
        Source_state string
        Target_state string
        Event string
        Transition_count int
    } {Domain Class Source_state Target_state Event}

    # Population
    relvar insert Test_Case\
        {Name test_1 Summary {Vessel waits when no transit lane is available}}\
        {Name test_2 Summary {Vessel proceeds up with the available transit lane as up}}\
        {Name test_3 Summary {Vessel requests up transfer when only down is available}}\
        {Name test_4 Summary {Vessel requests down transfer when only up is available}}\
        {Name test_5 Summary {Vessel requests down transfer when only down is available}}

    relvar insert Wets_Configuration\
        {Name Wets_1 Lane_count 1 Gate_count 2}\
        {Name Wets_2 Lane_count 1 Gate_count 3}\
        {Name Wets_3 Lane_count 1 Gate_count 4}\
        {Name Wets_4 Lane_count 1 Gate_count 2}\
        {Name Wets_5 Lane_count 1 Gate_count 3}\
        {Name Wets_6 Lane_count 1 Gate_count 4}\
        {Name Wets_7 Lane_count 1 Gate_count 2}\
        {Name Wets_8 Lane_count 1 Gate_count 3}\
        {Name Wets_9 Lane_count 1 Gate_count 4}

    relvar insert Tested_Configuration\
        {Test_case test_1 Configuration Wets_1}\
        {Test_case test_1 Configuration Wets_3}\
        {Test_case test_2 Configuration Wets_1}\
        {Test_case test_2 Configuration Wets_4}\
        {Test_case test_3 Configuration Wets_1}\
        {Test_case test_3 Configuration Wets_9}\
        {Test_case test_4 Configuration Wets_1}\
        {Test_case test_5 Configuration Wets_1}

    relvar insert Test_Phase\
        {Name Setup Phase_order 0}\
        {Name Trigger Phase_order 1}\
        {Name Reset Phase_order 2}\
        {Name Finalize Phase_order 3}

    relvar insert Test_Section\
        {Test_case test_1 Configuration Wets_1 Test_phase Setup Test_process setup}\
        {Test_case test_1 Configuration Wets_1 Test_phase Trigger Test_process trigger}\
        {Test_case test_1 Configuration Wets_1 Test_phase Reset Test_process reset}\
        {Test_case test_1 Configuration Wets_1 Test_phase Finalize Test_process finalize}\
        \
        {Test_case test_1 Configuration Wets_3 Test_phase Setup Test_process setup}\
        {Test_case test_1 Configuration Wets_3 Test_phase Trigger Test_process trigger}\
        {Test_case test_1 Configuration Wets_3 Test_phase Reset Test_process reset}\
        {Test_case test_1 Configuration Wets_3 Test_phase Finalize Test_process finalize}\
        \
        {Test_case test_2 Configuration Wets_1 Test_phase Trigger Test_process trigger}\
        {Test_case test_2 Configuration Wets_1 Test_phase Reset Test_process reset}\
        \
        {Test_case test_2 Configuration Wets_4 Test_phase Trigger Test_process trigger}\
        {Test_case test_2 Configuration Wets_4 Test_phase Reset Test_process reset}\
        \
        {Test_case test_3 Configuration Wets_1 Test_phase Setup Test_process setup}\
        {Test_case test_3 Configuration Wets_1 Test_phase Trigger Test_process trigger}\
        {Test_case test_3 Configuration Wets_1 Test_phase Reset Test_process reset}\
        {Test_case test_3 Configuration Wets_1 Test_phase Finalize Test_process finalize}\
        \
        {Test_case test_3 Configuration Wets_9 Test_phase Setup Test_process setup}\
        {Test_case test_3 Configuration Wets_9 Test_phase Trigger Test_process trigger}\
        {Test_case test_3 Configuration Wets_9 Test_phase Reset Test_process reset}\
        {Test_case test_3 Configuration Wets_9 Test_phase Finalize Test_process finalize}\
        \
        {Test_case test_4 Configuration Wets_1 Test_phase Setup Test_process setup}\
        {Test_case test_4 Configuration Wets_1 Test_phase Trigger Test_process trigger}\
        {Test_case test_4 Configuration Wets_1 Test_phase Reset Test_process reset}\
        {Test_case test_4 Configuration Wets_1 Test_phase Finalize Test_process finalize}\
        \
        {Test_case test_5 Configuration Wets_1 Test_phase Setup Test_process setup}\
        {Test_case test_5 Configuration Wets_1 Test_phase Trigger Test_process trigger}\
        {Test_case test_5 Configuration Wets_1 Test_phase Reset Test_process reset}\
        {Test_case test_5 Configuration Wets_1 Test_phase Finalize Test_process finalize}

    relvar insert Section_Trace\
        {Test_case test_1 Configuration Wets_1 Test_phase Setup Trace_number 0}\
        {Test_case test_1 Configuration Wets_1 Test_phase Trigger Trace_number 0}\
        {Test_case test_1 Configuration Wets_1 Test_phase Reset Trace_number 0}\
        {Test_case test_1 Configuration Wets_1 Test_phase Reset Trace_number 1}\
        \
        {Test_case test_1 Configuration Wets_3 Test_phase Setup Trace_number 0}\
        {Test_case test_1 Configuration Wets_3 Test_phase Trigger Trace_number 0}\
        {Test_case test_1 Configuration Wets_3 Test_phase Reset Trace_number 0}\
        {Test_case test_1 Configuration Wets_3 Test_phase Reset Trace_number 1}\
        \
        {Test_case test_2 Configuration Wets_1 Test_phase Trigger Trace_number 0}\
        {Test_case test_2 Configuration Wets_1 Test_phase Reset Trace_number 0}\
        \
        {Test_case test_2 Configuration Wets_4 Test_phase Trigger Trace_number 0}\
        {Test_case test_2 Configuration Wets_4 Test_phase Reset Trace_number 0}\
        \
        {Test_case test_3 Configuration Wets_1 Test_phase Trigger Trace_number 0}\
        {Test_case test_3 Configuration Wets_1 Test_phase Reset Trace_number 0}\
        \
        {Test_case test_3 Configuration Wets_9 Test_phase Trigger Trace_number 0}\
        {Test_case test_3 Configuration Wets_9 Test_phase Reset Trace_number 0}\
        \
        {Test_case test_4 Configuration Wets_1 Test_phase Trigger Trace_number 0}\
        {Test_case test_4 Configuration Wets_1 Test_phase Reset Trace_number 0}\
        \
        {Test_case test_5 Configuration Wets_1 Test_phase Trigger Trace_number 0}\
        {Test_case test_5 Configuration Wets_1 Test_phase Reset Trace_number 0}

    relvar insert Trace_Composition\
        {Test_case test_1 Configuration Wets_1 Test_phase Setup Trace_number 0 Trace_spec 0}\
        {Test_case test_1 Configuration Wets_1 Test_phase Trigger Trace_number 0 Trace_spec 1}\
        {Test_case test_1 Configuration Wets_1 Test_phase Reset Trace_number 0 Trace_spec 0}\
        {Test_case test_1 Configuration Wets_1 Test_phase Reset Trace_number 1 Trace_spec 2}\
        \
        {Test_case test_1 Configuration Wets_3 Test_phase Setup Trace_number 0 Trace_spec 0}\
        {Test_case test_1 Configuration Wets_3 Test_phase Trigger Trace_number 0 Trace_spec 1}\
        {Test_case test_1 Configuration Wets_3 Test_phase Reset Trace_number 0 Trace_spec 0}\
        {Test_case test_1 Configuration Wets_3 Test_phase Reset Trace_number 1 Trace_spec 2}\
        \
        {Test_case test_2 Configuration Wets_1 Test_phase Trigger Trace_number 0 Trace_spec 0}\
        {Test_case test_2 Configuration Wets_1 Test_phase Reset Trace_number 0 Trace_spec 2}\
        \
        {Test_case test_2 Configuration Wets_4 Test_phase Trigger Trace_number 0 Trace_spec 0}\
        {Test_case test_2 Configuration Wets_4 Test_phase Reset Trace_number 0 Trace_spec 2}\
        \
        {Test_case test_3 Configuration Wets_1 Test_phase Trigger Trace_number 0 Trace_spec 0}\
        {Test_case test_3 Configuration Wets_1 Test_phase Reset Trace_number 0 Trace_spec 2}\
        \
        {Test_case test_3 Configuration Wets_9 Test_phase Trigger Trace_number 0 Trace_spec 0}\
        {Test_case test_3 Configuration Wets_9 Test_phase Reset Trace_number 0 Trace_spec 2}\
        \
        {Test_case test_4 Configuration Wets_1 Test_phase Trigger Trace_number 0 Trace_spec 0}\
        {Test_case test_4 Configuration Wets_1 Test_phase Reset Trace_number 0 Trace_spec 2}\
        \
        {Test_case test_5 Configuration Wets_1 Test_phase Trigger Trace_number 0 Trace_spec 0}\
        {Test_case test_5 Configuration Wets_1 Test_phase Reset Trace_number 0 Trace_spec 2}

    relvar insert Trace_Spec\
        {Spec_id 0 Domain wets Class Assigned_Vessel Operation insert Filters License}\
        {Spec_id 1 Domain wets Class Waiting_Vessel Operation insert Filters License}\
        {Spec_id 2 Domain wets Class Vessel Operation delete Filters License}

    relvar insert Expected_Capture\
        {Test_case test_1 Configuration Wets_1 Capture_order 1 Result {License VS-00} Trace_spec 0}\
        {Test_case test_1 Configuration Wets_1 Capture_order 2 Result {License VS-99} Trace_spec 1}\
        {Test_case test_1 Configuration Wets_1 Capture_order 3 Result {License VS-00} Trace_spec 2}\
        {Test_case test_1 Configuration Wets_1 Capture_order 4 Result {License VS-99} Trace_spec 0}\
        {Test_case test_1 Configuration Wets_1 Capture_order 5 Result {License VS-99} Trace_spec 2}\
        \
        {Test_case test_1 Configuration Wets_3 Capture_order 1 Result {License VS-00} Trace_spec 0}\
        {Test_case test_1 Configuration Wets_3 Capture_order 2 Result {License VS-99} Trace_spec 1}\
        {Test_case test_1 Configuration Wets_3 Capture_order 3 Result {License VS-00} Trace_spec 2}\
        {Test_case test_1 Configuration Wets_3 Capture_order 4 Result {License VS-99} Trace_spec 0}\
        {Test_case test_1 Configuration Wets_3 Capture_order 5 Result {License VS-99} Trace_spec 2}\
        \
        {Test_case test_2 Configuration Wets_1 Capture_order 1 Result {License VS-00} Trace_spec 0}\
        {Test_case test_2 Configuration Wets_1 Capture_order 2 Result {License VS-00} Trace_spec 2}\
        \
        {Test_case test_2 Configuration Wets_4 Capture_order 1 Result {License VS-00} Trace_spec 0}\
        {Test_case test_2 Configuration Wets_4 Capture_order 2 Result {License VS-00} Trace_spec 2}\
        \
        {Test_case test_3 Configuration Wets_1 Capture_order 1 Result {License VS-00} Trace_spec 0}\
        {Test_case test_3 Configuration Wets_1 Capture_order 2 Result {License VS-00} Trace_spec 2}\
        \
        {Test_case test_3 Configuration Wets_9 Capture_order 1 Result {License VS-00} Trace_spec 0}\
        {Test_case test_3 Configuration Wets_9 Capture_order 2 Result {License VS-00} Trace_spec 2}\
        \
        {Test_case test_4 Configuration Wets_1 Capture_order 1 Result {License VS-00} Trace_spec 0}\
        {Test_case test_4 Configuration Wets_1 Capture_order 2 Result {License VS-00} Trace_spec 2}\
        \
        {Test_case test_5 Configuration Wets_1 Capture_order 1 Result {License VS-00} Trace_spec 0}\
        {Test_case test_5 Configuration Wets_1 Capture_order 2 Result {License VS-00} Trace_spec 2}


    # Associations
    relvar association R1\
        Expected_Capture {Test_case Configuration} +\
        Tested_Configuration {Test_case Configuration} 1
    relvar association R9\
        Actual_Capture {Test_case Configuration} *\
        Tested_Configuration {Test_case Configuration} 1
    relvar correlation R3 Tested_Configuration\
        Test_case + Test_Case Name\
        Configuration * Wets_Configuration Name
    relvar correlation R5 Test_Section\
        {Test_case Configuration} + Tested_Configuration {Test_case Configuration}\
        {Test_phase} * Test_Phase {Name}
    relvar association R6\
        Section_Trace {Test_case Configuration Test_phase} *\
        Test_Section {Test_case Configuration Test_phase} 1
    relvar correlation R7 Trace_Composition\
        {Test_case Configuration Test_phase Trace_number} +\
            Section_Trace {Test_case Configuration Test_phase Trace_number}\
        Trace_spec + Trace_Spec Spec_id
    relvar association R11\
        Actual_Capture Trace_spec * Trace_Spec Spec_id 1
    relvar association R12\
        Expected_Capture Trace_spec + Trace_Spec Spec_id 1


    proc runTestCases {} {
        set passed_tests 0
        set failed_tests 0

        rosea trace control clear
        rosea trace control on

        # Loop over all test cases
        relation foreach test_case [relvar set Test_Case] {
            # Loop over all the configurations for the test
            set configs [pipe {
                relvar set Tested_Configuration |
                relation semijoin $test_case ~ -using {Name Test_case}
            }]
            relation foreach config $configs {
                # Loop over all test phases
                set test_phases [pipe {
                    relvar set Test_Phase |
                    relation join $config ~ |
                    relation rename ~ Name Test_phase
                }] ; # heading is Test_case / Configuration / Test_phase / Phase_order

                relation foreach test_phase $test_phases -ascending Phase_order {
                    set sections [pipe {
                        relvar set Test_Section |
                        relation join $test_phase ~
                    }]

                    relation foreach section $sections -ascending Phase_order {
                        relation assign $section\
                            {Test_case test_case} {Configuration configuration} {Test_phase test_phase}
                        # Install the traces for the phase
                        installPhaseTraces $test_case $configuration $test_phase add
                        # Execute the phase processing
                        set section_cmd [join [relation extract $section Test_case Test_process] ::]
                        $section_cmd {*}[relation extract $section Test_case Configuration Test_phase]
                        # Uninstall the traces for the phase
                        installPhaseTraces $test_case $configuration $test_phase remove
                    }
                }

                # After each test case is run on a configuration, evaluate results
                relation assign $config {Configuration configuration}
                set expected [pipe {
                    relvar set Expected_Capture |
                    relation restrictwith ~ {$Test_case eq $test_case && $Configuration eq $configuration}
                }]
                log::debug \n[relformat $expected {Expected Capture}]
                set actual [pipe {
                    relvar set Actual_Capture |
                    relation restrictwith ~ {$Test_case eq $test_case && $Configuration eq $configuration}
                }]
                log::debug \n[relformat $actual {Actual Capture}]

                if {[relation is $expected == $actual]} {
                    log::notice "PASSED: $test_case / $configuration"
                    incr passed_tests
                } else {
                    log::warn "FAILED: $test_case / $configuration"
                    log::warn \n[relformat $expected {Expected Capture}]
                    log::warn \n[relformat $actual {Actual Capture}]
                    incr failed_tests
                }

                clearResults
            }
        }
        rosea trace control off

        if {$failed_tests == 0} {
            log::notice "PASSED: ALL"
        } else {
            log::notice "FAILED: $failed_tests tests"
        }

        reportModelCoverage
    }
    namespace export runTestCases

    proc installPhaseTraces {test_case configuration test_phase trace_op} {
        set traces [pipe {
            relvar set Trace_Composition |
            relation restrictwith ~ {\
                $Test_case eq $test_case &&\
                $Configuration eq $configuration &&\
                $Test_phase eq $test_phase} |
            relation join ~ [relvar set Trace_Spec] -using {Trace_spec Spec_id}
        }]
        log::debug "[info level 0]:\n[relformat $traces {traces to install}]"

        relation foreach trace $traces -ascending Trace_number {
            relation assign $trace Domain Class Operation Filters Trace_spec
            relvar trace $trace_op variable ::${Domain}::${Class} $Operation\
                [namespace code "sync $test_case $configuration $Trace_spec $Filters"]
        }
    }

    variable capture_order 0

    proc postResult {test_case configuration trace_spec result} {
        variable capture_order

        set order [incr capture_order]
        relvar insert Actual_Capture [list\
            Test_case $test_case\
            Configuration $configuration\
            Capture_order $order\
            Result $result\
            Trace_spec $trace_spec\
        ]
    }

    proc clearResults {} {
        variable capture_order
        set capture_order 0

        relvar set Actual_Capture [relation emptyof [relvar set Actual_Capture]]
    }

    proc reportModelCoverage {} {
        # Initialize the transition counts to zero
        # Note we build up the State_Model_Transition instances at run time
        # using introspection.
        set domain wets
        foreach class [rosea info domain classes $domain] {
            set transitions [rosea info statemodel transitions $domain $class]
            dict for {source_state state_trans} $transitions {
                dict for {event target_state} $state_trans {
                    if {$target_state ni {CH IG}} {
                        relvar insert Model_State_Transition [list\
                            Domain $domain\
                            Class $class\
                            Source_state $source_state\
                            Target_state $target_state\
                            Event $event\
                            Transition_count 0\
                        ]
                    }
                }
            }
        }

        # Decode all the collected traces. Filter them by requiring the
        # target to be a class in the "wets" domain. Count the number of
        # times the transition is taken.
        foreach trace [rosea trace decode all] {
            if {[dict get $trace type] ne "transition"} {
                continue
            }

            set target [dict get $trace target]
            set qual_target_class [lindex $target 0]
            set target_class [namespace tail $qual_target_class]
            set target_domain [string trimleft [namespace qualifiers $qual_target_class] ::]
            if {$target_domain ne $domain} {
                continue
            }

            relvar updateone Model_State_Transition mst [list\
                Domain $domain\
                Class $target_class\
                Source_state [dict get $trace current]\
                Target_state [dict get $trace new]\
                Event [dict get $trace event]\
            ] {tuple update $mst Transition_count [expr {[tuple extract $mst Transition_count] + 1}]}
        }
        log::notice \n[relformat [relvar set Model_State_Transition] "Wets Domain Transition Counts"]

        # Find any transition _not_ taken
        set not_taken [pipe {
            relvar set Model_State_Transition |
            relation restrictwith ~ {$Transition_count == 0}
        }]
        if {[relation isempty $not_taken]} {
            log::notice "PASSED: all state machine transitions taken"
        } else {
            log::error "FAILED: transitions not taken:\n[relformat $not_taken {Wets Domain Transitions Not Taken}]"
        }
    }

    proc sync {test_case configuration trace_spec filters ops relvar args} {
        log::debug [info level 0]
        lassign $args tuple
        set operation [lindex $ops 0]
        set trace_op [pipe {
            relvar restrictone Trace_Spec Spec_id $trace_spec |
            relation extract ~ Operation
        }]
        if {$operation ne $trace_op} {
            set msg "expected operation: '$trace_op', got: '$operation'"
            log::error $msg
            throw UNEXPECTED_OPERATION $msg
        }
        set attr_values [tuple get $tuple]
        postResult\
            $test_case\
            $configuration\
            $trace_spec\
            [dict filter $attr_values key {*}$filters]
        set ::done $attr_values
        return [expr {$operation eq "insert" ? $tuple : {}}]
    }

    proc waitForSync {} {
        set timer [after $::options(timeout) {set ::done TIMEOUT}]
        vwait ::done
        after cancel $timer

        if {$::done eq "TIMEOUT"} {
            throw SYNC_TIMEOUT "synchronization timeout after $::options(timeout) ms"
        }
        log::debug "synchronization value: '$::done'"

        return $::done
    }
    namespace export waitForSync

    namespace ensemble create

    source ./test_1.tcl
    source ./test_2.tcl
    source ./test_3.tcl
    source ./test_4.tcl
    source ./test_5.tcl
}
