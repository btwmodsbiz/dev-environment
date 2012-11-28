#!/bin/bash

# Prevent script from being executed directly.
[ -z "$BASH_SOURCE" -o "$BASH_SOURCE" == "$0" ] && exit 1

declare -r __COMMON_DIR="$(cd "$(dirname "$BASH_SOURCE" 2> /dev/null)"; pwd)"

. "$__COMMON_DIR/common_argvalidation.sh" || return 1
. "$__COMMON_DIR/common_multiplatform.sh" || return 1

# Set path constants.
declare -r ARCHIVES=archives
declare -r MOJANGARCHIVE=archives/mojang
declare -r MCBIN=$MOJANGARCHIVE/bin
declare -r MCCLIENT=$MCBIN/minecraft.jar
declare -r MCRESOURCES=$MOJANGARCHIVE/resources
declare -r MCSERVER=$MOJANGARCHIVE/minecraft_server.jar
declare -r BTWARCHIVE=archives/btw
declare -r MLARCHIVE=archives/modloader
declare -r MCPARCHIVE=archives/mcp
declare -r MCP=mcp
declare -r MCPJARS=$MCP/jars
declare -r CONF=conf
declare -r WORKSPACE=workspace

declare -r SERVER_MODS_PROJECT=$WORKSPACE/server-mods
declare -r SERVER_API_PROJECT=$WORKSPACE/server-api
declare -r SERVER_SRC_PROJECT=$WORKSPACE/server-src
declare -r SERVER_SRC_DECOMPILEBRANCH=btw

declare -r CLIENT_API_PROJECT=$WORKSPACE/client-api
declare -r CLIENT_SRC_PROJECT=$WORKSPACE/client-src
declare -r CLIENT_SRC_DECOMPILEBRANCH=btw

declare -r PYTHON_WIN_DIR="$__COMMON_DIR/../$MCPARCHIVE/runtime/bin/python"
declare -r JAVA_WIN_DIR='/c/Program Files/Java'

function EXPORT_BRANCH() {
	VALIDATE_ARGUMENTS $FUNCNAME -c4 !-e4 -- $@
	
	local branch="$1"
	local remote="$2"
	local dest="$3"
	local log="$4"
	local ret=
	
	if [ ! -d "$TEMPDIR" ]; then
		echo '$TEMPDIR has not been set or is not a directory' > "$log"
		return 1
	fi
	
	if [ ! -d "$dest" ]; then
		echo "$dest is not a directory" > "$log"
		return 1
	fi
	
	git archive --remote="$remote" "$branch" src > "$TEMPDIR/export_branch.tar" 2> "$log"
	ret=$?
	
	if [ $ret -ne 0 ]; then
		rm "$TEMPDIR/export_branch.tar"
		return $ret
	fi
	
	tar -xf "$TEMPDIR/export_branch.tar" --strip-components=1 -C "$dest" 2> "$log"
	ret=$?
	
	rm "$TEMPDIR/export_branch.tar" &> /dev/null
	[ $ret -ne 0 ] && return $ret
	
	return 0
}

function EXPORT_BRANCH_SAFE() {
	VALIDATE_ARGUMENTS $FUNCNAME -l3 -u4 -- $@

	local branch="$1"
	local remoteprefix="$2"
	local remote="$3"
	local dest="$4"
	
	# Allow second argument to be optional.
	if [ -z "$dest" ]; then
		dest="$remote"
		remote="$remoteprefix"
		remoteprefix=
	fi
	
	echo "Exporting '$branch' branch from $remote..."
	
	VALIDATE_ARGUMENTS $FUNCNAME -d1 -- "$dest"
	
	EXPORT_BRANCH "$branch" "$remoteprefix$remote" "$dest" "$TEMPDIR/export.out"
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/export.out"
}

function FAIL_CAT() {
	VALIDATE_ARGUMENTS $FUNCNAME -l1 -u2 -f1 -- $@
	
	local file="$1"
	local message="$2"
	
	[ -z "$message" ] && message=FAILED
	
	echo
	echo "$message. See below:"
	echo "================================================="
	cat "$1"
	EXITCLEAN 1
}

function MKCLEANTEMP() {
	VALIDATE_ARGUMENTS $FUNCNAME -c1 -n1 !-f1 -- $@
	
	# First remove any existing temp dir if $TEMPDIR was already set.
	RMTEMP
	
	TEMPDIR="$1"
	
	RMTEMP
	[ $? -ne 0 ] && echo "ERROR: Could not remove the old temp directory at:" && echo "    $TEMPDIR" && EXITCLEAN 1
	
	mkdir -p "$1" > /dev/null
	[ $? -ne 0 ] && echo "ERROR: Could not create temp directory at:" && echo "    $TEMPDIR" && EXITCLEAN 1
}

function MKDIR_SAFE() {
	VALIDATE_ARGUMENTS $FUNCNAME -l1 -u2 -n1 -- $@
	
	local dirprefix="$1"
	local dir="$2"
	
	# Allow second argument to be optional.
	if [ -z "$dir" ]; then
		dir="$dirprefix"
		dirprefix=
	fi
	
	[ -e "$dirprefix$dir" -a ! -d "$dirprefix$dir" ] \
		&& echo "ERROR: Could not create directory as it already exists and is not a directory:" \
		&& echo "    $dir" \
		&& EXITCLEAN 1
		
	if [ ! -d "$dirprefix$dir" ]; then
		mkdir -p "$dirprefix$dir" > /dev/null
		
		[ $? -ne 0 ] \
			&& echo "ERROR: Could not create directory at:" \
			&& echo "    $dir" \
			&& EXITCLEAN 1
	fi
}

function RMTEMP() {
	if [ -n "$TEMPDIR" -a -d "$TEMPDIR" ]; then
		rm -rf "$TEMPDIR" &> /dev/null
		return $?
	fi
	
	return 0
}

function EXITCLEAN() {
	
	local ret="$1"
	shift
	
	RMTEMP
	
	for arg in "$@"; do
		echo "$arg"
	done
	
	VALIDATE_ARGUMENTS $FUNCNAME -i1 -- "$ret"
	exit $ret
}

function SYNTAX() {
	if [ -n "$SYNTAX" ]; then
		EXITCLEAN 1 "$@" "$SYNTAX"
	else
		EXITCLEAN 1 "$@"
	fi
}

function CHECK_FILE_SAFE() {
	VALIDATE_ARGUMENTS $FUNCNAME -l2 -u3 -n1 -n2 -- $@
	
	local pathprefix="$1"
	local path="$2"
	local name="$3"
	
	# Allow first argument to be optional.
	if [ -z "$name" ]; then
		name="$path"
		path="$pathprefix"
		pathprefix=
	fi
	
	if [ ! -f "$pathprefix$path" ]; then
		echo
		echo "ERROR: $name not found at: $path"
		EXITCLEAN 1
	fi
}

function CHECK_DIR_SAFE() {
	VALIDATE_ARGUMENTS $FUNCNAME -l2 -u3 -n1 -n2 -- $@
	
	local pathprefix="$1"
	local path="$2"
	local name="$3"
	
	# Allow first argument to be optional.
	if [ -z "$name" ]; then
		name="$path"
		path="$pathprefix"
		pathprefix=
	fi
	
	if [ ! -d "$pathprefix$path" ]; then
		echo
		echo "ERROR: $name not found at: $path"
		EXITCLEAN 1
	fi
}

true
