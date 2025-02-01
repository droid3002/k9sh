#!/bin/bash

# Custom shell name
K9SH_NAME="k9sh"
K9SH_PROMPT="ksh>"
K9SH_HISTORY="$HOME/.k9sh_history"
K9SH_CONFIG="$HOME/.k9shrc"

# Load history from file if it exists
[ -f "$K9SH_HISTORY" ] && history -r "$K9SH_HISTORY"

# Load config file
[ -f "$K9SH_CONFIG" ] && source "$K9SH_CONFIG"

# ASCII Art for 'ver' Command
K9SH_ASCII_DOG="
 / \\__
(    @\\____
 /         O
/   (_____/
/_____/   U
"

# Detect package manager
if command -v pkg &>/dev/null; then
    PKG_MANAGER="pkg"
elif command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
else
    PKG_MANAGER="none"
fi

# Handle exit
cleanup() {
    echo "Exiting $K9SH_NAME..."
    history -w "$K9SH_HISTORY"  # Save history
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT  # Handle Ctrl+C and exit commands

# Enable tab completion
bind '"\t":menu-complete'

# Background job management
declare -A JOBS
JOB_COUNT=0

check_jobs() {
    for pid in "${!JOBS[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "[${JOBS[$pid]}] Done"
            unset "JOBS[$pid]"
        fi
    done
}

# kpkg (package installer) function
kpkg() {
    if [ "$PKG_MANAGER" == "pkg" ]; then
        echo "Using pkg..."
        sudo pkg install "$@"
    elif [ "$PKG_MANAGER" == "apt" ]; then
        echo "Using apt (kapt)..."
        sudo apt install "$@"
    else
        echo "No supported package manager found!"
    fi
}

# Main command loop
while true; do
    check_jobs  # Clean up finished background jobs
    echo -n "$K9SH_PROMPT"
    read -r line

    # Skip empty input
    [ -z "$line" ] && continue

    # Save to history
    history -s "$line"

    # Handle built-in commands
    case "$line" in
        "exit")
            cleanup
            ;;
        "cd "*)
            dir="${line#cd }"
            cd "$dir" || echo "$K9SH_NAME: cd: $dir: No such file or directory"
            continue
            ;;
        "history")
            history
            continue
            ;;
        "ver")
            echo "$K9SH_ASCII_DOG"
            echo "$K9SH_NAME version 1.1"
            continue
            ;;
        "jobs")
            for pid in "${!JOBS[@]}"; do
                echo "[${JOBS[$pid]}] Running (PID: $pid)"
            done
            continue
            ;;
        "fg "*)
            job_id="${line#fg }"
            fg_pid=""
            for pid in "${!JOBS[@]}"; do
                if [[ "${JOBS[$pid]}" == "$job_id" ]]; then
                    fg_pid=$pid
                    break
                fi
            done
            if [ -n "$fg_pid" ]; then
                echo "Bringing job [$job_id] to foreground"
                fg "$fg_pid"
                unset "JOBS[$fg_pid]"
            else
                echo "$K9SH_NAME: fg: No such job"
            fi
            continue
            ;;
        "bg "*)
            job_id="${line#bg }"
            for pid in "${!JOBS[@]}"; do
                if [[ "${JOBS[$pid]}" == "$job_id" ]]; then
                    echo "Resuming job [$job_id] in background"
                    kill -CONT "$pid"
                    break
                fi
            done
            continue
            ;;
        kpkg*)
            kpkg "${line#kpkg }"
            continue
            ;;
        sudo*)
            eval "$line"
            continue
            ;;
        *)
            # Handle background jobs
            if [[ "$line" == *"&" ]]; then
                cmd="${line%&}"
                eval "$cmd" &
                pid=$!
                JOB_COUNT=$((JOB_COUNT + 1))
                JOBS[$pid]=$JOB_COUNT
                echo "[$JOB_COUNT] Started (PID: $pid)"
                continue
            fi

            # Handle pipes
            if [[ "$line" == *"|"* ]]; then
                eval "$line"
            else
                eval "$line"
            fi
            ;;
    esac
done
