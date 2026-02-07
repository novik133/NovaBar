# Testing the Enhanced Bluetooth Indicator

## Overview

The Enhanced Bluetooth Indicator is now integrated into NovaBar. By default, it uses the **basic** Bluetooth indicator for stability. You can enable the **enhanced** version using an environment variable.

## Current Status

✅ **Compiled Successfully**: The enhanced Bluetooth indicator is built and ready
✅ **Integrated**: The panel now uses the factory function to select the indicator
✅ **Feature Flag**: Environment variable controls which version is used

## How to Test

### Option 1: Basic Bluetooth Indicator (Default)

Run NovaBar normally - it will use the basic Bluetooth indicator:

```bash
./builddir/novabar
```

This is the **current behavior** - same as before.

### Option 2: Enhanced Bluetooth Indicator

Enable the enhanced version with an environment variable:

```bash
export NOVABAR_ENHANCED_BLUETOOTH=1
./builddir/novabar
```

Or in one line:

```bash
NOVABAR_ENHANCED_BLUETOOTH=1 ./builddir/novabar
```

## What to Expect

### Basic Mode (Default)
- Simple Bluetooth on/off toggle
- Basic device list
- Minimal features
- Same as the original indicator

### Enhanced Mode (NOVABAR_ENHANCED_BLUETOOTH=1)
- **Comprehensive Device Management**: Full control over Bluetooth devices
- **Audio Profile Switching**: Switch between A2DP, HFP, HSP profiles
- **File Transfer Support**: Send and receive files via OBEX
- **Advanced Pairing**: Support for all pairing methods
- **Multi-Adapter Support**: Manage multiple Bluetooth adapters
- **Accessibility**: Full keyboard navigation and screen reader support
- **Trust Management**: Mark devices as trusted or blocked
- **Configuration Persistence**: Settings persist across restarts

## Checking Which Mode is Active

When you run NovaBar, check the debug output:

```bash
# Basic mode will show:
BluetoothIndicatorFactory: Creating basic Bluetooth indicator

# Enhanced mode will show:
BluetoothIndicatorFactory: Creating enhanced Bluetooth indicator
EnhancedBluetoothWrapper: Enhanced Bluetooth indicator wrapper created
EnhancedBluetoothWrapper: Initializing enhanced Bluetooth indicator...
```

## Troubleshooting

### Enhanced Mode Not Working

1. **Check the environment variable**:
   ```bash
   echo $NOVABAR_ENHANCED_BLUETOOTH
   # Should output: 1
   ```

2. **Check BlueZ daemon is running**:
   ```bash
   systemctl status bluetooth
   ```

3. **Check for initialization errors**:
   ```bash
   ./builddir/novabar 2>&1 | grep -i bluetooth
   ```

### Enhanced Mode Initialization Fails

If the enhanced indicator fails to initialize:
- It will show "Bluetooth unavailable" in the UI
- Check that BlueZ D-Bus service is available:
  ```bash
  busctl list | grep bluez
  ```
- The indicator will still be functional but with limited features

## Making Enhanced Mode Permanent

To always use the enhanced Bluetooth indicator, add to your shell profile:

```bash
# Add to ~/.bashrc or ~/.profile
export NOVABAR_ENHANCED_BLUETOOTH=1
```

Then restart your shell or run:
```bash
source ~/.bashrc
```

## Testing Checklist

### Basic Functionality
- [ ] Bluetooth indicator appears in the panel
- [ ] Clicking the indicator shows a popup
- [ ] Can toggle Bluetooth on/off
- [ ] Can see connected devices

### Enhanced Features (when enabled)
- [ ] Device discovery works
- [ ] Can pair with new devices
- [ ] Can connect/disconnect devices
- [ ] Audio profile switching works (for audio devices)
- [ ] File transfer UI appears
- [ ] Settings panel is accessible
- [ ] Keyboard navigation works
- [ ] Configuration persists after restart

## Known Limitations

1. **Runtime Switching**: Currently requires NovaBar restart to change modes
2. **BlueZ Dependency**: Enhanced mode requires BlueZ daemon to be running
3. **D-Bus Access**: Enhanced mode requires D-Bus access to org.bluez

## Next Steps

1. Test basic mode (default behavior)
2. Test enhanced mode with the environment variable
3. Report any issues or bugs
4. Provide feedback on the enhanced features

## Logs and Debugging

Enable verbose logging:

```bash
# Basic mode
./builddir/novabar --verbose

# Enhanced mode
NOVABAR_ENHANCED_BLUETOOTH=1 ./builddir/novabar --verbose
```

Check system logs:
```bash
journalctl -f | grep -i bluetooth
```

## Installation

To install the compiled version:

```bash
sudo ninja -C builddir install
```

Then run from the installed location:
```bash
novabar
```

Or with enhanced mode:
```bash
NOVABAR_ENHANCED_BLUETOOTH=1 novabar
```

## Feedback

Please test both modes and report:
- Which mode you prefer
- Any bugs or issues
- Feature requests
- Performance observations
- UI/UX feedback

The enhanced Bluetooth indicator is ready for testing!
