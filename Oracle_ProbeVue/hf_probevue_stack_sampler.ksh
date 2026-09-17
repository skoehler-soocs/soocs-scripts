#!/usr/bin/ksh93
#
# Script-Version: 0.3
# Author: Stefan Koehler ( http://www.soocs.de )
# Description: Korn shell wrapper script for a high-frequency stack sampler (up to approximately 1000 Hz) on AIX
#              This script relies entirely on AIX standard functionality such as Gensyms, Perl, and ProbeVue to ensure portability - additionally, it automatically generates a FlameGraph for the sampled stacks
# Requirements: AIX version 6.1 or higher, with installp packages: bos.perf.tools, bos.sysmgt.trace, and perl.rte
#               shell> probevctrl -c max_total_mem_size=256 -t (ProbeVue adjustments needed to avoid "Out of memory while allocating trace buffers. Max pinned memory for the ProbeVue framework is not enough to accommodate the trace buffer size." error)
# Bugs: Fixed "Out of memory!" Perl error with large samples and/or binaries (e.g. Oracle RDBMS)
# Performance optimizations: Dropped Math::BigInt by zero-padding hex strings to 16 characters
#                            Replaced O(N×M) address-by-address substitution with a single O(M) pass
#                            Combined gensym mapping and ProbeVue sample processing into a single awk pass
# Use at your own risk!

KSH_V_GENSYMS_BACKGROUND_SLEEP=60
KSH_V_PID=${1}
KSH_V_RAND_NUM=${RANDOM}

# FlameGraph can be downloaded from GitHub ( https://github.com/brendangregg/FlameGraph )
KSH_V_PATH_FLAMEGRAPH=/tmp/FlameGraph-master
KSH_V_OUTPUT_FOLDER=/tmp
KSH_V_PATH_FINAL=${KSH_V_OUTPUT_FOLDER}/hf_sampler.${KSH_V_PID}.${KSH_V_RAND_NUM}
KSH_V_PATH_TMP=${KSH_V_OUTPUT_FOLDER}/hf_sampler.${KSH_V_PID}.${KSH_V_RAND_NUM}.tmp

# KSH environment variables used for post-processing stack address-to-function-name translation in Perl
export PERL_ENV_PATH_GENSYMS_MAPPING=${KSH_V_PATH_TMP}/all_text_symbols_uniq_gensyms.out
export PERL_ENV_PATH_TRANS_STACK=${KSH_V_PATH_TMP}/probevue_samples_translated.out
export PERL_ENV_PATH_UNIQ_STACK=${KSH_V_PATH_TMP}/probevue_samples_uniq.out;

