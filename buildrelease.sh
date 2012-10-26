#!/bin/bash

. bin/common.sh

echo "This script is in development. Do not use!"
exit 1

function main() {
	declare -r SYNTAX="Syntax: $0 <client|server|both> [OPTIONS]"
	
	# Argument defaults
	local doclient=false
	local doserver=false
	local clientsrc=master
	local clientapi=master
	local serversrc=master
	local serverapi=master
	
	parse_arguments "$@"
	#init_verify
	
	#copy_src
	#copy_api
}

function parse_arguments() {
	[ $# -eq 0 ] && SYNTAX
	
	# First argument is fixed.
	case "$1" in
		"both")
			doclient=true
			doserver=true
			;;
		"client")
			doclient=true
			;;
		"server")
			doserver=true
			;;
		*)
			SYNTAX "First argument must be 'client', 'server' or 'both'."
			;;
	esac
	
	if ! $doclient && ! $doserver; then
		SYNTAX "Missing first argument. Must be 'client', 'server' or 'both'."
	fi
	
	shift
	
	# Optional arguments.
	while [ $# -gt 0 ]; do
		case "$1" in
			"--treeish")
				[ "$2" == "" ] && SYNTAX "Missing argument after $1"
				clientsrc="$2"
				clientapi="$2"
				serversrc="$2"
				serverapi="$2"
				shift
				;;
			"-cs")
				[ "$2" == "" ] && SYNTAX "Missing argument after $1"
				clientsrc="$2"
				shift
				;;
			"-ca")
				[ "$2" == "" ] && SYNTAX "Missing argument after $1"
				clientapi="$2"
				shift
				;;
			"-ss")
				[ "$2" == "" ] && SYNTAX "Missing argument after $1"
				serversrc="$2"
				shift
				;;
			"-sa")
				[ "$2" == "" ] && SYNTAX "Missing argument after $1"
				serverapi="$2"
				shift
				;;
			*)
				SYNTAX "Unexpected argument: $1"
				;;
		esac
		shift
	done
}

function init_verify() {
	if [ ! -d "$SCRIPTDIR/$MCPJARS" ]; then
		echo
		echo "MCP jars directory does not exist."
		echo "You may need to install MCP to $SCRIPTDIR/$MCP"
		EXITCLEAN 1
	fi
	
	CHECKJAVAC
	
	if $doclient; then
		#CHECK_FILE "$MCCLIENT" "Minecraft client jar"
		#CHECK_DIR "$BTWARCHIVE/MINECRAFT-JAR" "BTW client files"
		#CHECK_DIR "$MLARCHIVE" "ModLoader directory"
		#CHECK_FILE "$MLARCHIVE/ModLoader.class" "ModLoader ModLoader.class file"
	fi
	
	if $doserver; then
		#CHECK_FILE "$MCSERVER" "Minecraft server jar"
		#CHECK_DIR "$BTWARCHIVE/MINECRAFT_SERVER-JAR" "BTW server files"
	fi
	
	MKCLEANTEMP "$SCRIPTDIR/temp/createjar"
}

main "$@"
echo "COMPLETE!"
#EXITCLEAN 0