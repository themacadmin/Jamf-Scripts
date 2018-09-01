#!/bin/bash

<<ABOUT_THIS_SCRIPT
-----------------------------------------------------------------------

Modified by:
Miles Leacy
Technical Expert: Apple Technology
Walmart

Modifed on: 2018 08 31

Modification summary:
* Simplified and genericized code
* Adjusted data points and formatting based on individual use case
* Simplified dialog and removed "Run Additional Commands"
* Added Jamf inventory update at end

========== Original Info Follows ==========
	Written by:William Smith
	Professional Services Engineer
	Jamf
	bill@talkingmoose.net
	https://github.com/talkingmoose/Jamf-Scripts
	
	Originally posted: August 13, 2018

	Purpose: Display a dialog to end users with computer information when
	run from within Jamf Pro Self Service. Useful for Help Desks to
	ask end users to run when troubleshooting.

	Except where otherwise noted, this work is licensed under
	http://creativecommons.org/licenses/by/4.0/

	"they're good dogs Brent"

INSTRUCTIONS

	1) Edit the "Run Additional Commands" section to choose a behavior
	   for the Enable Remote Support button. This button can do anything
	   you'd like. Three examples are provided:
	   
	   - open an application
	   - run a Jamf Pro policy
	   - email the computer information to your Help Desk
	   
	2) In Jamf Pro choose Settings (cog wheel) > Computer Mangement >
	   Scripts and create a new script. Copy this script in full to the
	   script body and save.
	3) Then choose Computers > Policies and create a new policy. Add
	   the script to the policy and enable it for Self Service.
	4) When an end user calls your Help Desk, the technician can instruct
	   him or her to open Self Service and run the script for trouble-
	   shooting.
	
-----------------------------------------------------------------------
ABOUT_THIS_SCRIPT

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# FUNCTIONS
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

