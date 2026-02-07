/**
 * Enhanced Bluetooth Indicator - Adapter Manager
 * 
 * Manages Bluetooth adapter lifecycle and configuration, including adapter discovery,
 * power control, discovery control, and property monitoring.
 */

using GLib;

namespace EnhancedBluetooth {

    /**
     * Manages Bluetooth adapter lifecycle and configuration
     */
    public class AdapterManager : Object {
        private const string ADAPTER_INTERFACE = "org.bluez.Adapter1";
        
        // BlueZ client reference
        private BlueZClient client;
        
        // Adapter storage
        private HashTable<string, BluetoothAdapter> adapters;
        private string? default_adapter_path;
        
        /**
         * Signal emitted when an adapter is added
         */
        public signal void adapter_added(BluetoothAdapter adapter);
        
        /**
         * Signal emitted when an adapter is removed
         */
        public signal void adapter_removed(string adapter_path);
        
        /**
         * Signal emitted when adapter properties change
         */
        public signal void adapter_property_changed(string adapter_path, string property);
        
        /**
         * Signal emitted when adapter state changes (powered, discovering, etc.)
         */
        public signal void adapter_state_changed(BluetoothAdapter adapter);
        
        /**
         * Constructor
         */
        public AdapterManager() {
            adapters = new HashTable<string, BluetoothAdapter>(str_hash, str_equal);
        }
        
        /**
         * Initialize the adapter manager with a BlueZ client
         * 
         * @param client The BlueZ D-Bus client
         */
        public async void initialize(BlueZClient client) throws Error {
            debug("AdapterManager: Initializing...");
            
            this.client = client;
            
            // Connect to BlueZ client signals
            client.object_added.connect(on_object_added);
            client.object_removed.connect(on_object_removed);
            client.properties_changed.connect(on_properties_changed);
            
            // Scan for existing adapters
            yield scan_adapters();
            
            debug("AdapterManager: Initialization complete, found %u adapter(s)", adapters.size());
        }
        
        /**
         * Scan for all available Bluetooth adapters
         */
        public async void scan_adapters() throws Error {
            debug("AdapterManager: Scanning for adapters...");
            
            if (client == null || !client.is_connected) {
                throw new IOError.NOT_CONNECTED("BlueZ client not connected");
            }
            
            // Get all adapter object paths
            var adapter_paths = client.get_objects_by_interface(ADAPTER_INTERFACE);
            
            debug("AdapterManager: Found %u adapter object(s)", adapter_paths.length);
            
            // Load each adapter
            for (uint i = 0; i < adapter_paths.length; i++) {
                try {
                    yield load_adapter(adapter_paths[i]);
                } catch (Error e) {
                    warning("AdapterManager: Failed to load adapter %s: %s", 
                           adapter_paths[i], e.message);
                }
            }
            
            // Set default adapter if not already set
            if (default_adapter_path == null && adapters.size() > 0) {
                // Use first adapter as default
                BluetoothAdapter? first_adapter = null;
                adapters.foreach((key, adapter) => {
                    if (first_adapter == null) {
                        first_adapter = adapter;
                    }
                });
                if (first_adapter != null) {
                    default_adapter_path = first_adapter.object_path;
                    first_adapter.is_default = true;
                    debug("AdapterManager: Set default adapter to %s", default_adapter_path);
                }
            }
        }
        
        /**
         * Load an adapter from D-Bus
         */
        private async void load_adapter(string object_path) throws Error {
            debug("AdapterManager: Loading adapter %s", object_path);
            
            // Get all adapter properties
            var properties = yield client.get_all_properties(object_path, ADAPTER_INTERFACE);
            
            // Create adapter model
            var adapter = new BluetoothAdapter();
            adapter.object_path = object_path;
            
            // Populate properties
            update_adapter_from_properties(adapter, properties);
            
            // Store adapter
            adapters.insert(object_path, adapter);
            
            debug("AdapterManager: Loaded adapter %s (%s)", object_path, adapter.get_display_name());
            
            // Emit signal
            adapter_added(adapter);
        }
        
