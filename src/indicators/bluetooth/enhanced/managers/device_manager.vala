/**
 * Enhanced Bluetooth Indicator - Device Manager
 * 
 * Manages device discovery, pairing, connection lifecycle, and trust/block management.
 */

using GLib;

namespace EnhancedBluetooth {

    /**
     * Device Manager for Bluetooth device lifecycle management
     * 
     * This class handles device discovery, pairing operations, connection management,
     * trust/block management, and property monitoring for Bluetooth devices.
     */
    public class DeviceManager : Object {
        // D-Bus constants
        private const string DEVICE_INTERFACE = "org.bluez.Device1";
        
        // BlueZ client reference
        private BlueZClient client;
        
        // Device storage
        private HashTable<string, BluetoothDevice> devices;
        
        // Trust and block management
        private GenericArray<string> trusted_devices;
        private GenericArray<string> blocked_devices;
        
        // Initialization state
        private bool is_initialized;
        
        // RSSI monitoring
        private uint rssi_monitor_timeout_id;
        private const int RSSI_MONITOR_INTERVAL_MS = 30000;  // 30 seconds
        
        /**
         * Signal emitted when a device is discovered
         */
        public signal void device_found(BluetoothDevice device);
        
        /**
         * Signal emitted when a device is removed
         */
        public signal void device_removed(string device_path);
        
        /**
         * Signal emitted when device properties change
         */
        public signal void device_property_changed(string device_path, string property);
        
        /**
         * Signal emitted when a device connects
         */
        public signal void device_connected(BluetoothDevice device);
        
        /**
         * Signal emitted when a device disconnects
         */
        public signal void device_disconnected(BluetoothDevice device);
        
        /**
         * Constructor
         */
        public DeviceManager() {
            devices = new HashTable<string, BluetoothDevice>(str_hash, str_equal);
            trusted_devices = new GenericArray<string>();
            blocked_devices = new GenericArray<string>();
            is_initialized = false;
        }
        
        /**
         * Initialize the device manager with a BlueZ client
         * 
         * @param client The BlueZ D-Bus client
         */
        public async void initialize(BlueZClient client) throws Error {
            if (is_initialized) {
                warning("DeviceManager: Already initialized");
                return;
            }
            
            debug("DeviceManager: Initializing...");
            
            this.client = client;
            
            // Subscribe to BlueZ object events
            client.object_added.connect(on_object_added);
            client.object_removed.connect(on_object_removed);
            client.properties_changed.connect(on_properties_changed);
            
            // Scan for existing devices
            yield scan_all_devices();
            
            // Start RSSI monitoring
            start_rssi_monitoring();
            
            is_initialized = true;
            debug("DeviceManager: Initialization complete");
        }
        
        /**
         * Shutdown the device manager
         */
        public void shutdown() {
            debug("DeviceManager: Shutting down...");
            
            // Stop RSSI monitoring
            stop_rssi_monitoring();
            
            // Clear data
            devices.remove_all();
            trusted_devices = new GenericArray<string>();
            blocked_devices = new GenericArray<string>();
            
            is_initialized = false;
            debug("DeviceManager: Shutdown complete");
        }
        
        /**
         * Start RSSI monitoring for connected devices
         */
        private void start_rssi_monitoring() {
            if (rssi_monitor_timeout_id > 0) {
                return;
            }
            
            debug("DeviceManager: Starting RSSI monitoring");
            
            rssi_monitor_timeout_id = Timeout.add(RSSI_MONITOR_INTERVAL_MS, () => {
                update_rssi_for_connected_devices();
                return Source.CONTINUE;
            });
        }
        
        /**
         * Stop RSSI monitoring
         */
        private void stop_rssi_monitoring() {
            if (rssi_monitor_timeout_id > 0) {
                Source.remove(rssi_monitor_timeout_id);
                rssi_monitor_timeout_id = 0;
                debug("DeviceManager: Stopped RSSI monitoring");
            }
        }
        
        /**
         * Update RSSI for all connected devices
         */
        private void update_rssi_for_connected_devices() {
            devices.foreach((key, device) => {
                if (device.connected) {
                    update_device_rssi.begin(key);
                }
            });
        }
        
