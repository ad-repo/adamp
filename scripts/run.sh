#!/bin/bash
# AdAmp Build and Run Script
# Kills any running instance, builds, and runs the app

set -e

cd "$(dirname "$0")/.."

echo "🔄 Stopping any running AdAmp instances..."
# Kill only the AdAmp binary, not processes with adamp in path
pkill -9 -x AdAmp 2>/dev/null || true
sleep 1

# Wait for any lingering processes to fully terminate
while pgrep -x AdAmp > /dev/null 2>&1; do
    echo "⏳ Waiting for previous instance to terminate..."
    sleep 0.5
done

echo "🔨 Building AdAmp..."
swift build

echo "🚀 Launching AdAmp..."
.build/debug/AdAmp &

echo "✅ AdAmp is running!"