        /**
         * Update adapter model from D-Bus properties
         */
        private void update_adapter_from_properties(
            BluetoothAdapter adapter,
            HashTable<string, Variant> properties
        ) {
            properties.foreach((key, value) => {
                switch (key) {
                    case "Address":
                        adapter.address = value.get_string();
                        break;
                    case "Alias":
                        adapter.alias = value.get_string();
                        break;
                    case "Name":
                        adapter.name = value.get_string();
                        break;
                    case "Powered":
                        adapter.powered = value.get_boolean();
                        break;
                    case "Discoverable":
                        adapter.discoverable = value.get_boolean();
                        break;
                    case "Pairable":
                        adapter.pairable = value.get_boolean();
                        break;
                    case "DiscoverableTimeout":
                        adapter.discoverable_timeout = value.get_uint32();
                        break;
                    case "PairableTimeout":
                        adapter.pairable_timeout = value.get_uint32();
                        break;
                    case "Discovering":
                        adapter.discovering = value.get_boolean();
                        break;
                    case "UUIDs":
                        adapter.uuids = variant_to_string_array(value);
                        break;
                    case "Modalias":
                        adapter.modalias = value.get_string();
                        break;
                }
            });
        }
        
        /**
         * Convert a Variant array to string array
         */
        private string[] variant_to_string_array(Variant variant) {
            var array = new GenericArray<string>();
            var iter = variant.iterator();
            string str;
            while (iter.next("s", out str)) {
                array.add(str);
            }
            
            var result = new string[array.length];
            for (uint i = 0; i < array.length; i++) {
                result[i] = array[i];
            }
            return result;
        }
        
        /**
         * Get an adapter by object path
         * 
         * @param adapter_path The adapter object path
         * @return The adapter, or null if not found
         */
        public BluetoothAdapter? get_adapter(string adapter_path) {
            return adapters.lookup(adapter_path);
        }
        
        /**
         * Get the default adapter
         * 
         * @return The default adapter, or null if no adapters available
         */
        public BluetoothAdapter? get_default_adapter() {
            if (default_adapter_path != null) {
                return adapters.lookup(default_adapter_path);
            }
            return null;
        }
        
        /**
         * Get all adapters
         * 
         * @return List of all adapters
         */
        public GenericArray<BluetoothAdapter> get_all_adapters() {
            var list = new GenericArray<BluetoothAdapter>();
            adapters.foreach((key, adapter) => {
                list.add(adapter);
            });
            return list;
        }
        
