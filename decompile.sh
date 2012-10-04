#!/bin/bash

. bin/common.sh

function main() {
	CHECKPYTHON
	local cfgpath="$(FIXPATH "$SCRIPTDIR/$CONF" mcp-decompile.cfg)"
	local scriptpath="$(FIXPATH "$SCRIPTDIR/$MCP/runtime" decompile.py)"
	
	cd "$SCRIPTDIR/$MCP"
	"$PYCMD" "$scriptpath" -r -c "$cfgpath"
}

main "$@"
EXITCLEAN 0