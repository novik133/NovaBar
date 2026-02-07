# Design Document: Enhanced Bluetooth Indicator

## Overview

The Enhanced Bluetooth Indicator provides comprehensive Bluetooth device management for NovaBar through a modular, layered architecture. The design follows the proven patterns from the Enhanced Network Indicator, adapting them for Bluetooth-specific requirements while maintaining consistency with NovaBar's architecture.

### Key Design Principles

1. **Modular Architecture**: Separate concerns into specialized managers (Adapter, Device, Audio, Transfer)
2. **D-Bus Integration**: Leverage BlueZ D-Bus API for all Bluetooth operations
3. **Asynchronous Operations**: Non-blocking operations for responsive UI
4. **Error Resilience**: Comprehensive error handling with graceful degradation
5. **Accessibility First**: Full keyboard navigation and screen reader support
6. **Resource Efficiency**: Minimal memory footprint and CPU usage
7. **Testability**: Design for unit, integration, and property-based testing

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    NovaBar Indicator System                  │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│              BluetoothIndicator (Main Entry)                 │
│  - Lifecycle management                                      │
│  - Icon state management                                     │
│  - Popover coordination                                      │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                  BluetoothController                         │
│  - Coordinates all managers                                  │
│  - Event routing and aggregation                             │
│  - State synchronization                                     │
└─────┬──────────┬──────────┬──────────┬─────────────────────┘
      │          │          │          │
      ▼          ▼          ▼          ▼
┌──────────┐ ┌────────┐ ┌────────┐ ┌──────────┐
│ Adapter  │ │ Device │ │ Audio  │ │ Transfer │
│ Manager  │ │ Manager│ │ Manager│ │ Manager  │
└────┬─────┘ └───┬────┘ └───┬────┘ └────┬─────┘
     │           │          │           │
     └───────────┴──────────┴───────────┘
                 │
     ┌───────────▼────────────┐
     │    BlueZClient         │
     │  - D-Bus communication │
     │  - Signal handling     │
     │  - Object management   │
     └───────────┬────────────┘
                 │
     ┌───────────▼────────────┐
     │    BlueZ Daemon        │
     │  (org.bluez)           │
     └────────────────────────┘
```



## Architecture

### Component Hierarchy

The Enhanced Bluetooth Indicator follows a layered architecture with clear separation of concerns:

**Layer 1: Indicator Interface**
- `BluetoothIndicator`: Main indicator class integrating with NovaBar
- `BluetoothPopover`: Popover UI container
- `BluetoothPanel`: Main UI panel with device list and controls

**Layer 2: Controller**
- `BluetoothController`: Central coordinator managing all subsystems
- Aggregates events from managers
- Coordinates state changes across components
- Manages lifecycle of all managers

**Layer 3: Managers**
- `AdapterManager`: Bluetooth adapter lifecycle and configuration
- `DeviceManager`: Device discovery, pairing, connection management
- `AudioManager`: Audio profile management and routing
- `TransferManager`: File transfer operations via OBEX
- `AgentManager`: Pairing authentication and user interaction

**Layer 4: D-Bus Client**
- `BlueZClient`: Low-level D-Bus communication with BlueZ daemon
- Object path management
- Signal subscription and routing
- Property caching and updates

**Layer 5: Models**
- `BluetoothAdapter`: Adapter state and properties
- `BluetoothDevice`: Device state and properties
- `AudioProfile`: Audio profile information
- `FileTransfer`: Transfer state and progress
- `PairingRequest`: Pairing authentication data

**Layer 6: Support Components**
- `ErrorHandler`: Error categorization and recovery
- `PolicyKitClient`: Authorization management
- `ConfigManager`: Configuration persistence
- `NotificationManager`: User notifications

### Data Flow

**Device Discovery Flow:**
```
User clicks "Scan" → BluetoothPanel
  → BluetoothController.start_discovery()
    → AdapterManager.start_discovery()
      → BlueZClient.call_method("StartDiscovery")
        → BlueZ emits DeviceFound signals
          → BlueZClient routes to DeviceManager
            → DeviceManager creates BluetoothDevice models
              → BluetoothController.device_found signal
                → BluetoothPanel updates device list
```

**Device Connection Flow:**
```
User clicks "Connect" → BluetoothPanel
  → BluetoothController.connect_device(address)
    → DeviceManager.connect(address)
      → BlueZClient.call_method("Connect")
        → BlueZ establishes connection
          → BlueZ emits Connected property change
            → BlueZClient routes to DeviceManager
              → DeviceManager updates device state
                → AudioManager detects audio device
                  → AudioManager configures audio routing
                    → BluetoothController.device_connected signal
                      → BluetoothPanel updates UI
                        → NotificationManager shows notification
```



## Components and Interfaces

### BluetoothIndicator

Main indicator class that integrates with NovaBar's indicator system.

```vala
public class BluetoothIndicator : Indicator {
    private BluetoothController controller;
    private BluetoothPopover popover;
    private Gtk.Image icon;
    
    // Lifecycle
    public override void activate();
    public override void deactivate();
    
    // Icon management
    private void update_icon_state(BluetoothState state);
    private string get_icon_name_for_state(BluetoothState state);
    