# Parameter value checks and parameter default settings
if [ $# -eq 0 ]; then
  echo "Invalid parameters for script ${0}"
  echo "------------------------------------------------------------------------------------------------------------"
  echo "Please use the following syntax: ${0} <PID> <DURATION> <SAMPLE_FREQ_HZ>"
  echo "  - <PID>             Process ID of target process (mandatory)"
  echo "  - <DURATION> 	      Sample duration in seconds (optional - default 60 seconds)"
  echo "  - <SAMPLE_FREQ_HZ>  Sampling frequency in Hz (optional - default 100 Hz / up to 1000 Hz possible)"
  echo "------------------------------------------------------------------------------------------------------------"
  exit 1
fi

if [ -z "${2}" ]; then
  KSH_V_PROBEVUE_SAMPLE_DUR_SEC=60
else
  KSH_V_PROBEVUE_SAMPLE_DUR_SEC=${2}
fi
KSH_V_PROBEVUE_SAMPLE_DUR_MS=$((${KSH_V_PROBEVUE_SAMPLE_DUR_SEC} * 1000))

if [ -z "${3}" ]; then
  KSH_V_PROBEVUE_SAMPLE_FREQ_HZ=100
else
  KSH_V_PROBEVUE_SAMPLE_FREQ_HZ=${3}
  if [ "${KSH_V_PROBEVUE_SAMPLE_FREQ_HZ}" -le 0 ] 2>/dev/null; then
    echo "Invalid <SAMPLE_FREQ_HZ> value: ${KSH_V_PROBEVUE_SAMPLE_FREQ_HZ} (must be a positive integer)"
    exit 1
  fi
fi
KSH_V_PROBEVUE_TIME_SAMPLE_MS=$((1000 / ${KSH_V_PROBEVUE_SAMPLE_FREQ_HZ}))

# Check if process exists
if ! ps -p ${KSH_V_PID} > /dev/null; then
  echo "Process with PID ${KSH_V_PID} does not exist"
  exit 1
fi

# Gathering necessary address, stack, and symbol information of the running process before stack sampling with ProbeVue
echo "`date` - Pre-sampling: Generating symbol name to stack address mapping information with gensyms ..."
mkdir -p ${KSH_V_PATH_TMP}
KSH_V_BINARY_INODE=$(istat /proc/${KSH_V_PID}/object/a.out | grep Inode | awk '{print $2}')
KSH_V_BINARY_MOUNTPOINT=$(df -F %m /proc/${KSH_V_PID}/object/a.out | grep -v Filesystem | awk '{print $3}')
KSH_V_BINARY_FULL_PATH=$(find ${KSH_V_BINARY_MOUNTPOINT} -inum ${KSH_V_BINARY_INODE} 2> /dev/null)
gensyms -b ${KSH_V_BINARY_FULL_PATH} -f -g -s > ${KSH_V_PATH_TMP}/pre_sampling_gensyms_binary.out 2>&1
gensyms -f -g -P ${KSH_V_PID} > ${KSH_V_PATH_TMP}/pre_sampling_gensyms_pid_loaded_modules.out 2>&1

echo "`date` - ProbeVue sampling PID ${KSH_V_PID} for ${KSH_V_PROBEVUE_SAMPLE_DUR_SEC} seconds with a sample frequency of ${KSH_V_PROBEVUE_SAMPLE_FREQ_HZ} Hz"
ps -p ${KSH_V_PID}

# Continuously gathering address, stack, and symbol information every ${KSH_V_GENSYMS_BACKGROUND_SLEEP} seconds from the running process during stack sampling with ProbeVue
touch ${KSH_V_PATH_TMP}/background_sampling_gensyms_pid_loaded_modules.out
if [ ${KSH_V_PROBEVUE_SAMPLE_DUR_SEC} -gt ${KSH_V_GENSYMS_BACKGROUND_SLEEP} ]; then
  nohup ksh93 "while true; do gensyms -f -g -P ${KSH_V_PID} > ${KSH_V_PATH_TMP}/background_sampling_gensyms_pid_loaded_modules.out 2>&1; sleep ${KSH_V_GENSYMS_BACKGROUND_SLEEP}; done" > /dev/null 2>&1 & 
  KSH_V_GENSYMS_BACKGROUND_PID=$!
fi

# Stack sampling with ProbeVue (run whole script as root or assign permissions to user as described here: https://www.ibm.com/docs/en/aix/7.3?topic=facility-running-probevue)
probevue -u -s 2048 -o ${KSH_V_PATH_TMP}/probevue_samples.out <<EOF
  __kernel long long lbolt;
  probev_timestamp_t v_g_start_time;
  probev_timestamp_t v_g_end_time;

  @@BEGIN
  {
    printf("Info: ProbeVue sampling of PID %d started at %A ...\n",${KSH_V_PID},timestamp());
    v_g_start_time = timestamp();
  }

  @@sysproc:sendsig:${KSH_V_PID}
  when(__sigsendinfo->signo == 9 || __sigsendinfo->signo == 11)
  {
    printf("Info: ProbeVue sampling of PID %d interrupted by signal at %A ...\n",${KSH_V_PID},timestamp());
    exit();
  }

  @@syscall:${KSH_V_PID}:exit:entry
  {
    printf("Info: ProbeVue sampling of PID %d ended due to exit syscall at %A ...\n",${KSH_V_PID},timestamp());
    exit();
  }

  @@interval:${KSH_V_PID}:clock:${KSH_V_PROBEVUE_TIME_SAMPLE_MS}
  {
    /* 
      The official IBM documentation is inadequate, as user symbols are not populated regardless of the flag or option used with get_stktrace() or stktrace, or the state of the process.
        https://www.ibm.com/docs/en/aix/7.3?topic=r-raschk-stktrace-kernel-service
        RAS_STK_GET_SYMBOLS
        If this flag bit value is set, then all the call chain addresses are translated into a stream of bytes containing 
        symbols with offset (null terminated) and placed in the caller's buffer.

        https://www.ibm.com/docs/en/ssw_aix_73/generalprogramming/probevue_var_stack.html
        The symbol with the address (symbol plus address) are printed only when the thread that corresponds to the stktrace_t variable is in the running state and when the %t format specifier is used to print the stack trace; 
        otherwise only the stack trace as the address is printed for the variable. Addresses with symbol (symbol name + offset) is printed if thread that corresponds to the stktrace_t type stored in the associative array is 
        running; otherwise only addresses is printed. 
    */

    printf("%llu\n", __k:lbolt);
    printf("%T\n", get_stktrace(-1));

    v_g_end_time = timestamp();
    diff_ms = diff_time(v_g_start_time,v_g_end_time, MILLISECONDS);
    if ((diff_ms > ${KSH_V_PROBEVUE_SAMPLE_DUR_MS}))
    {
      printf("Info: ProbeVue sampling of PID %d ended after reaching its time window at %A ...\n",${KSH_V_PID},timestamp());
      exit();
    }
  }
EOF

# Stopping continuously gathering of address, stack, and symbol information
if [ ${KSH_V_PROBEVUE_SAMPLE_DUR_SEC} -gt ${KSH_V_GENSYMS_BACKGROUND_SLEEP} ]; then
  kill -9 ${KSH_V_GENSYMS_BACKGROUND_PID}
fi

# Gathering necessary address, stack, and symbol information of the running process after stack sampling with ProbeVue (works only if the process is still running)
echo "`date` - Post-sampling: Generating symbol name to stack address mapping information with gensyms ..."
if ! ps -p ${KSH_V_PID} > /dev/null; then
  echo "The process with PID ${KSH_V_PID} no longer exists - the mapping information of symbol names to stack addresses might be incomplete"
fi
gensyms -f -g -P ${KSH_V_PID} > ${KSH_V_PATH_TMP}/post_sampling_gensyms_pid_loaded_modules.out 2>&1

echo "`date` - Post-Processing symbol name, stack address and ProbeVue sampling data with Perl ..."
awk '"T" == $2 || "t" == $2 {
  key = "0x" $1 " " $3
  if (!(key in seen)) { seen[key] = 1; print key }
}' ${KSH_V_PATH_TMP}/pre_sampling_gensyms_binary.out ${KSH_V_PATH_TMP}/pre_sampling_gensyms_pid_loaded_modules.out ${KSH_V_PATH_TMP}/background_sampling_gensyms_pid_loaded_modules.out ${KSH_V_PATH_TMP}/post_sampling_gensyms_pid_loaded_modules.out > ${KSH_V_PATH_TMP}/all_text_symbols_uniq_gensyms.out

