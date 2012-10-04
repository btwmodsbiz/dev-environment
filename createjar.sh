#!/bin/bash

. bin/common.sh

function main() {
	declare -r SYNTAX="Syntax: $0 <client|server|both>"
	
	# Argument defaults
	local doclient=false
	local doserver=false
	
	parse_arguments "$@"
	init_verify
	
	copy_fresh_files
	copy_btw_files
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
	
	CHECKZIP
	
	if $doclient; then
		CHECK_FILE "$MCCLIENT" "Minecraft client jar"
		CHECK_DIR "$MCRESOURCES" "Minecraft resources directory"
		CHECK_DIR "$BTWARCHIVE/MINECRAFT-JAR" "BTW client files"
	fi
	
	if $doserver; then
		CHECK_FILE "$MCSERVER" "Minecraft server jar"
		CHECK_DIR "$BTWARCHIVE/MINECRAFT_SERVER-JAR" "BTW server files"
	fi
	
	MKCLEANTEMP "$SCRIPTDIR/temp/createjar"
}

# Copy fresh files to the jar directory.
function copy_fresh_files() {
	if $doclient; then
		echo "Copying fresh Minecraft client bin directory..."
		cp -fR "$SCRIPTDIR/$MCBIN" "$SCRIPTDIR/$MCPJARS/" > /dev/null
		[ $? -ne 0 ] && echo "ERROR: Failed to copy directory." && EXITCLEAN 1
		
		echo "Copying fresh Minecraft resources directory..."
		cp -fR "$SCRIPTDIR/$MCRESOURCES" "$SCRIPTDIR/$MCPJARS/" > /dev/null
		[ $? -ne 0 ] && echo "ERROR: Failed to copy directory." && EXITCLEAN 1
	fi
	
	if $doserver; then
		echo "Copying fresh Minecraft server jar..."
		cp -f "$SCRIPTDIR/$MCSERVER" "$SCRIPTDIR/$MCPJARS/" > /dev/null
		[ $? -ne 0 ] && echo "ERROR: Failed to copy file." && EXITCLEAN 1
	fi
}

# Copy BTW into Minecraft.
function copy_btw_files() {
	if $doclient; then
		local archive="$(FIXPATH "$SCRIPTDIR/$MCPJARS/bin" minecraft.jar)"
		local addedfiles="$(FIXPATH "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT-JAR" '*')"
	
		echo "Adding BTW files to minecraft.jar..."
		ZIPADD "$archive" "$addedfiles" &> "$TEMPDIR/adding-btw-client.out"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/adding-btw-client.out"
	
		echo "Removing META-INF from minecraft.jar..."
		ZIPDEL "$archive" "META-INF" &> "$TEMPDIR/adding-btw-client.out"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/removing-metainf-client.out"
	fi
	
	if $doserver; then
		local archive="$(FIXPATH "$SCRIPTDIR/$MCPJARS" minecraft_server.jar)"
		local addedfiles="$(FIXPATH "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT_SERVER-JAR" '*')"
		
		echo "Adding BTW files to minecraft_server.jar..."
		ZIPADD "$archive" "$addedfiles" &> "$TEMPDIR/adding-btw-client.out"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/adding-btw-client.out"
	
		echo "Removing META-INF from minecraft_server.jar..."
		ZIPDEL "$archive" "META-INF" &> "$TEMPDIR/removing-metainf-server.out"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/removing-metainf-server.out"
	fi
}

main "$@"
echo "COMPLETE!"
EXITCLEAN 0