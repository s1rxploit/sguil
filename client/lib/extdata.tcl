################################################
# Sguil proc for getting/displaying external   #
# data (rules, references, xscript, dns,       #
# etc)                                         #
################################################
# $Id: extdata.tcl,v 1.10 2004/09/22 19:28:31 creining Exp $

proc GetRuleInfo {} {
  global currentSelectedPane ACTIVE_EVENT SHOWRULE socketID DEBUG referenceButton icatButton MULTI_SELECT SSN_QUERY
  global CONNECTED eventArray SANCP_QUERY
  ClearRuleText
  if {$ACTIVE_EVENT && $SHOWRULE && !$MULTI_SELECT && !$SSN_QUERY && !$SANCP_QUERY} {
    if {!$CONNECTED} {
      ErrorMessage "Not connected to sguild. Cannot make rule request."
      return
    }
    set selectedIndex [$currentSelectedPane.msgFrame.list curselection]
    set message [$currentSelectedPane.msgFrame.list get $selectedIndex]
    set sensorName [$currentSelectedPane.sensorFrame.list get $selectedIndex]
    if {$DEBUG} {puts  "RuleRequest $sensorName $message"}
    SendToSguild "RuleRequest $sensorName $message"
  } else {
    $referenceButton configure -state disabled
    $icatButton configure -state disabled
  }
}
proc ClearRuleText {} {
  global ruleText
  $ruleText clear
}
proc InsertRuleData { ruleData } {
  global ruleText referenceButton
  global ruleText icatButton
  $ruleText component text insert end $ruleData
  $referenceButton configure -state normal
  if [regexp {cve,([^;]*)} $ruleData] {
    $icatButton configure -state normal
  } else {
    $icatButton configure -state disabled
  }
}
proc GetDshieldIP { arg } {
  global DEBUG BROWSER_PATH currentSelectedPane ACTIVE_EVENT MULTI_SELECT
  if { $ACTIVE_EVENT && !$MULTI_SELECT} {
    set selectedIndex [$currentSelectedPane.srcIPFrame.list curselection]
    if { $arg == "srcip" } {
      set ipAddr [$currentSelectedPane.srcIPFrame.list get $selectedIndex]
    } else {
      set ipAddr [$currentSelectedPane.dstIPFrame.list get $selectedIndex]
    }
    if {[file exists $BROWSER_PATH] && [file executable $BROWSER_PATH]} {
	exec $BROWSER_PATH http://www.dshield.org/ipinfo.php?ip=$ipAddr &
    } else {
      tk_messageBox -type ok -icon warning -message\
       "$BROWSER_PATH does not exist or is not executable. Please update the BROWSER_PATH variable\
        to point your favorite browser."
      puts "Error: $BROWSER_PATH does not exist or is not executable."
    }
  }
}
proc GetDshieldPort { arg } {
  global DEBUG BROWSER_PATH currentSelectedPane ACTIVE_EVENT MULTI_SELECT
  if { $ACTIVE_EVENT && !$MULTI_SELECT} {
    set selectedIndex [$currentSelectedPane.srcPortFrame.list curselection]
    if { $arg == "srcport" } {
      set ipPort [$currentSelectedPane.srcPortFrame.list get $selectedIndex]
    } else {
      set ipPort [$currentSelectedPane.dstPortFrame.list get $selectedIndex]
    }
    if {[file exists $BROWSER_PATH] && [file executable $BROWSER_PATH]} {
	exec $BROWSER_PATH http://www.dshield.org/port_report.php?port=$ipPort &
    } else {
      tk_messageBox -type ok -icon warning -message\
       "$BROWSER_PATH does not exist or is not executable. Please update the BROWSER_PATH variable\
        to point your favorite browser."
      puts "Error: $BROWSER_PATH does not exist or is not executable."
    }
  }
}
proc GetReference {} {
  global DEBUG ruleText BROWSER_PATH
  
  set signature [$ruleText get 0.0 end]
  # parse the sig for the sid
  regexp {sid:\s*([0-9]+)\s*;} $signature match sid
  if {$sid > 1000000} {
    # Local Rule
    tk_messageBox -type ok -icon warning -message\
     "Sid $sid is a locally managed signature/rule."
    puts "Error: Sid $sid is a locally managed signature/rule."
  } elseif { $sid <= 100 } {
    tk_messageBox -type ok -icon warning -message\
     "Sid $sid is reserved for future use. Is there an error in the sig file?"
    puts "Error: Sid $sid is reserved for future use. Error?."
  } else {
    if {[file exists $BROWSER_PATH] && [file executable $BROWSER_PATH]} {
      exec $BROWSER_PATH http://www.snort.org/snort-db/sid.html?sid=$sid &
      if {$DEBUG} {puts "$BROWSER_PATH http://www.snort.org/snort-db/sid.html?sid=$sid launched."}
    } else {
      tk_messageBox -type ok -icon warning -message\
       "$BROWSER_PATH does not exist or is not executable. Please update the BROWSER_PATH variable\
        to point your favorite browser."
      puts "Error: $BROWSER_PATH does not exist or is not executable."
    }
  }
}
proc GetIcat {} {
  global DEBUG ruleText BROWSER_PATH

  set signature [$ruleText get 0.0 end]
  # parse the sig for the cve
  regexp {cve,([^;]*)} $signature match cve
  if {[file exists $BROWSER_PATH] && [file executable $BROWSER_PATH]} {
        exec $BROWSER_PATH http://icat.nist.gov/icat.cfm?cvename=CAN-$cve &
  if {$DEBUG} {puts "$BROWSER_PATH http://icat.nist.gov/icat.cfm?cvename=CAN-$cve launched."}
  } else {
    tk_messageBox -type ok -icon warning -message\
    "$BROWSER_PATH does not exist or is not executable. Please update the BROWSER_PATH variable\
    to point your favorite browser."
    puts "Error: $BROWSER_PATH does not exist or is not executable."                }
}

