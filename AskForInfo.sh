#!/bin/bash

### This script gathers info we'll need later in the setup process.

# First, attempt to mute the computer
osascript -e "set Volume 0"

# Globals vars
POPUP=`dirname "$0"`/cocoaDialog.app/Contents/MacOS/cocoaDialog  # Path to the cocoaDialog tool
ITEMS=("Accounting" "Art" "HR" "IT" "Logistics" "Marketing" "Operations" "Production" "Sales" "Servers" "Spares" "Other")   # list for departments, must match what's in watchman
sshKey=`dirname "$0"`/deploystudio


## Functions
askForAID () {
	#set null for AID to pass variable later
	assetID="null"
	# Options for cocoaDialog
	local RUNMODE="standard-inputbox"
	local TITLE="Enter Asset Tag"
	local TEXT="#####"
	local ICON="computer"
	local ICONSIZE="128"

	#Do the dialog, get the result and strip the Okay button code
	local RESPONSE=$("$POPUP" "$RUNMODE" --no-cancel --float --string-output --icon $ICON --icon-size $ICONSIZE --title "${TITLE}" --text "${TEXT}" --timeout 30)
	local RESPONSE=`echo $RESPONSE | sed 's/Okay //g'`

	# Assign the variable to reflect the choice
	case $RESPONSE in
		"#####") # just entered the default or timed out, set nothing
			#bogus info, don't set anything
			echo "RuntimeSetCustomProperty: SET_AID=DONOTHING"
			;;
		[0-9][0-9][0-9][0-9][0-9]) #a properly formatted assetID
			echo "RuntimeSetCustomProperty: SET_AID=${RESPONSE}"
			;;
		*)
			#bogus info, don't set anything
			echo "RuntimeSetCustomProperty: SET_AID=DONOTHING"
			## TODO Bitch about a failure to the GUI?
			;;
	esac
}

askForDept () {
	# Options for cocoaDialog
	local RUNMODE="standard-dropdown"
	local TITLE="Select department:"
	local TEXT="Please select which department this computer is used in."
	local OTHEROPTS="--no-cancel --float --string-output"
	local ITEMS=("Accounting" "Art" "HR" "IT" "Logistics" "Marketing" "Operations" "Production" "Sales" "Servers" "Spares" "Other")
	local ICON="info"
	local ICONSIZE="128"

	#Do the dialog, get the result and strip the Okay button code
	local RESPONSE=$("$POPUP" $RUNMODE $OTHEROPTS --icon $ICON --icon-size $ICONSIZE --title "${TITLE}" --text "${TEXT}" --items "${ITEMS[@]}")
	local RESPONSE=`echo $RESPONSE | sed 's/Okay //g'`

	# Assign the variable to reflect the choice
	case $RESPONSE in
		"Other") # None
			wm_group="NEW"
			;;
		"Accounting") 
			wm_group="Accounting"
			;;
		"Art") 
			wm_group="Art"
			;;
		"HR") 
			wm_group="HR"
			;;
		"IT") 
			wm_group="IT"
			;;    
		"Logistics") 
			wm_group="Logistics"
			;;
		"Marketing") 
			wm_group="Marketing"
			;;
		"Operations") 
			wm_group="Operations"
			;;	
		"Production") 
			wm_group="Production"
			;;
		"Sales") 
			wm_group="Sales"
			;;	
	   "Spares") 
			wm_group="Spares"
			;;
	   "Testing") 
			wm_group="test"
			;;
		"Servers")
			wm_group="Servers"
			;;
		"timeout")
			wm_group="NEW"
			;;
		*)
			echo "RuntimeAbortWorkflow: Unknown return value from popup: $retval"
			exit 1
			;;
	esac

	#save the variable for later
	echo "RuntimeSetCustomProperty: WM_GROUP=${wm_group}"
}

askForUserName () {
	# Options for cocoaDialog
	local RUNMODE="standard-inputbox"
	local TITLE="Enter User's Long Name"
	local TEXT="No Username"
	local INFOTEXT="Enter the users name as they want it to appear."
	local ICON="person"
	local ICONSIZE="128"

	#Do the dialog, get the result and strip the Okay button code
	local RESPONSE=$("$POPUP" "$RUNMODE" --no-cancel --float --string-output --icon $ICON --icon-size $ICONSIZE --title "${TITLE}" --text "${TEXT}" ‑‑informative‑text "${INFOTEXT}")
	local RESPONSE=`echo $RESPONSE | sed 's/Okay //g'`
	
	if [ "$RESPONSE" == "timeout" ] || [ "$RESPONSE" == "Okay" ] || [ "$RESPONSE" == "No Username" ] || [ -z "$RESPONSE" ]; then
		#either no username was specified in time or was blank, pass information ot variable
		echo "RuntimeSetCustomProperty: USER_LONGNAME=NONE"
	else
		# Assign the variable to reflect the choice
		echo "RuntimeSetCustomProperty: USER_LONGNAME=${RESPONSE}"
	fi
}

askAboutVM () {
	local RUNMODE="yesno-msgbox"
	local TITLE="VM Check"
	local TEXT="Is this a remote VM?"
	local INFOTEXT="Is this a remote VM?"
	local ICON="hazard"
	local ICONSIZE="50"

	local RESPONSE=$("$POPUP" "$RUNMODE" --no-cancel --float --string-output --icon $ICON --icon-size $ICONSIZE --title "${TITLE}" --text "${TEXT}")
	
	case "$RESPONSE" in
		"Yes"|"timeout" )
			#Fill in canned values and exit clean
			echo "RuntimeSetCustomProperty: SET_AID=DONOTHING"
			#echo "RuntimeSetCustomProperty: USER_LONGNAME=tester"
			echo "RuntimeSetCustomProperty: WM_GROUP=RemoteVM"
			askForUserName
			exit 0
			;;
		"No" )
			#Proceed as normal
			return 0
			;;
		* )
			echo "ERROR, unexpected output from VM check!"
			exit 3
			;;
	esac
}

serverAccounts () {
	chmod 600 "$sshKey"
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i "$sshKey" admin@littlemac.grandstand.private "/usr/local/grandstand/create_OD_user.x '$USER_LONGNAME' '$WM_GROUP'"
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i "$sshKey" admin@bigmac.grandstand.private "/usr/local/grandstand/create_OD_user.x '$USER_LONGNAME' '$WM_GROUP'"
}

### Main loop
# Check if we're a VM and if so, ask if we can used canned values
checkModel=$(sysctl hw.model | grep 'VMware')
if [ -n "$checkModel" ]; then
	#it is a VM, ask about it
	askAboutVM
fi

# Ask about the department
askForDept

# If we need to get a username, get it, else continue. Don't need username if it's a server (we set one for "admin") and if we're a spare, no user is made.
case "$wm_group" in
	"Servers")
		echo "RuntimeSetCustomProperty: USER_LONGNAME=NONE"
		;;
	"Spares")
		echo "RuntimeSetCustomProperty: USER_LONGNAME=NONE"
		;;
	*)  #anything else
		askForUserName
		# Setup some server accounts
		# serverAccounts
		;;
esac

# Asset ID check
checkAID=$(nvram -p | grep ASSET | awk -F ' ' '{print $2}')
if [ -z "$checkAID" ]; then
	#no AID on this hardware, ask to set it
	askForAID
fi


exit 0