    // Event handlers
    private void on_adapter_state_changed(bool powered, bool discovering);
    private void on_device_connected(BluetoothDevice device);
    private void on_device_disconnected(BluetoothDevice device);
}
```

### BluetoothController

Central coordinator managing all Bluetooth subsystems.

```vala
public class BluetoothController : Object {
    private AdapterManager adapter_manager;
    private DeviceManager device_manager;
    private AudioManager audio_manager;
    private TransferManager transfer_manager;
    private AgentManager agent_manager;
    private BlueZClient bluez_client;
    private ErrorHandler error_handler;
    
    // Signals
    public signal void adapter_state_changed(BluetoothAdapter adapter);
    public signal void device_found(BluetoothDevice device);
    public signal void device_connected(BluetoothDevice device);
    public signal void device_disconnected(BluetoothDevice device);
    public signal void pairing_request(PairingRequest request);
    public signal void transfer_progress(FileTransfer transfer);
    public signal void error_occurred(BluetoothError error);
    
    // Initialization
    public async bool initialize() throws Error;
    public void shutdown();
    
    // Adapter operations
    public async void set_adapter_powered(string adapter_path, bool powered) throws Error;
    public async void set_adapter_discoverable(string adapter_path, bool discoverable, uint32 timeout) throws Error;
    public async void start_discovery(string adapter_path) throws Error;
    public async void stop_discovery(string adapter_path) throws Error;
    public Gee.List<BluetoothAdapter> get_adapters();
    
    // Device operations
    public async void pair_device(string device_path) throws Error;
    public async void unpair_device(string device_path) throws Error;
    public async void connect_device(string device_path) throws Error;
    public async void disconnect_device(string device_path) throws Error;
    public async void trust_device(string device_path, bool trusted) throws Error;
    public async void block_device(string device_path, bool blocked) throws Error;
    public Gee.List<BluetoothDevice> get_devices(string? adapter_path = null);
    
    // Audio operations
    public async void set_audio_profile(string device_path, string profile) throws Error;
    public Gee.List<AudioProfile> get_audio_profiles(string device_path);
    
    // Transfer operations
    public async string send_file(string device_path, string file_path) throws Error;
    public async void cancel_transfer(string transfer_path) throws Error;
}
```

### AdapterManager

Manages Bluetooth adapter lifecycle and configuration.

```vala
public class AdapterManager : Object {
    private BlueZClient client;
    private Gee.Map<string, BluetoothAdapter> adapters;
    
    // Signals
    public signal void adapter_added(BluetoothAdapter adapter);
    public signal void adapter_removed(string adapter_path);
    public signal void adapter_property_changed(string adapter_path, string property);
    
    // Initialization
    public async void initialize(BlueZClient client) throws Error;
    
    // Adapter discovery
    public async void scan_adapters() throws Error;
    
    // Adapter operations
    public async void set_powered(string adapter_path, bool powered) throws Error;
    public async void set_discoverable(string adapter_path, bool discoverable, uint32 timeout) throws Error;
    public async void set_pairable(string adapter_path, bool pairable, uint32 timeout) throws Error;
    public async void set_alias(string adapter_path, string alias) throws Error;
    public async void start_discovery(string adapter_path) throws Error;
    public async void stop_discovery(string adapter_path) throws Error;
    
    // Adapter queries
    public BluetoothAdapter? get_adapter(string adapter_path);
    public BluetoothAdapter? get_default_adapter();
    public Gee.List<BluetoothAdapter> get_all_adapters();
    
    // Property monitoring
    private void on_adapter_properties_changed(string adapter_path, HashTable<string, Variant> changed);
}
```

### DeviceManager

Manages device discovery, pairing, and connection lifecycle.

```vala
public class DeviceManager : Object {
    private BlueZClient client;
    private Gee.Map<string, BluetoothDevice> devices;
    private Gee.Set<string> trusted_devices;
    private Gee.Set<string> blocked_devices;
    
    // Signals
    public signal void device_found(BluetoothDevice device);
    public signal void device_removed(string device_path);
    public signal void device_property_changed(string device_path, string property);
    public signal void device_connected(BluetoothDevice device);
    public signal void device_disconnected(BluetoothDevice device);
    
    // Initialization
    public async void initialize(BlueZClient client) throws Error;
    
    // Device discovery
    public async void scan_devices(string adapter_path) throws Error;
    
    // Pairing operations
    public async void pair(string device_path) throws Error;
    public async void unpair(string device_path) throws Error;
    
    // Connection operations
    public async void connect(string device_path) throws Error;
    public async void disconnect(string device_path) throws Error;
    
    // Trust management
    public async void set_trusted(string device_path, bool trusted) throws Error;
    public async void set_blocked(string device_path, bool blocked) throws Error;
    public bool is_trusted(string device_path);
    public bool is_blocked(string device_path);
    
    // Device queries
    public BluetoothDevice? get_device(string device_path);
    public Gee.List<BluetoothDevice> get_devices_for_adapter(string adapter_path);
    public Gee.List<BluetoothDevice> get_connected_devices();
    public Gee.List<BluetoothDevice> get_paired_devices();
    
    // Property monitoring
    private void on_device_properties_changed(string device_path, HashTable<string, Variant> changed);
    private void update_device_rssi(string device_path);
}
```



### AudioManager

Manages audio device profiles and routing.

```vala
public class AudioManager : Object {
    private BlueZClient client;
    private Gee.Map<string, Gee.List<AudioProfile>> device_profiles;
    
