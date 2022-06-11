#!/bin/bash
#
# Script-Version: 0.1
# Author: Stefan Koehler ( http://www.soocs.de )
# Description: Wrapper script for Ghidra to decompile a single function in command line
#              Use at your own risk!
# Usage: GhidraDecompiler_Func_CMD.sh <MEMORY_ADDRESS_OF_FUNCTION>
# Input parameter:
#                  $1 = <MEMORY_ADDRESS_OF_FUNCTION> which can be determined with readelf (for example) on binary in advance

# Ghidra paths to your installation
GHIDRAPATH=/app/Ghidra/ghidra_10.1.2_PUBLIC
GHIDRAPROP=/app/Ghidra/projects
# Change this variable to your desired Ghidra project name
GHIDRAPROJ=<PROJECT>.gpr
# Change this variable only if you want to import a new binary into a project
GHIDRABIN=/dev/null

GHIDRASCRI=`pwd`
MEMADDR=$1

# For first run only to create and import binary into project (only needed if no project already exists for the binary)
# ${GHIDRAPATH}/support/analyzeHeadless ${GHIDRAPROP} ${GHIDRAPROJ} -import ${GHIDRABIN} -scriptPath ${GHIDRASCRI} -postScript GhidraDecompiler.py -noanalysis

# For any subsequent run an existing Ghidra project (GHIDRAPROJ) is used - this can be a project that already includes an analyzed or non-analyzed binary
echo "${MEMADDR}" > /tmp/memaddr.ghidra
${GHIDRAPATH}/support/analyzeHeadless ${GHIDRAPROP} ${GHIDRAPROJ} -process -scriptPath ${GHIDRASCRI} -postScript GhidraDecompiler.py -noanalysis
rm -f /tmp/memaddr.ghidra
