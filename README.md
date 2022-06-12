![Soocs Logo](http://www.soocs.de/wp-content/uploads/Soocs_Header.gif)

## General Information
Github repository for various scripts that I developed during my Oracle database and OS troubleshooting work

## Contents
- Ghidra/[GhidraDecompiler.py](Ghidra/GhidraDecompiler.py) & Ghidra/[GhidraDecompiler_Func_CMD.sh](Ghidra/GhidraDecompiler_Func_CMD.sh): Ghidra scripts to decompile a single function in command line
- Linux_Scripts/[latency_dm-delay_oradata.sh](Linux_Scripts/latency_dm-delay_oradata.sh): Sample shell script to emulate I/O latency issue with help of device mappers delay target
- Oracle_DTrace/[dtrace_kghal_pga_code.sh](Oracle_DTrace/dtrace_kghal_pga_code.sh): Track PGA memory allocation by PL/SQL and SQL code
- Oracle_DTrace/[dtrace_stack_Wnnn.sh](Oracle_DTrace/dtrace_stack_Wnnn.sh): Capture C stack traces for Wnnn processes
- Oracle_ORADEBUG/[lgwr_redo_writing_latch.sh](Oracle_ORADEBUG/lgwr_redo_writing_latch.sh): Oradebug script to aquire "latch: redo writing" for longer periods
- Oracle_ProbeVue/[calc_read_nttfprd_diff.e](Oracle_ProbeVue/calc_read_nttfprd_diff.e): Sample ProbeVue script to measure network packet handling times
- Oracle_SQL/[hinth_version.sql](Oracle_SQL/hinth_version.sql): Display the areas / features in Oracle kernel (including version) that a hint affects

## Business Contact
- Website: www.soocs.de
- Twitter: www.twitter.com/OracleSK