    // Signals
    public signal void audio_device_connected(string device_path, string profile);
    public signal void audio_device_disconnected(string device_path);
    public signal void profile_changed(string device_path, string profile);
    
    // Initialization
    public async void initialize(BlueZClient client) throws Error;
    
    // Profile detection
    public async void detect_profiles(string device_path) throws Error;
    public Gee.List<AudioProfile> get_profiles(string device_path);
    
    // Profile management
    public async void connect_profile(string device_path, string profile_uuid) throws Error;
    public async void disconnect_profile(string device_path, string profile_uuid) throws Error;
    public async void set_active_profile(string device_path, string profile_uuid) throws Error;
    
    // Audio routing
    private async void configure_audio_sink(string device_path) throws Error;
    private async void configure_audio_source(string device_path) throws Error;
    private async void cleanup_audio_routing(string device_path) throws Error;
    
    // Device monitoring
    private void on_device_connected(BluetoothDevice device);
    private void on_device_disconnected(BluetoothDevice device);
}
```

### TransferManager

Manages file transfers via OBEX protocol.

```vala
public class TransferManager : Object {
    private BlueZClient client;
    private Gee.Map<string, FileTransfer> active_transfers;
    
    // Signals
    public signal void transfer_started(FileTransfer transfer);
    public signal void transfer_progress(FileTransfer transfer, uint64 bytes_transferred);
    public signal void transfer_completed(FileTransfer transfer);
    public signal void transfer_failed(FileTransfer transfer, Error error);
    
    // Initialization
    public async void initialize(BlueZClient client) throws Error;
    
    // Send operations
    public async string send_file(string device_path, string file_path) throws Error;
    public async string send_files(string device_path, string[] file_paths) throws Error;
    
    // Receive operations
    public async void accept_transfer(string transfer_path, string save_path) throws Error;
    public async void reject_transfer(string transfer_path) throws Error;
    
    // Transfer control
    public async void cancel_transfer(string transfer_path) throws Error;
    public async void pause_transfer(string transfer_path) throws Error;
    public async void resume_transfer(string transfer_path) throws Error;
    
    // Transfer queries
    public FileTransfer? get_transfer(string transfer_path);
    public Gee.List<FileTransfer> get_active_transfers();
    
    // Progress monitoring
    private void on_transfer_properties_changed(string transfer_path, HashTable<string, Variant> changed);
    private void update_transfer_progress(string transfer_path);
}
```

### AgentManager

Handles pairing authentication and user interaction.

```vala
public class AgentManager : Object {
    private BlueZClient client;
    private string agent_path;
    private PairingRequest? current_request;
    
    // Signals
    public signal void pairing_request(PairingRequest request);
    public signal void pairing_completed(string device_path, bool success);
    
    // Initialization
    public async void initialize(BlueZClient client) throws Error;
    public async void register_agent() throws Error;
    public async void unregister_agent() throws Error;
    
    // Agent interface implementation (org.bluez.Agent1)
    public async void request_pin_code(string device_path) throws Error;
    public async uint32 request_passkey(string device_path) throws Error;
    public async void display_passkey(string device_path, uint32 passkey, uint16 entered) throws Error;
    public async void display_pin_code(string device_path, string pin_code) throws Error;
    public async void request_confirmation(string device_path, uint32 passkey) throws Error;
    public async void request_authorization(string device_path) throws Error;
    public async void authorize_service(string device_path, string uuid) throws Error;
    public void cancel() throws Error;
    
    // User response handling
    public async void provide_pin_code(string pin_code) throws Error;
    public async void provide_passkey(uint32 passkey) throws Error;
    public async void confirm_pairing(bool confirmed) throws Error;
    public async void authorize(bool authorized) throws Error;
}
```

### BlueZClient

Low-level D-Bus communication with BlueZ daemon.

```vala
public class BlueZClient : Object {
    private DBusConnection connection;
    private DBusObjectManagerClient object_manager;
    private Gee.Map<string, DBusProxy> proxies;
    private Gee.Map<string, uint> signal_subscriptions;
    
    // Signals
    public signal void object_added(string object_path, string interface_name);
    public signal void object_removed(string object_path, string interface_name);
    public signal void properties_changed(string object_path, string interface_name, HashTable<string, Variant> changed);
    
    // Initialization
    public async void initialize() throws Error;
    public void shutdown();
    
    // Connection management
    private async void connect_to_bluez() throws Error;
    private async void setup_object_manager() throws Error;
    private void reconnect_with_backoff();
    
    // Object management
    public async DBusProxy get_proxy(string object_path, string interface_name) throws Error;
    public Gee.List<string> get_objects_by_interface(string interface_name);
    
    // Method calls
    public async Variant call_method(string object_path, string interface_name, string method_name, Variant? parameters = null) throws Error;
    
    // Property access
    public async Variant get_property(string object_path, string interface_name, string property_name) throws Error;
    public async void set_property(string object_path, string interface_name, string property_name, Variant value) throws Error;
    public async HashTable<string, Variant> get_all_properties(string object_path, string interface_name) throws Error;
    
    // Signal subscription
    public uint subscribe_to_signals(string object_path, string interface_name, owned DBusSignalCallback callback);
    public void unsubscribe_from_signals(uint subscription_id);
    
