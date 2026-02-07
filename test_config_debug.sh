#!/bin/bash

# Run the config manager test and capture output
cd builddir
./tests/test_bluetooth_config_manager 2>&1 | tee /tmp/config_test_output.txt

# Check if config file was created
CONFIG_DIR="$HOME/.config/novabar/bluetooth"
CONFIG_FILE="$CONFIG_DIR/config.ini"

echo ""
echo "=== Config File Location ==="
echo "Expected: $CONFIG_FILE"
echo "Exists: $(test -f "$CONFIG_FILE" && echo "YES" || echo "NO")"

if [ -f "$CONFIG_FILE" ]; then
    echo ""
    echo "=== Config File Contents ==="
    cat "$CONFIG_FILE"
fi
