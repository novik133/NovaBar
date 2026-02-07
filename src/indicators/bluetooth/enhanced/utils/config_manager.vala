/**
 * Enhanced Bluetooth Indicator - Configuration Manager
 * 
 * This file implements configuration persistence for the Enhanced Bluetooth Indicator.
 * It manages adapter settings, trusted devices, blocked devices, and UI preferences.
 */

using GLib;

namespace EnhancedBluetooth {

    /**
     * Configuration Manager
     * 
     * Manages persistent configuration for the Enhanced Bluetooth Indicator including:
     * - Adapter settings (name, discoverable timeout, pairable timeout)
     * - Trusted device list
     * - Blocked device list
     * - UI preferences (filter, sort, view mode)
     */
    public class ConfigManager : GLib.Object {
        private string _config_file_path;
        private KeyFile _config_file;
        
        // Configuration sections
        private HashTable<string, AdapterConfig> _adapter_configs;
        private HashTable<string, bool> _trusted_devices;
        private HashTable<string, bool> _blocked_devices;
        private UIPreferences _ui_preferences;
        
        private const string SECTION_ADAPTERS = "Adapters";
        private const string SECTION_TRUSTED = "TrustedDevices";
        private const string SECTION_BLOCKED = "BlockedDevices";
        private const string SECTION_UI = "UIPreferences";
        
        /**
         * Signal emitted when configuration is saved
         */
        public signal void configuration_saved(bool success, string message);
        
        /**
         * Signal emitted when configuration is loaded
         */
        public signal void configuration_loaded(bool success, string message);
        
        /**
         * Signal emitted when adapter configuration changes
         */
        public signal void adapter_config_changed(string adapter_path, AdapterConfig config);
        
        /**
         * Signal emitted when trusted device list changes
         */
        public signal void trusted_devices_changed();
        
        /**
         * Signal emitted when blocked device list changes
         */
        public signal void blocked_devices_changed();
        
        /**
         * Signal emitted when UI preferences change
         */
        public signal void ui_preferences_changed(UIPreferences preferences);
        
        public ConfigManager() {
            // Initialize configuration file path
            var config_dir = Path.build_filename(Environment.get_user_config_dir(), "novabar", "bluetooth");
            _config_file_path = Path.build_filename(config_dir, "config.ini");
            
            // Initialize key file
            _config_file = new KeyFile();
            
            // Initialize data structures
            _adapter_configs = new HashTable<string, AdapterConfig>(str_hash, str_equal);
            _trusted_devices = new HashTable<string, bool>(str_hash, str_equal);
            _blocked_devices = new HashTable<string, bool>(str_hash, str_equal);
            _ui_preferences = new UIPreferences();
            
            debug("ConfigManager: Initialized with config file: %s", _config_file_path);
        }
        
        /**
         * Load configuration from file
         */
        public bool load_configuration() {
            print("ConfigManager: load_configuration() called\n");
            print("ConfigManager: Loading configuration from: %s\n", _config_file_path);
            
            try {
                var file = File.new_for_path(_config_file_path);
                
                if (!file.query_exists()) {
                    print("ConfigManager: Configuration file does not exist\n");
                    configuration_loaded(true, "Using default configuration");
                    return true;
                }
                
                print("ConfigManager: Config file exists, loading...\n");
                
                // Load key file
                _config_file.load_from_file(_config_file_path, KeyFileFlags.NONE);
                
                print("ConfigManager: KeyFile loaded, loading sections...\n");
                
                // Load adapter configurations
                load_adapter_configs();
                
                // Load trusted devices
                load_trusted_devices();
                
                // Load blocked devices
                load_blocked_devices();
                
                // Load UI preferences
                load_ui_preferences();
                
                print("ConfigManager: Configuration loaded successfully\n");
                configuration_loaded(true, "Configuration loaded successfully");
                return true;
                
            } catch (Error e) {
                warning("ConfigManager: Failed to load configuration: %s", e.message);
                warning("ConfigManager: Using default configuration");
                
                // Use safe defaults on error
                _adapter_configs.remove_all();
                _trusted_devices.remove_all();
                _blocked_devices.remove_all();
                _ui_preferences = new UIPreferences();
                
                configuration_loaded(false, "Failed to load configuration, using defaults: %s".printf(e.message));
                return false;
            }
        }
        
