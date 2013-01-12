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
	MKCLEANTEMP "$SCRIPTDIR/temp/decompile"
	
	CHECKPYTHON
	local cfgpath="$(FIXPATH "$SCRIPTDIR/$CONF" mcp-decompile.cfg)"
	local decompilescript="$(FIXPATH "$SCRIPTDIR/$MCPARCHIVE/runtime" decompile.py)"
	
	local doclient=true
	local doserver=true
	local checkdirty=false
	local branch=
	
	parse_arguments "$@"
	
	check_client_src_project || EXITCLEAN $?
	check_server_src_project || EXITCLEAN $?
	
	mkdir "$TEMPDIR/jars"
	[ $? -ne 0 ] && echo "Failed to create $TEMPDIR/jars" && EXITCLEAN 1
	
	if $doclient; then
		cp -r "$SCRIPTDIR/$MCBIN"/* "$TEMPDIR/jars"
	fi
	
	if $doserver && $doclient; then
		"$SCRIPTDIR/createjar.sh" both -d "$TEMPDIR/jars"
		[ $? -ne 0 ] && EXITCLEAN 1
		
	elif $doserver; then
		"$SCRIPTDIR/createjar.sh" server -d "$TEMPDIR/jars"
		[ $? -ne 0 ] && EXITCLEAN 1
		
	elif $doclient; then
		"$SCRIPTDIR/createjar.sh" client -d "$TEMPDIR/jars"
		[ $? -ne 0 ] && EXITCLEAN 1
	fi
	
	if $doserver || $doclient; then
		echo
		cd "$SCRIPTDIR/$MCPARCHIVE"
		"$PYCMD" "$decompilescript" -r -c "$cfgpath"
		ret=$?
		[ $ret -ne 0 ] && echo "ERROR: decompile.py failed with exit: $ret" && exit 1
	else
		echo "ERROR: Neither client nor server passed checks. Nothing to do."
		EXITCLEAN 1
	fi
}

function parse_arguments() {
	# Optional arguments.
	while [ $# -gt 0 ]; do
		case "$1" in
			"client")
				doclient=true
				doserver=false
				;;
			"server")
				doclient=false
				doserver=true
				;;
			"-f")
				shift
				checkdirty=false
				;;
			*)
				SYNTAX "Unexpected argument: $1"
				;;
		esac
		shift
	done
}

check_client_src_project() {
	branch="$(cd "$SCRIPTDIR/$CLIENT_SRC_PROJECT" 2> /dev/null && git symbolic-ref -q HEAD 2> /dev/null)"
	if $doclient && [ "$branch" != "refs/heads/$CLIENT_SRC_DECOMPILEBRANCH" ]; then
		if [ "$branch" == "" ]; then
			echo "SKIPPING CLIENT: Either $CLIENT_SRC_PROJECT is not a git repo or it is not on the refs/heads/$CLIENT_SRC_DECOMPILEBRANCH branch."
		else
			echo "SKIPPING CLIENT: $CLIENT_SRC_PROJECT must be on the '$CLIENT_SRC_DECOMPILEBRANCH' branch."
		fi
		doclient=false
	fi
	
	if $doclient && [ -d "$SCRIPTDIR/$CLIENT_SRC_PROJECT/src" ]; then
		if $checkdirty; then
			(cd "$SCRIPTDIR/$CLIENT_SRC_PROJECT" && git status -u --ignored --porcelain 2> /dev/null > "$TEMPDIR/gitstatus")
			[ $? -ne 0 ] && echo "ERROR: Could not get a list of untracked/ignored files for: $CLIENT_SRC_PROJECT" && return 1
			
			statuslines="$(grep -v '!! bin/' "$TEMPDIR/gitstatus" | wc -l | tr -d '\t ')"
			[ "$statuslines" != "0" ] && echo "ERROR: One or more untracked or ignored files are in: $CLIENT_SRC_PROJECT" && echo "       You must remove or stash them. See: git status -u --ignored" && return 1
		fi
		
		echo "Removing $CLIENT_SRC_PROJECT/src..."
		rm -rf "$SCRIPTDIR/$CLIENT_SRC_PROJECT/src"
		[ $? -ne 0 ] && echo "ERROR: Could not remove old src directory." && return 1
	fi
	
	return 0
}

check_server_src_project() {
	branch="$(cd "$SCRIPTDIR/$SERVER_SRC_PROJECT" 2> /dev/null && git symbolic-ref -q HEAD 2> /dev/null)"
	if $doserver && [ "$branch" != "refs/heads/$SERVER_SRC_DECOMPILEBRANCH" ]; then
		if [ "$branch" == "" ]; then
			echo "SKIPPING SERVER: Either $SERVER_SRC_PROJECT is not a git repo or it is not on the refs/heads/$SERVER_SRC_DECOMPILEBRANCH branch."
		else
			echo "SKIPPING SERVER: $SERVER_SRC_PROJECT must be on the '$SERVER_SRC_DECOMPILEBRANCH' branch."
		fi
		doserver=false
	fi
	
	if $doserver && [ -d "$SCRIPTDIR/$SERVER_SRC_PROJECT/src" ]; then
		if $checkdirty; then
			(cd "$SCRIPTDIR/$SERVER_SRC_PROJECT" && git status -u --ignored --porcelain 2> /dev/null > "$TEMPDIR/gitstatus")
			[ $? -ne 0 ] && echo "ERROR: Could not get a list of untracked/ignored files for: $SERVER_SRC_PROJECT" && return 1
			
			statuslines="$(grep -v '!! bin/' "$TEMPDIR/gitstatus" | wc -l | tr -d '\t ')"
			[ "$statuslines" != "0" ] && echo "ERROR: One or more untracked or ignored files are in: $SERVER_SRC_PROJECT" && echo "       You must remove or stash them. See: git status -u --ignored" && return 1
		fi
		
		echo "Removing $SERVER_SRC_PROJECT/src..."
		rm -rf "$SCRIPTDIR/$SERVER_SRC_PROJECT/src"
		[ $? -ne 0 ] && echo "ERROR: Could not remove old src directory." && return 1
	fi
	
	return 0
}

main "$@"
EXITCLEAN 0