awk -v UNIQF="${KSH_V_PATH_TMP}/probevue_samples_uniq.out" -v TRANSF="${KSH_V_PATH_TMP}/probevue_samples_translated.out" '
{
  if ($0 !~ /Info: ProbeVue/) print $0 > TRANSF
  if ($0 ~ /0x/ && !seen[$0]++) print $0 > UNIQF
}' ${KSH_V_PATH_TMP}/probevue_samples.out

# Stack address-to-function-name translation is implemented in Perl
perl -X <<'EOF'
  #!/usr/bin/perl

  use strict;
  use warnings;
  no warnings 'uninitialized';

  my $PERL_V_PATH_GENSYMS_MAPPING = $ENV{PERL_ENV_PATH_GENSYMS_MAPPING};
  my $PERL_V_PATH_TRANS_STACK     = $ENV{PERL_ENV_PATH_TRANS_STACK};
  my $PERL_V_PATH_UNIQ_STACK      = $ENV{PERL_ENV_PATH_UNIQ_STACK};

  # Zero-pad a 0x string to 16 hex digits so that plain string comparison produces the same ordering as unsigned 64-bit numeric comparison would without ever converting to a number (and therefore without needing bigint)
  sub perl_uf_norm_hex
  {
    my $PERL_V_H = uc(shift);
    $PERL_V_H =~ s/^0X//;
    return $PERL_V_H if length($PERL_V_H) >= 16;
    return ('0' x (16 - length($PERL_V_H))) . $PERL_V_H;
  }

  # Loading the entire ProbeVue stack samples into memory to efficiently replace stack addresses with their corresponding symbol names
  open(my $PERL_V_PATH_TRANS_STACK_FH, '<', $PERL_V_PATH_TRANS_STACK) or die "Could not open file $PERL_V_PATH_TRANS_STACK because $!";
  my $PERL_V_TRANS_STACK_CONTENT = do { local $/; <$PERL_V_PATH_TRANS_STACK_FH> };
  close $PERL_V_PATH_TRANS_STACK_FH;

  # Loading the unique ProbeVue stack samples (including instruction offsets), paired with their normalized sort key
  open(my $PERL_V_PATH_UNIQ_STACK_FH, '<', $PERL_V_PATH_UNIQ_STACK) or die "Could not open file $PERL_V_PATH_UNIQ_STACK because $!";
  chomp(my @PERL_A_UNIQ_STACK_RAW = <$PERL_V_PATH_UNIQ_STACK_FH>);
  close $PERL_V_PATH_UNIQ_STACK_FH;
  my @PERL_A_UNIQ_STACK_SORTED = sort { $a->[1] cmp $b->[1] } map { [ $_, perl_uf_norm_hex($_) ] } @PERL_A_UNIQ_STACK_RAW;

  # Loading the gensyms mapping information, paired with their normalized sort key
  open(my $PERL_V_PATH_GENSYMS_MAPPING_FH, '<', $PERL_V_PATH_GENSYMS_MAPPING) or die "Could not open file $PERL_V_PATH_GENSYMS_MAPPING because $!";
  my @PERL_A_GENSYMS_MAPPING_RAW;
  while (my $PERL_V_PATH_GENSYMS_MAPPING_LINE = <$PERL_V_PATH_GENSYMS_MAPPING_FH>)
  {
    chomp $PERL_V_PATH_GENSYMS_MAPPING_LINE;
    my ($PERL_V_ADDR, $PERL_V_SYM) = split(/\s+/, $PERL_V_PATH_GENSYMS_MAPPING_LINE);
    push @PERL_A_GENSYMS_MAPPING_RAW, [ $PERL_V_ADDR, $PERL_V_SYM ];
  }
  close $PERL_V_PATH_GENSYMS_MAPPING_FH;
  my @PERL_A_GENSYMS_MAPPING_SORTED = sort { $a->[2] cmp $b->[2] } map { [ $_->[0], $_->[1], perl_uf_norm_hex($_->[0]) ] } @PERL_A_GENSYMS_MAPPING_RAW;
  my $PERL_V_GENSYMS_COUNT = scalar @PERL_A_GENSYMS_MAPPING_SORTED;

  # Single merge pass over both sorted lists (O(n+m)) building one address -> symbol hash.For each stack address this finds the mapping entry with the largest address that is still <= the stack address
  # Addresses outside the mapping's [min,max] range are "Unknown"
  my %PERL_H_SYMBOL_OF;
  if ($PERL_V_GENSYMS_COUNT == 0)
  {
    $PERL_H_SYMBOL_OF{$_->[0]} = 'Unknown' for @PERL_A_UNIQ_STACK_SORTED;
  }
  else
  {
    my $PERL_V_MIN_KEY = $PERL_A_GENSYMS_MAPPING_SORTED[0][2];
    my $PERL_V_MAX_KEY = $PERL_A_GENSYMS_MAPPING_SORTED[-1][2];
    my $PERL_V_MAP_IDX = 0;

    for my $PERL_V_PAIR (@PERL_A_UNIQ_STACK_SORTED)
    {
      my ($PERL_V_ADDR, $PERL_V_KEY) = @$PERL_V_PAIR;

      if ($PERL_V_KEY lt $PERL_V_MIN_KEY || $PERL_V_KEY gt $PERL_V_MAX_KEY)
      {
        $PERL_H_SYMBOL_OF{$PERL_V_ADDR} = 'Unknown';
        next;
      }

      while ($PERL_V_MAP_IDX + 1 < $PERL_V_GENSYMS_COUNT && $PERL_A_GENSYMS_MAPPING_SORTED[$PERL_V_MAP_IDX + 1][2] le $PERL_V_KEY)
      {
        $PERL_V_MAP_IDX++;
      }
      $PERL_H_SYMBOL_OF{$PERL_V_ADDR} = $PERL_A_GENSYMS_MAPPING_SORTED[$PERL_V_MAP_IDX][1];
    }
  }

  # Single O(M) pass over the whole stack-trace content, replacing every hex address in one global substitution
  $PERL_V_TRANS_STACK_CONTENT =~ s/(0x[0-9A-Fa-f]+)/exists $PERL_H_SYMBOL_OF{$1} ? $PERL_H_SYMBOL_OF{$1} : $1/ge;

  # Write the translated stacks into the corresponding OS file
  open(my $PERL_V_PATH_TRANS_STACK_OUT_FH, '>', $PERL_V_PATH_TRANS_STACK) or die "Could not open file $PERL_V_PATH_TRANS_STACK because $!";
  print $PERL_V_PATH_TRANS_STACK_OUT_FH $PERL_V_TRANS_STACK_CONTENT;
  close $PERL_V_PATH_TRANS_STACK_OUT_FH;
