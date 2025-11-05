# test runner for Wet integration test

namespace eval ::test_mgmt {
    set logger [::logger::initNamespace [namespace current]]
    set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
            "colorConsole" : "console"}]
    ::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
            -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}

    namespace import ::ral::*
    namespace import ::ralutil::*

    log::setlevel $::options(level)

    relvar create Test_Case {
        Name string
        Setup list
        Trigger list
        Reset list
        Finalize list
    } {Name}

    relvar insert Test_Case\
        {Name test_1 Setup setup Trigger trigger Reset reset Finalize finalize}

    proc run_test_cases {} {
        relation foreach test_case [relvar set Test_Case] -ascending Name {
            relation assign $test_case
            $Name $Setup
            $Name $Trigger
            $Name $Reset
            $Name $Finalize
        }
    }

    # 1.    Transfer request from a new vessel with no available Transit Lane
    #       Expect an instance of Waiting Vessel to be created
    namespace eval test_1 {
        set logger [::logger::initNamespace [namespace current]]
        set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
                "colorConsole" : "console"}]
        ::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
                -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}

        namespace import ::ral::*
        namespace import ::ralutil::*

        namespace export *
        proc setup {} {
            log::debug [info level 0]

            # To avoid racing the program, set up relvar traces that will be used
            relvar trace add variable ::wets::Assigned_Vessel insert [namespace code sync]

            # The goal is to drive the system to the state where no transit lane
            # is available and a request for a new transfer arrives
            set wets Wets_3 ; # has 1 transit lane, 4 transit gates
            ::vessel_mgmt asyncCreationReceiver Vessel [list License VS-01 Status ready]\
                Start_transfer $wets up

            # wait until the assigned vessel is created
            vwait ::done
            log::info "setup: $::done created"
        }

        proc trigger {} {
            log::debug [info level 0]

            rosea trace control on

            relvar trace add variable ::wets::Waiting_Vessel insert [namespace code sync]
            set wets Wets_3 ; # has 1 transit lane, 4 transit gates
            ::vessel_mgmt asyncCreationReceiver Vessel [list License VS-02 Status ready]\
                Start_transfer $wets up

            # wait until the waiting vessel is created
            vwait ::done
            log::info "trigger: $::done created"

            relvar trace remove variable ::wets::Waiting_Vessel insert [namespace code sync]
        }

        proc reset {} {
            log::debug [info level 0]

            # wait until the VS-02 is assigned
            vwait ::done
            if {$::done eq "VS-02"} {
                log::info "reset: $::done is assigned a transit lane"
            } else {
                error "expected VS-02 to be assigned, got '$::done'"
            }

            relvar trace remove variable ::wets::Assigned_Vessel insert [namespace code sync]

            relvar trace add variable ::wets::Vessel delete [namespace code sync]

            vwait ::done
            log::info "reset: sync to $::done vessel"
            if {$::done eq "VS-02"} {
                log::info "trigger: $::done transfer is completed"
            } else {
                error "expected VS-02 to be assigned, got '$::done'"
            }

            rosea trace control off
        }

        proc finalize {} {
            log::debug [info level 0]

            log::info \n[rosea trace format [rosea trace decode all]]

            rosea trace control clear
        }

        proc sync {ops relvar args} {
            log::debug [info level 0]

            foreach operation $ops {
                switch -exact -- $operation {
                    insert {
                        lassign $args tuple
                        set ::done [tuple extract $tuple License]
                        return $tuple
                    }
                    delete {
                        lassign $args tuple
                        set ::done [tuple extract $tuple License]
                        return
                    }
                    default {
                        log::error "unexpected relvar trace operation: '$operation'"
                    }
                }
            }

        }

        namespace ensemble create
    }
}
