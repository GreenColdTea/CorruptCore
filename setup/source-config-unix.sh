#!/bin/bash

cd "$(dirname "$0")/.."

echo "Installing dependencies with HMM..."
echo

if [ ! -f "hmm.json" ]; then
    echo "ERROR: hmm.json not found!"
    exit 1
fi

if ! haxelib list | grep -q "^hmm"; then
    echo "hmm not found. Installing hmm globally..."
    haxelib --global install hmm
    haxelib --global run hmm setup
fi

haxelib run hmm install

if [ $? -ne 0 ]; then
    echo
    echo "ERROR: Failed to install dependencies."
    exit 1
fi

echo
echo "Dependencies installed successfully!"