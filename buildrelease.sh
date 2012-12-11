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
	declare -r SYNTAX="Syntax: $BASH_SOURCE <client|server|both> [OPTIONS]"
	
	local builddir="$SCRIPTDIR/build"
	
	# Actions to be performed.
	local doclient=false
	local doserver=false
	
	# Whether or not to use the working copy of the repo.
	local useworkingdir=false
	
	# Default Git branches
	local clientsrc=master
	local clientapi=master
	local serversrc=master
	local serverapi=master
	local servermods=master
	
	# Class paths for javac
	local clientclasspath='.'
	local serverclasspath='.'
	
	parse_arguments "$@"
	init_verify
	
	$doclient && build_side server
	$doserver && build_side server
	
	echo
}

function build_side() {
	local side="$1"
	
	echo
	echo "==== Building $side ===="
	
	echo
	echo "Extracting $side dependencies:"
	echo "------------------------------------------"
	extract_dependencies $side
	
	echo
	echo "Collecting $side sources:"
	echo "------------------------------------------"
	collect_sources $side
	
	echo
	echo "Compiling $side:"
	echo "------------------------------------------"
	compile $side
	
	echo
	echo "Creating jars:"
	echo "------------------------------------------"
	create_jars $side
}

function extract_dependencies() {
	local side="$1"
	local depfile="conf/$side-dependencies.txt"
	local bindir="$TEMPDIR/$side-bin"
	local command=
	local nojava=
	local classpath=
	
	while IFS="" read line; do
		IFS=" " set -- $line
		
		command="$1"
		shift
		
		# Strip whitespace from the command.
		command="$(echo "$command" | tr -d '\t ')"
		
		# Skip blank lines and comments.
		[ -z "$command" -o "${command:0:1}" == "#" ] \
			&& continue
		
		case "$command" in
			jar|zip|dir)
				nojava=false
				
				if [ "$1" == "-nojava" ]; then
					nojava=true
					shift
					
					rm -rf "$TEMPDIR/temp-nojava"
					[ $? -ne 0 ] && echo "ERROR: Could not remove $TEMPDIR/temp-nojava" && EXITCLEAN 1
					
					MKDIR_SAFE "$TEMPDIR/temp-nojava"
				fi
				
				if [ "$command" == "dir" ]; then
					[ ! -d "$SCRIPTDIR/$1" ] \
						&& echo "ERROR: Missing dependency: $1" \
						&& EXITCLEAN 1
					
					classpath="$(FIXPATH "$SCRIPTDIR/$1" "")"
					
					cp -r "$SCRIPTDIR/$1"/* "$($nojava && echo "$TEMPDIR/temp-nojava" || echo "$bindir")"
						
				else
					[ ! -f "$SCRIPTDIR/$1" ] \
						&& echo "ERROR: Missing dependency: $1" \
						&& EXITCLEAN 1
					
					classpath="$(FIXPATH "$SCRIPTDIR/" "$1")"
					
					[ "$side" == "client" ] \
						&& clientclasspath="$clientclasspath$JAVAPATHSEP$classpath" \
						|| serverclasspath="$serverclasspath$JAVAPATHSEP$classpath"
					
					ZIPEXTRACT_SAFE "$SCRIPTDIR/" "$1" "$($nojava && echo "$TEMPDIR/temp-nojava" || echo "$bindir")"
				fi
				
				if $nojava; then
					# Find java/class files.
					find "$TEMPDIR/temp-nojava" -type f \( -iname '*.java' -o -iname '*.class' \) -print0 > "$TEMPDIR/nojava-find.out" 2> "$TEMPDIR/nojava-find.err"
					[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/nojava-find.err" "'find' command failed while listing class/java files."
					
					# Remove them.
					cat "$TEMPDIR/nojava-find.out" | xargs -0 rm &> "$TEMPDIR/nojava-rm.err"
					[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/nojava-rm.err" "Failed to remove class/java files."
					
					# Copy the remaining files.
					cp -R "$TEMPDIR/temp-nojava"/* "$bindir" &> "$TEMPDIR/nojava-cp.out"
					[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/nojava-cp.err" "Failed to copy non-java files."
				fi
				;;
				
			*)
				echo "ERROR: Invalid dependency line in $depfile:"
				echo "    $line"
				EXITCLEAN 1
				;;
		esac
		
	done < "$SCRIPTDIR/$depfile"
	
	# Remove the META-INF, if it was extracted from the dependencies
	if [ -d "$bindir/META-INF" ]; then
		echo "Removing META-INF..."
		rm -rf "$bindir/META-INF"
		[ $? -ne 0 ] && echo "ERROR: Could not remove $bindir/META-INF" && EXITCLEAN 1
	fi
}

function collect_sources() {
	local side="$1"
	
	if [ "$side" == "server" ]; then
		if $useworkingdir; then
			MKDIR_SAFE "$TEMPDIR/server-src/src"
			
			echo "Copying server-src sources from working dir..."
			cp -r "$SERVER_SRC_PROJECT/src"/* "$TEMPDIR/server-src/src" &> "$TEMPDIR/cp.out" || FAIL_CAT "$TEMPDIR/cp.out"
			
			echo "Copying server-api sources from working dir..."
			cp -r "$SERVER_API_PROJECT/src"/* "$TEMPDIR/server-src/src" &> "$TEMPDIR/cp.out" || FAIL_CAT "$TEMPDIR/cp.out"
			
			echo "Copying server-mods sources from working dir..."
			cp -r "$SERVER_MODS_PROJECT/src"/* "$TEMPDIR/server-src/src" &> "$TEMPDIR/cp.out" || FAIL_CAT "$TEMPDIR/cp.out"
		else
			EXPORT_BRANCH_SAFE "$serversrc" "$SCRIPTDIR/" "$SERVER_SRC_PROJECT" "$TEMPDIR/server-src"
			EXPORT_BRANCH_SAFE "$serverapi" "$SCRIPTDIR/" "$SERVER_API_PROJECT" "$TEMPDIR/server-src"
			EXPORT_BRANCH_SAFE "$servermods" "$SCRIPTDIR/" "$SERVER_MODS_PROJECT" "$TEMPDIR/server-src"
		fi
	fi
}

function compile() {
	local side="$1"
	local srcdir=
	local bindir=
	local classpath=
	
	if [ "$side" == "client" ]; then
		srcdir="$TEMPDIR/client-src"
		bindir="$(FIXPATH "$TEMPDIR/client-bin")"
		classpath="$clientclasspath"
		
	elif [ "$side" == "server" ]; then
		srcdir="$TEMPDIR/server-src"
		bindir="$(FIXPATH "$TEMPDIR/server-bin")"
		classpath="$serverclasspath"
	fi
	
	cd "$srcdir"
	
	echo "Creating list of java files..."
	find . -type f -name '*.java' > "$TEMPDIR/javasrcdirs.txt" 2> "$TEMPDIR/findjava.out"
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/findjava.out"
	
	echo "Compiling..."
	"$JAVACCMD" -classpath "$classpath" -target 1.6 @"$(FIXPATH "$TEMPDIR" javasrcdirs.txt)" -d "$bindir"
	
	cd "$SCRIPTDIR"
}

function create_jars() {
	local side="$1"
	
	if [ "$side" == "server" ]; then
		echo "Extracting META-INF from original minecraft_server.jar..."
		ZIPEXTRACT_SAFE -q "$SCRIPTDIR/" "archives/mojang/minecraft_server.jar" "$TEMPDIR/server-bin" META-INF/MANIFEST.MF
		
		cd "$TEMPDIR/server-bin"
		
		find btwmod -type d -mindepth 1 -maxdepth 1 > "$TEMPDIR/btwmod-find.out" 2> "$TEMPDIR/btwmod-find.err"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/btwmod-find.err" "Failed to list the btwmod subdirectories."
		
		# Individual btwmod zips.
		while IFS="" read dir; do
			echo "Creating btwmod-$(basename "$dir").zip..."
			
			ZIPADD_SAFE -q -c "$TEMPDIR/" "btwmod-$(basename "$dir").zip" "$dir"
			
			mv "$TEMPDIR/btwmod-$(basename "$dir").zip" "$builddir/btwmods/"
			[ $? -ne 0 ] && echo "ERROR: Could not move zip to final location." && EXITCLEAN 1
			
			rm -rf "$dir"
			[ $? -ne 0 ] && echo "ERROR: Could not remove btwmod directory: $dir" && EXITCLEAN 1
		
		done < "$TEMPDIR/btwmod-find.out"
		
		# Remove the btwmod directory since they are separate.
		rm -rf "$TEMPDIR/server-bin/btwmod"
		[ $? -ne 0 ] && echo "ERROR: Could not remove btwmod directory." && EXITCLEAN 1
		
		echo "Creating minecraft_server.jar..."
		ZIPADD_SAFE -q -c "$TEMPDIR/" "minecraft_server.jar" .
		
		mv "$TEMPDIR/minecraft_server.jar" "$builddir/" &> "$TEMPDIR/mv.out"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/mv.out" "ERROR: Could not move jar to final location."
		
		echo "Creating btwmods.zip..."
		ZIPADD_SAFE -q -c "$TEMPDIR/" "btwmods.zip" btwmods
		
		mv "$TEMPDIR/btwmods.zip" "$builddir/"
		[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/mv.out" "ERROR: Could not move zip to final location."
		
		cd "$SCRIPTDIR"
	fi
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
			-w)
				useworkingdir=true
				;;
			-d|--builddir)
				[ "$2" == "" ] && SYNTAX "Missing argument after $1"
				builddir="$2"
				shift
				;;
			--treeish)
				[ "$2" == "" ] && SYNTAX "Missing argument after $1"
				clientsrc="$2"
				clientapi="$2"
				serversrc="$2"
				serverapi="$2"
				servermods="$2"
				shift
				;;
			-cs|--clientsrc)
				[ "$2" == "" ] && SYNTAX "Missing argument after $1"
				clientsrc="$2"
				shift
				;;
			-ca|--clientapi)
				[ "$2" == "" ] && SYNTAX "Missing argument after $1"
				clientapi="$2"
				shift
				;;
			-ss|--serversrc)
				[ "$2" == "" ] && SYNTAX "Missing argument after $1"
				serversrc="$2"
				shift
				;;
			-sa|--serverapi)
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
	CHECKJAVAC
	
	CHECK_DIR_SAFE "$SCRIPTDIR/" "build" "Build directory"
	CHECK_DIR_SAFE "$SCRIPTDIR/" "build/btwmods" "Build sub-directory (btwmods)"
	
	if $doclient; then
		CHECK_FILE_SAFE "$SCRIPTDIR/" "$MCCLIENT" "Minecraft client jar"
		CHECK_DIR_SAFE "$SCRIPTDIR/" "$BTWARCHIVE/MINECRAFT-JAR" "BTW client files"
		CHECK_DIR_SAFE "$SCRIPTDIR/" "$MLARCHIVE" "ModLoader directory"
		CHECK_FILE_SAFE "$SCRIPTDIR/" "$MLARCHIVE/ModLoader.class" "ModLoader ModLoader.class file"
	fi
	
	if $doserver; then
		CHECK_FILE_SAFE "$SCRIPTDIR/" "$MCSERVER" "Minecraft server jar"
		CHECK_DIR_SAFE "$SCRIPTDIR/" "$BTWARCHIVE/MINECRAFT_SERVER-JAR" "BTW server files"
	fi
	
	MKCLEANTEMP "$SCRIPTDIR/temp/buildrelease"
	
	if $doclient; then
		MKDIR_SAFE "$TEMPDIR/client-bin"
		MKDIR_SAFE "$TEMPDIR/client-src"
	fi
	
	if $doserver; then
		MKDIR_SAFE "$TEMPDIR/server-bin"
		MKDIR_SAFE "$TEMPDIR/server-src"
	fi
}

main "$@"
echo "COMPLETE!"
EXITCLEAN 0