#
# DnsButtonActy: Called when the reverse DNS button is released
#
proc ResolveHosts {} {
  global REVERSE_DNS currentSelectedPane ACTIVE_EVENT MULTI_SELECT
  ClearDNSText
  if {$REVERSE_DNS && $ACTIVE_EVENT && !$MULTI_SELECT} {
    Working
    update
    set selectedIndex [$currentSelectedPane.srcIPFrame.list curselection]
    set srcIP [$currentSelectedPane.srcIPFrame.list get $selectedIndex]
    set dstIP [$currentSelectedPane.dstIPFrame.list get $selectedIndex]
    set srcName [GetHostbyAddr $srcIP]
    set dstName [GetHostbyAddr $dstIP]
    InsertDNSData $srcIP $srcName $dstIP $dstName
    Idle
  }
}
proc GetWhoisData {} {
  global ACTIVE_EVENT currentSelectedPane WHOISLIST whoisText WHOIS_PATH MULTI_SELECT
  ClearWhoisData
  if {$ACTIVE_EVENT && $WHOISLIST != "none" && !$MULTI_SELECT} {
    Working
    update
    set selectedIndex [$currentSelectedPane.$WHOISLIST.list curselection]
    set ip [$currentSelectedPane.$WHOISLIST.list get $selectedIndex]
    if { $WHOIS_PATH == "SimpleWhois" } {
      foreach line [SimpleWhois $ip] {
        $whoisText insert end "$line\n"
      }
    } else {
      $whoisText insert end "Attempting whois query on $ip\n"
      update
      set whoisCommandID [open "| $WHOIS_PATH $ip" r]
      while { [gets $whoisCommandID data] >= 0 } {
        $whoisText insert end "$data\n"
      }
      catch {close $whoisCommandID} closeError
      $whoisText insert end $closeError
    }
    Idle
  }
}
#
# GetHostbyAddr: uses extended tcl (wishx) to get an ips hostname
#                May move to a server func in the future
#
proc GetHostbyAddr { ip } {
  if [catch {host_info official_name $ip} hostname] {
    set hostname "Unknown"
  }
  return $hostname
}
#
# ClearDNSText: Clears the src/dst dns results
#
proc ClearDNSText {} {
  global srcDnsDataEntryTextFrame dstDnsDataEntryTextFrame
  foreach i "nameText ipText" {
    $srcDnsDataEntryTextFrame.$i delete 0.0 end
    $dstDnsDataEntryTextFrame.$i delete 0.0 end
  }
} 
proc InsertDNSData { srcIP srcName dstIP dstName} {
  global srcDnsDataEntryTextFrame dstDnsDataEntryTextFrame
  $srcDnsDataEntryTextFrame.ipText insert 0.0 $srcIP
  $srcDnsDataEntryTextFrame.nameText insert 0.0 $srcName
  $dstDnsDataEntryTextFrame.ipText insert 0.0 $dstIP
  $dstDnsDataEntryTextFrame.nameText insert 0.0 $dstName
}
proc ClearWhoisData {} {
  global whoisText
  $whoisText delete 0.0 end
}
proc CreateXscriptWin { winName } {
  toplevel $winName
  menubutton $winName.menubutton -underline 0 -text File -menu $winName.menubutton.menu
  menu $winName.menubutton.menu -tearoff 0
  $winName.menubutton.menu add command -label "Save As" -command "SaveXscript $winName"
  $winName.menubutton.menu add command -label "Close Window" -command "destroy $winName"
  scrolledtext $winName.sText -vscrollmode dynamic -hscrollmode dynamic -wrap word\
   -visibleitems 85x30 -sbwidth 10
  $winName.sText tag configure hdrTag -foreground black -background "#00FFFF"
  $winName.sText tag configure srcTag -foreground blue
  $winName.sText tag configure dstTag -foreground red
  scrolledtext $winName.debug -vscrollmode dynamic -hscrollmode none -wrap word\
   -visibleitems 85x5 -sbwidth 10 -labeltext "Debug Messages" -textbackground lightblue
  pack $winName.menubutton -side top -anchor w
  pack $winName.sText $winName.debug -side top -fill both -expand true
}
proc XscriptMainMsg { winName data } {
  global XSCRIPTDATARCVD SESSION_STATE
  if { ! [winfo exist $winName] } {
    CreateXscriptWin $winName
  }
  if {! $XSCRIPTDATARCVD($winName)} {
    $winName.sText clear
    set XSCRIPTDATARCVD($winName) 1
  }
  switch -exact -- $data {
     HDR { set SESSION_STATE($winName) HDR }
     SRC { set SESSION_STATE($winName) SRC }
     DST { set SESSION_STATE($winName) DST }
     DEBUG { set SESSION_STATE($winName) DEBUG }
     DONE { unset SESSION_STATE($winName); unset XSCRIPTDATARCVD($winName); $winName configure -cursor left_ptr }
     ERROR { set SESSION_STATE($winName) ERROR }
     default { InsertXscriptData $winName $SESSION_STATE($winName) $data }
  }
}
  