EOF

# The final output files will contain the following content:
# File final_stack_details_pid_${KSH_V_PID}.out: <number of ticks since last boot>;<stack frame>;<stack frame>;<stack frame>
# File final_stack_flamegraph_pid_${KSH_V_PID}.out: <stack frame>;<stack frame>;<stack frame> <sample count of this unique stack>
# File final_stack_flamegraph_pid_${KSH_V_PID}.svg: FlameGraph SVG (if FlameGraph is available)
echo "`date` - Creating desired stack information output formats and flamegraph (if available) ..."
awk '!NF{print "\n"}1' ORS=";" ${KSH_V_PATH_TMP}/probevue_samples_translated.out | sed 's/;;//g' | rev | cut -c 2- | rev >  ${KSH_V_PATH_TMP}/final_stack_details_pid_${KSH_V_PID}.out
cat ${KSH_V_PATH_TMP}/final_stack_details_pid_${KSH_V_PID}.out | cut -d ';' -f2- | sort | uniq -c | awk '{print $2 " " $1}' > ${KSH_V_PATH_TMP}/final_stack_flamegraph_pid_${KSH_V_PID}.out
if [[ -f "${KSH_V_PATH_FLAMEGRAPH}/flamegraph.pl" ]]; then
  ${KSH_V_PATH_FLAMEGRAPH}/flamegraph.pl ${KSH_V_PATH_TMP}/final_stack_flamegraph_pid_${KSH_V_PID}.out > ${KSH_V_PATH_TMP}/final_stack_flamegraph_pid_${KSH_V_PID}.svg
