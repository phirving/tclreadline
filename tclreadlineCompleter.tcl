#!/usr/locanl/bin/tclsh
# FILE: "/diska/home/joze/src/tclreadline/tclreadlineCompleter.tcl"
# LAST MODIFICATION: "Wed Sep  8 17:30:20 1999 (joze)"
# (C) 1998, 1999 by Johannes Zellner, <johannes@zellner.org>
# $Id$
# ---
#
# tclreadline -- gnu readline for tcl
# Copyright (C) 1999  Johannes Zellner
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# johannes@zellner.org
# http://www.zellner.org/tclreadline/
#
# ================================================================== 

# done:
#
# - append
# - array
# - bgerror
# - binary
# - break
# - catch
# - cd
# - clock
# - close
# - concat
# - continue
# - (ddd is only on M$)
# - encoding
# - eof
# - error
# - eval
# - exec
# - exit
# - expr
# - fblocked
# - fconfigure
# - fcopy
# - file
# - fileevent
# - flush
# - for # TODO
# - foreach # TODO
# - format # TODO
# - gets
# - glob
# - global
# - if # TODO
# - incr
# - index
# - info
# - interp
# - join
# - lappend
# - llength
# - linsert
# - list
# - load
# - lrange
# - lreplace
# - lsearch
# - lsort
# - history
# - load
# - namespace
# - open
# - package
# - pkg_mkIndex
# - proc
# - puts
# - pwd
# - pid
# - read
# - regexp
# - (registry is only on M$)
# - regsub
# - rename
# - (resource is on mac only)
# - return
# - scan # TODO
# - seek
# - socket
# - source
# - split # TODO
# - string
# - subst
# - switch
# - tell
# - time # TODO ??
# - trace
# - set
# - unknown
# - unset
# - update
# - uplevel
# - upvar
# - variable
# - vwait
# - while # TODO
# 