        /**
         * Save configuration to file
         */
        public bool save_configuration() {
            debug("ConfigManager: Saving configuration to: %s", _config_file_path);
            
            try {
                // Validate configuration before saving
                if (!validate_configuration()) {
                    throw new IOError.INVALID_DATA("Configuration validation failed");
                }
                
                // Create configuration directory if it doesn't exist
                var config_dir = Path.get_dirname(_config_file_path);
                var dir = File.new_for_path(config_dir);
                
                if (!dir.query_exists()) {
                    dir.make_directory_with_parents();
                }
                
                // Clear existing configuration
                _config_file = new KeyFile();
                
                // Save adapter configurations
                save_adapter_configs();
                
                // Save trusted devices
                save_trusted_devices();
                
                // Save blocked devices
                save_blocked_devices();
                
                // Save UI preferences
                save_ui_preferences();
                
                // Add metadata
                _config_file.set_string("Metadata", "version", "1.0");
                _config_file.set_string("Metadata", "last_saved", new DateTime.now_local().to_string());
                
                // Write to file
                _config_file.save_to_file(_config_file_path);
                
                debug("ConfigManager: Configuration saved successfully");
                configuration_saved(true, "Configuration saved successfully");
                return true;
                
            } catch (Error e) {
                warning("ConfigManager: Failed to save configuration: %s", e.message);
                configuration_saved(false, "Failed to save configuration: %s".printf(e.message));
                return false;
            }
        }
        
        /**
         * Validate configuration before saving
         */
        private bool validate_configuration() {
            // Validate adapter configurations
            var adapter_paths = _adapter_configs.get_keys();
            foreach (var path in adapter_paths) {
                var config = _adapter_configs.get(path);
                if (!config.is_valid()) {
                    warning("ConfigManager: Invalid adapter configuration for: %s", path);
                    return false;
                }
            }
            
            // Validate trusted devices (MAC addresses)
            var trusted_addresses = _trusted_devices.get_keys();
            foreach (var address in trusted_addresses) {
                if (!is_valid_mac_address(address)) {
                    warning("ConfigManager: Invalid trusted device address: %s", address);
                    return false;
                }
            }
            
            // Validate blocked devices (MAC addresses)
            var blocked_addresses = _blocked_devices.get_keys();
            foreach (var address in blocked_addresses) {
                if (!is_valid_mac_address(address)) {
                    warning("ConfigManager: Invalid blocked device address: %s", address);
                    return false;
                }
            }
            
            return true;
        }
        
        /**
         * Check if a MAC address is valid
         */
        private bool is_valid_mac_address(string address) {
            if (address.length != 17) return false;
            
            var parts = address.split(":");
            if (parts.length != 6) return false;
            
            foreach (var part in parts) {
                if (part.length != 2) return false;
                
                for (int i = 0; i < part.length; i++) {
                    if (!part[i].isxdigit()) return false;
                }
            }
            
            return true;
        }
        
        // Adapter configuration methods
        
        /**
         * Set adapter configuration
         */
        public void set_adapter_config(string adapter_path, AdapterConfig config) {
            if (!config.is_valid()) {
                warning("ConfigManager: Invalid adapter configuration for: %s", adapter_path);
                return;
            }
            
            _adapter_configs.set(adapter_path, config);
            adapter_config_changed(adapter_path, config);
            debug("ConfigManager: Adapter configuration updated for: %s", adapter_path);
        }
        
        /**
         * Get adapter configuration
         */
        public AdapterConfig? get_adapter_config(string adapter_path) {
            print("ConfigManager: get_adapter_config called with path: '%s'\n", adapter_path);
            print("ConfigManager: _adapter_configs has %u entries\n", _adapter_configs.size());
            
            // Print all keys in the hash table
            var keys = _adapter_configs.get_keys();
            foreach (var key in keys) {
                print("ConfigManager: Hash table contains key: '%s'\n", key);
            }
            
            var result = _adapter_configs.get(adapter_path);
            print("ConfigManager: Result is %s\n", result == null ? "null" : "not null");
            return result;
        }
        
        /**
         * Remove adapter configuration
         */
        public void remove_adapter_config(string adapter_path) {
            _adapter_configs.remove(adapter_path);
            debug("ConfigManager: Adapter configuration removed for: %s", adapter_path);
        }
        
        // Trusted device methods
        
        /**
         * Add trusted device
         */
        public void add_trusted_device(string device_address) {
            if (!is_valid_mac_address(device_address)) {
                warning("ConfigManager: Invalid device address: %s", device_address);
                return;
            }
            
            _trusted_devices.set(device_address, true);
            trusted_devices_changed();
            debug("ConfigManager: Device added to trusted list: %s", device_address);
        }
        
        /**
         * Remove trusted device
         */
        public void remove_trusted_device(string device_address) {
            _trusted_devices.remove(device_address);
            trusted_devices_changed();
            debug("ConfigManager: Device removed from trusted list: %s", device_address);
        }
        