        /**
         * Set adapter powered state
         * 
         * @param adapter_path The adapter object path
         * @param powered Whether to power on or off
         */
        public async void set_powered(string adapter_path, bool powered) throws Error {
            debug("AdapterManager: Setting adapter %s powered to %s", adapter_path, powered.to_string());
            
            if (!adapters.contains(adapter_path)) {
                throw new IOError.NOT_FOUND("Adapter not found: %s", adapter_path);
            }
            
            try {
                yield client.set_property(
                    adapter_path,
                    ADAPTER_INTERFACE,
                    "Powered",
                    new Variant.boolean(powered)
                );
                
                debug("AdapterManager: Adapter powered state set successfully");
                
            } catch (Error e) {
                warning("AdapterManager: Failed to set powered state: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Start device discovery on an adapter
         * 
         * @param adapter_path The adapter object path
         */
        public async void start_discovery(string adapter_path) throws Error {
            debug("AdapterManager: Starting discovery on adapter %s", adapter_path);
            
            if (!adapters.contains(adapter_path)) {
                throw new IOError.NOT_FOUND("Adapter not found: %s", adapter_path);
            }
            
            var adapter = adapters.lookup(adapter_path);
            
            // Check if adapter is powered
            if (!adapter.powered) {
                throw new IOError.FAILED("Adapter must be powered on to start discovery");
            }
            
            try {
                yield client.call_method(
                    adapter_path,
                    ADAPTER_INTERFACE,
                    "StartDiscovery",
                    null
                );
                
                debug("AdapterManager: Discovery started successfully");
                
            } catch (Error e) {
                warning("AdapterManager: Failed to start discovery: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Stop device discovery on an adapter
         * 
         * @param adapter_path The adapter object path
         */
        public async void stop_discovery(string adapter_path) throws Error {
            debug("AdapterManager: Stopping discovery on adapter %s", adapter_path);
            
            if (!adapters.contains(adapter_path)) {
                throw new IOError.NOT_FOUND("Adapter not found: %s", adapter_path);
            }
            
            try {
                yield client.call_method(
                    adapter_path,
                    ADAPTER_INTERFACE,
                    "StopDiscovery",
                    null
                );
                
                debug("AdapterManager: Discovery stopped successfully");
                
            } catch (Error e) {
                warning("AdapterManager: Failed to stop discovery: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Set adapter discoverable state
         * 
         * @param adapter_path The adapter object path
         * @param discoverable Whether the adapter should be discoverable
         * @param timeout Timeout in seconds (0 for unlimited)
         */
        public async void set_discoverable(
            string adapter_path,
            bool discoverable,
            uint32 timeout = 0
        ) throws Error {
            debug("AdapterManager: Setting adapter %s discoverable to %s (timeout: %u)",
                  adapter_path, discoverable.to_string(), timeout);
            
            if (!adapters.contains(adapter_path)) {
                throw new IOError.NOT_FOUND("Adapter not found: %s", adapter_path);
            }
            
            try {
                // Set discoverable timeout first if specified
                if (timeout > 0) {
                    yield client.set_property(
                        adapter_path,
                        ADAPTER_INTERFACE,
                        "DiscoverableTimeout",
                        new Variant.uint32(timeout)
                    );
                }
                
                // Set discoverable state
                yield client.set_property(
                    adapter_path,
                    ADAPTER_INTERFACE,
                    "Discoverable",
                    new Variant.boolean(discoverable)
                );
                
                debug("AdapterManager: Adapter discoverable state set successfully");
                
            } catch (Error e) {
                warning("AdapterManager: Failed to set discoverable state: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Set adapter pairable state
         * 
         * @param adapter_path The adapter object path
         * @param pairable Whether the adapter should be pairable
         * @param timeout Timeout in seconds (0 for unlimited)
         */
        public async void set_pairable(
            string adapter_path,
            bool pairable,
            uint32 timeout = 0
        ) throws Error {
            debug("AdapterManager: Setting adapter %s pairable to %s (timeout: %u)",
                  adapter_path, pairable.to_string(), timeout);
            
            if (!adapters.contains(adapter_path)) {
                throw new IOError.NOT_FOUND("Adapter not found: %s", adapter_path);
            }
            
            try {
                // Set pairable timeout first if specified
                if (timeout > 0) {
                    yield client.set_property(
                        adapter_path,
                        ADAPTER_INTERFACE,
                        "PairableTimeout",
                        new Variant.uint32(timeout)
                    );
                }
                
                // Set pairable state
                yield client.set_property(
                    adapter_path,
                    ADAPTER_INTERFACE,
                    "Pairable",
                    new Variant.boolean(pairable)
                );
                
                debug("AdapterManager: Adapter pairable state set successfully");
                
            } catch (Error e) {
                warning("AdapterManager: Failed to set pairable state: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Set adapter alias (display name)
         * 
         * @param adapter_path The adapter object path
         * @param alias The new alias for the adapter
         */
        public async void set_alias(string adapter_path, string alias) throws Error {
            debug("AdapterManager: Setting adapter %s alias to '%s'", adapter_path, alias);
            
            if (!adapters.contains(adapter_path)) {
                throw new IOError.NOT_FOUND("Adapter not found: %s", adapter_path);
            }
            
            // Validate alias
            if (!validate_alias(alias)) {
                throw new IOError.INVALID_ARGUMENT("Invalid adapter alias: must be 1-248 characters");
            }
            
            try {
                yield client.set_property(
                    adapter_path,
                    ADAPTER_INTERFACE,
                    "Alias",
                    new Variant.string(alias)
                );
                
                debug("AdapterManager: Adapter alias set successfully");
                
            } catch (Error e) {
                warning("AdapterManager: Failed to set adapter alias: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Validate adapter alias
         * 
         * @param alias The alias to validate
         * @return true if valid, false otherwise
         */
        private bool validate_alias(string alias) {
            // BlueZ requires alias to be 1-248 characters
            return alias.length > 0 && alias.length <= 248;
        }
        
        /**
         * Validate timeout value
         * 
         * @param timeout The timeout value to validate
         * @return true if valid, false otherwise
         */
        private bool validate_timeout(uint32 timeout) {
            // Timeout must be 0 (unlimited) or positive
            // BlueZ typically accepts values up to 65535 seconds
            return timeout <= 65535;
        }
        
        /**
         * Validate adapter configuration before applying
         * 
         * @param adapter_path The adapter object path
         * @param property The property name
         * @param value The property value
         * @return true if valid, false otherwise
         */
        public bool validate_configuration(string adapter_path, string property, Variant value) {
            switch (property) {
                case "Alias":
                    return validate_alias(value.get_string());
                    
                case "DiscoverableTimeout":
                case "PairableTimeout":
                    return validate_timeout(value.get_uint32());
                    
                case "Powered":
                case "Discoverable":
                case "Pairable":
                    // Boolean values are always valid
                    return true;
                    
                default:
                    warning("AdapterManager: Unknown property for validation: %s", property);
                    return false;
            }
        }
        
        /**
         * Handle object added from BlueZ
         */
        private void on_object_added(string object_path, string interface_name) {
            if (interface_name == ADAPTER_INTERFACE) {
                debug("AdapterManager: Adapter added: %s", object_path);
                load_adapter.begin(object_path, (obj, res) => {
                    try {
                        load_adapter.end(res);
                    } catch (Error e) {
                        warning("AdapterManager: Failed to load new adapter %s: %s",
                               object_path, e.message);
                    }
                });
            }
        }
        
        /**
         * Handle object removed from BlueZ
         */
        private void on_object_removed(string object_path, string interface_name) {
            if (interface_name == ADAPTER_INTERFACE && adapters.contains(object_path)) {
                debug("AdapterManager: Adapter removed: %s", object_path);
                
                // If this was the default adapter, clear it
                if (default_adapter_path == object_path) {
                    default_adapter_path = null;
                    
                    // Set a new default if other adapters exist
                    if (adapters.size() > 1) {
                        adapters.foreach((key, adapter) => {
                            if (key != object_path && default_adapter_path == null) {
                                default_adapter_path = adapter.object_path;
                                adapter.is_default = true;
                                debug("AdapterManager: New default adapter: %s", default_adapter_path);
                            }
                        });
                    }
                }
                
                // Remove adapter
                adapters.remove(object_path);
                
                // Emit signal
                adapter_removed(object_path);
            }
        }
        
        /**
         * Handle properties changed from BlueZ
         */
        private void on_properties_changed(
            string object_path,
            string interface_name,
            HashTable<string, Variant> changed_properties
        ) {
            if (interface_name == ADAPTER_INTERFACE && adapters.contains(object_path)) {
                var adapter = adapters.lookup(object_path);
                
                // Track if state-related properties changed
                bool state_changed = false;
                
                // Update adapter properties
                changed_properties.foreach((key, value) => {
                    debug("AdapterManager: Property changed on %s: %s", object_path, key);
                    
                    switch (key) {
                        case "Alias":
                            adapter.alias = value.get_string();
                            break;
                        case "Powered":
                            adapter.powered = value.get_boolean();
                            state_changed = true;
                            break;
                        case "Discoverable":
                            adapter.discoverable = value.get_boolean();
                            state_changed = true;
                            break;
                        case "Pairable":
                            adapter.pairable = value.get_boolean();
                            break;
                        case "DiscoverableTimeout":
                            adapter.discoverable_timeout = value.get_uint32();
                            break;
                        case "PairableTimeout":
                            adapter.pairable_timeout = value.get_uint32();
                            break;
                        case "Discovering":
                            adapter.discovering = value.get_boolean();
                            state_changed = true;
                            break;
                        case "UUIDs":
                            adapter.uuids = variant_to_string_array(value);
                            break;
                    }
                    
                    // Emit property changed signal
                    adapter_property_changed(object_path, key);
                });
                
                // Emit state changed signal if relevant properties changed
                if (state_changed) {
                    adapter_state_changed(adapter);
                }
            }
        }
    }
}