    // Error handling
    private void on_connection_closed();
    private void on_name_owner_changed(string name, string old_owner, string new_owner);
}
```



## Data Models

### BluetoothAdapter

Represents a Bluetooth adapter (hardware controller).

```vala
public class BluetoothAdapter : Object {
    public string object_path { get; set; }
    public string address { get; set; }
    public string alias { get; set; }
    public string name { get; set; }
    public bool powered { get; set; }
    public bool discoverable { get; set; }
    public bool pairable { get; set; }
    public uint32 discoverable_timeout { get; set; }
    public uint32 pairable_timeout { get; set; }
    public bool discovering { get; set; }
    public string[] uuids { get; set; }
    public string modalias { get; set; }
    
    // Computed properties
    public bool is_default { get; set; }
    public int device_count { get; set; }
    public int connected_device_count { get; set; }
    
    // Methods
    public string get_display_name();
    public string get_status_text();
}
```

### BluetoothDevice

Represents a remote Bluetooth device.

```vala
public class BluetoothDevice : Object {
    public string object_path { get; set; }
    public string adapter_path { get; set; }
    public string address { get; set; }
    public string alias { get; set; }
    public string name { get; set; }
    public string icon { get; set; }
    public uint32 device_class { get; set; }
    public uint16 appearance { get; set; }
    public string[] uuids { get; set; }
    public bool paired { get; set; }
    public bool connected { get; set; }
    public bool trusted { get; set; }
    public bool blocked { get; set; }
    public int16 rssi { get; set; }
    public int8 tx_power { get; set; }
    public string modalias { get; set; }
    
    // Optional properties
    public uint8? battery_percentage { get; set; }
    public bool? services_resolved { get; set; }
    
    // Computed properties
    public DeviceType device_type { get; set; }
    public ConnectionState connection_state { get; set; }
    public SignalStrength signal_strength { get; set; }
    public DateTime? last_seen { get; set; }
    
    // Methods
    public string get_display_name();
    public string get_device_type_icon();
    public string get_signal_strength_icon();
    public bool has_audio_profile();
    public bool has_input_profile();
    public bool supports_file_transfer();
}
```

### AudioProfile

Represents an audio profile supported by a device.

```vala
public class AudioProfile : Object {
    public string uuid { get; set; }
    public string name { get; set; }
    public AudioProfileType profile_type { get; set; }
    public bool connected { get; set; }
    public string? codec { get; set; }
    
    // Methods
    public string get_display_name();
    public string get_description();
}

public enum AudioProfileType {
    A2DP_SINK,      // Advanced Audio Distribution Profile (playback)
    A2DP_SOURCE,    // Advanced Audio Distribution Profile (recording)
    HFP,            // Hands-Free Profile
    HSP,            // Headset Profile
    AVRCP,          // Audio/Video Remote Control Profile
    UNKNOWN
}
```

### FileTransfer

Represents an ongoing file transfer.

```vala
public class FileTransfer : Object {
    public string object_path { get; set; }
    public string session_path { get; set; }
    public string device_path { get; set; }
    public string filename { get; set; }
    public string local_path { get; set; }
    public uint64 size { get; set; }
    public uint64 transferred { get; set; }
    public TransferStatus status { get; set; }
    public TransferDirection direction { get; set; }
    public DateTime started { get; set; }
    public DateTime? completed { get; set; }
    
    // Computed properties
    public double progress_percentage { get; }
    public uint64 bytes_per_second { get; }
    public TimeSpan estimated_time_remaining { get; }
    
    // Methods
    public string get_status_text();
    public string get_progress_text();
}

public enum TransferStatus {
    QUEUED,
    ACTIVE,
    SUSPENDED,
    COMPLETE,
    ERROR
}

public enum TransferDirection {
    SENDING,
    RECEIVING
}
```

### PairingRequest

Represents a pairing authentication request.

```vala
public class PairingRequest : Object {
    public string device_path { get; set; }
    public string device_name { get; set; }
    public PairingMethod method { get; set; }
    public uint32? passkey { get; set; }
    public string? pin_code { get; set; }
    public DateTime requested { get; set; }
    
    // Response handling
    public signal void response_provided(bool accepted, string? value);
    
    // Methods
    public string get_prompt_text();
    public bool requires_user_input();
}

public enum PairingMethod {
    PIN_CODE,           // User enters PIN
    PASSKEY_ENTRY,      // User enters 6-digit passkey
    PASSKEY_DISPLAY,    // User confirms displayed passkey
    PASSKEY_CONFIRMATION, // User confirms passkey matches
    AUTHORIZATION,      // User authorizes connection
    SERVICE_AUTHORIZATION // User authorizes specific service
}
```

### BluetoothError

Represents categorized Bluetooth errors.

```vala
public class BluetoothError : Object {
    public ErrorCategory category { get; set; }
    public string code { get; set; }
    public string message { get; set; }
    public string? details { get; set; }
    public string? recovery_suggestion { get; set; }
    public DateTime occurred { get; set; }
    
    // Methods
    public string get_user_message();
    public bool is_recoverable();
}

