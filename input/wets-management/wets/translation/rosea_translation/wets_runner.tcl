#!/usr/bin/env tclsh

package require Tcl 8.6
package require rosea
package require cmdline
package require logger
package require logger::utils
package require logger::appender

namespace import ::ral::*
namespace import ::ralutil::*

set optlist {
    {level.arg notice {Log debug level}}
    {trace {Trace state machine transitions}}
    {rash {Use rash package as dashboard}}
    {seed.arg {} {Initial random number generator seed}}
    {mintime.arg {3000} {Minimum time between vessel requests}}
    {maxtime.arg {8000} {Maximum time between vessel requests}}
    {randomize {Randomize timings for vessel, gate, valve, etc. simulations}}
}

try {
    array set options [::cmdline::getoptions argv $optlist]
} on error {result} {
    chan puts -nonewline stderr $result
    exit 1
}

set logger [::logger::init runner]
set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
        "colorConsole" : "console"}]
::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
        -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}
::logger::import -all -namespace log runner

log::setlevel $::options(level)

namespace eval ::wets {
    set logger [::logger::initNamespace [namespace current]]
    set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
            "colorConsole" : "console"}]
    ::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
            -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}

    log::setlevel $::options(level)
}

namespace eval ::mechanical_mgmt {
    set logger [::logger::initNamespace [namespace current]]
    set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
            "colorConsole" : "console"}]
    ::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
            -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}

    log::setlevel $::options(level)
}

namespace eval ::vessel_mgmt {
    set logger [::logger::initNamespace [namespace current]]
    set appenderType [expr {[dict exist [fconfigure stdout] -mode] ?\
            "colorConsole" : "console"}]
    ::logger::utils::applyAppender -appender $appenderType -serviceCmd $logger\
            -appenderArgs {-conversionPattern {\[%c\] \[%p\] '%m'}}

    log::setlevel $::options(level)
}

set ::vessel_num 0

proc genRandomVesselRequest {} {
    set configurations [shuffle [list 1 2 3 4 5 6 7 8 9]]
    foreach config $configurations {
        set backlog [getWaitingBacklog Wets_${config}]
        if {$backlog < 3} {
            set license [format "VS-%04d" $::vessel_num]
            set ::vessel_num [expr {($::vessel_num + 1) % 10000}]
            set direction [expr {[randomInRange 0 1] == 0 ? "up" : "down"}]
            set configuration [format "Wets_%d" $config]
            ::vessel_mgmt asyncCreationReceiver Vessel [list\
                License $license\
                Randomize_timing [expr {$::options(randomize) ? "true" : "false"}]\
            ] Start_transfer $configuration $direction
        }
    }

    after [randomInRange $::options(mintime) $::options(maxtime)] genRandomVesselRequest
}

proc getWaitingBacklog {wets} {
    return [pipe {
        relvar set ::wets::Waiting_Vessel |
        relation restrictwith ~ {$Wets eq $wets} |
        relation cardinality ~
    }]
}

proc randomInRange {min max} {
    return [expr {int(rand() * ($max - $min + 1)) + $min}]
}

proc shuffle {list} {
    set n [llength $list]
    for {set i 1} {$i < $n} {incr i} {
        set j [expr {int(rand() * $n)}]
        set temp [lindex $list $i]
        lset list $i [lindex $list $j]
        lset list $j $temp
    }
    return $list
}

source ./wets.tcl
source ./mechanical_mgmt.tcl
source ./vessel_mgmt.tcl
source ./wets_bridge.tcl

rosea configure {
    domain wets $::wets
    domain mechanical_mgmt $::mechanical_mgmt
    domain vessel_mgmt $::vessel_mgmt
}
rosea generate
rosea populate {
    domain wets $::wets_pop
    domain mechanical_mgmt $::mechanical_mgmt_pop
}

if {$::options(seed) != {}} {
    expr srand($::options(seed))
}

if {$::options(rash)} {
    package require rash
    wm withdraw .
    rash init
    # tkwait window .rash
} elseif {$::options(trace)} {
    rosea trace control loglevel info
    rosea trace control logon
    rosea trace control on
}

if {$::options(randomize)} {
    ::mechanical_mgmt randomizeTiming
}

genRandomVesselRequest

vwait forever
