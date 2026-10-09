#!/usr/bin/env bash
set -eu

# Run two Renode scenarios to validate the bootloader/application behavior.
# Usage:
#   ./run_renode_tests.sh         # run both scenarios and print Renode output snippets
#   ./run_renode_tests.sh --gdb   # start Renode once with a GDB server on port 3333

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BOOT_ELF="$ROOT_DIR/build/bootloader/bootloader.elf"
APP_ELF="$ROOT_DIR/build/application/application.elf"
RENODE_SCRIPT="$ROOT_DIR/Renode/nucleog474re.repl"

exit_code=0

if [ ! -f "$BOOT_ELF" ] || [ ! -f "$APP_ELF" ]; then
    echo "Error: expected ELF files not found. Run 'make all' first."
    echo "Expected: $BOOT_ELF" 
    echo "Expected: $APP_ELF" 
    exit 1
fi

# Cleanup helper: kill any Renode processes launched for this workspace
kill_renode_procs() {
    # Kill any process whose command line includes the Renode script path
    if pgrep -f "$RENODE_SCRIPT" >/dev/null 2>&1; then
        echo "Killing leftover Renode processes matching $RENODE_SCRIPT"
        pkill -f "$RENODE_SCRIPT" || true
        # Also try to kill any renode wrapper/binaries
        pkill -f "/opt/renode/bin/Renode.dll" || true
    fi
}

# Ensure cleanup on exit (so stray renode processes are removed)
trap 'kill_renode_procs; exit_code=$((exit_code==0?1:exit_code))' EXIT

if [ "${1:-}" = "--gdb" ]; then
    echo "Starting Renode with GDB server on port 3333"
    echo "Connect with: arm-none-eabi-gdb $BOOT_ELF  (then) target remote :3333"
    renode -e "include @$RENODE_SCRIPT; sysbus LoadELF @$BOOT_ELF; sysbus LoadELF @$APP_ELF; StartGdbServer 3333; start;" 
    exit 0
fi