        /**
         * Check if device is trusted
         */
        public bool is_device_trusted(string device_address) {
            return _trusted_devices.contains(device_address);
        }
        
        /**
         * Get all trusted devices
         */
        public List<string> get_trusted_devices() {
            var result = new List<string>();
            var keys = _trusted_devices.get_keys();
            foreach (var key in keys) {
                result.append(key);
            }
            return result;
        }
        
        // Blocked device methods
        
        /**
         * Add blocked device
         */
        public void add_blocked_device(string device_address) {
            if (!is_valid_mac_address(device_address)) {
                warning("ConfigManager: Invalid device address: %s", device_address);
                return;
            }
            
            _blocked_devices.set(device_address, true);
            blocked_devices_changed();
            debug("ConfigManager: Device added to blocked list: %s", device_address);
        }
        
        /**
         * Remove blocked device
         */
        public void remove_blocked_device(string device_address) {
            _blocked_devices.remove(device_address);
            blocked_devices_changed();
            debug("ConfigManager: Device removed from blocked list: %s", device_address);
        }
        
        /**
         * Check if device is blocked
         */
        public bool is_device_blocked(string device_address) {
            return _blocked_devices.contains(device_address);
        }
        
        /**
         * Get all blocked devices
         */
        public List<string> get_blocked_devices() {
            var result = new List<string>();
            var keys = _blocked_devices.get_keys();
            foreach (var key in keys) {
                result.append(key);
            }
            return result;
        }
        
        // UI preferences methods
        
        /**
         * Set UI preferences
         */
        public void set_ui_preferences(UIPreferences preferences) {
            _ui_preferences = preferences;
            ui_preferences_changed(preferences);
            debug("ConfigManager: UI preferences updated");
        }
        
        /**
         * Get UI preferences
         */
        public UIPreferences get_ui_preferences() {
            return _ui_preferences;
        }
        
        // Private load methods
        
        private void load_adapter_configs() {
            _adapter_configs.remove_all();
            
            try {
                if (!_config_file.has_group(SECTION_ADAPTERS)) {
                    print("ConfigManager: No Adapters section found\n");
                    return;
                }
                
                var keys = _config_file.get_keys(SECTION_ADAPTERS);
                print("ConfigManager: Found %d keys in Adapters section\n", keys.length);
                
                // Group keys by adapter path (sanitized key prefix)
                var adapter_key_prefixes = new HashTable<string, bool>(str_hash, str_equal);
                foreach (var key in keys) {
                    print("ConfigManager: Processing key: %s\n", key);
                    var parts = key.split(".");
                    if (parts.length >= 2) {
                        adapter_key_prefixes.set(parts[0], true);
                        print("ConfigManager: Added key prefix: %s\n", parts[0]);
                    }
                }
                
                // Load each adapter config
                var key_prefixes = adapter_key_prefixes.get_keys();
                print("ConfigManager: Found %d unique adapter key prefixes\n", (int)key_prefixes.length());
                foreach (var key_prefix in key_prefixes) {
                    print("ConfigManager: Loading config for key prefix: %s\n", key_prefix);
                    var config = new AdapterConfig();
                    
                    var alias_key = key_prefix + ".alias";
                    var disc_key = key_prefix + ".discoverable_timeout";
                    var pair_key = key_prefix + ".pairable_timeout";
                    
                    if (_config_file.has_key(SECTION_ADAPTERS, alias_key)) {
                        config.alias = _config_file.get_string(SECTION_ADAPTERS, alias_key);
                        print("ConfigManager: Loaded alias: %s\n", config.alias);
                    }
                    
                    if (_config_file.has_key(SECTION_ADAPTERS, disc_key)) {
                        config.discoverable_timeout = (uint32) _config_file.get_integer(SECTION_ADAPTERS, disc_key);
                        print("ConfigManager: Loaded discoverable_timeout: %u\n", config.discoverable_timeout);
                    }
                    
                    if (_config_file.has_key(SECTION_ADAPTERS, pair_key)) {
                        config.pairable_timeout = (uint32) _config_file.get_integer(SECTION_ADAPTERS, pair_key);
                        print("ConfigManager: Loaded pairable_timeout: %u\n", config.pairable_timeout);
                    }
                    
                    // Restore original path by replacing _ with /
                    var original_path = key_prefix.replace("_", "/");
                    print("ConfigManager: Restored path from '%s' to '%s'\n", key_prefix, original_path);
                    _adapter_configs.set(original_path, config);
                }
                
                print("ConfigManager: Loaded %u adapter configurations\n", _adapter_configs.size());
                
            } catch (Error e) {
                warning("ConfigManager: Failed to load adapter configs: %s", e.message);
            }
        }
        
