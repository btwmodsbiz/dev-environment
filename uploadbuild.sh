#!/bin/bash

# Standard script header.
# ==========================================
[ -z "$BASH_SOURCE" ] && echo "ERROR: This script cannot be run if piped to bash." && exit 1
cd "$(dirname "$BASH_SOURCE" 2> /dev/null)" 2> /dev/null;
[ $? -ne 0 ] && "ERROR: Failed to change to the working directory of: $BASH_SOURCE" && exit 1

declare -r SCRIPTDIR="$(pwd)"
. "$SCRIPTDIR/bin/common.sh";
[ $? -ne 0 ] && echo "ERROR: Failed to include bin/common.sh" && exit 1
# ==========================================

function main() {
	cd "$SCRIPTDIR/build" 2> /dev/null
	[ $? -ne 0 ] && echo "Could not change to 'build' directory." && exit 1
	
	echo
	echo "Removing old remote files..."
	ssh amekkawi@lifewater.kicks-ass.net 'rm -v /home/amekkawi/btwmods/*.zip'
	
	echo
	echo "Uploading new files..."
	scp minecraft_server.jar amekkawi@lifewater.kicks-ass.net:~
	scp -r btwmods/* amekkawi@lifewater.kicks-ass.net:~/btwmods
}

main "$@"

echo
echo "COMPLETE!"
EXITCLEAN 0