public enum ErrorCategory {
    ADAPTER_ERROR,      // Adapter power, configuration issues
    DEVICE_ERROR,       // Device not found, not available
    PAIRING_ERROR,      // Authentication, pairing failures
    CONNECTION_ERROR,   // Connection establishment failures
    TRANSFER_ERROR,     // File transfer failures
    DBUS_ERROR,         // D-Bus communication issues
    PERMISSION_ERROR,   // PolicyKit authorization failures
    TIMEOUT_ERROR,      // Operation timeouts
    UNKNOWN_ERROR
}
```

### Supporting Enums

```vala
public enum BluetoothState {
    OFF,            // Adapter powered off
    ON,             // Adapter powered on, no devices connected
    CONNECTED,      // At least one device connected
    DISCOVERING,    // Discovery in progress
    UNAVAILABLE     // BlueZ daemon not available
}

public enum DeviceType {
    AUDIO,          // Headphones, speakers, headsets
    INPUT,          // Keyboards, mice, game controllers
    PHONE,          // Mobile phones
    COMPUTER,       // Laptops, desktops
    PERIPHERAL,     // Printers, scanners
    WEARABLE,       // Smartwatches, fitness trackers
    UNKNOWN
}

public enum ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    DISCONNECTING
}

public enum SignalStrength {
    EXCELLENT,      // RSSI > -50 dBm
    GOOD,           // RSSI > -60 dBm
    FAIR,           // RSSI > -70 dBm
    WEAK,           // RSSI > -80 dBm
    VERY_WEAK       // RSSI <= -80 dBm
}
```



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, several patterns emerged that allow us to consolidate redundant properties:

**Consolidation Decisions:**
1. **Model completeness properties (1.3, 2.3, 5.1-5.5)**: Combined into comprehensive model validation properties
2. **State transition properties (1.1, 1.2, 4.1-4.3)**: Combined into state machine properties
3. **Persistence properties (17.1-17.6)**: Combined into round-trip persistence properties
4. **Error handling properties (1.7, 2.7, 3.6, 4.5, 8.7, 11.2-11.5)**: Combined into error categorization properties
5. **Notification properties (19.1-19.5)**: Combined into event notification properties
6. **Trust/block management (6.2, 6.6)**: Combined into round-trip properties

This reflection reduces ~100 potential properties to ~35 unique, non-redundant properties that provide comprehensive validation coverage.

### Core State Management Properties

**Property 1: Adapter Power State Consistency**
*For any* Bluetooth adapter, toggling the power state should result in the adapter's powered property matching the requested state.
**Validates: Requirements 1.1**

**Property 2: Adapter State Propagation**
*For any* adapter state change (powered, discoverable, pairable), the change should be reflected in the adapter model and trigger appropriate signals.
**Validates: Requirements 1.2, 1.4**

**Property 3: Adapter Model Completeness**
*For any* Bluetooth adapter, the adapter model should expose all required properties: object_path, address, alias, name, powered, discoverable, pairable, discoverable_timeout, pairable_timeout, discovering, and uuids.
**Validates: Requirements 1.3**

**Property 4: Multi-Adapter Independence**
*For any* system with multiple adapters, changing the state of one adapter should not affect the state of other adapters.
**Validates: Requirements 1.6, 10.4**

**Property 5: Default Adapter Selection**
*For any* system with multiple adapters, setting an adapter as default and then retrieving the default adapter should return the same adapter.
**Validates: Requirements 10.2**

### Device Discovery Properties

**Property 6: Discovery State Consistency**
*For any* adapter, starting discovery should set the adapter's discovering property to true, and stopping discovery should set it to false.
**Validates: Requirements 2.1, 2.5**

**Property 7: Device Model Completeness**
*For any* discovered Bluetooth device, the device model should expose all required properties: object_path, adapter_path, address, alias, name, icon, device_class, appearance, uuids, paired, connected, trusted, blocked, and rssi.
**Validates: Requirements 2.3, 5.1-5.5**

**Property 8: Device Type Filtering**
*For any* device list filtered by device type, all returned devices should have the specified device type.
**Validates: Requirements 2.4, 18.1**

**Property 9: Device Search Accuracy**
*For any* device search query (by name or address), all returned devices should have names or addresses containing the search query (case-insensitive).
**Validates: Requirements 18.3**

**Property 10: Device Sorting Correctness**
*For any* device list sorted by a property (name, RSSI, connection status), the list should be ordered according to that property's values.
**Validates: Requirements 18.4**

### Pairing and Authentication Properties

**Property 11: Pairing State Transition**
*For any* device, successful pairing should result in the device's paired property being true and trusted property being true.
**Validates: Requirements 3.5**

**Property 12: Unpairing Cleanup**
*For any* paired device, unpairing should result in the device's paired property being false and all bonding information removed.
**Validates: Requirements 3.7, 3.8**

**Property 13: Pairing Method Detection**
*For any* pairing request, the agent should generate a PairingRequest with the correct pairing method based on device capabilities (PIN_CODE, PASSKEY_ENTRY, PASSKEY_DISPLAY, PASSKEY_CONFIRMATION, AUTHORIZATION).
**Validates: Requirements 3.2, 3.3, 3.4**

### Connection Management Properties

**Property 14: Connection State Consistency**
*For any* device, successfully connecting should result in the device's connected property being true, and disconnecting should result in it being false.
**Validates: Requirements 4.1, 4.2, 4.3**

**Property 15: Connection State Exposure**
*For any* paired device, the device model should expose a connection_state property with valid values (DISCONNECTED, CONNECTING, CONNECTED, DISCONNECTING).
**Validates: Requirements 4.6**

### Trust and Block Management Properties

**Property 16: Trust Persistence Round-Trip**
*For any* device, marking it as trusted, persisting the configuration, and reloading should result in the device still being marked as trusted.
**Validates: Requirements 6.2, 17.2**

**Property 17: Block Status Round-Trip**
*For any* device, blocking it, persisting the configuration, and reloading should result in the device still being blocked.
**Validates: Requirements 6.4, 6.6, 17.3**

**Property 18: Trust and Block Status Exposure**
*For any* known device, the device model should expose both trusted and blocked properties.
**Validates: Requirements 6.1, 6.7**

### Audio Profile Properties

**Property 19: Audio Device Detection**
*For any* device with audio-related UUIDs (A2DP, HFP, HSP, AVRCP), the device should be categorized as an audio device type.
**Validates: Requirements 7.1**

**Property 20: Audio Profile Activation**
*For any* audio device that connects, the AudioManager should detect and expose available audio profiles.
**Validates: Requirements 7.2, 7.4**

**Property 21: Multiple Audio Device Support**
*For any* system state, multiple audio devices can be simultaneously connected without conflict.
**Validates: Requirements 7.7**

### File Transfer Properties

**Property 22: Transfer Progress Monotonicity**
*For any* active file transfer, the transferred bytes should never decrease (monotonically increasing).
**Validates: Requirements 8.3**

**Property 23: Transfer Metrics Calculation**
*For any* file transfer, the progress_percentage should equal (transferred / size) * 100, and bytes_per_second should be calculated from transferred bytes and elapsed time.
**Validates: Requirements 8.4**

**Property 24: Transfer Cancellation**
*For any* active file transfer, cancelling it should result in the transfer status changing to ERROR or being removed from active transfers.
**Validates: Requirements 8.5**

### Configuration and Persistence Properties

**Property 25: Adapter Configuration Round-Trip**
*For any* adapter configuration (name, discoverable_timeout, pairable_timeout), setting the configuration, persisting, and reloading should result in the same configuration values.
**Validates: Requirements 1.5, 9.1, 9.2, 9.3, 17.4**

**Property 26: UI Preferences Persistence**
*For any* UI preferences (filter settings, sort order), setting the preferences, persisting, and reloading should result in the same preference values.
**Validates: Requirements 17.5, 17.6, 18.7**

**Property 27: Configuration Corruption Resilience**
*For any* corrupted configuration file, loading the configuration should not crash and should result in safe default values being used.
**Validates: Requirements 17.7**

**Property 28: Configuration Validation**
*For any* invalid adapter configuration (e.g., negative timeout), the AdapterManager should reject the configuration and return an error.
**Validates: Requirements 9.7**

### Error Handling Properties

**Property 29: Error Categorization**
*For any* error that occurs, the ErrorHandler should produce a BluetoothError with a valid ErrorCategory (ADAPTER_ERROR, DEVICE_ERROR, PAIRING_ERROR, CONNECTION_ERROR, TRANSFER_ERROR, DBUS_ERROR, PERMISSION_ERROR, TIMEOUT_ERROR, UNKNOWN_ERROR).
**Validates: Requirements 1.7, 2.7, 3.6, 4.5, 8.7, 11.4**

**Property 30: Error Recovery Suggestions**
*For any* BluetoothError, the error should include a non-empty recovery_suggestion field providing actionable guidance.
**Validates: Requirements 11.5**

**Property 31: Timeout Error Specificity**
*For any* operation that times out, the resulting error should have category TIMEOUT_ERROR and a message indicating which operation timed out.
**Validates: Requirements 11.2**

**Property 32: Service Unavailable Error**
*For any* operation attempted when BlueZ daemon is unavailable, the error should have category DBUS_ERROR and indicate service unavailability.
**Validates: Requirements 11.3**

**Property 33: Authorization Failure Error**
*For any* operation that fails due to PolicyKit authorization denial, the error should have category PERMISSION_ERROR and indicate insufficient permissions.
**Validates: Requirements 14.3**

### Notification Properties

**Property 34: Event Notification Completeness**
*For any* significant event (device connected, device disconnected, pairing completed, pairing failed, transfer completed), a notification should be generated with appropriate content.
**Validates: Requirements 19.1, 19.2, 19.3, 19.4, 19.5**

**Property 35: Notification Settings Respect**
*For any* notification setting (enabled/disabled), when notifications are disabled, no notifications should be displayed regardless of events.
**Validates: Requirements 19.6**

### UI and Accessibility Properties

**Property 36: Icon State Mapping**
*For any* Bluetooth state (OFF, ON, CONNECTED, DISCOVERING, UNAVAILABLE), the indicator icon should reflect the current state.
**Validates: Requirements 13.3**

**Property 37: ARIA Attribute Completeness**
*For any* interactive UI element, the element should have appropriate ARIA labels and roles for screen reader compatibility.
**Validates: Requirements 12.3, 12.7**

**Property 38: State Change Announcements**
*For any* significant state change (adapter powered on/off, device connected/disconnected), an accessibility announcement should be generated for screen readers.
**Validates: Requirements 12.4**

### D-Bus Integration Properties

**Property 39: Adapter Change Detection**
*For any* change to an org.bluez.Adapter1 object's properties, the AdapterManager should detect the change and update the corresponding BluetoothAdapter model.
**Validates: Requirements 15.2**

**Property 40: Device Change Detection**
*For any* change to an org.bluez.Device1 object's properties, the DeviceManager should detect the change and update the corresponding BluetoothDevice model.
**Validates: Requirements 15.3**

**Property 41: Agent Registration**
*For any* pairing operation, the AgentManager should be registered with org.bluez.AgentManager1 before pairing begins.
**Validates: Requirements 15.5**

### PolicyKit Integration Properties

**Property 42: Privileged Operation Authorization**
*For any* privileged operation (adapter power control, device pairing, configuration changes), PolicyKit authorization should be requested before the operation proceeds.
**Validates: Requirements 14.1**

**Property 43: Authorization Cancellation Handling**
*For any* PolicyKit authorization dialog that is cancelled, the operation should be aborted gracefully without crashing or leaving inconsistent state.
**Validates: Requirements 14.5**



## Error Handling

### Error Categories and Recovery

The Enhanced Bluetooth Indicator implements comprehensive error handling with categorization, recovery suggestions, and graceful degradation.

#### Error Category Mapping

| Category | Causes | Recovery Strategies |
|----------|--------|---------------------|
| ADAPTER_ERROR | Adapter not found, power control failure, configuration error | Check adapter presence, verify permissions, reset adapter |
| DEVICE_ERROR | Device not found, device not available, invalid device path | Refresh device list, verify device is in range, restart discovery |
| PAIRING_ERROR | Authentication failure, pairing timeout, pairing rejected | Retry pairing, verify PIN/passkey, check device pairable mode |
| CONNECTION_ERROR | Connection timeout, connection refused, profile unavailable | Retry connection, verify device paired, check device powered on |
| TRANSFER_ERROR | Transfer failed, file not found, insufficient space | Retry transfer, verify file exists, check available space |
| DBUS_ERROR | BlueZ unavailable, D-Bus connection lost, method call failed | Restart BlueZ service, reconnect to D-Bus, check system logs |
| PERMISSION_ERROR | PolicyKit authorization denied, insufficient privileges | Grant permissions, run with appropriate privileges |
| TIMEOUT_ERROR | Operation timeout, no response from device | Increase timeout, retry operation, check device responsiveness |
| UNKNOWN_ERROR | Unexpected errors | Log error details, report bug, restart indicator |

#### Error Handler Implementation

```vala
public class ErrorHandler : Object {
    // Error creation
    public BluetoothError create_error(ErrorCategory category, string code, string message, string? details = null);
    
