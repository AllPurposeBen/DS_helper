#!/bin/bash

### This script writes the previously collected data to a local file on the new install so that it can act on the first run script

stashFile="/Volumes/$DS_LAST_SELECTED_TARGET/var/root/setupVars.txt"

echo "WMGROUP = $WM_GROUP" >> "$stashFile"
echo "ASSETID = $SET_AID" >> "$stashFile"
echo "LONGNAME = $USER_LONGNAME" >> "$stashFile"

exit 0