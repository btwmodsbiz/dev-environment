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
	cd "$SCRIPTDIR"
	
	MKCLEANTEMP "$SCRIPTDIR/temp/init"
	
	echo "> Initializing submodules..."
	git submodule init
	[ $? -ne 0 ] && EXITCLEAN 1 "FAILED"
	
	echo "> Getting list of submodules..."
	git submodule status > "$TEMPDIR/status"
	[ $? -ne 0 ] && EXITCLEAN 1 "FAILED"
	
	echo "> Cloning missing submodules..."
	
	local hasfailed=false
	while IFS=" " read sha path; do
		if [ "${sha:0:1}" == "-" ]; then
			sha="${sha:1}"
			url="$(git config --local "submodule.$path.url")"
			
			echo "$url --> $path" | tee -a "$TEMPDIR/clone.log"
			echo "=====================================" >> "$TEMPDIR/clone.log"
			
			git clone "$url" "$path" >> "$TEMPDIR/clone.log" 2>&1
			if [ $? -ne 0 ]; then
				echo "    FAILED. See $TEMPDIR/clone.log"
				hasfailed=true
			else
				echo "Checking out tree $sha for $path..."
				(cd "$path" > /dev/null 2>> "$TEMPDIR/clone.log" && git checkout "$sha" >> "$TEMPDIR/clone.log" 2>&1 )
				if [ $? -ne 0 ]; then
					echo "    FAILED. See $TEMPDIR/clone.log"
					hasfailed=true
				fi
			fi
			
			echo >> "$TEMPDIR/clone.log"
		fi
	done < "$TEMPDIR/status"
	
	if $hasfailed; then
		exit 1
	fi
}

main "$@"
EXITCLEAN 0
