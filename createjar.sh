#!/bin/bash

. bin/common.sh

function main() {
	# Set path constants.
	declare -r MOJANGARCHIVE=archives/mojang
	declare -r MCBIN=$MOJANGARCHIVE/bin
	declare -r MCCLIENT=$MCBIN/minecraft.jar
	declare -r MCRESOURCES=$MOJANGARCHIVE/resources
	declare -r MCSERVER=$MOJANGARCHIVE/minecraft_server.jar
	declare -r BTWARCHIVE=archives/btw
	declare -r MCP=mcp
	declare -r MCPJARS=$MCP/jars
	
	# Set other constants.
	#declare -r TEMPDIR="$SCRIPTDIR/temp/createjar"
	declare -r SYNTAX="Syntax: $0 <client|server|both>"
	
	local doclient=false
	local doserver=false
	
	parse_arguments "$@"
	init_verify
	
	copy_fresh_files
	copy_btw_files
	
	echo "COMPLETE!"
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
		#eval $(printf "$ZIPADDCMD" "$SCRIPTDIR/$MCPJARS/bin/minecraft.jar" "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT-JAR/\*") > "$TEMPDIR/adding-btw-client.out" 2>&1
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/adding-btw-client.out"
	
		echo "Removing META-INF from minecraft.jar..."
		ZIPDEL "$archive" "META-INF" &> "$TEMPDIR/adding-btw-client.out"
		#eval $(printf "$ZIPRMCMD" "$SCRIPTDIR/$MCPJARS/bin/minecraft.jar" META-INF) > "$TEMPDIR/removing-metainf-client.out" 2>&1
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/removing-metainf-client.out"
	fi
	
	if $doserver; then
		local archive="$(FIXPATH "$SCRIPTDIR/$MCPJARS" minecraft_server.jar)"
		local addedfiles="$(FIXPATH "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT_SERVER-JAR" '*')"
		
		echo "Adding BTW files to minecraft_server.jar..."
		ZIPADD "$archive" "$addedfiles" &> "$TEMPDIR/adding-btw-client.out"
		#eval $(printf "$ZIPADDCMD" "$SCRIPTDIR/$MCPJARS/minecraft_server.jar" "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT_SERVER-JAR/\*") > "$TEMPDIR/adding-btw-server.out" 2>&1
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/adding-btw-client.out"
	
		echo "Removing META-INF from minecraft_server.jar..."
		ZIPDEL "$archive" "META-INF" &> "$TEMPDIR/removing-metainf-server.out"
		#eval $(printf "$ZIPRMCMD" "$SCRIPTDIR/$MCPJARS/minecraft_server.jar" META-INF) > "$TEMPDIR/removing-metainf-server" 2>&1
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/removing-metainf-server.out"
	fi
}

main "$@"
exit 0

declare -r MOJANGARCHIVE=archives/mojang
declare -r MCBIN=$MOJANGARCHIVE/bin
declare -r MCCLIENT=$MCBIN/minecraft.jar
declare -r MCRESOURCES=$MOJANGARCHIVE/resources
declare -r MCSERVER=$MOJANGARCHIVE/minecraft_server.jar

declare -r BTWARCHIVE=archives/btw
declare -r MCP=mcp
declare -r MCPJARS=$MCP/jars

declare -r TEMPDIR="$SCRIPTDIR/temp/createjar"
declare -r SYNTAX="Syntax: $0 <client|server|both>"

if [ ! -d "$SCRIPTDIR/$MCPJARS" ]; then
	echo
	echo "MCP jars directory does not exist."
	echo "You may need to install MCP to $SCRIPTDIR/$MCP"
	EXITCLEAN 1
fi

if ! CHECKZIP; then
	echo
	echo "The 'zip' command is not available on your system or is not on your \$PATH."
	EXITCLEAN 1
fi

#declare -r UNAMECHECK="$(uname -s)"
#if command zip &> /dev/null; then
#	declare -r ZIPMODE=zip
#	#declare -r ZIP="zip %s %s"
#	#declare -r ZIPRMCMD="zip -d %s %s"
#elif [ "${UNAMECHECK:0:5}" == "MSYS_" -o "${UNAMECHECK:0:8}" == "MINGW32_" ]; then
#	declare -r ZIPMODE=7za
#	declare -r ZIPPATH="$(FIXPATH "$SCRIPTDIR/bin/7za" 7za.exe)"
#	#declare -r ZIPADDCMD="$SCRIPTDIR/bin/7za/7za.exe a -tzip %s %s"
#	#declare -r ZIPRMCMD="$SCRIPTDIR/bin/7za/7za.exe d -tzip %s %s"
#else
#	echo
#	echo "The 'zip' command is not available on your system or is not on your \$PATH."
#	EXITCLEAN 1
#fi

