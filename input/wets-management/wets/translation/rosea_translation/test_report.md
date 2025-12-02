---
title: Wets Domain Integration Test Report
author: Andrew Mangogna
date: 2025-12-01
tcl:
   eval: 1
   echo: 0
dot:
    app: dot
    ext: png
    eval: 1
    echo: 0
---

# Introduction

```{.tcl results=hide}
# eg, needsUpdate foo.png foo.uxf
proc needsUpdate {dep_file indep_file} {
    set dep_mtime [expr {[file exists $dep_file] ? [file mtime $dep_file] : 0}]
    set indep_mtime [file mtime $indep_file]
    return [expr {($indep_mtime > $dep_mtime) ? "true" : "false"}]
}

proc convertUmletFile {input output {format png}} {
    exec -- umlet -action=convert -format=$format -filename=$input -output=$output > /dev/null
}
```

This document contains a report on an integration test suite for the
[Wets domain](https://github.com/modelint/wets-case-study).
The Wets domain models the actions of canal locks as might be found
on a river.
The domain model was produced by Michael Lee as part of a case study project.
This document shows how the translated Wets domain was tested in a simulated
environment.

The Wets domain model was translated using
[Rosea](https://repos.modelrealization.com/cgi-bin/fossil/mrtools/wiki?name=RoseaPage).
Rosea is a Tcl based model execution environment.
Three other domains were constructed to complete the testing environment:

* The Mechanical Management domain provides services to the Wets domain for manipulating
    the gates, valves and flow sensors that are used to operate a lock.
* The Vessel Management domain provides services to request vessels to be transfer up
    or down the lock.
* The Test Management Domain orchestrates the running of the
    [test cases](https://github.com/modelint/wets-case-study/wiki/Testing-Considerations).

The following diagram shows a domain chart of the testing environment.

```{.dot label=testing_domains fig=true}
digraph Testing_Domains {
    "Test Management" -> "Vessel Management"
    "Vessel Management" -> Wets
    Wets -> "Mechanical Management"
}
```

The Testing Management domain requires the Vessel Management domain to
make requests to transfer the vessels used for the various test cases.
The Vessel Management domain requires the Wets domain to sequence the
necessary controls to cause the requested vessel transfers to happen.
The Wets domain requires the Vessel Management domain to move vessels
between chambers in the lock.
The Wets domain requires the Mechanical Management domain to operate
the physical gates, values, and flow sensors to effect a transfer.

## Test Management Domain

The Test Management domain is a realized domain.
It is constructed using [TclRAL](https://repos.modelrealization.com/cgi-bin/fossil/tclral/index).
Since Rosea is implemented using TclRAL, a plain TclRAL implementation of Test Management
easily interoperates with the Wets integration test environment.
The Wets integration test environment is unaware of the Test Management domain and no
special considerations were necessary to have the Test Management domain monitor and
interact with the Rosea domain translations.

The following figure shows a class model for the Test Management Domain:

```{.tcl results="asis"}
if {[needsUpdate ./images/test_mgmt_cm.png ./test_mgmt_cm.uxf]} {
    convertUmletFile ./test_mgmt_cm.uxf ./images/test_mgmt_cm
}
return {![Test Management Class Model](./images/test_mgmt_cm.png)}
```

The fundamental mechanism the Test Management domain uses to track the execution
is the _relvar trace_ facilities of TclRAL.
Since the other domains are Rosea translations and since Rosea uses TclRAL relvars
to store classes, the Test Management domain can use relvar tracing to keep track
of the high order execution of the domains.
This mechanism also works for trace state transitions, since Rosea stores the
current state of class instances in a relvar.

The Test Managment domain considers the 11 test cases outlined in the _Testing Considerations_
document and applies them to the 9 configurations of Wets classes also defined in the
_Testing Considerations_ document (*R3*).
Each test run of a *Tested Configuration* is divided into one or more phases.
The phases are:

Setup
: The setup phase establishes the pre-conditions for the test.

Trigger
: The trigger phase executes the necessary interactions with the modeled domains
    to cause the test to run.

Reset
: The reset phase causes the domains to complete any outstanding transfers and to
    cause the system to return to statis.

Finalize
: The finalize phase performs any remaining detailed work to ensure the
    system is in its original state.

For each test and each phase, there is specific code that executes to accomplish
the goals of that phase.
The Test Management domain will add relvar traces before the phase specific code executes
and remove those traces at the end of the section.
The details of the relvar traces are specified and an expected result based on the
trace is also specified.
During test execution, the actual trace capture result is recorded.
A test passes when the specified expected capture result matches the actual one.

## Vessel Management Domain

The Vessel Management domain consists of only a single class, Vessel.
An instance of Vessel is created each time a transfer request is made
to the Wets domain.

### Vessel Class State Model

The following figure shows the state model of the Vessel class.

```{.dot label=Vessel}
digraph Vessel {
    node[shape=box]
    psi [label="", shape="circle", width="0.25"]
    psi -> Requesting_Transfer [label=Start_transfer]
    Requesting_Transfer -> Requesting_Transfer [label=Start_transfer]
    Requesting_Transfer -> Waiting_To_Move [label=Request_granted]
    Requesting_Transfer -> Transfer_Aborted [label=Request_denied]

    Waiting_To_Move -> Moving [label=Move_through_gate]
    Waiting_To_Move -> Canceling [label=Cancel_transfer]
    Waiting_To_Move -> Duplicate_Request [label=Start_transfer]

    Moving -> Move_Completed [label=Passed_gate]

    Move_Completed -> Moving [label=Move_through_gate]
    Move_Completed -> Transfer_Completed [label=Transfer_complete]

    Duplicate_Request -> Waiting_To_Move [label=Request_denied]

    Transfer_Completed -> terminal
    Transfer_Aborted -> terminal
    Transfer_Removed -> terminal

    Canceling -> Transfer_Removed [label=Request_granted]
    Canceling -> Waiting_To_Move [label=Request_denied]

    terminal[label="", shape="point", bg_color="black", width="0.25"]
}
```

The usual path through the state model is to asynchronously create a Vessel instance
with the _Start transfer_ creation event.
The request is granted unless there is a conflict with the Vessel identifier.
The Vessel instance then waits to fulfill move requests that appear as
_Move through gate_ events.
The movement is simulated with a delayed event and eventually the
_Passed gate_ event is signaled.
The machine bounces back and forth between the *Moving* and *Move Completed* state until
the Wets domain completes the transfer, which is indicated by the *Transfer complete* event.
Being a terminal state, the Vessel instance is deleted when the *Transfer complete* event
is received.

The remainder of the states and transitions in the Vessel state model are used to
test cancelation and duplication of Vessel transfer requests.
These states are necessary since separate granted and denied events are signaled as
a result of any request made of the Wets domain.

## Mechanical Management Domain

The Mechanical Management domain contains two classes:

Motor
: is an abstraction of an electric motor.
    A Motor is used to open and close mechanical devices.
    It is assumed that the Motor is attached to the necessary gears to
    accomplish the motion intended.
    The Motor is run in two direction. Running the Motor _out_ opens
    the attached device.
    Running the Motor _in_ closes it.
    Implicitly, the Motor has a mechanism to signal when when it
    has reached its furthest extent of running in either direction.
    The Mechanical Management domain uses Motors to open and close
    the lock gates and to open and close the culvert valves between chambers.

Flow Sensor
: is an abstraction of a transducer that can register fluid flow.
    The Flow Sensor is a simple transducer used to determine if there is
    any water flow between two chambers through their connecting culvert.

### Motor Class State Model

The following figure shows the state model of the Motor class.

```{.dot label=Motor}
digraph Motor {
    node[shape=box]
    init [label="", shape="circle", width="0.25"]
    init -> In

    In -> In [label=run_in]
    In -> Running_Out [label=run_out]

    Running_Out -> Out [label=extent_reached]

    Out -> Out [label=run_out]
    Out -> Running_In [label=run_in]

    Running_In -> In [label=extent_reached]
}
```

### Flow Sensor State Model

The following figure shows the state model of the Flow Sensor class.

```{.dot label=Flow_Sensor}
digraph Flow_Sensor {
    node[shape=box]
    init [label="", shape="circle", width="0.25"]
    init -> Idle

    Idle -> Sensing [label=" monitor  "]
    Sensing -> Idle [label=" flow_zero  "]
}
```

## Test Results

The follow is a report generated by the test script:

```{.cmd results="show" eval=true echo=false}
cat ./wets_system.log | fold -s -w 70
```
