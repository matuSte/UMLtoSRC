#!/bin/bash

directory="$PWD/../HyperLua/_install"

echo "This script copy (and rewrite) some files from this repository to $directory for testing"

if [ -d $directory ]; then
	read -p "Are you sure? [Y/n] " -n 1 -r
	echo

	if [[ $REPLY =~ ^[Yy]$ ]]
	then
	echo "Ok..."
	echo
		cp -Rf -v -b src/*    ../HyperLua/_install/lib/lua/
		mkdir -p -v     ../HyperLua/_install/temp
		cp -f -v ostatne/helper.lua     ../HyperLua/_install/temp
		cp -f -v ostatne/parser_debug.lua     ../HyperLua/_install/temp
		cp -f -v ostatne/luameg_debug.lua     ../HyperLua/_install/temp
		mkdir -p -v     ../HyperLua/_install/temp/moon/
		cp -Rf -v ostatne/moonscript_testfile/*     ../HyperLua/_install/temp/moon
	fi
else
	echo "Directory \"$directory\" does not exist"
fi
