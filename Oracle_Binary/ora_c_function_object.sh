#!/bin/bash
#
# Script-Version: 0.1
# Author: Stefan Koehler ( http://www.soocs.de )
# Description: Wrapper shell script to list the archive, object file or shared library in which a specific Oracle RDBMS C function is implemented
#              This might be useful if you want to figure out if a specific Oracle RDBMS C function was or will be patched by an Oracle patchset, RU, etc.
# Use at your own risk!

# Path used for building the Oracle binary
## Oracle database rdbms specific libraries
PATH_ORA_RDBMS_SPEC=${ORACLE_HOME}/rdbms/lib
## Oracle database general libraries (objects are used by multiple products in the $ORACLE_HOME)
PATH_ORA_RDBMS_GEN=${ORACLE_HOME}/lib 
## Stub objects, which are versions of operating system libraries that contain no code, but allow the oracle executable to be build, even if a operating system library is missing
PATH_ORA_RDBMS_STUB=${ORACLE_HOME}/lib/stubs
## Oracle text
PATH_ORA_RDBMS_TEXT=${ORACLE_HOME}/ctx/lib

TMP_FOLDER=/tmp/ora_c_function_object_${RANDOM}
FUNC_NAME=$1

if [[ ${FUNC_NAME} = '-h' ]] || [[ ${FUNC_NAME} = '--help' ]] || [[ $# -eq 0 ]] ; then
  echo -e "Usage: $0 <C_function_name>"
  echo "<C_function_name> is used as a case-insensitive wildcard pattern" 
  exit 1
fi;

for ALL_FILES in `find ${PATH_ORA_RDBMS_SPEC} ${PATH_ORA_RDBMS_GEN} ${PATH_ORA_RDBMS_STUB} ${PATH_ORA_RDBMS_TEXT} -type f -name "*.o" -o -name "*.a" -o -name "*.so"`
do
  case "${ALL_FILES}" in
  *.o)
    LINE_OUTPUT=`readelf -s ${ALL_FILES} | grep FUNC | grep -i ${FUNC_NAME}`
    if [[ $? -eq 0 ]] ; then
      echo "Object file ${ALL_FILES} contains C function pattern ${FUNC_NAME}"
      echo "---------------------------------------------------------------"
      echo "   Num:    Value          Size Type    Bind   Vis      Ndx Name"
      echo "${LINE_OUTPUT}"
      exit 0
    fi;
    ;;

  *.so)
    LINE_OUTPUT=`readelf -s ${ALL_FILES} | grep FUNC | grep -i ${FUNC_NAME}`
    if [[ $? -eq 0 ]] ; then
      echo "Shared library ${ALL_FILES} contains C function pattern ${FUNC_NAME}"
      echo "---------------------------------------------------------------"
      echo "   Num:    Value          Size Type    Bind   Vis      Ndx Name"
      echo "${LINE_OUTPUT}"
      exit 0
    fi;
    ;;

  *.a)
    mkdir ${TMP_FOLDER}
    cd ${TMP_FOLDER}
    ar -x ${ALL_FILES}
    for O_FILES_IN_A in `find ${TMP_FOLDER} -type f -name "*.o"`
    do
        LINE_OUTPUT=`readelf -s ${O_FILES_IN_A} | grep FUNC | grep -i ${FUNC_NAME}`
        if [[ $? -eq 0 ]] ; then
        O_FILE_IN_A=`echo ${O_FILES_IN_A} | awk -F/ '{print $NF}'`
        echo "Object file ${O_FILE_IN_A} in archive file ${ALL_FILES} contains C function pattern ${FUNC_NAME}"
        echo "---------------------------------------------------------------"
        echo "   Num:    Value          Size Type    Bind   Vis      Ndx Name"
        echo "${LINE_OUTPUT}"
        rm -Rf ${TMP_FOLDER}
        exit 0
      fi;
    done
    rm -Rf ${TMP_FOLDER}
    ;;
  esac
done