        /**
         * Update RSSI for a specific device
         */
        private async void update_device_rssi(string device_path) {
            try {
                var rssi_variant = yield client.get_property(
                    device_path,
                    DEVICE_INTERFACE,
                    "RSSI"
                );
                
                var device = devices[device_path];
                if (device != null) {
                    var old_rssi = device.rssi;
                    device.rssi = rssi_variant.get_int16();
                    device.update_signal_strength();
                    
                    if (old_rssi != device.rssi) {
                        device_property_changed(device_path, "RSSI");
                    }
                }
                
            } catch (Error e) {
                // RSSI might not be available for all devices, don't spam warnings
                debug("DeviceManager: Failed to update RSSI for %s: %s", device_path, e.message);
            }
        }
        
        /**
         * Scan for all existing devices across all adapters
         */
        private async void scan_all_devices() throws Error {
            debug("DeviceManager: Scanning for existing devices...");
            
            var device_paths = client.get_objects_by_interface(DEVICE_INTERFACE);
            
            debug("DeviceManager: Found %u existing devices", device_paths.length);
            
            for (uint i = 0; i < device_paths.length; i++) {
                try {
                    yield create_device_from_path(device_paths[i]);
                } catch (Error e) {
                    warning("DeviceManager: Failed to create device from path %s: %s",
                           device_paths[i], e.message);
                }
            }
        }
        
        /**
         * Scan for devices on a specific adapter
         * 
         * @param adapter_path The adapter object path
         */
        public async void scan_devices(string adapter_path) throws Error {
            debug("DeviceManager: Scanning devices for adapter %s", adapter_path);
            
            var device_paths = client.get_objects_by_interface(DEVICE_INTERFACE);
            
            for (uint i = 0; i < device_paths.length; i++) {
                var device_path = device_paths[i];
                
                // Check if device belongs to this adapter
                if (!device_path.has_prefix(adapter_path)) {
                    continue;
                }
                
                // Skip if we already have this device
                if (devices.contains(device_path)) {
                    continue;
                }
                
                try {
                    yield create_device_from_path(device_path);
                } catch (Error e) {
                    warning("DeviceManager: Failed to create device from path %s: %s",
                           device_path, e.message);
                }
            }
        }
        
        /**
         * Create a BluetoothDevice from a D-Bus object path
         */
        private async BluetoothDevice create_device_from_path(string device_path) throws Error {
            debug("DeviceManager: Creating device from path: %s", device_path);
            
            // Get all device properties
            var properties = yield client.get_all_properties(device_path, DEVICE_INTERFACE);
            
            // Create device model
            var device = new BluetoothDevice();
            device.object_path = device_path;
            
            // Populate device properties
            update_device_properties(device, properties);
            
            // Store device
            devices[device_path] = device;
            
            // Update trust/block sets
            if (device.trusted) {
                add_to_array_if_not_present(trusted_devices, device_path);
            }
            if (device.blocked) {
                add_to_array_if_not_present(blocked_devices, device_path);
            }
            
            // Emit signal
            device_found(device);
            
            debug("DeviceManager: Created device: %s (%s)", device.get_display_name(), device.address);
            
            return device;
        }
        
