#!/bin/sh

EMU_EXE=parallel_n64
CORES_PATH=$(dirname "$0")

###############################

EMU_TAG=$(basename "$(dirname "$0")" .pak)
ROM="$1"
mkdir -p "$BIOS_PATH/$EMU_TAG"
mkdir -p "$SAVES_PATH/$EMU_TAG"
mkdir -p "$CHEATS_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME"

# Save and boost CPU for N64 emulation
CPU_GOV_FILE="/tmp/p64_cpu_gov"
CPU_MIN_FILE="/tmp/p64_cpu_min"
CPU_MAX_FILE="/tmp/p64_cpu_max"
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor > "$CPU_GOV_FILE"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq > "$CPU_MIN_FILE"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq > "$CPU_MAX_FILE"
    echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    echo 1608000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
    echo 1800000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
fi

minarch.elf "$CORES_PATH/${EMU_EXE}_libretro.so" "$ROM" &> "$LOGS_PATH/$EMU_TAG.txt"

# Restore CPU settings
if [ -f "$CPU_GOV_FILE" ]; then
    cat "$CPU_GOV_FILE" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    cat "$CPU_MIN_FILE" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
    cat "$CPU_MAX_FILE" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    rm -f "$CPU_GOV_FILE" "$CPU_MIN_FILE" "$CPU_MAX_FILE"
fi