proc InsertXscriptData { winName state data } {
  if { $state == "HDR" } {
    $winName.sText component text insert end "$data\n" hdrTag
  } elseif { $state == "SRC" } {
    $winName.sText component text insert end "$state: $data\n" srcTag
  } elseif { $state == "DST" } { 
    $winName.sText component text insert end "$state: $data\n" dstTag
  } elseif { $state == "ERROR" } {
    puts "data: $data"
    if { $data != "" } {
      ErrorMessage "$data"
    }
  } else {
    $winName.debug component text insert end "$data\n"
    $winName.debug see end
  } 
}
proc XscriptDebugMsg { winName data } {
    if [winfo exists $winName] {
      $winName.debug component text insert end "$data\n"
      $winName.debug see end
    }
}
proc EtherealDataPcap { socketID fileName bytes } {
  global ETHEREAL_STORE_DIR ETHEREAL_PATH
  set outFileID [open $ETHEREAL_STORE_DIR/$fileName w]
  fconfigure $outFileID -translation binary
  fconfigure $socketID -translation binary
  fcopy $socketID $outFileID -size $bytes
  close $outFileID
  fconfigure $socketID -encoding utf-8 -translation {auto crlf}
  eval exec $ETHEREAL_PATH -n -r $ETHEREAL_STORE_DIR/$fileName &
  InfoMessage\
   "Raw file is stored in $ETHEREAL_STORE_DIR/$fileName. Please delete when finished"
}
# Archiving this till I know for sure binary xfers are working correctly
proc EtherealDataBase64 { fileName data } {
  global ETHEREAL_PATH ETHEREAL_STORE_DIR b64FileID DEBUG
  if { $data == "BEGIN" } {
    set tmpFileName $ETHEREAL_STORE_DIR/${fileName}.base64
    set b64FileID($fileName) [open $tmpFileName w]
  } elseif { $data == "END" } {
    if [info exists b64FileID($fileName)] {
      close $b64FileID($fileName)
      set outFileID [open $ETHEREAL_STORE_DIR/$fileName w]
      set inFileID [open $ETHEREAL_STORE_DIR/${fileName}.base64 r]
      fconfigure $outFileID -translation binary
      fconfigure $inFileID -translation binary
      puts -nonewline $outFileID [::base64::decode [read -nonewline $inFileID]]
      close $outFileID
      close $inFileID
      file delete $ETHEREAL_STORE_DIR/${fileName}.base64
      eval exec $ETHEREAL_PATH -n -r $ETHEREAL_STORE_DIR/$fileName &
      InfoMessage "Raw file is stored in $ETHEREAL_STORE_DIR/$fileName. Please delete when finished"
    }
  } else {
    if [info exists b64FileID($fileName)] {
      puts $b64FileID($fileName) $data
    }
  }
}
proc GetXscript { type force } {
  global ACTIVE_EVENT SERVERHOST XSCRIPT_SERVER_PORT DEBUG currentSelectedPane XSCRIPTDATARCVD
  global socketWinName SESSION_STATE SSN_QUERY ETHEREAL_STORE_DIR SANCP_QUERY
  global OPENSSL VERSION USERNAME PASSWD
  if {!$ACTIVE_EVENT} {return}
  set winName $currentSelectedPane.sensorFrame.list
  set eventIndex [$winName curselection]
  set winParents [winfo parent [winfo parent $winName]]
  if {$SSN_QUERY || $SANCP_QUERY} {
    set cnxID [$winParents.xidFrame.list get $eventIndex]
    set timestamp [$winParents.startTimeFrame.list get $eventIndex]
    set proto [$winParents.ipProtoFrame.list get $eventIndex]
  } else {
    set proto [$winParents.protoFrame.list get $eventIndex]
    set cnxID [lindex [split [$winParents.eventIDFrame.list get $eventIndex] .] 1]
    set timestamp [$winParents.dateTimeFrame.list get $eventIndex]
  }
  if { $type == "xscript" && $proto != "6" } {
    tk_messageBox -type ok -icon warning -message\
     "Transcripts can only be generated for TCP traffic at this time."
    return
  }
  set sensor [$winParents.sensorFrame.list get $eventIndex]
  set srcIP [$winParents.srcIPFrame.list get $eventIndex]
  set srcPort [$winParents.srcPortFrame.list get $eventIndex]
  set dstIP [$winParents.dstIPFrame.list get $eventIndex]
  set dstPort [$winParents.dstPortFrame.list get $eventIndex]
  set xscriptWinName ".${sensor}_${cnxID}"
  if { $type == "xscript"} {
    if { ![winfo exists $xscriptWinName] } {
      CreateXscriptWin $xscriptWinName
    } else {
      InfoMessage "This transcipt is already being displayed by you. Please close\
       that window before you request a new one."
      # Try and bring the window to the top in case it is hidden.
      wm withdraw $xscriptWinName
      wm deiconify $xscriptWinName
      return  
    }
    set SESSION_STATE($xscriptWinName) HDR
    XscriptDebugMsg $xscriptWinName\
     "Your request has been sent to the server.\nPlease be patient as this can take some time."
    $xscriptWinName configure -cursor watch
    set XSCRIPTDATARCVD($xscriptWinName) 0
    SendToSguild "XscriptRequest $sensor $xscriptWinName \{$timestamp\} $srcIP $srcPort $dstIP $dstPort $force"
    if {$DEBUG} {
      puts "Xscript Request sent: $sensor $xscriptWinName \{$timestamp\} $srcIP $srcPort $dstIP $dstPort $force"
    }
    
  } elseif { $type == "ethereal" } {
    if {$DEBUG} {
      puts "Ethereal Request sent: $sensor \{$timestamp\} $srcIP \{$srcPort\} $dstIP \{$dstPort\} $proto $force"
    }
    SendToSguild "EtherealRequest $sensor \{$timestamp\} $srcIP \{$srcPort\} $dstIP \{$dstPort\} $proto $force"
  }
}
proc CopyDone { socketID tmpFileID tmpFile bytes {error {}} } {
  global DEBUG ETHEREAL_PATH
  close $tmpFileID
  close $socketID
  if {$DEBUG} {puts "Bytes Transfered: $bytes"}
  if { $bytes == 0 } { 
    ErrorMessage "No data available." 
    file delete $tmpFileID
  } else {
    eval exec $ETHEREAL_PATH -n -r $tmpFile &
    InfoMessage "Raw file is stored in $tmpFile. Please delete when finished"
  }
}
proc CopyRawData { socketID tmpFileID tmpFile } {
  catch {fcopy $socketID $tmpFileID -command [list CopyDone $socketID $tmpFileID $tmpFile]} dataError
}
proc SaveXscript { win } {
  set initialFile [string trimleft $win .]
  set saveFile [tk_getSaveFile -parent $win -initialfile $initialFile.txt]
  if { $saveFile == "" } {
    tk_messageBox -type ok -icon warning -parent $win -message\
     "No filename selected. Transcipt was NOT saved."
    return
  }
  if { [catch {$win.sText export $saveFile} saveError] } {
    tk_messageBox -type ok -icon warning -parent $win -message $saveError
  }
}
