#!/bin/bash
#
# Script-Version: 0.1
# Author: Stefan Koehler ( http://www.soocs.de )
# Description: Oradebug script to aquire "latch: redo writing" for longer periods and so simulating some kind of CPU starvation
#              Tested with Oracle version 19.x
#              Use at your own risk!

echo "Simulate CPU starvation for 20 seconds ..."

sqlplus "/ as sysdba" << EOF

	-- Default 500 ms
	alter system set "_long_log_write_warning_threshold"=100 scope=memory sid='*';

	oradebug setmypid
        host date +'%Y-%m-%d %H:%M:%S';
	oradebug call kslgetl 0x6006D480 1 0x0 3752
	host sleep 0.3;
	oradebug call kslfre 0x6006D480
	host sleep 0.3;

	oradebug call kslgetl 0x6006D480 1 0x0 3752
	host sleep 0.7;
	oradebug call kslfre 0x6006D480
	host sleep 0.7;

	oradebug call kslgetl 0x6006D480 1 0x0 3752
	host sleep 2.0;
	oradebug call kslfre 0x6006D480
	host sleep 2.0;

	oradebug call kslgetl 0x6006D480 1 0x0 3752
	host sleep 0.2;
	oradebug call kslfre 0x6006D480
	host sleep 0.2;

	oradebug call kslgetl 0x6006D480 1 0x0 3752
	host sleep 0.8;
	oradebug call kslfre 0x6006D480
	host sleep 0.8;

	oradebug call kslgetl 0x6006D480 1 0x0 3752
	host sleep 1.0;
	oradebug call kslfre 0x6006D480
	host sleep 1.0;

	oradebug call kslgetl 0x6006D480 1 0x0 3752
	host sleep 0.5;
	oradebug call kslfre 0x6006D480
	host sleep 0.5;

	oradebug call kslgetl 0x6006D480 1 0x0 3752
	host sleep 0.9;
	oradebug call kslfre 0x6006D480
	host sleep 0.9;

	oradebug call kslgetl 0x6006D480 1 0x0 3752
	host sleep 0.6;
	oradebug call kslfre 0x6006D480
	host sleep 0.6;
   
	oradebug call kslgetl 0x6006D480 1 0x0 3752
	host sleep 3.0;
	oradebug call kslfre 0x6006D480
	host sleep 3.0;
	
	host date +'%Y-%m-%d %H:%M:%S';

  	quit
EOF