# ====================================
# Parse arguments.
# ====================================

if [ $# -gt 1 ]; then
	SYNTAX "Too many arguments."
fi

if [ "$1" == "-h" -o "$1" == "--help" -o "$1" == "-?" ]; then
	SYNTAX
fi

doclient=
doserver=

if [ "$1" == "client" -o "$1" == "both" ]; then
	doclient=true
fi
if [ "$1" == "server" -o "$1" == "both" ]; then
	doserver=true
fi

if [ "$doclient$doserver" == "" ]; then
	SYNTAX "First argument must be 'client', 'server' or 'both'."
fi

# ====================================
# Verify that required files exist.
# ====================================

if $doclient; then
	CHECK_FILE "$MCCLIENT" "Minecraft client jar"
	CHECK_DIR "$MCRESOURCES" "Minecraft resources directory"
	CHECK_DIR "$BTWARCHIVE/MINECRAFT-JAR" "BTW client files"
fi

if $doserver; then
	CHECK_FILE "$MCSERVER" "Minecraft server jar"
	CHECK_DIR "$BTWARCHIVE/MINECRAFT_SERVER-JAR" "BTW server files"
fi

# ====================================
# Set up directories.
# ====================================

RMTEMP
[ $? -ne 0 ] && echo "ERROR: Could not remove the old temp directory at:" && echo "    $TEMPDIR" && EXITCLEAN 1

mkdir -p "$TEMPDIR" > /dev/null
[ $? -ne 0 ] && echo "ERROR: Could not create temp directory at:" && echo "    $TEMPDIR" && EXITCLEAN 1

# ====================================
# Copy fresh files to the jar directory.
# ====================================

if $doclient; then
	echo "Copying fresh Minecraft client bin directory..."
	cp -fR "$SCRIPTDIR/$MCBIN" "$SCRIPTDIR/$MCPJARS/" #> /dev/null
	[ $? -ne 0 ] && echo "ERROR: Failed to copy directory." && EXITCLEAN 1
	
	echo "Copying fresh Minecraft resources directory..."
	cp -fR "$SCRIPTDIR/$MCRESOURCES" "$SCRIPTDIR/$MCPJARS/" #> /dev/null
	[ $? -ne 0 ] && echo "ERROR: Failed to copy directory." && EXITCLEAN 1
fi

if $doserver; then
	echo "Copying fresh Minecraft server jar..."
	cp -f "$SCRIPTDIR/$MCSERVER" "$SCRIPTDIR/$MCPJARS/" #> /dev/null
	[ $? -ne 0 ] && echo "ERROR: Failed to copy file." && EXITCLEAN 1
fi

# ====================================
# Copy BTW into Minecraft.
# ====================================

if $doclient; then
	local archive="$(FIXPATH "$SCRIPTDIR/$MCPJARS/bin" minecraft.jar)"
	local addedfiles="$(FIXPATH "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT-JAR" '*')"

	echo "Adding BTW files to minecraft.jar..."
	ZIPADD "$archive" "$addedfiles" "$TEMPDIR/adding-btw-client.out"
	#eval $(printf "$ZIPADDCMD" "$SCRIPTDIR/$MCPJARS/bin/minecraft.jar" "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT-JAR/\*") > "$TEMPDIR/adding-btw-client.out" 2>&1
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/adding-btw-client.out"

	echo "Removing META-INF from minecraft.jar..."
	ZIPDEL "$archive" "META-INF" "$TEMPDIR/adding-btw-client.out"
	#eval $(printf "$ZIPRMCMD" "$SCRIPTDIR/$MCPJARS/bin/minecraft.jar" META-INF) > "$TEMPDIR/removing-metainf-client.out" 2>&1
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/removing-metainf-client.out"
exit
fi

if $doserver; then
	echo "Adding BTW files to minecraft_server.jar..."
	eval $(printf "$ZIPADDCMD" "$SCRIPTDIR/$MCPJARS/minecraft_server.jar" "$SCRIPTDIR/$BTWARCHIVE/MINECRAFT_SERVER-JAR/\*") > "$TEMPDIR/adding-btw-server.out" 2>&1
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/adding-btw-server.out"

	echo "Removing META-INF from minecraft_server.jar..."
	eval $(printf "$ZIPRMCMD" "$SCRIPTDIR/$MCPJARS/minecraft_server.jar" META-INF) > "$TEMPDIR/removing-metainf-server" 2>&1
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/removing-metainf-server.out"
fi

echo "COMPLETE!"

EXITCLEAN 0
