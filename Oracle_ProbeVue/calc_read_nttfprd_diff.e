#!/bin/probevue

/*
  Usage: probevue calc_read_nttfprd_diff.e <PID> <REMOTE_TNS_PORT>

  Example:
    lsof -an -p 49676698
      COMMAND      PID   USER   FD   TYPE             DEVICE    SIZE/OFF  NODE NAME
      oracle  49676698 ora<sid>   11u  IPv4 0xf1001000455493c0 0xb987d90be   TCP 1.1.1.1:1528->2.2.2.2:40404 (ESTABLISHED)
    probevue calc_read_nttfprd_diff.e 49676698 40404
*/

int read(int, char *, int);
probev_timestamp_t net_time_arrival;
probev_timestamp_t entry_time_nttfprd;
probev_timestamp_t exit_time_syscall_read;
int tns_remote_port;
int net_remote_port;
int latency_arrival_exit;
int count_arrival_exit;
int latency_exit_entry;
int count_exit_entry;
int diff;
net_info_t conn_info;

@@BEGIN
{
  tns_remote_port = $2;
  net_remote_port = 0;
  latency_arrival_exit = 0;
  count_arrival_exit = 0;
  latency_exit_entry = 0;
  count_exit_entry = 0;
  diff = 0;
}

@@syscall:$1:read:entry
{

  sockfd_netinfo(__arg1, conn_info);
  net_remote_port = conn_info.remote_port;
}

@@syscall:$1:read:exit
{
  if(net_remote_port == tns_remote_port)
  {
    exit_time_syscall_read =  timestamp();
    diff = diff_time(net_time_arrival, exit_time_syscall_read, MICROSECONDS);
    printf("Time difference between network package arrival and exit syscall read: %lld\n", diff);
    latency_arrival_exit  = latency_arrival_exit + diff;
    count_arrival_exit += 1;
  }
  local_port = 0;
}

@@uft:$1:*:nttfprd:entry
{
  if (count_exit_entry > 0)
  {
    entry_time_nttfprd = timestamp();
    diff = diff_time(exit_time_syscall_read, entry_time_nttfprd, MICROSECONDS);
    printf("Time difference between exit of syscall read and entry nttfprd: %lld\n", diff);
    latency_exit_entry = latency_exit_entry + diff;
  }
  count_exit_entry += 1;
}

@@net:bpf:en5:tcp:"src host 2.2.2.2"
{
  if ((__tcphdr->src_port == tns_remote_port))
  {
    net_time_arrival = timestamp();
  }
}

@@END
{
  printf("Avg latency (microseconds) between network package arrival and exit syscall read: %ld\n", latency_arrival_exit / count_arrival_exit);
  printf("Avg latency (microseconds) between exit of syscall read and entry nttfprd: %ld", latency_exit_entry / count_exit_entry);
}