        /**
         * Update device properties from D-Bus property hash table
         */
        private void update_device_properties(BluetoothDevice device, HashTable<string, Variant> properties) {
            // Extract adapter path from device path
            // Format: /org/bluez/hciX/dev_XX_XX_XX_XX_XX_XX
            var path_parts = device.object_path.split("/");
            if (path_parts.length >= 4) {
                device.adapter_path = "/" + string.joinv("/", path_parts[1:4]);
            }
            
            // Core properties
            if (properties.contains("Address")) {
                device.address = properties["Address"].get_string();
            }
            if (properties.contains("Alias")) {
                device.alias = properties["Alias"].get_string();
            }
            if (properties.contains("Name")) {
                device.name = properties["Name"].get_string();
            }
            if (properties.contains("Icon")) {
                device.icon = properties["Icon"].get_string();
            }
            if (properties.contains("Class")) {
                device.device_class = properties["Class"].get_uint32();
            }
            if (properties.contains("Appearance")) {
                device.appearance = properties["Appearance"].get_uint16();
            }
            if (properties.contains("UUIDs")) {
                device.uuids = properties["UUIDs"].dup_strv();
            }
            if (properties.contains("Paired")) {
                device.paired = properties["Paired"].get_boolean();
            }
            if (properties.contains("Connected")) {
                device.connected = properties["Connected"].get_boolean();
            }
            if (properties.contains("Trusted")) {
                device.trusted = properties["Trusted"].get_boolean();
            }
            if (properties.contains("Blocked")) {
                device.blocked = properties["Blocked"].get_boolean();
            }
            if (properties.contains("RSSI")) {
                device.rssi = properties["RSSI"].get_int16();
            }
            if (properties.contains("TxPower")) {
                device.tx_power = (int8) properties["TxPower"].get_int16();
            }
            if (properties.contains("Modalias")) {
                device.modalias = properties["Modalias"].get_string();
            }
            
            // Optional properties
            if (properties.contains("BatteryPercentage")) {
                device.battery_percentage = properties["BatteryPercentage"].get_byte();
            }
            if (properties.contains("ServicesResolved")) {
                device.services_resolved = properties["ServicesResolved"].get_boolean();
            }
            
            // Update computed properties
            device.update_signal_strength();
            device.update_connection_state();
            device.last_seen = new DateTime.now_local();
            
            // Determine device type from UUIDs
            if (device.has_audio_profile()) {
                device.device_type = DeviceType.AUDIO;
            } else if (device.has_input_profile()) {
                device.device_type = DeviceType.INPUT;
            } else if (device.icon != null) {
                // Try to determine from icon
                if (device.icon.contains("phone")) {
                    device.device_type = DeviceType.PHONE;
                } else if (device.icon.contains("computer")) {
                    device.device_type = DeviceType.COMPUTER;
                } else if (device.icon.contains("printer")) {
                    device.device_type = DeviceType.PERIPHERAL;
                }
            }
        }
        
        /**
         * Get a device by object path
         * 
         * @param device_path The device object path
         * @return The device or null if not found
         */
        public BluetoothDevice? get_device(string device_path) {
            return devices[device_path];
        }
        
        /**
         * Get all devices for a specific adapter
         * 
         * @param adapter_path The adapter object path
         * @return List of devices
         */
        public GenericArray<BluetoothDevice> get_devices_for_adapter(string adapter_path) {
            var result = new GenericArray<BluetoothDevice>();
            
            devices.foreach((key, device) => {
                if (device.adapter_path == adapter_path) {
                    result.add(device);
                }
            });
            
            return result;
        }
        
        /**
         * Get all connected devices
         * 
         * @return List of connected devices
         */
        public GenericArray<BluetoothDevice> get_connected_devices() {
            var result = new GenericArray<BluetoothDevice>();
            
            devices.foreach((key, device) => {
                if (device.connected) {
                    result.add(device);
                }
            });
            
            return result;
        }
        
        /**
         * Get all paired devices
         * 
         * @return List of paired devices
         */
        public GenericArray<BluetoothDevice> get_paired_devices() {
            var result = new GenericArray<BluetoothDevice>();
            
            devices.foreach((key, device) => {
                if (device.paired) {
                    result.add(device);
                }
            });
            
            return result;
        }
        
        /**
         * Set trusted status for a device
         * 
         * @param device_path The device object path
         * @param trusted Whether the device should be trusted
         */
        public async void set_trusted(string device_path, bool trusted) throws Error {
            debug("DeviceManager: Setting trusted=%s for device: %s", trusted.to_string(), device_path);
            
            var device = devices[device_path];
            if (device == null) {
                throw new IOError.NOT_FOUND("Device not found: %s", device_path);
            }
            
            if (device.trusted == trusted) {
                debug("DeviceManager: Device already has trusted=%s: %s", trusted.to_string(), device_path);
                return;
            }
            
            try {
                // Set Trusted property on device
                yield client.set_property(
                    device_path,
                    DEVICE_INTERFACE,
                    "Trusted",
                    new Variant.boolean(trusted)
                );
                
                debug("DeviceManager: Set trusted successful: %s", device.get_display_name());
                
            } catch (Error e) {
                warning("DeviceManager: Set trusted failed for %s: %s",
                       device.get_display_name(), e.message);
                throw e;
            }
        }
        