fi
  
echo "`date` - Clean up temporary data ..."
mkdir ${KSH_V_PATH_FINAL}
mv ${KSH_V_PATH_TMP}/final_stack_details_pid_${KSH_V_PID}.out ${KSH_V_PATH_FINAL}/
mv ${KSH_V_PATH_TMP}/final_stack_flamegraph_pid_${KSH_V_PID}.out ${KSH_V_PATH_FINAL}/
if [[ -f "${KSH_V_PATH_TMP}/final_stack_flamegraph_pid_${KSH_V_PID}.svg" ]]; then
  mv ${KSH_V_PATH_TMP}/final_stack_flamegraph_pid_${KSH_V_PID}.svg ${KSH_V_PATH_FINAL}/
fi
rm -Rf ${KSH_V_PATH_TMP}

echo "`date` - Profling done - data can be reviewed in folder ${KSH_V_PATH_FINAL}"
echo "-------------------------------------------------------------------------"
V_SAMPLE_COUNT=$(wc -l ${KSH_V_PATH_FINAL}/final_stack_details_pid_${KSH_V_PID}.out | awk '{print $1}')
echo "Runtime statistics: ProbeVue sampled ${V_SAMPLE_COUNT} samples during ${KSH_V_PROBEVUE_SAMPLE_DUR_SEC} seconds"
