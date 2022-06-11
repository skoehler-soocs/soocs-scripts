#!/usr/bin/bash
#
# Script-Version: 0.1
# Author: Stefan Koehler ( http://www.soocs.de )
# Description: DTrace script to track down root cause for PGA memory allocation by PL/SQL and SQL code with help of DTrace destructive actions and Oracle error stack traces
#              Created to track down the corresponding Oracle code for memory allocation after analysis with V$PROCESS_MEMORY_DETAIL or heap dumps
#              Use at your own risk!
# Usage: dtrace_kghal_pga_code <PID> <KGHAL_FUNC> <MEM_ALLOC_REASON> 
# Input parameter:
#                  $1 = PID
#                  $2 = KGHAL memory allocator function (e.g. kghalf, kghalo or kghalp)
#                  $3 = Memory allocation reason (e.g. kgich, koh-kghu call, pl/sql cursor meta-data, etc.)
#
# Reference for pre-analysis: http://blog.tanelpoder.com/2014/03/26/oracle-memory-troubleshooting-part-4-drilling-down-into-pga-memory-usage-with-vprocess_memory_detail/  
#                             http://blog.tanelpoder.com/files/scripts/dtrace/trace_kghal.sh

case $2 in
   kghalf)
     probe_arg_func="arg5";;
   kghalo)
     probe_arg_func="arg8";;
   kghalp)
     probe_arg_func="arg5";;
esac

/usr/sbin/dtrace -w -p $1 -n 'pid$target::'$2':entry
    /copyinstr('$probe_arg_func') == "'"$3"'" /
    {
      heap=arg1;
      alloc_reason='$probe_arg_func';
      printf("\nProcess is stopped due to memory allocation reason \"%s\" from heap \"%s\".\n", copyinstr(alloc_reason), copyinstr(heap+76));
      printf("Please run the following commands in separate SQL*Plus to dump an errorstack:\n");
      printf("SQL> ORADEBUG SETOSPID '$1'\nSQL> ORADEBUG DUMP ERRORSTACK 3    <<<< ORADEBUG will hang until process is continued by prun - works as designed\n");
      printf("----------------------------\n");
      printf("Please run the following command in separate shell after executing ORADEBUG:\n");
      printf("shell> /usr/bin/prun '$1'");
       
      /* http://docs.oracle.com/cd/E19253-01/817-6223/chp-actsub-4/index.html */
      stop();         
    }
'
