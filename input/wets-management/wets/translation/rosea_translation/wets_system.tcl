#!/usr/bin/env tclsh

package require Tcl 8.6
package require rosea
package require cmdline
package require logger
package require logger::utils
package require logger::appender

set optlist {
    {level.arg notice {Log debug level}}
    {trace {Trace state machine transitions}}
    {rash {Use rash package as a dashboard}}
    {summary {Print state machine transition counts}}
    {tests.arg {*} {List of test cases to run}}
    {timeout.arg {20000} {Synchronization timeout in ms}}
}

try {
    array set options [::cmdline::getoptions argv $optlist]
} on error {result} {
    chan puts -nonewline stderr $result
    exit 1
}

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

if {$::options(rash)} {
    package require rash
    wm withdraw .
    rash init
#    tkwait window .rash
}
if {$::options(trace)} {
    rosea trace control loglevel info
    rosea trace control logon
}
source ./test_mgmt.tcl
::test_mgmt runTestCases $::options(tests)
exit
