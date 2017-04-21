#!/bin/bash

### This script gathers info we'll need later in the setup process.

# Globals vars
POPUP=`dirname "$0"`/cocoaDialog.app/Contents/MacOS/cocoaDialog  # Path to the cocoaDialog tool
ITEMS=("Accounting" "Art" "HR" "IT" "Logistics" "Marketing" "Operations" "Production" "Sales" "Servers" "Spares" "Other")   # list for departments, must match what's in watchman

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
	local RESPONSE=$("$POPUP" $RUNMODE $OTHEROPTS --icon $ICON --icon-size $ICONSIZE --title "${TITLE}" --text "${TEXT}" --items "${ITEMS[@]}" --timeout 30)
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
	local TEXT="Long Name"
	local INFOTEXT="Enter the users name as they want it to appear."
	local ICON="person"
	local ICONSIZE="128"

	#Do the dialog, get the result and strip the Okay button code
	local RESPONSE=$("$POPUP" "$RUNMODE" --no-cancel --float --string-output --icon $ICON --icon-size $ICONSIZE --title "${TITLE}" --text "${TEXT}" ‑‑informative‑text "${INFOTEXT}" --timeout 30)
	local RESPONSE=`echo $RESPONSE | sed 's/Okay //g'`
	
	if [ "$RESPONSE" == "timeout" ] || [ "$RESPONSE" == "Okay" ] || [ "$RESPONSE" == "Long Name" ] || [ -z "$RESPONSE" ]; then
		#either no username was specified in time or was blank, pass information ot variable
		echo "RuntimeSetCustomProperty: USER_LONGNAME=NONE"
	else
		# Assign the variable to reflect the choice
		echo "RuntimeSetCustomProperty: USER_LONGNAME=${RESPONSE}"
	fi
}

doChecks () {
	## Asset ID check
	checkAID=$(nvram -p | grep ASSET | awk -F ' ' '{print $2}')
	if [ -z "$checkAID" ]; then
		#no AID on this hardware, ask to set it
		askForAID
	else	
		#we've got one already, pass a dummy variable
		echo "RuntimeSetCustomProperty: SET_AID=DONOTHING"
	fi

	## Ask for Department
	askForDept

	## Ask for User info
	askForUserName
	
	exit 0
}

askAboutVM () {
	local RUNMODE="yesno-msgbox"
	local TITLE="VM Check"
	local TEXT="Do you want to use the canned test values?"
	local INFOTEXT="Do you want to use the canned test values?"
	local ICON="hazard"
	local ICONSIZE="50"

	local RESPONSE=$("$POPUP" "$RUNMODE" --no-cancel --float --string-output --icon $ICON --icon-size $ICONSIZE --title "${TITLE}" --text "${TEXT}" --timeout 12)
	
	case "$RESPONSE" in
		"Yes"|"timeout" )
			#Fill in canned values and exit clean
			echo "RuntimeSetCustomProperty: SET_AID=DONOTHING"
			echo "RuntimeSetCustomProperty: USER_LONGNAME=user"
			echo "RuntimeSetCustomProperty: WM_GROUP=test"
			exit 0
			;;
		"No" )
			#Proceed as normal
			doChecks
			;;
		* )
			echo "ERROR, unexpected output from VM check!"
			exit 3
			;;
	esac
}

### Do stuff!!!

## Check if this is a VM and if so, ask if we should proceed normally or shortcut ot the test workflow
checkModel=$(sysctl hw.model | grep 'VMware')
if [ -n "$checkModel" ]; then
	#it is a VM, ask about it
	askAboutVM
else
	# Not a VM or use the normal routine
	doChecks
fi

exit 0