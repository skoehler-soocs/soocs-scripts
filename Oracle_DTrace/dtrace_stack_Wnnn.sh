#!/bin/bash
#
# Script-Version: 0.1
# Author: Stefan Koehler ( http://www.soocs.de )
# Description: DTrace script to capture C stack traces for Wnnn processes (Space Management Background Secondary)
# Input parameter:
#                  $1 = Oracle SID 
#                  $2 = Log file path
#                  $3 = Sample rate in Hz
# Reference for pre-analysis: Wait Chain = latch: shared pool JDBC Thin Client 3pg67vrdck621 -> ON CPU oracle@<host> (W004)
# MOS ID: 2297950.1: On 12.1.0.1, 11.2.0.4 and below, maximum of 10 secondary may be used. On 12.1.0.2 and above, maximum of 1024 secondary may be used.

/usr/sbin/dtrace -o $2/dtrace_Wnnn_analysis.out -q -x ustackframes=100 -n 'profile-'$3'
/  strtok(curpsinfo->pr_psargs,"_") == "ora" && strstr(strtok(NULL,"_"),"w0") != 0 && strtok(NULL,"_") == "'$1'" 
/
{ 
    printf("Timestamp: %Y - Process: %s", walltimestamp, curpsinfo->pr_psargs);
    ustack();
    printf("\n");
}' 
