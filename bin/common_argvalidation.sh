#!/bin/bash

# Prevent script from being included directly.
[ -z "$__COMMON_DIR" ] && exit 1

function VALIDATE_ARGUMENTS() {
	local safe=
	[ "$1" == '-q' ] && safe='-q' && shift
	
	[ $# -lt 3 ] && INVALID_ARGUMENT_COUNT $safe "$FUNCNAME" $# && return 1

	local funcname="$1"
	shift
	
	local count=
	local lower=
	local upper=
	local nonempty=
	local integer=
	local dir=
	local file=
	local exist=
	
	local arg=
	local val=
	local bool=
	
	while [ $# -gt 0 ]; do
		arg="$1"
		
		# Stop checking args and start validating.
		[ "$arg" == "--" ] && shift && break
		
		# Allow a ! to negate specific arguments.
		bool=true
		[ "$arg" == "!" ] && shift && bool='false'
		[ "${arg:0:1}" == "!" ] && bool='false' && arg="${arg:1}"
		
		# Check if the value is part of the arg (e.g. -i5)
		val="${arg:2:1}"
		arg="${arg:0:2}"
		shift
		
		# Get the value if it was not part of the arg (e.g. -i 5).
		[ -z "$val" ] && val="$1" && shift
		
		# Verify the value is a number.
		printf "%d" "$val" &> /dev/null || INVALID_ARGUMENT_INTEGER $safe "$FUNCNAME" '' "$val" && return 1
		
		case "$arg" in
			"-c")
				count=$val
				;;
			"-l")
				lower=$val
				;;
			"-u")
				upper=$val
				;;
			"-n")
				nonempty[$val]=$bool
				;;
			"-i")
				integer[$val]=$bool
				;;
			"-e")
				exist[$val]=$bool
				;;
			"-d")
				dir[$val]=$bool
				;;
			"-f")
				file[$val]=$bool
				;;
			*)
				echo "ERROR: You must end $FUNCNAME arguments with a -- before starting the arguments to validate: $arg" && EXITCLEAN 1
				;;
		esac
	done
	
	# Validate the number of arguments.
	[ -n "$count" ] && [ "$#" -ne "$count" ] && INVALID_ARGUMENT_COUNT $safe "$funcname" $# && return 1
	[ -n "$lower" ] && [ "$#" -lt "$lower" ] && INVALID_ARGUMENT_COUNT $safe "$funcname" $# && return 1
	[ -n "$upper" ] && [ "$#" -gt "$upper" ] && INVALID_ARGUMENT_COUNT $safe "$funcname" $# && return 1
	
	# Validate individual arguments.
	local argnum=1
	while [ $# -gt 0 ]; do
		echo ":$argnum"
		
		[ -n "${nonempty[$argnum]}" -a -z "$1" ] && INVALID_ARGUMENT_EMPTY $safe "$funcname" $argnum && return 1
		
		if [ -n "${integer[$argnum]}" ]; then
			printf "%d" "$1" &> /dev/null || INVALID_ARGUMENT_INTEGER $safe "$funcname" $argnum "$1" && return 1
		fi
		
		if [ "${dir[$argnum]}" == "true" -a ! -d "$1" ] \
			|| [ "${dir[$argnum]}" == "false" -a -d "$1" ]; then
			INVALID_ARGUMENT_DIR $safe "$funcname" $argnum "$1" "${dir[$argnum]}" && return 1
		fi
		
		if [ "${file[$argnum]}" == "true" -a ! -f "$1" ] \
			|| [ "${file[$argnum]}" == "false" -a -f "$1" ]; then
			INVALID_ARGUMENT_FILE $safe "$funcname" $argnum "$1" "${file[$argnum]}" && return 1
		fi
		
		if [ "${exist[$argnum]}" == "true" -a ! -e "$1" ] \
			|| [ "${exist[$argnum]}" == "false" -a -e "$1" ]; then
			INVALID_ARGUMENT_EXIST $safe "$funcname" $argnum "$1" "${exist[$argnum]}" && return 1
		fi
		
		shift
		(( argnum++ ))
	done
}

function INVALID_ARGUMENT() {
	local safe=true; [ "$1" == '-q' ] && safe=false && shift
	local funcname="$1"
	local argnum="$2"
	local argval="$3"
	
	if printf "%d" "$1" &> /dev/null; then
		LAST_ERROR_MESSAGE="ERROR: Argument $argnum for $funcname is invalid: $argval"
	else
		LAST_ERROR_MESSAGE="ERROR: Invalid argument for $funcname: $argval"
	fi
	
	$safe && echo "$LAST_ERROR_MESSAGE" && EXITCLEAN 1
}

function INVALID_ARGUMENT_EMPTY() {
	local safe=true; [ "$1" == '-q' ] && safe=false && shift
	local funcname="$1"
	local argnum="$2"
	
	LAST_ERROR_MESSAGE="ERROR: Argument $argnum for $funcname cannot be empty."
	$safe && echo "$LAST_ERROR_MESSAGE" && EXITCLEAN 1
}

function INVALID_ARGUMENT_INTEGER() {
	local safe=true; [ "$1" == '-q' ] && safe=false && shift
	local funcname="$1"
	local argnum="$2"
	local argval="$3"
	
	LAST_ERROR_MESSAGE="ERROR: Argument $argnum for $funcname is not a valid integer: $argval"
	$safe && echo "$LAST_ERROR_MESSAGE" && EXITCLEAN 1
}

function INVALID_ARGUMENT_COUNT() {
	local safe=true; [ "$1" == '-q' ] && safe=false && shift
	local funcname="$1"
	local argcount="$2"
	
	LAST_ERROR_MESSAGE="ERROR: Invalid number of $funcname arguments: $argcount"
	$safe && echo "$LAST_ERROR_MESSAGE" && EXITCLEAN 1
}

function INVALID_ARGUMENT_EXIST() {
	local safe=true; [ "$1" == '-q' ] && safe=false && shift
	local funcname="$1"
	local argnum="$2"
	local argval="$3"
	local bool="$4"
	
	[ "$bool" == "true" ] && bool='does not exist' || bool='already exists'
	
	LAST_ERROR_MESSAGE="ERROR: Argument $argnum for $funcname $bool: $argval"
	$safe && echo "$LAST_ERROR_MESSAGE" && EXITCLEAN 1
}

function INVALID_ARGUMENT_FILE() {
	local safe=true; [ "$1" == '-q' ] && safe=false && shift
	local funcname="$1"
	local argnum="$2"
	local argval="$3"
	local bool="$4"
	
	[ "$bool" == "true" ] && bool='is not' || bool='cannot be'
	
	LAST_ERROR_MESSAGE="ERROR: Argument $argnum for $funcname $bool a file: $argval"
	$safe && echo "$LAST_ERROR_MESSAGE" && EXITCLEAN 1
}

function INVALID_ARGUMENT_DIR() {
	local safe=true; [ "$1" == '-q' ] && safe=false && shift
	local funcname="$1"
	local argnum="$2"
	local argval="$3"
	local bool="$4"
	
	[ "$bool" == "true" ] && bool='is not' || bool='cannot be'
	
	LAST_ERROR_MESSAGE="ERROR: Argument $argnum for $funcname $bool a directory: $argval"
	$safe && echo "$LAST_ERROR_MESSAGE" && EXITCLEAN 1
}

true
