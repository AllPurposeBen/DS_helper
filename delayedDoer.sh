#!/bin/sh

# Created by Amsys
#
# Use at your own risk.  Amsys will accept
# no responsibility for loss or damage
# caused by this script.
#
# Requires 10.10 or higher.
#
# Mod'd for Grandstand 01/2018

###############
## variables ##
###############

# Make sure to change these variables
KEYBOARDNAME="US Extended"                    # Keyboard name
KEYBOARDCODE="-2"                             # Keyboard layout code (it's -2 according to my computer)
LANG="en"                                     # macOS language
REGION="en_US"                                # macOS region
SUBMIT_TO_APPLE=NO                            # Choose whether to submit diagnostic information to Apple
SUBMIT_TO_APP_DEVELOPERS=NO                   # Choose whether to submit diagnostic information to 3rd party developers
STD_USER_PASSWORD="CHANGEME"          	      # The default password for the standard user

#### These variables can be left alone
PLBUDDY=/usr/libexec/PlistBuddy
SW_VERS=$(sw_vers -productVersion)
BUILD_VERS=$(sw_vers -buildVersion)
ARD="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"
CRASHREPORTER_SUPPORT="/Library/Application Support/CrashReporter"
CRASHREPORTER_DIAG_PLIST="${CRASHREPORTER_SUPPORT}/DiagnosticMessagesHistory.plist"

#### These variables we get from reading our pre-population file
STASHFILE="/var/root/setupVars.txt"
WMGROUP=$(grep 'WMGROUP =' "$STASHFILE" | awk -F ' = ' '{print $2}')
ASSETID=$(grep 'ASSETID =' "$STASHFILE" | awk -F ' = ' '{print $2}')
USER_LONGNAME=$(grep 'LONGNAME =' "$STASHFILE" | awk -F ' = ' '{print $2}')
USER_SHORTNAME=$(echo "$USER_LONGNAME" | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:]' | tr -d '[:space:]')
HOSTNAME=$(echo "$USER_LONGNAME" | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:]' | tr ' ' -)

#clean up the sensitive stash file
rm -rf "$STASHFILE"



###############
## functions ##
###############

update_kdb_layout() {
  ${PLBUDDY} -c "Delete :AppleCurrentKeyboardLayoutInputSourceID" "${1}" &>/dev/null
  if [ ${?} -eq 0 ]
  then
    ${PLBUDDY} -c "Add :AppleCurrentKeyboardLayoutInputSourceID string com.apple.keylayout.${KEYBOARDNAME}" "${1}"
  fi

  for SOURCE in AppleDefaultAsciiInputSource AppleCurrentAsciiInputSource AppleCurrentInputSource AppleEnabledInputSources AppleSelectedInputSources
  do
    ${PLBUDDY} -c "Delete :${SOURCE}" "${1}" &>/dev/null
    if [ ${?} -eq 0 ]
    then
      ${PLBUDDY} -c "Add :${SOURCE} array" "${1}"
      ${PLBUDDY} -c "Add :${SOURCE}:0 dict" "${1}"
      ${PLBUDDY} -c "Add :${SOURCE}:0:InputSourceKind string 'Keyboard Layout'" "${1}"
      ${PLBUDDY} -c "Add :${SOURCE}:0:KeyboardLayout\ ID integer ${KEYBOARDCODE}" "${1}"
      ${PLBUDDY} -c "Add :${SOURCE}:0:KeyboardLayout\ Name string '${KEYBOARDNAME}'" "${1}"
    fi
  done
}

update_language() {
  ${PLBUDDY} -c "Delete :AppleLanguages" "${1}" &>/dev/null
  if [ ${?} -eq 0 ]
  then
    ${PLBUDDY} -c "Add :AppleLanguages array" "${1}"
    ${PLBUDDY} -c "Add :AppleLanguages:0 string '${LANG}'" "${1}"
  fi
}

update_region() {
  ${PLBUDDY} -c "Delete :AppleLocale" "${1}" &>/dev/null
  ${PLBUDDY} -c "Add :AppleLocale string ${REGION}" "${1}" &>/dev/null
  ${PLBUDDY} -c "Delete :Country" "${1}" &>/dev/null
  ${PLBUDDY} -c "Add :Country string ${REGION:3:2}" "${1}" &>/dev/null
}

################
#### Script ####
################

# Change Keyboard Layout
update_kdb_layout "/Library/Preferences/com.apple.HIToolbox.plist" "${KEYBOARDNAME}" "${KEYBOARDCODE}"

# Set the computer language
update_language "/Library/Preferences/.GlobalPreferences.plist" "${LANG}"

# Set the region
update_region "/Library/Preferences/.GlobalPreferences.plist" "${REGION}"

