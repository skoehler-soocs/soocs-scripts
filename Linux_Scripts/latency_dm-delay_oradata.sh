#!/bin/bash
#
# Script-Version: 0.1
# Author: Stefan Koehler ( http://www.soocs.de )
# Description: Sample shell script to setup and emulate I/O latency issue for Oracle data with help of device mappers delay target

PARM=$1

if [[ ${PARM} = '-h' ]] || [[ ${PARM} = '--help' ]] || [[ $# -eq 0 ]] ; then
  echo -e "Usage: $0 {setup|run}"
  echo -e "setup - Initial setup dm devices before emulating I/O latency issue for Oracle data" 
  echo -e "run - Emulate I/O latency issue for Oracle data" 
  exit 1
fi;

#Format
CR=`echo $'\n.'`
CR=${CR%.}

# Parameter I/O latency for Oracle data
NOLATENCY=0
LATENCY=20
#LATENCY=30

if [[ ${PARM} = 'setup' ]] ; then

  # Oracle datalog filesystems
  umount /oracle/oradata
  size_data=$(blockdev --getsize /dev/mapper/vgoracle-lvoradata)
  echo "0 $size_data delay /dev/mapper/vgoracle-lvoradata 0 $NOLATENCY" | dmsetup create lvoradata_stack
  mount /dev/mapper/lvoradata_stack /oracle/oradata

  exit 0

elif [[ ${PARM} = 'run' ]]; then

  size_data=$(blockdev --getsize /dev/mapper/vgoracle-lvoradata)

  # Introduce I/O latency problem
  read -p "Press any key to continue to emulate Oracle data latency problem ... $CR" -n1 -s

  date
  # Oracle data LVs / DMs
  dmsetup suspend lvoradata_stack
  dmsetup reload lvoradata_stack --table "0 $size_data delay 252:3 0 $LATENCY"
  dmsetup resume lvoradata_stack 

  # Fix I/O latency problem
  read -p "Press any key to continue to fix Oracle data latency problem ... $CR" -n1 -s
  
  date
  # Oracle data LVs / DMs
  dmsetup suspend lvoradata_stack
  dmsetup reload lvoradata_stack --table "0 $size_data delay 252:3 0 $NOLATENCY"
  dmsetup resume lvoradata_stack

else

  echo -e "Usage: $0 {setup|run}"
  echo -e "setup - Initial setup dm devices before emulating I/O latency issue for Oracle data"
  echo -e "run - Emulate I/O latency issue for Oracle data"
  exit 1

fi;