        private void load_trusted_devices() {
            _trusted_devices.remove_all();
            
            try {
                if (!_config_file.has_group(SECTION_TRUSTED)) {
                    return;
                }
                
                var keys = _config_file.get_keys(SECTION_TRUSTED);
                foreach (var key in keys) {
                    if (is_valid_mac_address(key)) {
                        _trusted_devices.set(key, true);
                    }
                }
                
                debug("ConfigManager: Loaded %u trusted devices", _trusted_devices.size());
                
            } catch (Error e) {
                warning("ConfigManager: Failed to load trusted devices: %s", e.message);
            }
        }
        
        private void load_blocked_devices() {
            _blocked_devices.remove_all();
            
            try {
                if (!_config_file.has_group(SECTION_BLOCKED)) {
                    return;
                }
                
                var keys = _config_file.get_keys(SECTION_BLOCKED);
                foreach (var key in keys) {
                    if (is_valid_mac_address(key)) {
                        _blocked_devices.set(key, true);
                    }
                }
                
                debug("ConfigManager: Loaded %u blocked devices", _blocked_devices.size());
                
            } catch (Error e) {
                warning("ConfigManager: Failed to load blocked devices: %s", e.message);
            }
        }
        
        private void load_ui_preferences() {
            try {
                if (!_config_file.has_group(SECTION_UI)) {
                    return;
                }
                
                if (_config_file.has_key(SECTION_UI, "filter_type")) {
                    string filter_str = _config_file.get_string(SECTION_UI, "filter_type");
                    _ui_preferences.filter_type = parse_device_type_filter(filter_str);
                }
                
                if (_config_file.has_key(SECTION_UI, "sort_order")) {
                    string sort_str = _config_file.get_string(SECTION_UI, "sort_order");
                    _ui_preferences.sort_order = parse_sort_order(sort_str);
                }
                
                if (_config_file.has_key(SECTION_UI, "show_only_paired")) {
                    _ui_preferences.show_only_paired = _config_file.get_boolean(SECTION_UI, "show_only_paired");
                }
                
                if (_config_file.has_key(SECTION_UI, "show_only_connected")) {
                    _ui_preferences.show_only_connected = _config_file.get_boolean(SECTION_UI, "show_only_connected");
                }
                
                if (_config_file.has_key(SECTION_UI, "notifications_enabled")) {
                    _ui_preferences.notifications_enabled = _config_file.get_boolean(SECTION_UI, "notifications_enabled");
                }
                
                if (_config_file.has_key(SECTION_UI, "notify_on_connect")) {
                    _ui_preferences.notify_on_connect = _config_file.get_boolean(SECTION_UI, "notify_on_connect");
                }
                
                if (_config_file.has_key(SECTION_UI, "notify_on_disconnect")) {
                    _ui_preferences.notify_on_disconnect = _config_file.get_boolean(SECTION_UI, "notify_on_disconnect");
                }
                
                if (_config_file.has_key(SECTION_UI, "notify_on_pairing")) {
                    _ui_preferences.notify_on_pairing = _config_file.get_boolean(SECTION_UI, "notify_on_pairing");
                }
                
                if (_config_file.has_key(SECTION_UI, "notify_on_transfer")) {
                    _ui_preferences.notify_on_transfer = _config_file.get_boolean(SECTION_UI, "notify_on_transfer");
                }
                
                debug("ConfigManager: UI preferences loaded");
                
            } catch (Error e) {
                warning("ConfigManager: Failed to load UI preferences: %s", e.message);
            }
        }
        
        // Private save methods
        
        private void save_adapter_configs() {
            var adapter_paths = _adapter_configs.get_keys();
            foreach (var path in adapter_paths) {
                var config = _adapter_configs.get(path);
                
                // Sanitize path for use as key prefix (replace / with _)
                var key_prefix = path.replace("/", "_");
                
                _config_file.set_string(SECTION_ADAPTERS, key_prefix + ".alias", config.alias);
                _config_file.set_integer(SECTION_ADAPTERS, key_prefix + ".discoverable_timeout", (int) config.discoverable_timeout);
                _config_file.set_integer(SECTION_ADAPTERS, key_prefix + ".pairable_timeout", (int) config.pairable_timeout);
            }
        }
        
        private void save_trusted_devices() {
            var addresses = _trusted_devices.get_keys();
            foreach (var address in addresses) {
                _config_file.set_boolean(SECTION_TRUSTED, address, true);
            }
        }
        