# Supress first run screens at login (iCloud, Siri & Diagnostics)
for USER_TEMPLATE in "/System/Library/User Template"/*
  do
    /usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
    /usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant GestureMovieSeen none
    /usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant DidSeeSiriSetup -bool TRUE
    /usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${SW_VERS}"
    /usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant LastSeenCloudProductVersion "${SW_VERS}"
  	/usr/bin/defaults write "${USER_TEMPLATE}"/Library/Preferences/com.apple.SetupAssistant LastSeenBuddyBuildVersion "${BUILD_VERS}"
  done

# Disable diagnostics pop-up on 10.10 and above

if [ ! -d "${CRASHREPORTER_SUPPORT}" ]; then
  mkdir "${CRASHREPORTER_SUPPORT}"
  chmod 775 "${CRASHREPORTER_SUPPORT}"
  chown root:admin "${CRASHREPORTER_SUPPORT}"
fi

for key in AutoSubmit AutoSubmitVersion ThirdPartyDataSubmit ThirdPartyDataSubmitVersion; do
  $PLBUDDY -c "Delete :$key" "${CRASHREPORTER_DIAG_PLIST}" 2> /dev/null
done

$PLBUDDY -c "Add :AutoSubmit bool ${SUBMIT_TO_APPLE}" "${CRASHREPORTER_DIAG_PLIST}"
$PLBUDDY -c "Add :AutoSubmitVersion integer 4" "${CRASHREPORTER_DIAG_PLIST}"
$PLBUDDY -c "Add :ThirdPartyDataSubmit bool ${SUBMIT_TO_APP_DEVELOPERS}" "${CRASHREPORTER_DIAG_PLIST}"
$PLBUDDY -c "Add :ThirdPartyDataSubmitVersion integer 4" "${CRASHREPORTER_DIAG_PLIST}"

# Set the time zone to Central
/usr/sbin/systemsetup -settimezone "America/Chicago"

# Enable network time servers
/usr/sbin/systemsetup -setusingnetworktime on

# Configure a specific NTP server
/usr/sbin/systemsetup -setnetworktimeserver "time.apple.com"

# Switch on Apple Remote Desktop
$ARD -configure -activate

# Configure ARD access for the local admin user
$ARD -configure -access -on
$ARD -configure -allowAccessFor -specifiedUsers
$ARD -configure -access -on -users $LOCAL_ADMIN_SHORTNAME -privs -all

# Enable SSH
systemsetup -setremotelogin on

# Enable admin info at the Login Window
/usr/bin/defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName

### Grandstand added items

# Try to mute the computer
osascript -e "set Volume 0"

## SET Asset ID if needed
if [ -n "$ASSETID" ] && [ "$ASSETID" != "DONOTHING" ]; then
	#asset value is not blank and isn't the DONOTHING value, set the stored value to nvram
	nvram ASSET="$ASSETID"
fi

## Set WM Group
/usr/bin/defaults write /Library/MonitoringClient/ClientSettings ClientGroup -string "$WMGROUP"

## Set the initial munki manifest
# figure out which manifest to use
case "$WMGROUP" in
	"Art" )
		manifest="setup-art"
		;;
	"test" )
		manifest="test"
		;;
	"Servers" )
		manifest="setup-server"
		;;
	"Production" )
		manifest="setup-production"
		;;
	"RemoteVM" )
		manifest="remoteVM"
		;;
	* )
		manifest="setup"
		;;
esac
# set it
/usr/bin/defaults write /Library/Preferences/ManagedInstalls.plist ClientIdentifier "$manifest"
# set the rest of the munki config
/usr/bin/defaults write /Library/Preferences/ManagedInstalls.plist SoftwareRepoURL "http://beermunki.grandstand.private/munkirepo"
/usr/bin/defaults write /Library/Preferences/ManagedInstalls.plist HelpURL "http://helpdesk.grandstand.private/portal"
/usr/bin/defaults write /Library/Preferences/ManagedInstalls.plist InstallAppleSoftwareUpdates -bool True
/usr/bin/defaults write /Library/Preferences/ManagedInstalls.plist UnattendedAppleUpdates -bool True
/usr/bin/defaults write /Library/Preferences/ManagedInstalls.plist SuppressUserNotification -bool False
/usr/bin/defaults write /Library/Preferences/ManagedInstalls.plist SuppressStopButtonOnInstall -bool False
touch /Users/Shared/.com.googlecode.munki.checkandinstallatstartup

## Create the local admin just so we do have an admin account at outset. Will be over written by the current localadmin pkg when munki runs.
sysadminctl -addUser localadmin -fullName "Local Admin" -password "gl@ssofb33r" -admin
dscl . -create /Users/localadmin NFSHomeDirectory /Users/localadmin	# Create new home dir attribute

## Create the standard user
# If we got a NONE value, skip the user setup section entirely 
if [ "$USER_LONGNAME" == "tester" ]; then
	sysadminctl -addUser $USER_SHORTNAME -fullName "$USER_LONGNAME" -password "password" -admin
	dscl . -create /Users/$USER_SHORTNAME NFSHomeDirectory /Users/$USER_SHORTNAME	# Create new home dir attribute

	## Set computer name. hostname and localhostname
	scutil --set ComputerName "Test Machine"
	scutil --set HostName "test".local
	scutil --set LocalHostName "test" 
elif [ "$USER_LONGNAME" != "NONE" ]; then
	sysadminctl -addUser $USER_SHORTNAME -fullName "$USER_LONGNAME" -password "$STD_USER_PASSWORD" 
	dscl . -create /Users/$USER_SHORTNAME NFSHomeDirectory /Users/$USER_SHORTNAME	# Create new home dir attribute
	#set password to force change on login
	pwpolicy -a localadmin -p 'gl@ssofb33r' -u $USER_SHORTNAME -setpolicy "newPasswordRequired=1"
	
	#check if this is a Remote VM and if so, append "Remote" to the end of the sharing name
	if [ "$manifest" == "remoteVM" ]; then
		sharingName="$USER_LONGNAME Remote"
	else
		sharingName="$USER_LONGNAME"
	fi
	
	## Set computer name. hostname and localhostname
	scutil --set ComputerName "$sharingName"
	scutil --set HostName "$HOSTNAME".local
	scutil --set LocalHostName "$HOSTNAME" 
elif [ "$USER_LONGNAME" == "NONE" ] && [ "$WMGROUP" == "Spares" ];then
	#don't setup a user but put the asset ID in the hostname so it's easy to identify in WM
	setThisAID=$(nvram -p | grep ASSET | awk -F ' ' '{print $2}')
	scutil --set ComputerName "Asset ID $setThisAID"
else
	#there was no std user to set
	echo "No standard user specified to set."	
fi		

exit 0