simplifyBytes() {
    b=${1:-0}; d=''; s=0; S=(Bytes {K,M,G,T,P,E,Z,Y}B)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    echo "$b$d ${S[$s]}"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# SYSTEM VARIABLES
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

timeStamp=$(date +"%F %T")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Data Collection for Output
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	# General
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	
	# Get computer name
	computerName="Computer Name: $( /usr/sbin/scutil --get ComputerName ) (for macOS)"
	
	# Get host name
	hostName="Host Name: $( /usr/sbin/scutil --get HostName ) (for AD)"
	
	# Get operating system
	operatingSystemVersion=$( /usr/bin/sw_vers -productVersion)
	operatingSystemBuild=$( /usr/bin/sw_vers -buildVersion)
	case $(echo $operatingSystemVersion | awk -F "." '{ print $2 }') in
		14)
			operatingSystemName="macOS Mojave"
			;;
		 13)
			operatingSystemName="macOS High Sierra"
			;;
		12)
			operatingSystemName="macOS Sierra"
			;;
		11)
			operatingSystemName="OS X El Capitan"
			;;
		*)
			operatingSystemName="Unsupported macOS Version"
			;;
		esac
	osDisplay="OS: $operatingSystemName v$operatingSystemVersion ($operatingSystemBuild)"
	
	# Get serial number
	serialNumber="Serial Number: $( ioreg -l | awk -F'"' '/IOPlatformSerialNumber/ { print $4;}' )"
	
	# Get Model Name
	modelIdentifier=$(sysctl hw.model | awk '{print $2}')
	marketingModel="$(defaults read /System/Library/PrivateFrameworks/ServerInformation.framework/Versions/A/Resources/English.lproj/SIMachineAttributes.plist "$modelIdentifier"|sed -n -e 's/\\//g' -e 's/.*marketingModel = "\(.*\)";/\1/p'|sed 's/"/\\"/g')"
	modelDisplay="Model: $marketingModel"
	
	# Get uptime
	runCommand=$( /usr/bin/uptime | /usr/bin/awk -F "(up |, [0-9] users)" '{ print $2 }' )
	if [[ "$runCommand" = *day* ]] || [[ "$runCommand" = *sec* ]] || [[ "$runCommand" = *min* ]] ; then
		upTime="Uptime: $runCommand"
	else
		upTime="Uptime: $runCommand hrs/min"
	fi

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	# Hardware
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	
	# Get RAM
	bytes=$(sysctl hw.memsize | awk '{print $2'})
	totalRam="Total RAM: $(simplifyBytes $bytes)"
	
	# Get free space on /
	FreeSpace=$( /usr/sbin/diskutil info / | /usr/bin/awk '/Free Space/ || /Available Space/ {print $4 " " $5}')
	FreePercentage=$( /usr/sbin/diskutil info / | /usr/bin/awk -F'[\(\)]' '/Free Space/ || /Available Space/ {print $6}' )
	diskSpace="Disk Space: $FreeSpace free ($FreePercentage available)"
	
	# Display battery cycle count
	if [[ "$marketingModel" = *Book* ]]; then
		batteryCycleCount="Battery Cycle Count: $( /usr/sbin/ioreg -r -c "AppleSmartBattery" | /usr/bin/awk '/\"CycleCount\"/ {print $3}' )"
	fi
	
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	# Network
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	
	# Display active network services and IP Addresses
	
	networkServices=$( /usr/sbin/networksetup -listallnetworkservices | /usr/bin/grep -v asterisk )
	
	while IFS= read aService
	do
		activePort=$( /usr/sbin/networksetup -getinfo "$aService" | /usr/bin/grep "IP address" | /usr/bin/grep -v "IPv6" )
		if [ "$activePort" != "" ] && [ "$activeServices" != "" ]; then
			activeServices="$activeServices\n$aService $activePort"
		elif [ "$activePort" != "" ] && [ "$activeServices" = "" ]; then
			activeServices="$aService $activePort"
		fi
	done <<< "$networkServices"
	
	activeServices=$( echo "$activeServices" | /usr/bin/sed '/^$/d')
	
	
	# Display Wi-Fi SSID
	model=$( /usr/sbin/system_profiler SPHardwareDataType | /usr/bin/grep 'Model Name' )
	
	if [[ "$model" = *Book* ]]; then
		runCommand=$( /usr/sbin/networksetup -getairportnetwork en0 | /usr/bin/awk -F ": " '{ print $2 }' )
	else
		runCommand=$( /usr/sbin/networksetup -getairportnetwork en1 | /usr/bin/awk -F ": " '{ print $2 }' )
	fi
	SSID="SSID: $runCommand"
	
	# Display SSH status
	runCommand=$( /usr/sbin/systemsetup -getremotelogin | /usr/bin/awk -F ": " '{ print $2 }' ) 
	SSH="SSH: $runCommand"
	
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
	# Active Directory
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	
	# Display Active Directory binding
	boundFqDomain=$( /usr/sbin/dsconfigad -show | /usr/bin/grep "Directory Domain" | /usr/bin/awk -F "= " '{ print $2 }' )
	boundDomain=$( echo $boundFqDomain | /usr/bin/awk -F'[.]' '{print toupper($1)}')
	
	if [ "$boundDomain" = "" ]; then
		AD="Domain: None"
	else
		AD="Domain: $boundFqDomain"	
	fi
	
	# Test Active Directory binding
	bindTest=$( /usr/bin/dscl "/Active Directory/"$boundDomain"/All Domains" read /Users )
	
	if [ "$bindTest" = "name: dsRecTypeStandard:Users" ]; then
		testAD="AD Connection Test: Successful"
	else
		testAD="AD Connection Test: Failed"	
	fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Format Output
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

displayInfo="
General
-------------------------------------------------
$computerName
$hostName
$osDisplay
$serialNumber
$modelDisplay
$upTime

Hardware
-------------------------------------------------
$totalRam
$diskSpace
$batteryCycleCount

Network
-------------------------------------------------
$activeServices
$SSID
$SSH

Active Directory
-------------------------------------------------
$AD
$testAD
"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display Output
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# echo to stdout for testing
# echo "$displayInfo"

osascript -e "Tell application \"System Events\" to display dialog \"$displayInfo\" with title \"Computer Information\" with icon file posix file \"/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns\" buttons {\"OK\"} default button {\"OK\"}"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Jamf Inventory
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Get JSS availability
jamf checkjssconnection -retry 1
jssAvailable="$?"

if [ $jssAvailable -eq 0 ]; then
	jamf recon
else
	printf "$timeStamp %s\n" "JSS is unavailable, unable to update inventory."
fi

exit 0