namespace eval tclreadline {

proc FirstNonOption {line} {
    set expr_pos 1
    foreach word [lrange ${line} 1 end] {; # 0 is the command itself
        if {"-" != [string index ${word} 0]} {
            break
        } else {
            incr expr_pos
        }
    }
    return ${expr_pos}
}

proc RemoveUsedOptions {line opts {terminate {}}} {
    if {[llength ${terminate}]} {
        if {[regexp -- ${terminate} ${line}]} {
            return ""
        }
    }
    set new ""
    foreach word ${opts} {
        if {![regexp -- ${word} ${line}]} {
            lappend new ${word}
        }
    }
    return [string trim ${new}]
}

proc Alert {} {
    puts -nonewline \a
    flush stdout
}

# AttemptFromList will return an empty string, if
# the text typed so far does not match any of the
# elements in list. This might be used to allow
# subsequent filename completion by the builtin
# completer.
#
proc AttemptFromList {text lst} {
    return [string trim [Format [FindInList $text $lst] $text]]
}

# CompleteFromList will never return an empty string.
#
proc CompleteFromList {text lst} {
    set result [AttemptFromList ${text} ${lst}]
    if {![llength ${result}]} {
        Alert
        return [string trim "${text} ${lst}"]
    } else {
        return ${result}
    }
}

# ???????
proc MenuFromList {text lst} {
    if {![llength ${text}]} {
        return [string trim "{} ${lst}"]
    } else {
        return [AttemptFromList ${text} ${lst}]
    }
}

# never return an empty string
#
proc Menu {lst} {
    return [string trim "{} ${lst}"]
}

proc FindInList {text lst} {
    set result ""
    foreach word $lst {
        if {[string match ${text}* ${word}]} {
            lappend result ${word}
        }
    }
    return [string trim $result]
}


# get the longest common completion
# e.g. str == {tcl_version tclreadline_version tclreadline_library}
# --> [GetCommon ${str}] == "tcl"
#
proc GetCommon {str} {
    # puts stderr str=$str
    set match0 [lindex ${str} 0]
    set len0 [string length $match0]
    set no_matches [llength ${str}]
    set part ""
    for {set i 0} {$i < $len0} {incr i} {
        set char [string index $match0 $i]
        for {set j 1} {$j < $no_matches} {incr j} {
            if {$char != [string index [lindex ${str} $j] $i]} {
                break
            }
        }
        if {$j < $no_matches} {
            break
        } else {
            append part $char
        }
    }
    # puts stderr part=$part
    return ${part}
}

proc SubCmd {start line} {
    set depth 0
    # puts stderr SubCmd
    for {set i $start} {$i >= 0} {incr i -1} {
        set c [string index $line $i]
        if {{;} == $c} {
            incr i; # discard command break character
            return [list [expr $start - $i] [string range $line $i end]]
        } elseif {{]} == $c} {
            incr depth
        } elseif {{[} == $c} {
            incr depth -1
            if {$depth < 0} {
                incr i; # discard command break character
                return [list [expr $start - $i] [string range $line $i end]]
            }
        }
    }
    return ""
}

proc IsWhite {char} {
    if {" " == $char || "\n" == $char || "\t" == $char} {
        return 1
    } else {
        return 0
    }
}

proc PreviousWord {start line} {
    incr start -1
    set found 0
    for {set i $start} {$i > 0} {incr i -1} {
        set c [string index $line $i]
        if {${found} && [IsWhite $c]} {
            break
        } elseif {!${found} && ![IsWhite $c]} {
            set found 1
        }
    }
    return [string trim [string range ${line} $i $start]]
}

proc Quote {value left} {
    set right [Right ${left}]
    if {1 < [llength $value] && "" == $right} {
        return [list \"${value}\"]
    } else {
        return [list ${left}${value}${right}]
    }
}

proc InChannelId {text} {
    # return [ChannelId ${text} inChannel {stdin}]
    return [ChannelId ${text} inChannel]
}

proc OutChannelId {text} {
    # return [ChannelId ${text} outChannel {stdout stderr}]
    return [ChannelId ${text} outChannel]
}

proc ChannelId {text {descript channelId} {chs ""}} {
    if {"" == ${chs}} {
        if [catch {set chs [file channels]}] {
            set chs {stdin stdout stderr}
        }
    }
    if {[llength [set channel [MenuFromList ${text} ${chs}]]]} {
        return ${channel}
    } else {
        return [Menu ${descript}]
    }
}

proc QuoteQuotes {line} {
    regsub -all -- \" $line {\"} line
    regsub -all -- \{ $line {\{} line; # \}\} (keep the editor happy)
    return $line
}

#**
# get the word position.
# @return the word position
# @note will returned modified values.
# @sa EventuallyEvaluateFirst
# @date Sep-06-1999
#
# % p<TAB>
# % bla put<TAB> $b
# % put<TAB> $b
# part  == put
# start == 0
# end   == 3
# line  == "put $b"
# [PartPosition] should return 0
#
proc PartPosition {partT startT endT lineT} {

    upvar $partT part $startT start $endT end $lineT line
    EventuallyEvaluateFirst part start end line

    # puts stderr "(PartPosition) line\[start\]=[string index $line $start]"
    # puts stderr "(PartPosition) part=|$part|"
    incr start -1
    if {"\"" == [string index $line $start]} {
        incr start -1
    }
    # puts stderr "(PartPosition) line=|$line|" 
    # puts stderr "(PartPosition) start=$start"
    set line [string range $line 0 $start]
    set line [QuoteQuotes $line]
    # puts stderr "(PartPosition) line=|$line|" 
    set result [llength $line]
    # puts stderr $result
    return $result
}

proc Right {left} {
    if {"\"" == $left} {
        return ""
    } elseif {"\{" == $left} {
        return "\}"
    } elseif {"\\\{" == $left} {
        return "\\\}"
    }
    return ""
}

proc GetPrefix {text} {
    set null [string index $text 0]
    # puts null=|$null|
    if {"\"" == $null} {
        # puts stderr \neins\n
        set pre "\\\""
    } elseif {"\{" == $null} {
        # puts stderr \nzwei\n
        set pre "\\\{"
    } else {
        # puts stderr \ndrei\n
        set pre ""
    }
    return ${pre}
}

proc Format {matches {part {}}} {
    # puts matches=|$matches|
    # puts stderr \npart=|$part|\n
    set pre [GetPrefix ${part}]
    if {1 == [llength $matches]} { ; # unique match
        # puts stderr \nunique=$matches\n
        # puts stderr "\n|${pre}${matches}[Right ${pre}]|\n"
        return [string trim ${pre}${matches}[Right ${pre}]]
    } elseif {"" != ${matches}} {
        # puts stderr \nmore=$matches\n
        set common [GetCommon ${matches}]
        # puts stderr common=|$common|
        if {"" == $common} {
            return [string trim "[list $part] ${matches}"]
        } else {
            return [string trim "${pre}${common} ${matches}"]
        }
    } else {
        return ""; # nothing to complete
    }
}

proc ListCompletion {text {level -1}} {
    # TODO
    return ""
    # return [VarCompletion ${text} ${level}]
}

proc VarCompletion {text {level -1}} {
    if {-1 == ${level}} {
        set level [info level]
    } else {
        incr level
    }
    set pre [GetPrefix ${text}]

    if {"" == ${pre}} {
        set var ${text}
    } else {
        set var [string range ${text} 1 end]
    }

    # arrays
    #
    if {[regexp {([^(]*)\((.*)} ${var} all array name]} {
        set names [uplevel ${level} array names ${array} ${name}*]
        if {1 == [llength $names]} { ; # unique match
            return "${array}(${names})"
        } elseif {"" != ${names}} {
            return "${array}([GetCommon ${names}] ${names}"
        } else {
            return ""; # nothing to complete
        }
    }

    # non-arrays
    #
    regsub ":$" ${var} "::" var
    set namespaces [namespace children :: ${var}*]
    if {[llength ${namespaces}] && "::" != [string range ${var} 0 1]} {
        foreach name ${namespaces} {
            regsub "^::" ${name} "" name
            if {[string length ${name}]} {
                lappend new ${name}::
            }
        }
        set namespaces ${new}
        unset new
    }
    set matches \
    [string trim "[uplevel ${level} info vars ${var}*] ${namespaces}"]
    if {1 == [llength $matches]} { ; # unique match
        # check if this unique match is an
        # array name, (whith no "(" yet).
        #
        if {[uplevel ${level} array exists $matches]} {
            return [VarCompletion ${matches}( ${level}]; # recursion
        } else {
            return ${pre}${matches}[Right ${pre}]
        }
    } elseif {"" != $matches} { ; # more than one match
        set common [GetCommon ${matches}]
        if {"" == ${common}} {
            return [Format ${matches} ${text}]
        } else {
            return [string trim "${pre}${common} ${matches}"]
        }
    } else {
        return ""; # nothing to complete
    }
}

proc FullQualifiedMatches {qualifier matchlist} {
    set new ""
    foreach entry ${matchlist} {
        set full ${qualifier}::${entry}
        if {"" != [namespace which ${full}]} {
            lappend new ${full}
        }
    }
    return ${new}
}

proc ProcsOnlyCompletion {cmd} {
    return [CommandCompletion ${cmd} procs]
}

proc CommandsOnlyCompletion {cmd} {
    return [CommandCompletion ${cmd} commands]
}

proc CommandCompletion {cmd {action both} {spc ::}} {
    set quali [namespace qualifiers ${cmd}]
    if {[llength ${quali}]} {
        set rec [CommandCompletion [namespace tail ${cmd}] ${action} ${quali}]
        return [FullQualifiedMatches ${quali} ${rec}]
    }
    # puts stderr \ncmd=|$cmd|\n
    set cmd [string trim ${cmd}]*
    if {"procs" != ${action}} {
        set commands [namespace eval $spc "info commands [QuoteQuotes ${cmd}]"]
        # puts stderr commands=|$commands|
    } else {
        set commands ""
    }
    if {"commands" != ${action}} {
        set procs [namespace eval $spc "info procs [QuoteQuotes ${cmd}]"]
        # puts stderr procs=|$procs|
    } else {
        set procs ""
    }
    set matches [namespace eval $spc concat ${commands} ${procs}]
# 
#     foreach match ${matches} {
#         set full ${spc}::${match}
#         if {"" != [namespace which ${full}]} {
#             lappend new bla::${full}
#         }
#     }
# 
    set namespaces [namespace children $spc ${cmd}]
    if {![llength ${matches}] && 1 == [llength ${namespaces}]} {
        set namespaces [string trim ${namespaces}]
        regsub {^([^:])} $namespaces {::\1} namespaces
    #    set matches [namespace eval ${namespaces} \
    #    {concat [info commands] [info procs]}]
        if {"procs" != ${action}} {
            set n_commands [namespace eval ${namespaces} "info commands"]
        } else {
            set n_commands ""
        }
        if {"commands" != ${action}} {
            set n_procs [namespace eval ${namespaces} "info procs"]
        } else {
            set n_procs ""
        }
        set matches [string trim "${n_commands} ${n_procs}"]
        if {[llength ${matches}]} {
# 
#             foreach match ${matches} {
#                 set full ${namespaces}::${match}
#                 if {"" != [namespace which ${full}]} {
#                     lappend new ${namespaces}::${match}
#                 }
#             }
# 
#             set matches ${new}
#             unset new
# 
            set matches [FullQualifiedMatches ${namespaces} ${matches}]
            set namespaces ""
        }
    }
    return [string trim "${matches} ${namespaces}"]
}

#**
# check, if the first argument starts with a '['
# and must be evaluated before continuing.
# NOTE: eventually modifies all arguments.
# DATE: Sep-06-1999
#
proc EventuallyEvaluateFirst {partT startT endT lineT} {
    # return; # disabled
    upvar $partT part $startT start $endT end $lineT line
    set line [string trim ${line}]

    set char [string index ${line} 0]
    if {{[} != ${char} && {$} != ${char}} {return}

    set pos 0
    while {-1 != [set idx [string first {]} ${line} ${pos}]]} {
        set cmd [string range ${line} 0 ${idx}]
        if {[info complete ${cmd}]} {
            break;
        }
        set pos [expr ${idx} + 1]
    }

    if {![info exists cmd]} {return}
    if {![info complete ${cmd}]} {return}
    set cmd [string range ${cmd} 1 [expr [string length ${cmd}] - 2]]
    set rest [string range ${line} [expr ${idx} + 1] end]

    if {[catch [list set result [string trim [eval ${cmd}]]]]} {return}

    set line ${result}${rest}
    set diff [expr [string length ${result}] - ([string length ${cmd}] + 2)]
    incr start ${diff}
    incr end ${diff}
}

# if the line entered so far is
# % puts $b<TAB>
# part  == $b
# start == 5
# end   == 7
# line  == "$puts $b"
#
proc ScriptCompleter {part start end line} {
    # puts stderr "(ScriptCompleter) |$part| $start $end |$line|"
    variable known_cmds
    if {{$} == [string index $part 0]} {
        # check for a !$ history event
        #
        if {$start > 0} {
            if {{!} == [string index $line [expr $start - 1]]} {
                return ""
            }
        }
        # variable completion. Check first, if the
        # variable starts with a plain `$' or should
        # be enclosed in braces.
        #
        set var [string range $part 1 end]
# 
#         if {"\{" == [string index $part 1]} {
#             set var [string range $part 2 end]
#             set left "\{"
#         } else {
#             set left ""
#             set var [string range $part 1 end]
#         }
# 
        # check if $var is an array name, which
        # already has already a "(" somewhere inside.
        #
        if {"" != [set vc [VarCompletion $var]]} {
            if {"" == [lindex $vc 0]} {
                return "\$ [lrange ${vc} 1 end]"
            } else {
                return \$${vc}
            }
            # puts stderr vc=|$vc|
        } else {
            return ""
        }
    # SCENARIO:
    #
    # % puts bla; put<TAB> $b
    # part  == put
    # start == 10
    # end   == 13
    # line  == "puts bla; put $b"
    # [SubCmd] --> {1 " put $b"} == sub
    # new_start = [lindex $sub 0] == 1
    # new_end   = [expr $end - ($start - $new_start)] == 4
    # new_part  == $part == put
    # new_line  = [lindex $sub 1] == " put $b"
    # 
    } elseif {"" != [set sub [SubCmd $start $line]]} {
        set new_start [lindex $sub 0]
        set new_end [expr $end - ($start - $new_start)]
        set new_line [lindex $sub 1]
        # puts stderr "(SubCmd) $new_start $new_end $new_line"
        return [ScriptCompleter $part $new_start $new_end $new_line]
    } elseif {0 == [set pos [PartPosition part start end line]]} {
        # puts stderr "(PartPosition) $part $start $end $line"
        # set matches [array names known_cmds "[string trim ${part}]*"]
        set all [CommandCompletion ${part}]
        #puts \nmatches=$matches\n
        return [Format $all $part]
    } else {
        # try to use $pos further ...
        # puts stderr |$line|
        if {"." == [string index [lindex ${line} 0] 0]} {
            set alias WIDGET
        } else {
            set alias [lindex [QuoteQuotes ${line}] 0]
        }
        foreach cmd [list ${alias} tclreadline_complete_unknown] {
            if {"" != [namespace eval ::tclreadline \
                [list info procs complete(${cmd})]]
            } {
                # to be more error-proof, we check here,
                # if complete($cmd) takes exactly 5 arguments.
                #
                if {6 != [set arguments [llength \
                    [namespace eval ::tclreadline \
                    [list info args complete(${cmd})]]]]
                } {
                    error [list complete(${cmd}) takes ${arguments} \
                    arguments, but should take exactly 6.]
                }

                # remove leading quotes
                #
                if {"\"" == [string index $part 0] \
                    || "\{" == [string index $part 0]
                } {
                    set mod [string range $part 1 end]
                } else {
                    set mod $part
                }

                if {[catch [list set script_result \
                    [complete(${cmd}) $part \
                    $start $end $line $pos $mod]] ::tclreadline::errorMsg]
                } {
                    error "error during evaluation of `complete(${cmd})'"
                }
                return ${script_result}
            }
        }
        # no specific command completer found.
        if {"" != [array names known_cmds $cmd]} {
            set current [lindex $known_cmds($cmd) $pos]
            if {"" != $current && "" == [string trim $part]} {
                return $current
            } else {
                return ""
            }
        } else {
            return ""
        }
    }
    error "{NOTREACHED (this is probably an error)}"
}


# explicit command completers
#

# -------------------------------------
#                 TCL
# -------------------------------------

proc complete(append) {text start end line pos mod} {
    switch -- $pos {
        1 { return [VarCompletion ${text}] }
        default { return [Menu ?value?] }
    }
}

proc complete(if) {text start end line pos mod} {
    # TODO: this is not good yet.
    if {2 == $pos} {
        return [AttemptFromList $text {then}]
    } elseif {$pos > 2} {
        set prev [PreviousWord ${start} ${line}]
        switch $prev {
            then -
            else -
            elseif { return "" }
        }
        return [AttemptFromList $text {then else elseif}]
    }
}

proc complete(incr) {text start end line pos mod} {
    if {1 == $pos} {
        set matches [uplevel 2 info vars "${mod}*"]
        set final ""
        # check for integers
        #
        foreach match $matches {
            if {[uplevel 2 array exists $match]} {
                continue
            }
            if {[regexp {^[0-9]+$} [uplevel 2 set $match]]} {
                lappend final $match
            }
        }
        return [Format ${final} $text]
    }
}

proc complete(array) {text start end line pos mod} {
    if {1 == $pos} {
        set cmds {
            anymore donesearch exists get names
            nextelement set size startsearch
        }
        return [AttemptFromList $text $cmds]
    } elseif {2 == $pos} {
        set cmd [lindex $line 1]
        switch -- $cmd {
            anymore -
            donesearch -
            exists -
            get -
            names -
            nextelement -
            set -
            size -
            startsearch {
                set matches ""
                set vars [uplevel [info level] info vars ${mod}*]
                foreach var ${vars} {
                    if {[uplevel [info level] array exists ${var}]} {
                        lappend matches ${var}
                    }
                }
                return [Format ${matches} ${text}]
            }
        }
    } elseif {3 == $pos} {
        set cmd [lindex $line 1]
        switch -- $cmd {
            get -
            names {
                if {[catch {
                    set names [uplevel [info level] \
                    array names [lindex $line 2] [lindex $line 3]*]}]} {
                    return ""
                } else {
                    set common [GetCommon ${names}]
                    if {"" == ${common}} {
                        return [Format ${names} ${text}]
                    } else {
                        return [string trim "${common} ${names}"]
                    }
                }
            }
        }
    }
    return ""
}

proc complete(binary) {text start end line pos mod} {
    set cmd [lindex $line 1]
    switch -- $pos {
        1 {
            return [AttemptFromList $text {format scan}]
        }
        2 {
            switch -- $cmd {
                format { return [Menu formatString] }
                scan   { return [Menu string] }
            }
        }
        3 {
            switch -- $cmd {
                format { return [Menu ?arg?] }
                scan   { return [Menu formatString] }
            }
        }
        default {
            switch -- $cmd {
                format { return [Menu ?arg?] }
                scan   { return [Menu ?varName?] }
            }
        }
    }
    return ""
}

proc complete(clock) {text start end line pos mod} {
    set cmd [lindex $line 1]
    switch -- $pos {
        1 {
            return [AttemptFromList $text {clicks format scan seconds}]
        }
        2 {
            switch -- $cmd {
                format  { return [Menu clockValue] }
                scan    { return [Menu dateString] }
                clicks  -
                seconds {}
            }
        }
        3 {
            switch -- $cmd {
                format {
                    set sub [lindex $line 3]
                    set subcmds {-fmt -gmt}
                    return [AttemptFromList $text $subcmds]
                }
                scan {
                    set sub [lindex $line 3]
                    set subcmds {-base -gmt}
                    return [AttemptFromList $text $subcmds]
                }
                clicks  -
                seconds {}
            }
        }
    }
    return ""
}

proc complete(encoding) {text start end line pos mod} {
    set cmd [lindex $line 1]
    switch -- $pos {
        1 {
            return [AttemptFromList $text {convertfrom convertto names system}]
        }
        2 {
            switch -- $cmd {
                names {}
                convertfrom -
                convertto -
                system {
                    return [AttemptFromList ${text} [encoding names]]
                }
            }
        }
    }
    return ""
}

proc complete(expr) {text start end line pos mod} {
    set cmds {
        acos    cos     hypot   sinh 
        asin    cosh    log     sqrt 
        atan    exp     log10   tan 
        atan2   floor   pow     tanh 
        ceil    fmod    sin     abs 
        double  int     rand    round 
        srand 
    }
    return [AttemptFromList $text $cmds]
}

proc complete(fconfigure) {text start end line pos mod} {
    set cmd [lindex $line 1]
    switch -- $pos {
        1 {
            return [ChannelId ${mod}]
        }
        default {
            set option [PreviousWord ${start} ${line}]
            switch -- $option {
                -blocking {
                    return [AttemptFromList ${text} {yes no}]
                }
                -buffering {
                    return [AttemptFromList ${text} {full line none}]
                }
                -buffersize {
                    if {![llength ${text}]} {
                        return [Menu newSize]
                    }
                }
                -encoding {
                    return [AttemptFromList ${text} [encoding names]]
                }
                -eofchar {
                    return [Menu {\{inChar\ outChar\}}]
                }
                -translation {
                    return [AttemptFromList ${text} {auto binary cr crlf lf}]
                }
                default {return [AttemptFromList $text {
                    -blocking -buffering -buffersize
                    -encoding -eofchar -translation}]
                }
            }
        }
    }
    return ""
}

proc complete(fcopy) {text start end line pos mod} {
    switch -- $pos {
        1 {
            return [InChannelId ${mod}]
        }
        2 {
            return [OutChannelId ${mod}]
        }
        default {
            set option [PreviousWord ${start} ${line}]
            switch -- $option {
                -size    { return [Menu size] }
                -command { return [Menu callback] }
                default  { return [AttemptFromList $text {-size -command}] }
            }
        }
    }
    return ""
}

proc complete(file) {text start end line pos mod} {
    switch -- $pos {
        1 {
            set cmds {
                atime attributes copy delete dirname executable exists
                extension isdirectory isfile join lstat mtime mkdir
                nativename owned pathtype readable readlink rename
                rootname size split stat tail type volumes writable
            }
            return [AttemptFromList $text $cmds]
        }
        2 {
            set cmd [lindex $line 1]
            switch -- $cmd {
                atime -
                attributes -
                dirname -
                executable -
                exists -
                extension -
                isdirectory -
                isfile -
                join -
                lstat -
                mtime -
                mkdir -
                nativename -
                owned -
                pathtype -
                readable -
                readlink -
                rootname -
                size -
                split -
                stat -
                tail -
                type -
                volumes -
                writable {
                    return ""
                }

                copy -
                delete -
                rename {
                #    set match [MenuFromList ${mod} {-force}]
                    return ""
                }
            }
        }
    }
    return ""
}

proc complete(fileevent) {text start end line pos mod} {
    switch -- $pos {
        1 {
            return [ChannelId ${mod}]
        }
        2 {
            return [CompleteFromList ${mod} {readable writable}]
        }
    }
    return ""
}

proc complete(flush) {text start end line pos mod} {
    switch -- $pos {
        1 { return [ChannelId ${mod}] }
    }
    return ""
}

proc complete(gets) {text start end line pos mod} {
    switch -- $pos {
        1 { return [InChannelId ${mod}] }
    }
    return ""
}

proc complete(glob) {text start end line pos mod} {
    switch -- $pos {
        1 {
            set matches [AttemptFromList ${mod} {-nocomplain --}]
            if {[llength [string trim ${mod}]] && [llength ${matches}]} {
                return ${matches}
            }
        }
    }
    return ""
}

proc complete(global) {text start end line pos mod} {
    return [VarCompletion ${text}]
}

proc complete(index) {text start end line pos mod} {
    if {1 == $pos} {
        return [VarCompletion ${text}]
    } elseif {2 == $pos && ![llength ${mod}]} {
        return <index>
    }
    return ""
}

proc complete(info) {text start end line pos mod} {
    if {1 == $pos} {
        set cmds {
            args body cmdcount commands complete default exists
            globals hostname level library loaded locals nameofexecutable
            patchlevel procs script sharedlibextension tclversion vars}
        return [AttemptFromList $text $cmds]
    } elseif {2 == $pos} {
        set cmd [lindex $line 1]
        switch -- $cmd {
            args -
            body -
            default -
            procs { return [complete(proc) ${text} 0 0 ${line} 1 ${mod}] }
            complete { ; # TODO
            }
            level { ; # TODO
            }
            loaded { ;# TODO
            }
            commands -
            exists -
            globals -
            locals -
            vars {
                if {"exists" == $cmd} {
                    set do vars
                } else {
                    set do $cmd
                }
                # puts stderr [list complete(info) level = [info level]]
                return \
                [Format [uplevel 2 info ${do} "${mod}*"] $text]
            }
        }
    }
    return ""
}

proc complete(interp) {text start end line pos mod} {
    set cmd [lindex $line 1]
    if {1 == $pos} {
        set cmds {
            alias aliases create delete eval exists expose hide hidden
            issafe invokehidden marktrusted slaves share target transfer}
        return [AttemptFromList $text $cmds]
    } elseif {2 == $pos} {
        switch -- $cmd {
            create {
                return [AttemptFromList $text {-safe -- ?path?}]
            }

            eval -
            exists -
            expose -
            hide -
            hidden -
            invokehidden -
            marktrusted -
            target {if {![llength ${mod}]} { return <path> }}

            aliases -
            delete -
            issafe -
            slaves {if {![llength ${mod}]} { return ?path? }}

            alias -
            share -
            transfer {if {![llength ${mod}]} { return <srcPath> }}
        }
    } elseif {3 == $pos} {
        switch -- $cmd {

            alias {if {![llength ${mod}]} { return <srcCmd> }}

            create {
                return [AttemptFromList $text {-safe -- ?path?}]
            }

            eval {if {![llength ${mod}]} { return <arg> }}
            delete {if {![llength ${mod}]} { return ?path? }}

            expose {if {![llength ${mod}]} { return <hiddenName> }}
            hide {if {![llength ${mod}]} { return <exposedCmdName> }}

            invokehidden {
                return \
                [AttemptFromList $text {?-global? <hiddenCmdName}]
            }

            target {if {![llength ${mod}]} { return <alias> }}

            exists {}
            hidden {}
            marktrusted {}
            aliases {}
            issafe {}
            slaves {}

            share -
            tranfer {return [ChannelId ${mod}]}
        }
    } elseif {4 == $pos} {
        switch -- $cmd {

            alias {if {![llength ${mod}]} { return <targetPath> }}

            create {
                return [AttemptFromList $text {-safe -- path}]
            }

            expose {if {![llength ${mod}]} { return ?exposedCmdName? }}
            hide {if {![llength ${mod}]} { return ?hiddenCmdName? }}

            share -
            tranfer {if {![llength ${mod}]} { return ?destPath? }}
        }
    }
    return ""
}

proc complete(join) {text start end line pos mod} {
    if {1 == $pos} {
        return [VarCompletion ${text}]
    }
    return ""
}

proc complete(lappend) {text start end line pos mod} {
    if {1 == $pos} {
        return [ListCompletion ${text}]
    }
    return ""
}

proc complete(linsert) {text start end line pos mod} {
    if {1 == $pos} {
        return [ListCompletion ${text}]
    }
    return ""
}

proc complete(llength) {text start end line pos mod} {
    if {1 == $pos} {
        return [ListCompletion ${text}]
    }
    return ""
}

proc complete(load) {text start end line pos mod} {
    if {1 == $pos} {
        return ""; # filename
    } elseif {2 == $pos && ![llength ${mod}]} {
        return "<packageName>"
    } elseif {3 == $pos && ![llength ${mod}]} {
        return "<interp>"
    }
    return ""
}

proc complete(lrange) {text start end line pos mod} {
    if {1 == $pos} {
        return [ListCompletion ${text}]
    } elseif {2 == $pos && ![llength ${mod}]} {
        return "<first>"
    } elseif {3 == $pos && ![llength ${mod}]} {
        return "<last>"
    }
    return ""
}

proc complete(lreplace) {text start end line pos mod} {
    if {1 == $pos} {
        return [ListCompletion ${text}]
    } elseif {2 == $pos && ![llength ${mod}]} {
        return "<first>"
    } elseif {3 == $pos && ![llength ${mod}]} {
        return "<last>"
    } elseif {![llength ${mod}]} {
        return "?element?"
    }
    return ""
}

proc complete(lsearch) {text start end line pos mod} {
    if {1 == $pos} {
        set options [MenuFromList ${mod} {
            -exact -glob -regexp <list>}]
        set matches [ListCompletion ${text}]
        return [string trim "${matches} ${options}"]
    } else {
        if {![llength ${mod}]} {
            set opt [lindex ${line} 1]
            if {[llength [MenuFromList ${opt} {
                -exact -glob -regexp }]]} {
                incr pos -1
            }
            if {1 == $pos} {
                return <list>
            } elseif {2 == $pos} {
                return <pattern>
            }
        }
    }
    return ""
}

proc complete(lsort) {text start end line pos mod} {
    set options [Menu ${mod} {
        -ascii -dictionary -integer -real -command
        -increasing -decreasing -index
    }]
    set matches [ListCompletion ${text}]
    return [string trim "${matches} ${options}"]
}

proc complete(history) {text start end line pos mod} {
    if {1 == $pos} {
        set cmds {add change clear event info keep nextid redo}
        return [AttemptFromList $text $cmds]
    } elseif {2 == ${pos}} {
        set cmd [lindex $line 1]
        switch -- $cmd {
            add { if {![llength ${mod}]} { return <newValue> } }
            change { if {![llength ${mod}]} { return <newValue> } }

            info -
            keep { if {![llength ${mod}]} { return ?count? } }

            event -
            redo { if {![llength ${mod}]} { return ?event? } }

            clear -
            nextid { return "" }
        }
    }
    return ""
}

proc complete(namespace) {text start end line pos mod} {
    regsub {^([^:])} ${mod} {::\1} mod
    # TODO dosn't work ???
    set space_matches [namespace children :: [string trim ${mod}*]]
    # puts \nspace_matches=|${space_matches}|
    set cmd [lindex $line 1]
    if {1 == $pos} {
        set cmds {
            children code current delete eval export forget
            import inscope origin parent qualifiers tail which}
        return [AttemptFromList $text $cmds]
    } elseif {2 == $pos} {
        switch -- $cmd {
            children -
            delete -
            eval -
            inscope -
            forget -
            parent { return [AttemptFromList ${mod} $space_matches] }
            code { return "" }
            current {}
            export { return [MenuFromList ${mod} -clear ?pattern?] }
            import {
                return [MenuFromList ${mod} "-force $space_matches"]
            }
            origin { if {![llength ${mod}]} { return <command> } }
            qualifiers -
            tail { if {![llength ${mod}]} { return <string> } }
            which { return [MenuFromList ${mod} {
                -command -variable <name>}] }
        }
     #      forget { if {![llength ${mod}]} { return ?pattern? } }
    } elseif {3 == $pos && "inscope" == $cmd} {
            if {![llength ${mod}]} { return arg }
    } else {
        switch -- $cmd {
            children { if {![llength ${mod}]} { return ?pattern? } }
            delete { return [AttemptFromList $text $space_matches] }
            eval { if {![llength ${mod}]} { return ?arg? } }
            inscope { if {![llength ${mod}]} { return ?arg? } }
            parent {}
            code {}
            current {}
            export -
            forget -
            import { return [Menu ?pattern?] }
            origin {}
            qualifiers {}
            tail {}
            which { return [MenuFromList $text {
                -command -variable <name>}] }
        }
    }
    return ""
}

proc complete(open) {text start end line pos mod} {
    if {![llength ${mod}]} {
        if {2 == $pos} {
            return ?access?
        } elseif {3 == $pos} {
            return ?permissions?
        }
    }
    return ""
}

proc complete(package) {text start end line pos mod} {
    set cmd [lindex $line 1]
    if {1 == $pos} {
        set cmds {
            forget ifneeded names present provide require
            unknown vcompare versions vsatisfies}
        return [AttemptFromList $text $cmds]
    } elseif {2 == $pos} {
        switch -- $cmd {
            forget -
            ifneeded -
            provide -
            versions { return [MenuFromList ${mod} [package names]] }
            present -
            require {
                return [MenuFromList ${mod} "-exact [package names]"] }
            names {}
            unknown { if {![llength ${mod}]} { return ?command? } }
            vcompare -
            vsatisfies { if {![llength ${mod}]} { return <version1> } }
        }
    } elseif {3 == $pos} {
        switch -- $cmd {
            forget {}
            ifneeded { if {![llength ${mod}]} { return <version> } }
            provide { if {![llength ${mod}]} { return ?version? } }
            versions {}
            present -
            require {
                set prev [PreviousWord ${start} ${line}]
                if {[llength [MenuFromList ${prev} -exact]]} {
                    return [MenuFromList ${mod} [package names]]
                } elseif {![llength ${mod}]} {
                    return ?version?
                }
            }
            names {}
            unknown {}
            vcompare -
            vsatisfies { if {![llength ${mod}]} { return <version2> } }
        }
    } 
    return ""
}

proc complete(pkg_mkIndex) {text start end line pos mod} {
    set cmds [RemoveUsedOptions ${line} {-direct -load -verbose -- <dir>} {--}]
    set res [string trim [MenuFromList $text $cmds]]
    if {[regexp -- [PreviousWord ${start} ${line}] -load] \
        && ![llength ${mod}]} {
            return <pkgPat>
    }
    if {![llength [join ${res}]]} {
        return ""
    } else {
        return ${res}
    }
    return ""
}

proc complete(proc) {text start end line pos mod} {
    # puts known_procs=|${known_procs}|
    if {1 == $pos} {
        set known_procs [ProcsOnlyCompletion ${mod}]
        set common [GetCommon ${known_procs}]
        if {"" == ${common}} {
            return [Format ${known_procs} ${text}]
        } else {
            return [string trim "${common} ${known_procs}"]
        }
    } elseif {2 == $pos} {
        set proc [lindex $line 1]
        if {[catch {set args [uplevel 2 info args ${proc}]}]} {
            return ""
        } else {
            return [list "\{${args}\} \{"]
        }
    }
    return ""
}

proc complete(puts) {text start end line pos mod} {
    if {1 == $pos} {
        return [MenuFromList ${mod} "-nonewline [OutChannelId ${mod}]"]
    } elseif {2 <= $pos} {
        if {![llength ${mod}]} {
            set opt [lindex ${line} 1]
            if {[llength [MenuFromList ${opt} {-nonewline}]]} {
                incr pos -1
            }
            if {1 == $pos} {
                return [OutChannelId ${mod}]
            } elseif {2 == $pos} {
                return [Menu <string>]
                return <string>
            }
        }
    }
    return ""
}

proc complete(read) {text start end line pos mod} {
    if {1 == $pos} {
        return [MenuFromList ${mod} "-nonewline [InChannelId ${mod}]"]
    } elseif {2 == $pos} {
        if {![llength ${mod}]} {
            set opt [lindex ${line} 1]
            if {[llength [MenuFromList ${opt} {-nonewline}]]} {
                return [InChannelId ${mod}]
            } elseif {![llength ${mod}]} {
                return <numBytes>
            }
        }
    }
    return ""
}

proc complete(regexp) {text start end line pos mod} {
    set prev [PreviousWord ${start} ${line}]
    if {[llength ${prev}] && ("-" == [string index ${prev} 0] || 1 == $pos)} {
        set cmds [RemoveUsedOptions ${line} {
            -nocase -indices -expanded -line 
            -linestop -lineanchor -about <expression> --} {--}]
        if {[llength ${cmds}]} {
            return [string trim [MenuFromList $text $cmds]]
        }
    } else {
        set virtual_pos [expr ${pos} - [FirstNonOption ${line}]]
        switch -- ${virtual_pos} {
            1 { if {![llength ${mod}]} { return <string> } }
            2 { if {![llength ${mod}]} { return ?matchVar? } }
            default { if {![llength ${mod}]} { return ?subMatchVar? } }
        }
    }
    return ""
}

proc complete(regsub) {text start end line pos mod} {
    set prev [PreviousWord ${start} ${line}]
    if {[llength ${prev}] && ("-" == [string index ${prev} 0] || 1 == $pos)} {
        set cmds [RemoveUsedOptions ${line} {-all -nocase -- <expression>} {--}]
        set res [string trim [MenuFromList ${mod} ${cmds}]]
        if {[llength ${res}]} {
            return ${res}
        }
    } else {
        set virtual_pos [expr ${pos} - [FirstNonOption ${line}]]
        switch -- ${virtual_pos} {
            1 { if {![llength ${mod}]} { return <expression> } }
            2 { if {![llength ${mod}]} { return <string> } }
            3 { if {![llength ${mod}]} { return <subSpec> } }
            4 { if {![llength ${mod}]} { return <varName> } }
        }
    }
    return ""
}

proc complete(rename) {text start end line pos mod} {
    if {1 == $pos} {
        set all [CommandCompletion ${mod}]
        return [Format $all ${mod}]
    } elseif {2 == $pos && ![llength ${mod}]} {
        return <newName>
    }
    return ""
}

proc complete(return) {text start end line pos mod} {
    # TODO this is not perfect yet
    set cmds {-code -errorinfo -errorcode <string>}
    set res [MenuFromList [PreviousWord ${start} ${line}] ${cmds}]
    if {1 == [llength ${res}]} {
        switch -- ${res} {
            -errorinfo { if {![llength ${mod}]} { return <info> } }
            -code -
            -errorcode {
                set codes {ok error return break continue}
                return [AttemptFromList ${mod} ${codes}]
            }
        }
    }
    set cmds [RemoveUsedOptions ${line} ${cmds}]
    set res [string trim [MenuFromList ${mod} ${cmds}]]
    if {[llength ${res}]} {
        return ${res}
    }
    return ""
}

proc complete(seek) {text start end line pos mod} {
    if {1 == $pos} {
        return [ChannelId ${mod}]
    } elseif {2 == $pos} {
        return [AttemptFromList ${mod} {start current end}]
    }
    return ""
}

proc complete(set) {text start end line pos mod} {
    # puts stderr "\ntext=|$text| $start $end\n"
    # puts stderr \nline=|$line|\n
    # puts stderr \npos=|$pos|\n
    # puts stderr \nmod=|$mod|\n
    if {1 == $pos} {
        return [VarCompletion ${text}]
    } elseif {2 == $pos && ($text == "" || $text == "\"" || $text == "\{")} {
        set line [QuoteQuotes $line]
        if {[catch "set value [list [uplevel [info level] set [lindex $line 1]]]" msg]} {
            return ""
        } else {
            return [Quote $value ${text}]
        }
    }
    return ""
}

proc complete(socket) {text start end line pos mod} {
    set cmd [lindex ${line} 1]
    set prev [PreviousWord ${start} ${line}]
    if {"-server" == ${cmd}} {
        # server sockets
        #
        if {2 == $pos && ![llength ${mod}]} { return <command> }
        switch -- ${prev} {
            -myaddr { if {![llength ${mod}]} { return <addr> } }
        }
        return [AttemptFromList ${mod} [concat {-error -sockname -peername}]]
    } else {
        # client sockets
        #
        switch -- ${prev} {
            -myaddr { if {![llength ${mod}]} { return <addr> } }
            -myport { if {![llength ${mod}]} { return <port> } }
        }

        # read the host table only once.
        #
        variable hosts
        if {![info exists hosts] && "-server" != ${cmd}} {
            set id [open /etc/hosts r]
            set hosts ""
            if {0 != ${id}} {
                while {-1 != [gets ${id} line]} {
                    regsub {#.*} ${line} {} line
                    if {[llength ${line}] >= 2} {
                        lappend hosts [lindex ${line} 1]
                    }
                }
                close $id
            } 
        }
        set cmds {-myaddr -myport -async -myaddr -error -sockname -peername}
        if {$pos <= 1} {
            lappend cmds -server
        }
        return [AttemptFromList ${mod} [concat ${cmds} ${hosts}]]
    }
    return ""
}

proc complete(source) {text start end line pos mod} {
    return ""; # force file name completion
}

proc complete(string) {text start end line pos mod} {
    set cmd [lindex ${line} 1]
    set cmds {
        compare first index last length match range tolower
        totitle toupper trim trimleft trimright wordend wordstart}
    if {1 == $pos} {
        return [AttemptFromList ${mod} ${cmds}]
    } elseif {2 == $pos} {
        switch -- $cmd {
            compare -
            first -
            last { if {![llength ${mod}]} { return <string1> } }

            match { if {![llength ${mod}]} { return <pattern> } }

            index -
            length -
            range -
            tolower -
            totitle -
            toupper -
            trim -
            trimleft -
            trimright -
            wordend -
            wordstart { if {![llength ${mod}]} { return <string> } }
        }
    } elseif {3 == $pos} {
        switch -- $cmd {
            compare -
            first -
            last { if {![llength ${mod}]} { return <string2> } }

            index { if {![llength ${mod}]} { return <charIndex> } }
            length {}

            match { if {![llength ${mod}]} { return <string> } }

            range { if {![llength ${mod}]} { return <first> } }

            tolower -
            totitle -
            toupper {}

            trim -
            trimleft { if {![llength ${mod}]} { return ?chars? } }
            trimright -
            wordend -
            wordstart { if {![llength ${mod}]} { return <index> } }
        }
    }
    return ""
}

proc complete(subst) {text start end line pos mod} {
    set opts {-nobackslashes -nocommands -novariables}
    set opts [RemoveUsedOptions ${line} ${opts}]
    return [AttemptFromList ${mod} [concat ${opts} <string>]]
    return ""
}

proc complete(switch) {text start end line pos mod} {
    set opts {-exact -glob -regexp --}
    set opts [RemoveUsedOptions ${line} ${opts} {--}]
    return [AttemptFromList ${mod} [concat ${opts} <string>]]
    return ""
}

proc complete(tell) {text start end line pos mod} {
    if {1 == $pos} {
        return [ChannelId ${mod}]
    }
    return ""
}

proc complete(trace) {text start end line pos mod} {
    set cmd [lindex ${line} 1]
    if {1 == $pos} {
        return [AttemptFromList ${mod} {variable vdelete vinfo}]
    } elseif {2 == $pos} {
        return [Format [uplevel 2 info vars "${mod}*"] ${mod}]
    } elseif {3 == $pos && "variable" == ${cmd}} {
        return [AttemptFromList ${mod} {r w u}]
    }
    return ""
}

proc complete(update) {text start end line pos mod} {
    if {1 == $pos && ![llength ${mod}]} {
        return idletasks
    }
    return ""
}

proc complete(uplevel) {text start end line pos mod} {
    if {![llength ${mod}]} {
        if {1 == $pos} {
            return ?level?
        } elseif {2 == $pos} {
            return <command>
        } elseif {3 == $pos} {
            return ?arg?
        } elseif {4 == $pos} {
            return ?...?
        }
    }
    return ""
}

proc complete(upvar) {text start end line pos mod} {
    if {![llength ${mod}]} {
        if {1 == $pos} {
            return ?level?
        } elseif {2 == $pos} {
            return <otherVar>
        } elseif {3 == $pos} {
            return <myVar>
        } elseif {4 == $pos} {
            return ?...?
        }
    }
    return ""
}

proc complete(variable) {text start end line pos mod} {
    set modulo [expr $pos % 2]
    if {1 == ${modulo}} {
        return [VarCompletion ${mod}]
    } elseif {0 == ${modulo} && \
        ($text == "" || $text == "\"" || $text == "\{")} {
        set line [QuoteQuotes $line]
        incr pos -1
        if {[catch \
            "set value [list [uplevel [info level] set [lindex $line ${pos}]]]"\
            msg]} {
            return ""
        } else {
            return [Quote $value ${mod}]
        }
    }
    return ""
}

proc complete(vwait) {text start end line pos mod} {
    if {1 == ${pos}} {
        return [VarCompletion ${mod}]
    }
}

proc complete(unset) {text start end line pos mod} {
    return [VarCompletion ${text}]
}

# -------------------------------------
#                  TK
# -------------------------------------

# generic widget configuration

proc TrySubCmds {cmd} {
    set trystring ____
    set result ""
    if [catch {set result [${cmd} ${trystring}]} msg] {
        if {[regexp {bad *option.*____.*: *must *be( .*$)} ${msg} all raw]} {
            regsub -all -- , ${raw} { } raw
            set len [llength ${raw}]
            set len_2 [expr ${len} - 2]
            for {set i 0} {${i} < ${len}} {incr i} {
                set word [lindex ${raw} ${i}]
                if {"or" != ${word} && ${i} != ${len_2}} {
                    lappend result ${word}
                }

            }
        } else {
            # check, if it's a blt error msg ...
            #
            set msglst [split ${msg} \n]
            foreach line ${msglst} {
                if {[regexp "${cmd}\[ \t\]\+\(\[^ \t\]*\)\[^:\]*$" \
                    ${line} all sub]} {
                    lappend result [list ${sub}]
                }
            }
        }
    }
    return ${result}
}

proc WidgetList {pattern} {
    regsub {^([^\.])} ${pattern} {\.\1} pattern
    if {[winfo exists ${pattern}]} {
        return [winfo children ${pattern}]
    } else {
        regsub {.[^.]*$} $pattern {} pattern
        if {[winfo exists ${pattern}]} {
            return [winfo children ${pattern}]
        } else {
            return ""
        }
    }
}

proc complete(WIDGET) {text start end line pos mod} {
    set widget [lindex ${line} 0]
    set cmd [lindex ${line} 1]

    # first we build an option table
    #
    if {[catch [list set option_table [${widget} configure]] msg]} {
        return ""
    }
    foreach optline ${option_table} {
        if {5 != [llength ${optline}]} continue else {
            lappend options(switches) [lindex ${optline} 0]
            lappend options(value)    [lindex ${optline} 4]
        }
    }

    if {1 >= ${pos}} {
        set cmds [TrySubCmds ${widget}]
        if {[llength ${cmds}]} {
            return [AttemptFromList ${mod} ${cmds}]
        }
    } elseif {2 <= ${pos} && 
        ([string match ${cmd}* cget] || \
         [string match ${cmd}* configure])} {
        set prev [PreviousWord ${start} ${line}]
        #puts \nprev=|$prev|
        #puts switches=|$options(switches)|
        #puts found=[lsearch -exact ${prev} $options(switches)]
        if {-1 != [set found [lsearch -exact $options(switches) ${prev}]]} {
            if {![llength ${mod}]} {
                return [list "[lindex $options(value) ${found}]"]
            }
        } else {
            return [AttemptFromList ${mod} $options(switches)]
        }
    }
    return ""
}

proc complete(winfo) {text start end line pos mod} {
    set cmd [lindex ${line} 1]
    if {1 >= ${pos}} {
        set cmds [TrySubCmds winfo]
        if {[llength ${cmds}]} {
            return [AttemptFromList ${mod} ${cmds}]
        }
    } elseif {2 == ${pos}} {
        return [AttemptFromList ${mod} [WidgetList ${mod}]]
    }
    return ""
}

}; # namespace tclreadline