        /**
         * Set blocked status for a device
         * 
         * @param device_path The device object path
         * @param blocked Whether the device should be blocked
         */
        public async void set_blocked(string device_path, bool blocked) throws Error {
            debug("DeviceManager: Setting blocked=%s for device: %s", blocked.to_string(), device_path);
            
            var device = devices[device_path];
            if (device == null) {
                throw new IOError.NOT_FOUND("Device not found: %s", device_path);
            }
            
            if (device.blocked == blocked) {
                debug("DeviceManager: Device already has blocked=%s: %s", blocked.to_string(), device_path);
                return;
            }
            
            try {
                // Set Blocked property on device
                yield client.set_property(
                    device_path,
                    DEVICE_INTERFACE,
                    "Blocked",
                    new Variant.boolean(blocked)
                );
                
                debug("DeviceManager: Set blocked successful: %s", device.get_display_name());
                
            } catch (Error e) {
                warning("DeviceManager: Set blocked failed for %s: %s",
                       device.get_display_name(), e.message);
                throw e;
            }
        }
        
        /**
         * Check if a device is trusted
         * 
         * @param device_path The device object path
         * @return true if the device is trusted
         */
        public bool is_trusted(string device_path) {
            return array_contains(trusted_devices, device_path);
        }
        
        /**
         * Check if a device is blocked
         * 
         * @param device_path The device object path
         * @return true if the device is blocked
         */
        public bool is_blocked(string device_path) {
            return array_contains(blocked_devices, device_path);
        }
        
        /**
         * Connect to a device
         * 
         * @param device_path The device object path
         */
        public async void connect(string device_path) throws Error {
            debug("DeviceManager: Connecting to device: %s", device_path);
            
            var device = devices[device_path];
            if (device == null) {
                throw new IOError.NOT_FOUND("Device not found: %s", device_path);
            }
            
            if (device.connected) {
                debug("DeviceManager: Device already connected: %s", device_path);
                return;
            }
            
            // Update connection state to CONNECTING
            device.connection_state = ConnectionState.CONNECTING;
            device_property_changed(device_path, "ConnectionState");
            
            try {
                // Call Connect method on device
                yield client.call_method(
                    device_path,
                    DEVICE_INTERFACE,
                    "Connect",
                    null,
                    30000  // 30 second timeout for connection
                );
                
                debug("DeviceManager: Connection successful: %s", device.get_display_name());
                
            } catch (Error e) {
                // Reset connection state on failure
                device.connection_state = ConnectionState.DISCONNECTED;
                device_property_changed(device_path, "ConnectionState");
                
                warning("DeviceManager: Connection failed for %s: %s",
                       device.get_display_name(), e.message);
                throw e;
            }
        }
        
        /**
         * Disconnect from a device
         * 
         * @param device_path The device object path
         */
        public async void disconnect(string device_path) throws Error {
            debug("DeviceManager: Disconnecting from device: %s", device_path);
            
            var device = devices[device_path];
            if (device == null) {
                throw new IOError.NOT_FOUND("Device not found: %s", device_path);
            }
            
            if (!device.connected) {
                debug("DeviceManager: Device not connected: %s", device_path);
                return;
            }
            
            // Update connection state to DISCONNECTING
            device.connection_state = ConnectionState.DISCONNECTING;
            device_property_changed(device_path, "ConnectionState");
            
            try {
                // Call Disconnect method on device
                yield client.call_method(
                    device_path,
                    DEVICE_INTERFACE,
                    "Disconnect",
                    null,
                    10000  // 10 second timeout for disconnection
                );
                
                debug("DeviceManager: Disconnection successful: %s", device.get_display_name());
                
            } catch (Error e) {
                // Reset connection state on failure
                device.update_connection_state();
                device_property_changed(device_path, "ConnectionState");
                
                warning("DeviceManager: Disconnection failed for %s: %s",
                       device.get_display_name(), e.message);
                throw e;
            }
        }
        
        /**
         * Pair with a device
         * 
         * @param device_path The device object path
         */
        public async void pair(string device_path) throws Error {
            debug("DeviceManager: Pairing with device: %s", device_path);
            
            var device = devices[device_path];
            if (device == null) {
                throw new IOError.NOT_FOUND("Device not found: %s", device_path);
            }
            
            if (device.paired) {
                debug("DeviceManager: Device already paired: %s", device_path);
                return;
            }
            
            try {
                // Call Pair method on device
                yield client.call_method(
                    device_path,
                    DEVICE_INTERFACE,
                    "Pair",
                    null,
                    60000  // 60 second timeout for pairing
                );
                
                debug("DeviceManager: Pairing successful: %s", device.get_display_name());
                
            } catch (Error e) {
                warning("DeviceManager: Pairing failed for %s: %s",
                       device.get_display_name(), e.message);
                throw e;
            }
        }
        
