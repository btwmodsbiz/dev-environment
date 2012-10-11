#!/bin/bash

. bin/common.sh

function main() {
	MKCLEANTEMP "$SCRIPTDIR/temp/decompile"

	CHECKPYTHON
	local cfgpath="$(FIXPATH "$SCRIPTDIR/$CONF" mcp-decompile.cfg)"
	local scriptpath="$(FIXPATH "$SCRIPTDIR/$MCP/runtime" decompile.py)"
	
	local doclient=true
	local doserver=true
	local branch=
	
	check_client_src_project() || EXITCLEAN $?
	check_server_src_project() || EXITCLEAN $?
	
	if $doserver || $doclient; then
		echo
		cd "$SCRIPTDIR/$MCP"
		"$PYCMD" "$scriptpath" -r -c "$cfgpath"
	fi
}

check_client_src_project() {
	branch="$(cd "$SCRIPTDIR/$CLIENT_SRC_PROJECT" 2> /dev/null && git symbolic-ref -q HEAD 2> /dev/null)"
	if [ "$branch" != "refs/heads/$CLIENT_SRC_DECOMPILEBRANCH" ]; then
		if [ "$branch" == "" ]; then
			echo "SKIPPING CLIENT: Either $CLIENT_SRC_PROJECT is not a git repo or it is not on the refs/heads/$CLIENT_SRC_DECOMPILEBRANCH branch."
		else
			echo "SKIPPING CLIENT: $CLIENT_SRC_PROJECT must be on the '$CLIENT_SRC_DECOMPILEBRANCH' branch."
		fi
		doclient=false
	fi
	
	if $doclient && [ -d "$SCRIPTDIR/$CLIENT_SRC_PROJECT/src" ]; then
		(cd "$SCRIPTDIR/$CLIENT_SRC_PROJECT" && git status -u --ignored --porcelain 2> /dev/null > "$TEMPDIR/gitstatus")
		[ $? -ne 0 ] && echo "ERROR: Could not get a list of untracked/ignored files for: $CLIENT_SRC_PROJECT" && return 1
		
		statuslines="$(grep -v '!! bin/' "$TEMPDIR/gitstatus" | wc -l | tr -d '\t ')"
		[ "$statuslines" != "0" ] && echo "ERROR: One or more untracked or ignored files are in: $CLIENT_SRC_PROJECT" && echo "       You must remove or stash them. See: git status -u --ignored" && return 1
		
		echo "Removing $CLIENT_SRC_PROJECT/src..."
		rm -rf "$SCRIPTDIR/$CLIENT_SRC_PROJECT/src"
		[ $? -ne 0 ] && echo "ERROR: Could not remove old src directory." && return 1
	fi
}

check_server_src_project() {
	branch="$(cd "$SCRIPTDIR/$SERVER_SRC_PROJECT" 2> /dev/null && git symbolic-ref -q HEAD 2> /dev/null)"
	if [ "$branch" != "refs/heads/$SERVER_SRC_DECOMPILEBRANCH" ]; then
		if [ "$branch" == "" ]; then
			echo "SKIPPING SERVER: Either $SERVER_SRC_PROJECT is not a git repo or it is not on the refs/heads/$SERVER_SRC_DECOMPILEBRANCH branch."
		else
			echo "SKIPPING SERVER: $SERVER_SRC_PROJECT must be on the '$SERVER_SRC_DECOMPILEBRANCH' branch."
		fi
		doserver=false
	fi
	
	if $doserver && [ -d "$SCRIPTDIR/$SERVER_SRC_PROJECT/src" ]; then
		(cd "$SCRIPTDIR/$SERVER_SRC_PROJECT" && git status -u --ignored --porcelain 2> /dev/null > "$TEMPDIR/gitstatus")
		[ $? -ne 0 ] && echo "ERROR: Could not get a list of untracked/ignored files for: $SERVER_SRC_PROJECT" && return 1
		
		statuslines="$(grep -v '!! bin/' "$TEMPDIR/gitstatus" | wc -l | tr -d '\t ')"
		[ "$statuslines" != "0" ] && echo "ERROR: One or more untracked or ignored files are in: $SERVER_SRC_PROJECT" && echo "       You must remove or stash them. See: git status -u --ignored" && return 1
		
		echo "Removing $SERVER_SRC_PROJECT/src..."
		rm -rf "$SCRIPTDIR/$SERVER_SRC_PROJECT/src"
		[ $? -ne 0 ] && echo "ERROR: Could not remove old src directory." && return 1
	fi
}

do_client() {
	
}

do_server() {
	
}

main "$@"
EXITCLEAN 0