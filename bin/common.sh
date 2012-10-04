#!/bin/bash

declare -r SCRIPTDIR="$(cd "$(dirname "$0")"; pwd)"

# Set path constants.
declare -r ARCHIVES=archives
declare -r MOJANGARCHIVE=archives/mojang
declare -r MCBIN=$MOJANGARCHIVE/bin
declare -r MCCLIENT=$MCBIN/minecraft.jar
declare -r MCRESOURCES=$MOJANGARCHIVE/resources
declare -r MCSERVER=$MOJANGARCHIVE/minecraft_server.jar
declare -r BTWARCHIVE=archives/btw
declare -r MCP=mcp
declare -r MCPJARS=$MCP/jars

function CHECKISWIN() {
	if [ -z "$ISWIN" ]; then
		local UNAMECHECK="$(uname -s)"
		if [ "${UNAMECHECK:0:5}" == "MSYS_" -o "${UNAMECHECK:0:8}" == "MINGW32_" ]; then
			ISWIN=true
		else
			ISWIN=false
		fi
	fi
	
	return 0
}

function CHECKZIP() {
	if CHECKISWIN; then
		if command zip &> /dev/null; then
			ZIPCMD=zip
			return 0
		elif $ISWIN; then
			ZIPCMD=7za
			ZIPPATH="$(FIXPATH "$SCRIPTDIR/bin/7za" 7za.exe)"
			local ret=$?
			
			[ "$ret" == "0" ] && return 0
			
			echo
			echo "ERROR: The '7za.exe' command could not be located in:"
			echo "    $SCRIPTDIR/bin/7za"
			EXITCLEAN 1
		fi
	fi
	
	echo
	echo "ERROR: The 'zip' command is not available on your system or is not on your \$PATH."
	EXITCLEAN 1
}

function ZIPADD() {
	CHECKZIP || return 1
	
	local archive="$1"
	shift
	
	if [ "$ZIPCMD" == "7za" ]; then
		cmd.exe //c "$ZIPPATH" a -tzip "$archive" "$@"
		return $?
	else
		zip "$archive" "$@"
		return $?
	fi
}

function ZIPDEL() {
	local archive="$1"
	shift
	
	if [ "$ZIPCMD" == "7za" ]; then
		cmd.exe //c "$ZIPPATH" d -tzip "$archive" "$@"
		return $?
	else
		zip -d "$archive" "$@"
		return $?
	fi
}

function FIXPATH() {
	CHECKISWIN || return 1
	
	local fixedpath=
	local dirname="$1"
	shift
	
	[ ! -d "$dirname" ] && return 1
	
	if $ISWIN; then
		fixedpath="$(cd "$dirname"; cmd //c cd)"
	else
		fixedpath="$(cd "$dirname"; pwd)"
	fi
	
	# Trim a single trailing slash, if it exists.
	fixedpath="${fixedpath%/}"
	fixedpath="${fixedpath%\\}"
	
	while [ "$#" != "0" ]; do
		local part="$1"
		
		# Trim slashes
		part="$(echo "$part" | sed -e 's#^/*##g' -e 's#/*$##g')"
		
		if $ISWIN; then
			fixedpath="$fixedpath\\${part/\//\\}"
		else
			fixedpath="$fixedpath/$part"
		fi
		
		shift
	done
	
	echo "$fixedpath"
	return 0
}

function FAIL_CAT() {
	echo "FAILED. See below:"
	echo "================================================="
	cat "$1"
	EXITCLEAN 1
}

function MKCLEANTEMP() {
	# First remove any existing temp dir if $TEMPDIR was already set.
	RMTEMP
	
	TEMPDIR="$1"
	
	RMTEMP
	[ $? -ne 0 ] && echo "ERROR: Could not remove the old temp directory at:" && echo "    $TEMPDIR" && EXITCLEAN 1
	
	mkdir -p "$1" > /dev/null
	[ $? -ne 0 ] && echo "ERROR: Could not create temp directory at:" && echo "    $TEMPDIR" && EXITCLEAN 1
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
	
	exit $ret
}

function SYNTAX() {
	if [ -n "$SYNTAX" ]; then
		EXITCLEAN 1 "$@" "$SYNTAX"
	else
		EXITCLEAN 1 "$@"
	fi
}

function CHECK_FILE() {
	if [ ! -f "$SCRIPTDIR/$1" ]; then
		echo
		echo "ERROR: $2 not found at: $1"
		EXITCLEAN 1
	fi
}

function CHECK_DIR() {
	if [ ! -d "$SCRIPTDIR/$1" ]; then
		echo
		echo "ERROR: $2 not found at: $1"
		EXITCLEAN 1
	fi
}