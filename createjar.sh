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
	declare -r SYNTAX="Syntax: $0 <client|server|both>"
	
	# Argument defaults
	local outdir="$SCRIPTDIR/$MCPJARS"
	local doclient=false
	local doserver=false
	
	parse_arguments "$@"
	init_verify
	
	copy_fresh_files
	copy_mod_files
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
			"-d")
				shift
				outdir="$1"
				;;
			*)
				SYNTAX "Unexpected argument: $1"
				;;
		esac
		shift
	done
}

function init_verify() {
	if [ ! -d "$outdir" ]; then
		echo
		echo "The jar output directory does not exist: $outdir"
		EXITCLEAN 1
	fi
	
	CHECKZIP
	
	if $doclient; then
		CHECK_FILE_SAFE "$SCRIPTDIR/$MCCLIENT" "Minecraft client jar"
		#CHECK_DIR_SAFE "$SCRIPTDIR/$MCRESOURCES" "Minecraft resources directory"
		CHECK_DIR_SAFE "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT-JAR" "BTW client files"
		CHECK_DIR_SAFE "$SCRIPTDIR/$MLARCHIVE" "ModLoader directory"
		CHECK_FILE_SAFE "$SCRIPTDIR/$MLARCHIVE/ModLoader.class" "ModLoader ModLoader.class file"
	fi
	
	if $doserver; then
		CHECK_FILE_SAFE "$SCRIPTDIR/" "$MCSERVER" "Minecraft server jar"
		CHECK_DIR_SAFE "$SCRIPTDIR/" "$BTWARCHIVE/MINECRAFT_SERVER-JAR" "BTW server files"
	fi
	
	
	MKDIR_SAFE "$outdir/bin"
	
	MKCLEANTEMP "$SCRIPTDIR/temp/createjar"
}

# Copy fresh files to the jar directory.
function copy_fresh_files() {
	if $doclient; then
		echo "Copying fresh Minecraft client bin directory..."
		cp -fR "$SCRIPTDIR/$MCBIN" "$outdir/" > /dev/null
		[ $? -ne 0 ] && echo "ERROR: Failed to copy directory." && EXITCLEAN 1
		
		#echo "Copying fresh Minecraft resources directory..."
		#cp -fR "$SCRIPTDIR/$MCRESOURCES" "$outdir/" > /dev/null
		#[ $? -ne 0 ] && echo "ERROR: Failed to copy directory." && EXITCLEAN 1
	fi
	
	if $doserver; then
		echo "Copying fresh Minecraft server jar..."
		cp -f "$SCRIPTDIR/$MCSERVER" "$outdir/" > /dev/null
		[ $? -ne 0 ] && echo "ERROR: Failed to copy file." && EXITCLEAN 1
	fi
}

# Copy mod into Minecraft.
function copy_mod_files() {
	if $doclient; then
		local archive="$outdir/bin/minecraft.jar"
		#"$(FIXPATH "$outdir/bin" minecraft.jar)"
	
		local mlfiles="$(FIXPATH "$SCRIPTDIR/$MLARCHIVE" '*')"
		echo "Adding ModLoader files to minecraft.jar..."
		ZIPADD "$archive" "$mlfiles" &> "$TEMPDIR/adding-modloader.out"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/adding-modloader.out"
	
		local btwfiles="$(FIXPATH "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT-JAR" '*')"
		echo "Adding BTW files to minecraft.jar..."
		ZIPADD "$archive" "$btwfiles" &> "$TEMPDIR/adding-btw-client.out"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/adding-btw-client.out"
	
		echo "Removing META-INF from minecraft.jar..."
		ZIPDEL "$archive" "META-INF" &> "$TEMPDIR/removing-metainf-client.out"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/removing-metainf-client.out"
	fi
	
	if $doserver; then
		local archive="$outdir/minecraft_server.jar"
		local addedfiles="$(FIXPATH "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT_SERVER-JAR" '*')"
		
		echo "Adding BTW files to minecraft_server.jar..."
		ZIPADD "$archive" "$addedfiles" &> "$TEMPDIR/adding-btw-client.out"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/adding-btw-client.out"
	
		#echo "Removing META-INF from minecraft_server.jar..."
		#ZIPDEL "$archive" "META-INF" &> "$TEMPDIR/removing-metainf-server.out"
		#[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/removing-metainf-server.out"
	fi
}

main "$@"
echo "COMPLETE!"
EXITCLEAN 0
