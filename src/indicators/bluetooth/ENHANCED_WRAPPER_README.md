# Enhanced Bluetooth Indicator Wrapper

## Overview

The Enhanced Bluetooth Indicator Wrapper provides a compatibility layer between NovaBar's indicator system and the enhanced Bluetooth indicator implementation. It allows seamless switching between the basic and enhanced Bluetooth indicators through a feature flag.

## Architecture

```
┌─────────────────────────────────────────┐
│   NovaBar Indicator System              │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│   Indicators.create_bluetooth_indicator()│
│   (Factory Function)                     │
└────────────┬───────────────┬────────────┘
             │               │
    ┌────────▼──────┐   ┌───▼──────────────────┐
    │ Basic         │   │ Enhanced Wrapper      │
    │ Bluetooth     │   │ (Indicators.Enhanced. │
    │ Indicator     │   │  BluetoothIndicator)  │
    └───────────────┘   └───┬──────────────────┘
                            │
                    ┌───────▼────────────────────┐
                    │ EnhancedBluetooth.         │
                    │ BluetoothIndicator         │
                    │ (Full Implementation)      │
                    └────────────────────────────┘
```

## Usage

### Enabling Enhanced Mode

The enhanced Bluetooth indicator can be enabled by setting an environment variable:

```bash
export NOVABAR_ENHANCED_BLUETOOTH=1
novabar
```

### Default Mode

By default (without the environment variable), NovaBar will use the basic Bluetooth indicator for stability and compatibility.

## Features

### Enhanced Mode Features

When enabled, the enhanced Bluetooth indicator provides:

- **Comprehensive Device Management**: Full control over Bluetooth devices
- **Audio Profile Switching**: Switch between A2DP, HFP, HSP profiles
- **File Transfer Support**: Send and receive files via OBEX
- **Advanced Pairing**: Support for all pairing methods (PIN, passkey, confirmation)
- **Multi-Adapter Support**: Manage multiple Bluetooth adapters
- **Accessibility**: Full keyboard navigation and screen reader support
- **Trust Management**: Mark devices as trusted or blocked
- **Configuration Persistence**: Settings persist across restarts

### Basic Mode Features

The basic Bluetooth indicator provides:

- Simple on/off toggle
- Connected device list
- Basic device connection
- Minimal resource usage

## API

### Factory Function

```vala
public Gtk.Widget create_bluetooth_indicator()
```

Creates and returns the appropriate Bluetooth indicator based on the feature flag.

**Returns**: A `Gtk.Widget` containing either the enhanced or basic Bluetooth indicator.

### Enhanced Wrapper Class

```vala
public class Indicators.Enhanced.BluetoothIndicator : Gtk.EventBox
```

Wrapper class that provides compatibility with NovaBar's indicator system.

#### Signals

- `bluetooth_state_changed(EnhancedBluetooth.BluetoothState state)`: Emitted when Bluetooth state changes
- `device_status_changed(string device_path, bool connected)`: Emitted when device connection status changes

#### Methods

- `bool is_initialized()`: Check if the enhanced indicator is initialized
- `EnhancedBluetooth.BluetoothState get_bluetooth_state()`: Get current Bluetooth state
- `async void refresh()`: Refresh the indicator state
- `void show_notification(string message, EnhancedBluetooth.NotificationType type)`: Show a notification
- `void hide_notification()`: Hide the current notification
- `EnhancedBluetooth.BluetoothIndicator get_enhanced_indicator()`: Get the enhanced indicator instance

## Implementation Details

### Backward Compatibility

The wrapper ensures backward compatibility by:

1. **Extending Gtk.EventBox**: Maintains the same widget hierarchy as the basic indicator
2. **Forwarding Events**: Button press events are forwarded to the enhanced indicator
3. **Signal Forwarding**: Signals from the enhanced indicator are re-emitted by the wrapper
4. **Asynchronous Initialization**: The controller is initialized asynchronously to avoid blocking

### Feature Flag Priority

The factory function checks for the enhanced mode in the following order:

1. **Environment Variable**: `NOVABAR_ENHANCED_BLUETOOTH=1`
2. **Configuration File**: (Future implementation)
3. **Default**: Use basic indicator

### Error Handling

If the enhanced indicator fails to initialize:

- The wrapper logs the error using `Debug.log()`
- The indicator state is set to `UNAVAILABLE`
- The UI remains functional but with limited features

## Testing

Tests for the wrapper are located in `tests/enhanced-bluetooth-indicator/test_wrapper.vala`.

Run tests with:

```bash
meson test test_bluetooth_wrapper
```

## Migration Guide

### For Users

To try the enhanced Bluetooth indicator:

1. Set the environment variable: `export NOVABAR_ENHANCED_BLUETOOTH=1`
2. Restart NovaBar
3. Click the Bluetooth indicator to access enhanced features

To revert to the basic indicator:

1. Unset the environment variable: `unset NOVABAR_ENHANCED_BLUETOOTH`
2. Restart NovaBar

### For Developers

To integrate the wrapper into NovaBar:

1. Include `enhanced_wrapper.vala` in the build configuration
2. Use the factory function to create the indicator:

```vala
var bluetooth_indicator = Indicators.create_bluetooth_indicator();
panel.add(bluetooth_indicator);
```

## Future Enhancements

- Configuration file support for persistent feature flag
- Per-user preferences for enhanced mode
- Automatic fallback to basic mode on initialization failure
- Runtime switching between basic and enhanced modes

## Troubleshooting

### Enhanced Mode Not Working

1. Check that the environment variable is set: `echo $NOVABAR_ENHANCED_BLUETOOTH`
2. Check logs for initialization errors: `journalctl -f | grep Bluetooth`
3. Verify BlueZ daemon is running: `systemctl status bluetooth`

### Compilation Errors

1. Ensure all enhanced Bluetooth files are included in `meson.build`
2. Verify dependencies are installed: `gtk+-3.0`, `gio-2.0`, `glib-2.0`
3. Check for missing BlueZ D-Bus interfaces

## License

This wrapper is part of NovaBar and follows the same license as the main project.
