#!/bin/bash
#
# Script-Version: 0.1
# Author: Stefan Koehler ( http://www.soocs.de )
# Description: Wrapper script for Ghidra to get function offsets of a single function in command line
#              Works with analyzed binary only
#              Use at your own risk!
# Usage: GhidraGetOffset_Func_CMD.sh <FUNCTION_NAME>
# Input parameter:
#                  $1 = <FUNCTION_NAME> for which the function offsets should be determined

# Ghidra paths to your installation
GHIDRAPATH=/app/Ghidra/ghidra_10.1.2_PUBLIC
GHIDRAPROP=/app/Ghidra/projects
# Change these variables to your desired Ghidra project name and imported binary
GHIDRAPROJ=<PROJECT>.gpr
GHIDRABIN=/dev/null

GHIDRASCRI=`pwd`
GHIDRAFUNC=$1

# Get function address
MEMADDR=`/usr/bin/readelf -s ${GHIDRABIN} | grep FUNC | grep ${GHIDRAFUNC} | awk '{print $2}' | uniq`

# For first run only to create and import binary into project (only needed if no analyzed project already exists for the binary)
# ${GHIDRAPATH}/support/analyzeHeadless ${GHIDRAPROP} ${GHIDRAPROJ} -import ${GHIDRABIN} -scriptPath ${GHIDRASCRI} -postScript GhidraGetOffset.py

# For any subsequent run an existing and analyzed Ghidra project (GHIDRAPROJ) is used
echo "0x${MEMADDR}" > /tmp/memaddr.ghidra
${GHIDRAPATH}/support/analyzeHeadless ${GHIDRAPROP} ${GHIDRAPROJ} -process -scriptPath ${GHIDRASCRI} -postScript GhidraGetOffset.py -noanalysis
rm -f /tmp/memaddr.ghidra
