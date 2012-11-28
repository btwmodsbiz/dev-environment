#!/bin/bash

# Prevent script from being included directly.
[ -z "$__COMMON_DIR" ] && exit 1

function CHECKISWIN() {
	if [ -z "$ISWIN" ]; then
		local UNAMECHECK="$(uname -s)"
		if [ "${UNAMECHECK:0:5}" == "MSYS_" -o "${UNAMECHECK:0:8}" == "MINGW32_" ]; then
			ISWIN=true
		else
			ISWIN=false
		fi
	fi
}

function FIXPATH() {
	CHECKISWIN
	
	local fixedpath=
	local dirname="$1"
	shift
	
	[ -z "$dirname" -o ! -d "$dirname" ] && return 1
	
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

function FIXPATH_SAFE() {
	VALIDATE_ARGUMENTS $FUNCNAME -l1 -d1 -- $@
	FIXPATH || EXITCLEAN 1
}

function CHECKZIP() {
	if [ -z "$ZIPCMD" ]; then
		CHECKISWIN
		
		if command -v zip &> /dev/null; then
			ZIPCMD=zip
			return 0
			
		elif $ISWIN; then
			if [ -f "$__COMMON_DIR/7za/7za.exe" ]; then
				ZIPCMD=7za
				ZIPPATH="$(FIXPATH "$__COMMON_DIR/7za" 7za.exe)"
				[ $? -eq 0 ] && return 0
			fi
			
			echo
			echo "ERROR: The '7za.exe' command could not be located in:"
			echo "    $__COMMON_DIR/7za"
			EXITCLEAN 1
		fi
		
		echo
		echo "ERROR: The 'zip' command is not available on your system or is not on your \$PATH."
		EXITCLEAN 1
	fi
}

function CHECKUNZIP() {
	if [ -z "$UNZIPCMD" ]; then
		CHECKISWIN
		
		if command -v unzip &> /dev/null; then
			UNZIPCMD=zip
			return 0
			
		elif $ISWIN; then
			if [ -f "$__COMMON_DIR/7za/7za.exe" ]; then
				UNZIPCMD=7za
				ZIPPATH="$(FIXPATH "$__COMMON_DIR/7za" 7za.exe)"
				[ $? -eq 0 ] && return 0
			fi
			
			echo
			echo "ERROR: The '7za.exe' command could not be located in:"
			echo "    $__COMMON_DIR/7za"
			EXITCLEAN 1
		fi
		
		echo
		echo "ERROR: The 'unzip' command is not available on your system or is not on your \$PATH."
		EXITCLEAN 1
	fi
}

function CHECKPYTHON() {
	CHECKISWIN
	
	if command -v python &> /dev/null; then
		PYCMD=python
		return 0
		
	elif $ISWIN; then
		if [ -f "$PYTHON_WIN_DIR/python_mcp.exe" ]; then
			PYCMD="$(FIXPATH "$PYTHON_WIN_DIR" python_mcp.exe)"
			[ $? -eq 0 ] && return 0
		fi
		
		echo
		echo "ERROR: The 'python_mcp.exe' command could not be located in:"
		echo "    $PYTHON_WIN_DIR"
		EXITCLEAN 1
	fi
	
	echo
	echo "ERROR: The 'python' command is not available on your system or is not on your \$PATH."
	EXITCLEAN 1
}

function CHECKJAVAC() {
	if [ -z "$JAVACCMD" ]; then
		CHECKISWIN
		
		if command -v javac &> /dev/null; then
			JAVACCMD=javac
			return 0
			
		elif $ISWIN; then
			local jdkcount="$(find "$JAVA_WIN_DIR" -mindepth 1 -maxdepth 1 -iname 'jdk1.*' | wc -l | tr -d ' \t')"
			
			if [ "$jdkcount" == "" ] || (echo "$jdkcount" | grep -vq '^[0-9]$'); then
				echo "ERROR: Internal error while attempting to find JDKs in c:\\Program Files\\Java" && EXITCLEAN 1
				
			elif [ $jdkcount -gt 1 ]; then
				echo "ERROR: More than one JDK was found in /c/Program Files/Java"
				echo "Instead, set the JDK you would like to use on your \$PATH"
				echo "e.g. PATH=\"\$PATH:$(find "$JAVA_WIN_DIR" -mindepth 1 -maxdepth 1 -iname 'jdk1.*' | head -n 1)"/bin\"
				EXITCLEAN 1
				
			elif [ $jdkcount -eq 1 ]; then
				JAVACCMD="$(FIXPATH "$(find "$JAVA_WIN_DIR" -mindepth 1 -maxdepth 1 -iname 'jdk1.*')/bin" javac.exe)"
			fi
		fi
		
		echo
		echo "ERROR: The 'javac' command is not available on your system or is not on your \$PATH."
		EXITCLEAN 1
	fi
}

function ZIPADD() {
	CHECKZIP
	
	local create=
	[ "$1" == "-c" ] && create=true && shift
	
	local archive="$1"; shift
	
	[ -z "$create" -a ! -f "$archive" ] && return 1
	[ -n "$create" -a -f "$archive" ] && return 1
	
	echo "$archive"
	
	if [ "$ZIPCMD" == "7za" ]; then
		cmd.exe //c "$ZIPPATH" a -tzip "$(FIXPATH "$(dirname "$archive")" "$(basename "$archive")")" "$@"
		return $?
	else
		zip "$archive" "$@"
		return $?
	fi
}

function ZIPADD_SAFE() {
	local quiet=false
	[ "$1" == "-q" ] && quiet=true && shift
	
	local create=
	[ "$1" == "-c" ] && create='-c' && shift
	
	VALIDATE_ARGUMENTS $FUNCNAME -l1 -- $@
	
	local archiveprefix="$1"; shift
	local archive="$1"; shift
	
	$quiet || echo "Adding to $archive archive..."
	ZIPADD $create "$archiveprefix$archive" $@ &> "$TEMPDIR/zipadd.out"
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/zipadd.out"
}

function ZIPDEL() {
	CHECKZIP
	
	local archive="$1"; shift
	
	[ ! -f "$archive" ] && return 1
	
	if [ "$ZIPCMD" == "7za" ]; then
		cmd.exe //c "$ZIPPATH" d -tzip "$archive" "$@"
		return $?
	else
		zip -d "$archive" "$@"
		return $?
	fi
}

function ZIPEXTRACT() {
	CHECKUNZIP
	
	local archive="$1"; shift
	local destination="$1"; shift
	
	[ ! -f "$archive" ] && return 1
	[ ! -d "$destination" ] && return 1
	
	if [ "$UNZIPCMD" == "7za" ]; then
		cmd.exe //c "$ZIPPATH" x -tzip -o"$(FIXPATH "$destination")" "$(FIXPATH "$(dirname "$archive")" "$(basename "$archive")")" "$@"
		return $?
	else
		unzip -o "$archive" -d "$destination" "$@"
		return $?
	fi
}

function ZIPEXTRACT_SAFE() {
	local quiet=false
	[ "$1" == "-q" ] && quiet=true && shift
	
	VALIDATE_ARGUMENTS $FUNCNAME -l2 -f1 -d2 -- $@
	
	local archiveprefix="$1"; shift
	local archive="$1"; shift
	local dest="$1"; shift
	
	# Allow first argument to be optional.
	if [ -z "$dest" ]; then
		dest="$archive"
		archive="$archiveprefix"
		archiveprefix=
	fi
	
	$quiet || echo "Extracting $archive..."
	ZIPEXTRACT "$archiveprefix$archive" "$dest" $@ &> "$TEMPDIR/zipextract.out"
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/zipextract.out"
}

true
