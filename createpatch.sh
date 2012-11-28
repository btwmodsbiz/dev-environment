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
	init_verify
	
	echo "Copying a fresh MCP..."
	cp -r "$SCRIPTDIR/$MCPARCHIVE/"* "$TEMPDIR" &> "$TEMPDIR/cp_mcparchive.out"
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/cp_mcparchive.out"
	
	#echo "Copying the MCP dev environment's config files..."
	#cp -R "$SCRIPTDIR/$MCP/conf/"* "$TEMPDIR/conf" &> "$TEMPDIR/cp_mcpconf.out"
	#[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/cp_mcpconf.out"
	
	echo "Updating MCP..."
	cd "$TEMPDIR" && "$PYCMD" "$(FIXPATH "$TEMPDIR/runtime" updatemcp.py)" --force &> "$TEMPDIR/mcp_update.out"
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/mcp_update.out"
	cd "$SCRIPTDIR"
	
	echo "Creating server jar..."
	"$SCRIPTDIR/createjar.sh" server -d "$TEMPDIR/jars" &> "$TEMPDIR/createjar.out"
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/createjar.out"
	
	echo "Decompiling..."
	pyscript="$(FIXPATH "$TEMPDIR/runtime" decompile.py)"
	cd "$TEMPDIR" && "$PYCMD" "$pyscript" &> "$TEMPDIR/mcp_decompile.out"
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/mcp_decompile.out"
	cd "$SCRIPTDIR"

	#--nocomments --norenamer --noreformat --norecompile
	#&> "$TEMPDIR/mcp_decompile.out"
	
	echo "Applying modified server src..."
	git archive --remote="$SCRIPTDIR/$SERVER_SRC_PROJECT" master src | tar -x --strip-components=1 -C "$TEMPDIR/src/minecraft_server"
	
	echo "Applying server API..."
	git archive --remote="$SCRIPTDIR/$SERVER_SRC_PROJECT" master src | tar -x --strip-components=1 -C "$TEMPDIR/src/minecraft_server"
	
	exit 0
	
	echo "Exporting '$SERVER_SRC_DECOMPILEBRANCH' branch from $SERVER_SRC_PROJECT..."
	git archive --remote="$SCRIPTDIR/$SERVER_SRC_PROJECT" "$SERVER_SRC_DECOMPILEBRANCH" src | tar -x --strip-components=1 -C "$TEMPDIR/src/minecraft_server"
	
	echo "Updating MCP MD5s..."
	cd "$TEMPDIR" && "$PYCMD" "$(FIXPATH "$TEMPDIR/runtime" updatemd5.py)" --force &> "$TEMPDIR/mcp_updatemd5s.out"
	[ $? -ne 0 -o ! -s "$TEMPDIR/temp/server.md5" ] && FAIL_CAT "$TEMPDIR/mcp_updatemd5s.out"
	
	rm -rf "$TEMPDIR/src/minecraft_server"
	mkdir "$TEMPDIR/src/minecraft_server"
	
	echo "Exporting 'master' branch from $SERVER_SRC_PROJECT..."
	git archive --remote="$SCRIPTDIR/$SERVER_SRC_PROJECT" master src | tar -x --strip-components=1 -C "$TEMPDIR/src/minecraft_server"
	
	echo "Reobfuscating..."
	cd "$TEMPDIR" && "$PYCMD" "$(FIXPATH "$TEMPDIR/runtime" reobfuscate.py)" --all &> "$TEMPDIR/mcp_reobfuscate.out"
	[ $? -ne 0 ] && FAIL_CAT "$TEMPDIR/mcp_reobfuscate.out"
	
	exit 0
}

function init_verify() {
	CHECKPYTHON
	MKCLEANTEMP "$SCRIPTDIR/temp/createpatch"
	
	MKDIR_SAFE "$TEMPDIR/jar"
	MKDIR_SAFE "$TEMPDIR/src/minecraft_server"
}

main "$@"
echo "COMPLETE!"
EXITCLEAN 0
