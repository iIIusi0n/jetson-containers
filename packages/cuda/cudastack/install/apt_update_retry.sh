#!/usr/bin/env bash

apt_update_retry() {
    local attempt=1
    local max_attempts=5
    local delay=15

    while (( attempt <= max_attempts )); do
        if apt-get update; then
            return 0
        fi

        if (( attempt == max_attempts )); then
            return 1
        fi

        echo "apt-get update failed (attempt ${attempt}/${max_attempts}), retrying in ${delay}s"
        rm -rf /var/lib/apt/lists/partial/*
        sleep "${delay}"
        attempt=$((attempt + 1))
    done
}