        /**
         * Unpair (remove pairing) from a device
         * 
         * @param device_path The device object path
         */
        public async void unpair(string device_path) throws Error {
            debug("DeviceManager: Unpairing device: %s", device_path);
            
            var device = devices[device_path];
            if (device == null) {
                throw new IOError.NOT_FOUND("Device not found: %s", device_path);
            }
            
            if (!device.paired) {
                debug("DeviceManager: Device not paired: %s", device_path);
                return;
            }
            
            try {
                // Get adapter path from device
                var adapter_path = device.adapter_path;
                
                // Call RemoveDevice method on adapter
                yield client.call_method(
                    adapter_path,
                    "org.bluez.Adapter1",
                    "RemoveDevice",
                    new Variant("(o)", device_path)
                );
                
                debug("DeviceManager: Unpairing successful: %s", device.get_display_name());
                
                // Device will be removed via object_removed signal
                
            } catch (Error e) {
                warning("DeviceManager: Unpairing failed for %s: %s",
                       device.get_display_name(), e.message);
                throw e;
            }
        }
        
        /**
         * Handle object added event from BlueZ
         */
        private void on_object_added(string object_path, string interface_name) {
            if (interface_name != DEVICE_INTERFACE) {
                return;
            }
            
            debug("DeviceManager: Device added: %s", object_path);
            
            // Create device asynchronously
            create_device_from_path.begin(object_path, (obj, res) => {
                try {
                    create_device_from_path.end(res);
                } catch (Error e) {
                    warning("DeviceManager: Failed to create device: %s", e.message);
                }
            });
        }
        
        /**
         * Handle object removed event from BlueZ
         */
        private void on_object_removed(string object_path, string interface_name) {
            if (interface_name != DEVICE_INTERFACE) {
                return;
            }
            
            debug("DeviceManager: Device removed: %s", object_path);
            
            // Remove from storage
            devices.remove(object_path);
            remove_from_array(trusted_devices, object_path);
            remove_from_array(blocked_devices, object_path);
            
            // Emit signal
            device_removed(object_path);
        }
        
        /**
         * Handle properties changed event from BlueZ
         */
        private void on_properties_changed(
            string object_path,
            string interface_name,
            HashTable<string, Variant> changed_properties
        ) {
            if (interface_name != DEVICE_INTERFACE) {
                return;
            }
            
            var device = devices[object_path];
            if (device == null) {
                // Device not yet in our map, might be a new device
                return;
            }
            
            debug("DeviceManager: Device properties changed: %s (%u properties)",
                  object_path, changed_properties.size());
            
            // Track connection state changes
            bool was_connected = device.connected;
            
            // Update device properties
            update_device_properties(device, changed_properties);
            
            // Update trust/block sets
            if (device.trusted) {
                add_to_array_if_not_present(trusted_devices, object_path);
            } else {
                remove_from_array(trusted_devices, object_path);
            }
            if (device.blocked) {
                add_to_array_if_not_present(blocked_devices, object_path);
            } else {
                remove_from_array(blocked_devices, object_path);
            }
            
            // Emit property changed signals
            changed_properties.foreach((key, value) => {
                device_property_changed(object_path, key);
            });
            
            // Emit connection state change signals
            if (!was_connected && device.connected) {
                debug("DeviceManager: Device connected: %s", device.get_display_name());
                device_connected(device);
            } else if (was_connected && !device.connected) {
                debug("DeviceManager: Device disconnected: %s", device.get_display_name());
                device_disconnected(device);
            }
        }
        
        /**
         * Helper: Check if GenericArray contains a string
         */
        private bool array_contains(GenericArray<string> array, string value) {
            for (uint i = 0; i < array.length; i++) {
                if (array[i] == value) {
                    return true;
                }
            }
            return false;
        }
        
        /**
         * Helper: Add string to GenericArray if not present
         */
        private void add_to_array_if_not_present(GenericArray<string> array, string value) {
            if (!array_contains(array, value)) {
                array.add(value);
            }
        }
        
        /**
         * Helper: Remove string from GenericArray
         */
        private void remove_from_array(GenericArray<string> array, string value) {
            for (uint i = 0; i < array.length; i++) {
                if (array[i] == value) {
                    array.remove_index(i);
                    return;
                }
            }
        }
    }
}