    // Error categorization
    public ErrorCategory categorize_dbus_error(Error error);
    public ErrorCategory categorize_bluez_error(string error_name);
    
    // Recovery suggestions
    public string get_recovery_suggestion(ErrorCategory category, string code);
    
    // Error logging
    public void log_error(BluetoothError error);
    
    // User notification
    public void notify_error(BluetoothError error);
}
```

### Graceful Degradation

When critical errors occur, the indicator degrades functionality gracefully:

1. **BlueZ Unavailable**: Display "Bluetooth unavailable" message, disable all controls, attempt reconnection
2. **Adapter Unavailable**: Hide adapter-specific controls, show "No adapter" message
3. **PolicyKit Unavailable**: Disable privileged operations, show read-only mode
4. **D-Bus Connection Lost**: Attempt reconnection with exponential backoff (1s, 2s, 4s, 8s, max 30s)

### Error Recovery Patterns

**Automatic Recovery:**
- D-Bus connection loss: Automatic reconnection with exponential backoff
- Transient device errors: Automatic retry with backoff
- Property update failures: Retry with cached values

**User-Initiated Recovery:**
- Pairing failures: Prompt user to retry with guidance
- Connection failures: Offer retry with troubleshooting steps
- Configuration errors: Prompt user to correct invalid values

**Unrecoverable Errors:**
- Critical D-Bus errors: Log error, notify user, disable indicator
- Hardware failures: Display error message, suggest system restart
- Corrupted state: Reset to defaults, log error for debugging



## Testing Strategy

### Dual Testing Approach

The Enhanced Bluetooth Indicator uses both unit tests and property-based tests for comprehensive coverage:

**Unit Tests:**
- Specific examples demonstrating correct behavior
- Edge cases and boundary conditions
- Error conditions and failure modes
- Integration points between components
- UI interactions and accessibility features

**Property-Based Tests:**
- Universal properties across all inputs
- State machine transitions
- Round-trip properties (persistence, serialization)
- Invariants (model completeness, data consistency)
- Metamorphic properties (filtering, sorting)

Both testing approaches are complementary and necessary. Unit tests catch concrete bugs in specific scenarios, while property-based tests verify general correctness across a wide input space.

### Property-Based Testing Configuration

**Library Selection:** Use [QuickCheck for Vala](https://github.com/vala-lang/vala-extra-vapis) or implement property testing using GLib.Test with custom generators.

**Test Configuration:**
- Minimum 100 iterations per property test (due to randomization)
- Each property test references its design document property
- Tag format: `// Feature: enhanced-bluetooth-indicator, Property N: [property text]`
- Each correctness property implemented by a SINGLE property-based test

