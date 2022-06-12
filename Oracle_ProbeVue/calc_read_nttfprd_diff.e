#!/bin/probevue
int read(int, char *, int);
probev_timestamp_t net_time_arrival;
probev_timestamp_t entry_time_nttfprd;
probev_timestamp_t exit_time_syscall_read;
int local_port;
int v_sock_fd;
net_info_t conn_info;

@@syscall:$1:read:entry
{
  v_sock_fd = __arg1;
  sockfd_netinfo(v_sock_fd, conn_info);
  local_port = conn_info.local_port;
}

@@syscall:$1:read:exit
{
    sockfd_netinfo(v_sock_fd, conn_info);
    if(conn_info.local_port > 0)
    {
       exit_time_syscall_read =  timestamp();
       printf("Time difference between network package arrival and exit syscall read: %lld\n", diff_time(net_time_arrival, exit_time_syscall_read, MICROSECONDS));
    }
}

@@uft:$1:*:nttfprd:entry
{
  entry_time_nttfprd = timestamp();
  printf("Time difference between exit of syscall read and entry nttfprd: %lld\n", diff_time(exit_time_syscall_read, entry_time_nttfprd, MICROSECONDS));
}

@@net:bpf:en3:tcp:"src host 192.168.111.1"
when (local_port > 0)
{
  if ((__tcphdr->dst_port == local_port))
  {
    net_time_arrival = timestamp();
  }
}