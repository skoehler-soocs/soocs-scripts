#!/usr/bin/env python3
"""
    Script-Version: 0.1
    Author: Stefan Koehler ( http://www.soocs.de )
    Description: BCC eBPF script to modify the SGA variable "ksdxdcmds_" to dynamically bypass ORADEBUG restrictions (enabled by default since 19.24).
                 ksdxdcmds_ = 0: none (no restrictions)
		         ksdxdcmds_ = 1: all (this effectively disables oradebug)
                 ksdxdcmds_ = 2: restricted (disables execution of restricted commands)

		         Attaches a uprobe at kewa_sampler+2, which fires every second (in the MMNL process). On every hit:
   	               * Reads the 4-byte value at the fixed address of ksdxdcmds_ and saves the value from the first sample.
   	               * Overwrites it with 0 via bpf_probe_write_user().
                   * Resets it to the value from the first sample on exit.

                 Use at your own risk, as it writes directly to the memory of a running Oracle process!
                 Some distro kernels disable bpf_probe_write_user() under lockdown/hardening settings, in which case BPF() will fail to load with a verifier error.

    Usage: sudo bcc_ksdxdcmds_mod.py
"""

import subprocess
import sys
import time

from bcc import BPF

BINARY = "/oracle/rdbms/23261/bin/oracle"
SYMBOL = "ksdxdcmds_"
PROBE_SYM = "kewa_sampler"
PROBE_OFFSET = 2

def find_symbol_addr(binary: str, symbol: str) -> int:
    out = subprocess.check_output(
        ["readelf", "-Ws", binary]
    ).decode()

    for line in out.splitlines():
        fields = line.split()

        if fields and fields[-1] == symbol:
            return int(fields[1], 16)

    raise RuntimeError(
        f"symbol {symbol!r} not found in {binary}"
    )


# Resolve the address of ksdxdcmds_ in the Oracle binary.
ksxd_addr = find_symbol_addr(BINARY, SYMBOL)

print(
    f"{SYMBOL} address: {hex(ksxd_addr)}",
    file=sys.stderr,
)


# ---------------------------------------------------------------------------
# BPF program: capture the current value of ksdxdcmds_, then zero it.
# ---------------------------------------------------------------------------

bpf_mod_text = f"""
#include <uapi/linux/ptrace.h>

struct data_t {{
    u32 val;
}};

BPF_PERF_OUTPUT(events);

BPF_ARRAY(initial_value, u32, 1);
BPF_ARRAY(initialized, u32, 1);

int modify_ksdxdcmds(struct pt_regs *ctx)
{{
    struct data_t data = {{}};
    u32 *addr = (u32 *){hex(ksxd_addr)};
    u32 key = 0;
    u32 zero = 0;
    u32 *saved;
    u32 *done;

    bpf_probe_read_user(
        &data.val,
        sizeof(data.val),
        addr
    );

    saved = initial_value.lookup(&key);
    done = initialized.lookup(&key); 

    if (saved && done && *done == 0) {{
        *saved = data.val;
        *done = 1;
    }}

    events.perf_submit(
        ctx,
        &data,
        sizeof(data)
    );

    bpf_probe_write_user(
        addr,
        &zero,
        sizeof(zero)
    );

    return 0;
}}
"""


b = BPF(text=bpf_mod_text)

b.attach_uprobe(
    name=BINARY,
    sym=PROBE_SYM,
    sym_off=PROBE_OFFSET,
    fn_name="modify_ksdxdcmds",
)


# ---------------------------------------------------------------------------
# Perf-buffer callback.
# ---------------------------------------------------------------------------
first_event = True

def print_event(cpu, data, size):
    global first_event
    
    if not first_event:
        return

    event = b["events"].event(data)
    print(f"Value of SGA variable ksdxdcmds_ = {event.val} is modified to 0x0 (0)")
    first_event = False

b["events"].open_perf_buffer(print_event)


print(
    f"Setup uprobe on {PROBE_SYM}+{PROBE_OFFSET} in {BINARY}, "
    f"zeroing {SYMBOL} on every hit (usually every second)... Ctrl-C to stop.",
    file=sys.stderr,
)


# ---------------------------------------------------------------------------
# Poll until interrupted.
# ---------------------------------------------------------------------------

try:
    while True:
        try:
            b.perf_buffer_poll()

        except KeyboardInterrupt:
            print(
                "\nStopping...",
                file=sys.stderr,
            )
            break

finally:
    # Detach the modifying uprobe first.
    try:
        b.detach_uprobe(
            name=BINARY,
            sym=PROBE_SYM,
            sym_off=PROBE_OFFSET,
        )

    except Exception as e:
        print(
            f"Warning: failed to detach uprobe: {e}",
            file=sys.stderr,
        )


# ---------------------------------------------------------------------------
# Retrieve the original value captured by the BPF map.
# ---------------------------------------------------------------------------

initial_map = b["initial_value"]

key = initial_map.Key(0)
value = initial_map[key]

initial_value = value.value

print(
    f"Resetting {SYMBOL} to initial value: "
    f"{hex(initial_value)} ({initial_value})",
    file=sys.stderr,
)


# ---------------------------------------------------------------------------
# BPF program: restore the original value.
# ---------------------------------------------------------------------------

bpf_res_text = f"""
#include <uapi/linux/ptrace.h>

int restore_ksdxdcmds(struct pt_regs *ctx)
{{
    u32 *addr = (u32 *){hex(ksxd_addr)};
    u32 value = {initial_value};

    bpf_probe_write_user(
        addr,
        &value,
        sizeof(value)
    );

    return 0;
}}
"""


restore_b = BPF(text=bpf_res_text)

restore_b.attach_uprobe(
    name=BINARY,
    sym=PROBE_SYM,
    sym_off=PROBE_OFFSET,
    fn_name="restore_ksdxdcmds",
)

print("Restore probe attached; waiting 10 seconds...", file=sys.stderr)
time.sleep(10)
print("Exiting.", file=sys.stderr)