**Example Property Test Structure:**

```vala
// Feature: enhanced-bluetooth-indicator, Property 1: Adapter Power State Consistency
void test_adapter_power_state_consistency() {
    for (int i = 0; i < 100; i++) {
        // Generate random adapter
        var adapter = generate_random_adapter();
        var initial_state = adapter.powered;
        var target_state = !initial_state;
        
        // Toggle power state
        adapter_manager.set_powered(adapter.object_path, target_state);
        
        // Verify state matches request
        assert(adapter.powered == target_state);
    }
}
```

### Test Organization

```
tests/enhanced-bluetooth-indicator/
├── unit/
│   ├── test_adapter_manager.vala
│   ├── test_device_manager.vala
│   ├── test_audio_manager.vala
│   ├── test_transfer_manager.vala
│   ├── test_agent_manager.vala
│   ├── test_bluez_client.vala
│   ├── test_error_handler.vala
│   └── test_models.vala
├── property/
│   ├── test_state_management_properties.vala
│   ├── test_persistence_properties.vala
│   ├── test_error_handling_properties.vala
│   ├── test_device_properties.vala
│   └── test_audio_properties.vala
├── integration/
│   ├── test_dbus_integration.vala
│   ├── test_polkit_integration.vala
│   └── test_end_to_end.vala
├── ui/
│   ├── test_accessibility.vala
│   ├── test_keyboard_navigation.vala
│   └── test_popover_interactions.vala
└── generators/
    ├── adapter_generator.vala
    ├── device_generator.vala
    └── transfer_generator.vala
```