        private void save_blocked_devices() {
            var addresses = _blocked_devices.get_keys();
            foreach (var address in addresses) {
                _config_file.set_boolean(SECTION_BLOCKED, address, true);
            }
        }
        
        private void save_ui_preferences() {
            _config_file.set_string(SECTION_UI, "filter_type", device_type_filter_to_string(_ui_preferences.filter_type));
            _config_file.set_string(SECTION_UI, "sort_order", sort_order_to_string(_ui_preferences.sort_order));
            _config_file.set_boolean(SECTION_UI, "show_only_paired", _ui_preferences.show_only_paired);
            _config_file.set_boolean(SECTION_UI, "show_only_connected", _ui_preferences.show_only_connected);
            _config_file.set_boolean(SECTION_UI, "notifications_enabled", _ui_preferences.notifications_enabled);
            _config_file.set_boolean(SECTION_UI, "notify_on_connect", _ui_preferences.notify_on_connect);
            _config_file.set_boolean(SECTION_UI, "notify_on_disconnect", _ui_preferences.notify_on_disconnect);
            _config_file.set_boolean(SECTION_UI, "notify_on_pairing", _ui_preferences.notify_on_pairing);
            _config_file.set_boolean(SECTION_UI, "notify_on_transfer", _ui_preferences.notify_on_transfer);
        }
        
        // Helper methods for enum conversion
        
        private DeviceTypeFilter parse_device_type_filter(string filter_str) {
            switch (filter_str.down()) {
                case "all":
                    return DeviceTypeFilter.ALL;
                case "audio":
                    return DeviceTypeFilter.AUDIO;
                case "input":
                    return DeviceTypeFilter.INPUT;
                case "phone":
                    return DeviceTypeFilter.PHONE;
                case "computer":
                    return DeviceTypeFilter.COMPUTER;
                default:
                    return DeviceTypeFilter.ALL;
            }
        }
        
        private string device_type_filter_to_string(DeviceTypeFilter filter) {
            switch (filter) {
                case DeviceTypeFilter.ALL:
                    return "all";
                case DeviceTypeFilter.AUDIO:
                    return "audio";
                case DeviceTypeFilter.INPUT:
                    return "input";
                case DeviceTypeFilter.PHONE:
                    return "phone";
                case DeviceTypeFilter.COMPUTER:
                    return "computer";
                default:
                    return "all";
            }
        }
        
        private SortOrder parse_sort_order(string sort_str) {
            switch (sort_str.down()) {
                case "name":
                    return SortOrder.NAME;
                case "signal_strength":
                    return SortOrder.SIGNAL_STRENGTH;
                case "connection_status":
                    return SortOrder.CONNECTION_STATUS;
                default:
                    return SortOrder.NAME;
            }
        }
        
        private string sort_order_to_string(SortOrder order) {
            switch (order) {
                case SortOrder.NAME:
                    return "name";
                case SortOrder.SIGNAL_STRENGTH:
                    return "signal_strength";
                case SortOrder.CONNECTION_STATUS:
                    return "connection_status";
                default:
                    return "name";
            }
        }
    }
    
    /**
     * Adapter configuration
     */
    public class AdapterConfig : GLib.Object {
        public string alias { get; set; default = ""; }
        public uint32 discoverable_timeout { get; set; default = 180; }
        public uint32 pairable_timeout { get; set; default = 0; }
        
        public bool is_valid() {
            // Alias can be empty (will use default)
            // Timeouts can be 0 (unlimited) or positive values
            return true;
        }
    }
    
    /**
     * UI preferences
     */
    public class UIPreferences : GLib.Object {
        public DeviceTypeFilter filter_type { get; set; default = DeviceTypeFilter.ALL; }
        public SortOrder sort_order { get; set; default = SortOrder.NAME; }
        public bool show_only_paired { get; set; default = false; }
        public bool show_only_connected { get; set; default = false; }
        public bool notifications_enabled { get; set; default = true; }
        public bool notify_on_connect { get; set; default = true; }
        public bool notify_on_disconnect { get; set; default = true; }
        public bool notify_on_pairing { get; set; default = true; }
        public bool notify_on_transfer { get; set; default = true; }
    }
    
    /**
     * Device type filter for UI
     */
    public enum DeviceTypeFilter {
        ALL,
        AUDIO,
        INPUT,
        PHONE,
        COMPUTER
    }
    
    /**
     * Sort order for device list
     */
    public enum SortOrder {
        NAME,
        SIGNAL_STRENGTH,
        CONNECTION_STATUS
    }
}
