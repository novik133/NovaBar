#!/bin/bash

# Debug script for NovaBar hanging issue on Fedora 43
# This script helps identify where the application hangs

echo "=== NovaBar Debug Script ==="
echo "System Information:"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo "Desktop: $XDG_CURRENT_DESKTOP"
echo "Session: $XDG_SESSION_TYPE"
echo "Display: $DISPLAY"
echo "Wayland Display: $WAYLAND_DISPLAY"
echo ""

echo "=== Checking Dependencies ==="
echo "GTK version:"
pkg-config --modversion gtk+-3.0 2>/dev/null || echo "GTK+3 not found"

echo "NetworkManager version:"
pkg-config --modversion libnm 2>/dev/null || echo "NetworkManager development files not found"

echo "libwnck version:"
pkg-config --modversion libwnck-3.0 2>/dev/null || echo "libwnck-3.0 not found"

echo ""
echo "=== Running NovaBar with verbose output ==="
echo "Press Ctrl+C to stop if it hangs..."
echo ""

# Set environment variables for debugging
export G_MESSAGES_DEBUG=all
export GTK_DEBUG=interactive

# Run with timeout to prevent indefinite hang
timeout 30s ./novabar -v

exit_code=$?
if [ $exit_code -eq 124 ]; then
    echo ""
    echo "=== APPLICATION TIMED OUT AFTER 30 SECONDS ==="
    echo "This confirms the hanging issue."
    echo ""
    echo "Suggested fixes:"
    echo "1. Try disabling NetworkManager integration"
    echo "2. Check if NetworkManager service is running: systemctl status NetworkManager"
    echo "3. Check permissions for NetworkManager access"
    echo "4. Try running as root to test permissions: sudo ./novabar -v"
elif [ $exit_code -eq 0 ]; then
    echo ""
    echo "=== APPLICATION COMPLETED SUCCESSFULLY ==="
else
    echo ""
    echo "=== APPLICATION EXITED WITH CODE: $exit_code ==="
fi