### Test Data Generators

Property-based tests require generators for creating random test data:

**Adapter Generator:**
```vala
public class AdapterGenerator {
    public static BluetoothAdapter generate_random_adapter() {
        var adapter = new BluetoothAdapter();
        adapter.object_path = "/org/bluez/hci" + Random.int_range(0, 10).to_string();
        adapter.address = generate_random_mac_address();
        adapter.alias = generate_random_string(8, 20);
        adapter.powered = Random.boolean();
        adapter.discoverable = Random.boolean();
        adapter.pairable = Random.boolean();
        adapter.discoverable_timeout = Random.int_range(0, 300);
        adapter.pairable_timeout = Random.int_range(0, 300);
        return adapter;
    }
}
```

**Device Generator:**
```vala
public class DeviceGenerator {
    public static BluetoothDevice generate_random_device() {
        var device = new BluetoothDevice();
        device.object_path = "/org/bluez/hci0/dev_" + generate_random_mac_address().replace(":", "_");
        device.address = generate_random_mac_address();
        device.alias = generate_random_string(5, 30);
        device.device_type = (DeviceType) Random.int_range(0, 7);
        device.paired = Random.boolean();
        device.connected = Random.boolean();
        device.trusted = Random.boolean();
        device.blocked = Random.boolean();
        device.rssi = (int16) Random.int_range(-100, -30);
        
        // Generate UUIDs based on device type
        device.uuids = generate_uuids_for_type(device.device_type);
        
        return device;
    }
    
    public static BluetoothDevice generate_audio_device() {
        var device = generate_random_device();
        device.device_type = DeviceType.AUDIO;
        device.uuids = {
            "0000110b-0000-1000-8000-00805f9b34fb", // A2DP
            "0000110e-0000-1000-8000-00805f9b34fb"  // AVRCP
        };
        return device;
    }
}
```

### Coverage Goals

- **Overall Code Coverage**: Minimum 80%
- **Manager Components**: Minimum 90% (critical business logic)
- **Error Handling Paths**: Minimum 85% (error recovery is critical)
- **UI Components**: Minimum 70% (UI testing is more complex)
- **D-Bus Integration**: Minimum 80% (integration layer)

### Continuous Integration

Tests should be run automatically on:
- Every commit (unit tests, fast property tests)
- Pull requests (full test suite including integration tests)
- Nightly builds (extended property tests with 1000+ iterations)

### Manual Testing Checklist

In addition to automated tests, manual testing should verify:

1. **Physical Device Testing**:
   - Pair with real Bluetooth devices (headphones, keyboard, mouse, phone)
   - Test audio playback and recording
   - Test file transfers
   - Test connection stability

2. **Multi-Adapter Testing**:
   - Test with USB Bluetooth adapters
   - Verify adapter switching
   - Test simultaneous adapter operation

3. **Accessibility Testing**:
   - Navigate entire UI with keyboard only
   - Test with screen reader (Orca)
   - Verify high contrast mode
   - Test with large text settings

4. **Error Scenario Testing**:
   - Disable BlueZ daemon during operation
   - Remove adapter during operation
   - Test with devices out of range
   - Test pairing failures
   - Test connection failures

5. **Performance Testing**:
   - Test with 20+ paired devices
   - Test discovery with many nearby devices
   - Monitor memory usage over extended period
   - Verify UI responsiveness under load

### Test Execution

```bash
# Run all tests
meson test -C build

# Run specific test suite
meson test -C build enhanced-bluetooth-indicator:unit
meson test -C build enhanced-bluetooth-indicator:property
meson test -C build enhanced-bluetooth-indicator:integration

# Run with verbose output
meson test -C build --verbose

# Run with coverage
meson test -C build --coverage
ninja coverage -C build
```