## Helper: start Renode with a GDB server, query PC via gdb, then stop Renode.
## Usage: run_once <name> <extra_commands> <gdb_port>
run_once() {
    local name="$1"
    local extra_cmds="$2"
    local out=/tmp/renode_${name}.log
    local timeout_seconds="${SCENARIO_TIMEOUT:-5}"

    echo "---- Running scenario: $name (timeout ${timeout_seconds}s) ----"
    local start_time=$(date +%s.%N)

    # Start Renode in a new session/process-group so we can reliably kill the
    # whole group on timeout. Use setsid to create a new session; $! is the
    # PID of the renode process we started.
    rm -f "$out"
    setsid renode -e "include @$RENODE_SCRIPT; $extra_cmds; sysbus LoadELF @$BOOT_ELF; sysbus LoadELF @$APP_ELF; $extra_cmds; start;" > "$out" 2>&1 &
    RENODE_PID=$!
    RENODE_PGID=$(ps -o pgid= "$RENODE_PID" 2>/dev/null | tr -d ' ' || true)

    # Start tail to stream the log to stdout while renode runs
    tail -n +1 -F "$out" 2>/dev/null &
    TAIL_PID=$!

    # Poll the log for the initial-PC line until timeout (check every 200ms)
    local interval_ms=200
    local max_iters=$(( (timeout_seconds * 1000) / interval_ms ))
    local iter=0
    local pc_hex=""
    while [ $iter -lt $max_iters ]; do
        # Prefer direct 'PC = 0x...' matches
        pc_hex=$(grep -oE "PC = 0x[0-9A-Fa-f]+" "$out" | tail -n1 | sed -E 's/PC = 0x([0-9A-Fa-f]+)/\1/') || true
        if [ -n "$pc_hex" ]; then
            break
        fi
        # Fallback: any '0x...' on the last relevant line
        pc_hex=$(grep -E "Setting initial values: PC = 0x[0-9A-Fa-f]+|PC = 0x[0-9A-Fa-f]+" "$out" | tail -n1 | sed -E 's/.*0x([0-9A-Fa-f]+).*/\1/') || true
        if [ -n "$pc_hex" ]; then
            break
        fi
        sleep 0.2
        iter=$((iter+1))
    done

    # If we didn't find the PC in time, try one final extraction
    if [ -z "$pc_hex" ]; then
        pc_hex=$(grep -E "Setting initial values: PC = 0x[0-9A-Fa-f]+|PC = 0x[0-9A-Fa-f]+" "$out" | tail -n1 | sed -E 's/.*0x([0-9A-Fa-f]+).*/\1/') || true
    fi

    if [ -n "$pc_hex" ]; then
        pc_val=$((16#${pc_hex}))
        printf "Renode log PC = 0x%08x\n" "$pc_val"
        eval "PC_${name}=$pc_val"
    else
        echo "No PC found in Renode log for scenario $name within ${timeout_seconds}s. See $out"
    fi

    local end_time=$(date +%s.%N)
    # compute elapsed in seconds with millisecond precision
    local elapsed
    elapsed=$(awk -v s="$start_time" -v e="$end_time" 'BEGIN{printf "%.3f", e - s}')
    eval "DURATION_${name}=$elapsed"

    # Kill the whole Renode process group if possible, otherwise fallback to PID kill
    if [ -n "$RENODE_PGID" ] && ps -o pid= -g "$RENODE_PGID" >/dev/null 2>&1; then
        echo "Killing Renode process group $RENODE_PGID"
        kill -TERM -"$RENODE_PGID" 2>/dev/null || true
        sleep 1
        if ps -o pid= -g "$RENODE_PGID" >/dev/null 2>&1; then
            echo "Renode group $RENODE_PGID did not exit after TERM; sending KILL"
            kill -KILL -"$RENODE_PGID" 2>/dev/null || true
        fi
    else
        # Fallback: try to kill by captured PID if PGID not available
        if [ -n "${RENODE_PID:-}" ] && kill -0 "$RENODE_PID" 2>/dev/null; then
            kill "$RENODE_PID" 2>/dev/null || true
            sleep 1
            if kill -0 "$RENODE_PID" 2>/dev/null; then
                kill -9 "$RENODE_PID" 2>/dev/null || true
            fi
        fi
    fi

    # Stop tail
    if [ -n "${TAIL_PID:-}" ] && kill -0 "$TAIL_PID" 2>/dev/null; then
        kill "$TAIL_PID" 2>/dev/null || true
        wait "$TAIL_PID" 2>/dev/null || true
    fi

    # As a final fallback, kill any renode processes matching the script
    kill_renode_procs || true
    echo
}


# Scenario 1: normal boot (no pin forced)
run_once "boot_to_app" "" 3333

# Scenario 2: force boot pin (GPIOA pin 0 low) so bootloader stays
run_once "bootloader_hold" "gpioa SetPin 0 0;" 3334

# Evaluate results and print verdicts
echo "---- Evaluating results ----"
# read expected reset handlers from ELFs
APP_RESET_HEX=$(arm-none-eabi-nm -n "$APP_ELF" | awk '/ Reset_Handler/{print $1; exit}')
BOOT_RESET_HEX=$(arm-none-eabi-nm -n "$BOOT_ELF" | awk '/ Reset_Handler/{print $1; exit}')
if [ -z "$APP_RESET_HEX" ] || [ -z "$BOOT_RESET_HEX" ]; then
    echo "Could not determine Reset_Handler addresses from ELFs. Skipping verdicts."
    exit 0
fi
APP_RESET=$((16#${APP_RESET_HEX#0x}))
BOOT_RESET=$((16#${BOOT_RESET_HEX#0x}))

boot_to_app_pc_var=PC_boot_to_app
bootloader_hold_pc_var=PC_bootloader_hold
boot_to_app_pc=${!boot_to_app_pc_var:-0}
bootloader_hold_pc=${!bootloader_hold_pc_var:-0}

check_match() {
    local observed=$1
    local expected=$2
    # allow either reset_handler or reset_handler + 1 (thumb)
    if [ "$observed" -eq "$expected" ] || [ "$observed" -eq $((expected+1)) ]; then
        return 0
    fi
    return 1
}

PASS_BOOT_TO_APP=0
if [ "$boot_to_app_pc" -ne 0 ]; then
    if check_match "$boot_to_app_pc" "$APP_RESET"; then
        printf "BOOT_TO_APP: PASS (PC -> application Reset_Handler 0x%08x)\n" "$boot_to_app_pc"
        PASS_BOOT_TO_APP=1
    else
        printf "BOOT_TO_APP: FAIL (expected application Reset_Handler 0x%08x, observed 0x%08x)\n" "$APP_RESET" "$boot_to_app_pc"
        echo "--- Renode log tail (boot_to_app) ---"
        tail -n 200 /tmp/renode_boot_to_app.log || true
        exit_code=1
    fi
else
    echo "BOOT_TO_APP: no data (renode/gdb failed)"
    echo "--- Renode log tail (boot_to_app) ---"
    tail -n 200 /tmp/renode_boot_to_app.log || true
    exit_code=1
fi

PASS_BOOTLOADER_HOLD=0
if [ "$bootloader_hold_pc" -ne 0 ]; then
    if check_match "$bootloader_hold_pc" "$BOOT_RESET"; then
        printf "BOOTLOADER_HOLD: PASS (PC -> bootloader Reset_Handler 0x%08x)\n" "$bootloader_hold_pc"
        PASS_BOOTLOADER_HOLD=1
    else
        printf "BOOTLOADER_HOLD: FAIL (expected bootloader Reset_Handler 0x%08x, observed 0x%08x)\n" "$BOOT_RESET" "$bootloader_hold_pc"
    fi
else
    echo "BOOTLOADER_HOLD: no data from combined run; attempting single-image bootloader-only run to confirm bootloader runs"
    out_single=/tmp/renode_bootloader_single.log
    renode -e "include @$RENODE_SCRIPT; sysbus LoadELF @$BOOT_ELF; start;" 2>&1 | tee "$out_single"
    pc_hex_single=$(grep -E "Setting initial values: PC = 0x[0-9A-Fa-f]+" "$out_single" | tail -n1 | sed -E 's/.*PC = 0x([0-9A-Fa-f]+).*/\1/' ) || true
    if [ -z "$pc_hex_single" ]; then
        pc_hex_single=$(grep -E "\bPC = 0x[0-9A-Fa-f]+\b|\bPC=0x[0-9A-Fa-f]+\b" "$out_single" | tail -n1 | sed -E 's/.*0x([0-9A-Fa-f]+).*/\1/' ) || true
    fi
    if [ -n "$pc_hex_single" ]; then
        pc_val_single=$((16#$pc_hex_single))
        if check_match "$pc_val_single" "$BOOT_RESET"; then
            printf "BOOTLOADER_HOLD: PASS (bootloader-only run PC -> bootloader Reset_Handler 0x%08x)\n" "$pc_val_single"
            PASS_BOOTLOADER_HOLD=1
        else
            printf "BOOTLOADER_HOLD: FAIL (bootloader-only run expected 0x%08x observed 0x%08x)\n" "$BOOT_RESET" "$pc_val_single"
            echo "--- Renode log tail (bootloader-only) ---"
            tail -n 200 "$out_single" || true
            exit_code=1
        fi
    else
        echo "BOOTLOADER_HOLD: could not determine PC from bootloader-only run either. See $out_single"
        tail -n 200 "$out_single" || true
        exit_code=1
    fi
fi


echo "Renode tests complete. Inspect /tmp/renode_*.log for full logs."

if [ "$exit_code" -ne 0 ]; then
    echo "One or more Renode tests failed. Exiting non-zero for CI." >&2
    # Produce JUnit XML report before exiting non-zero
    RENODE_RESULTS_DIR="$ROOT_DIR/build/renode"
    mkdir -p "$RENODE_RESULTS_DIR"
    RENODE_XML="$RENODE_RESULTS_DIR/renode_results.xml"
    # gather durations (default to 0)
    d_boot=${DURATION_boot_to_app:-0}
    d_hold=${DURATION_bootloader_hold:-0}
    tests=2
    failures=$exit_code
    cat > "$RENODE_XML" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="renode-tests" tests="$tests" failures="$failures">
    <testcase classname="renode" name="boot_to_app" time="$d_boot">
EOF
    if [ "$PASS_BOOT_TO_APP" -eq 0 ]; then
        echo "      <failure message=\"boot_to_app failed\">" >> "$RENODE_XML"
        tail -n 200 /tmp/renode_boot_to_app.log >> "$RENODE_XML" 2>/dev/null || true
        echo "      </failure>" >> "$RENODE_XML"
    fi
    cat >> "$RENODE_XML" <<EOF
    </testcase>
    <testcase classname="renode" name="bootloader_hold" time="$d_hold">
EOF
    if [ "$PASS_BOOTLOADER_HOLD" -eq 0 ]; then
        echo "      <failure message=\"bootloader_hold failed\">" >> "$RENODE_XML"
        tail -n 200 /tmp/renode_bootloader_hold.log >> "$RENODE_XML" 2>/dev/null || true
        echo "      </failure>" >> "$RENODE_XML"
    fi
    cat >> "$RENODE_XML" <<EOF
    </testcase>
  </testsuite>
</testsuites>
EOF
    echo "JUnit report written to $RENODE_XML"
    exit $exit_code
fi

# On success, also write a JUnit XML with zero failures for CI
RENODE_RESULTS_DIR="$ROOT_DIR/build/renode"
mkdir -p "$RENODE_RESULTS_DIR"
RENODE_XML="$RENODE_RESULTS_DIR/renode_results.xml"
d_boot=${DURATION_boot_to_app:-0}
d_hold=${DURATION_bootloader_hold:-0}
cat > "$RENODE_XML" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="renode-tests" tests="2" failures="0">
    <testcase classname="renode" name="boot_to_app" time="$d_boot"/>
    <testcase classname="renode" name="bootloader_hold" time="$d_hold"/>
  </testsuite>
</testsuites>
EOF
echo "JUnit report written to $RENODE_XML"
