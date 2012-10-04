#!/bin/bash

. bin/common.sh

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
			#echo $sha ${sha:0:1} -- ${sha:1} -- $path
			sha="${sha:1}"
			url="$(git config --local "submodule.$path.url")"
			
			echo "$url --> $path" | tee -a "$TEMPDIR/clone.log"
			echo "=====================================" >> "$TEMPDIR/clone.log"
			
			git clone "$url" "$path" >> "$TEMPDIR/clone.log" 2>&1
			if [ $? -ne 0 ]; then
				echo "    FAILED. See $TEMPDIR/clone.log"
				hasfailed=true
			else
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