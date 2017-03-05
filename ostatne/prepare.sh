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
		cp -Rf -v -b src/*    $directory/lib/lua/
		mkdir -p -v     $directory/temp
		cp -f -v ostatne/helper.lua     $directory/temp
		cp -f -v ostatne/parser_debug.lua     $directory/temp
		cp -f -v ostatne/luameg_debug.lua     $directory/temp
		mkdir -p -v     $directory/temp/moon/
		cp -Rf -v ostatne/moonscript_testfile/*     $directory/temp/moon
	fi
else
	echo "Directory \"$directory\" does not exist"
fi
