/**
 * Unit tests for ConfigManager
 */

using GLib;

// Inline ConfigManager classes for testing
namespace EnhancedBluetooth {
    
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
    
    /**
     * Adapter configuration
     */
    public class AdapterConfig : GLib.Object {
        public string alias { get; set; default = ""; }
        public uint32 discoverable_timeout { get; set; default = 180; }
        public uint32 pairable_timeout { get; set; default = 0; }
        
        public bool is_valid() {
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
    }
    
    /**
     * Simplified ConfigManager for testing
     */
    public class ConfigManager : GLib.Object {
        private string _config_file_path;
        private KeyFile _config_file;
        private HashTable<string, AdapterConfig> _adapter_configs;
        private HashTable<string, bool> _trusted_devices;
        private HashTable<string, bool> _blocked_devices;
        private UIPreferences _ui_preferences;
        
        private const string SECTION_ADAPTERS = "Adapters";
        private const string SECTION_TRUSTED = "TrustedDevices";
        private const string SECTION_BLOCKED = "BlockedDevices";
        private const string SECTION_UI = "UIPreferences";
        
        public signal void configuration_saved(bool success, string message);
        public signal void configuration_loaded(bool success, string message);
        public signal void adapter_config_changed(string adapter_path, AdapterConfig config);
        public signal void trusted_devices_changed();
        public signal void blocked_devices_changed();
        public signal void ui_preferences_changed(UIPreferences preferences);
        
        public ConfigManager() {
            var config_dir = Path.build_filename(Environment.get_user_config_dir(), "novabar", "bluetooth");
            _config_file_path = Path.build_filename(config_dir, "config.ini");
            _config_file = new KeyFile();
            _adapter_configs = new HashTable<string, AdapterConfig>(str_hash, str_equal);
            _trusted_devices = new HashTable<string, bool>(str_hash, str_equal);
            _blocked_devices = new HashTable<string, bool>(str_hash, str_equal);
            _ui_preferences = new UIPreferences();
        }
        
        public bool load_configuration() {
            try {
                var file = File.new_for_path(_config_file_path);
                if (!file.query_exists()) {
                    configuration_loaded(true, "Using default configuration");
                    return true;
                }
                _config_file.load_from_file(_config_file_path, KeyFileFlags.NONE);
                load_adapter_configs();
                load_trusted_devices();
                load_blocked_devices();
                load_ui_preferences();
                configuration_loaded(true, "Configuration loaded successfully");
                return true;
            } catch (Error e) {
                _adapter_configs.remove_all();
                _trusted_devices.remove_all();
                _blocked_devices.remove_all();
                _ui_preferences = new UIPreferences();
                configuration_loaded(false, "Failed to load configuration, using defaults");
                return false;
            }
        }
        
        public bool save_configuration() {
            try {
                if (!validate_configuration()) {
                    throw new IOError.INVALID_DATA("Configuration validation failed");
                }
                var config_dir = Path.get_dirname(_config_file_path);
                var dir = File.new_for_path(config_dir);
                if (!dir.query_exists()) {
                    dir.make_directory_with_parents();
                }
                _config_file = new KeyFile();
                save_adapter_configs();
                save_trusted_devices();
                save_blocked_devices();
                save_ui_preferences();
                _config_file.set_string("Metadata", "version", "1.0");
                _config_file.set_string("Metadata", "last_saved", new DateTime.now_local().to_string());
                _config_file.save_to_file(_config_file_path);
                configuration_saved(true, "Configuration saved successfully");
                return true;
            } catch (Error e) {
                configuration_saved(false, "Failed to save configuration");
                return false;
            }
        }
        
        private bool validate_configuration() {
            var adapter_paths = _adapter_configs.get_keys();
            foreach (var path in adapter_paths) {
                var config = _adapter_configs.get(path);
                if (!config.is_valid()) return false;
            }
            var trusted_addresses = _trusted_devices.get_keys();
            foreach (var address in trusted_addresses) {
                if (!is_valid_mac_address(address)) return false;
            }
            var blocked_addresses = _blocked_devices.get_keys();
            foreach (var address in blocked_addresses) {
                if (!is_valid_mac_address(address)) return false;
            }
            return true;
        }
        
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
        
        public void set_adapter_config(string adapter_path, AdapterConfig config) {
            if (!config.is_valid()) return;
            _adapter_configs.set(adapter_path, config);
            adapter_config_changed(adapter_path, config);
        }
        
        public AdapterConfig? get_adapter_config(string adapter_path) {
            return _adapter_configs.get(adapter_path);
        }
        
        public void remove_adapter_config(string adapter_path) {
            _adapter_configs.remove(adapter_path);
        }
        
        public void add_trusted_device(string device_address) {
            if (!is_valid_mac_address(device_address)) return;
            _trusted_devices.set(device_address, true);
            trusted_devices_changed();
        }
        
        public void remove_trusted_device(string device_address) {
            _trusted_devices.remove(device_address);
            trusted_devices_changed();
        }
        
        public bool is_device_trusted(string device_address) {
            return _trusted_devices.contains(device_address);
        }
        
        public List<string> get_trusted_devices() {
            var result = new List<string>();
            var keys = _trusted_devices.get_keys();
            foreach (var key in keys) {
                result.append(key);
            }
            return result;
        }
        
        public void add_blocked_device(string device_address) {
            if (!is_valid_mac_address(device_address)) return;
            _blocked_devices.set(device_address, true);
            blocked_devices_changed();
        }
        
        public void remove_blocked_device(string device_address) {
            _blocked_devices.remove(device_address);
            blocked_devices_changed();
        }
        
        public bool is_device_blocked(string device_address) {
            return _blocked_devices.contains(device_address);
        }
        
        public List<string> get_blocked_devices() {
            var result = new List<string>();
            var keys = _blocked_devices.get_keys();
            foreach (var key in keys) {
                result.append(key);
            }
            return result;
        }
        
        public void set_ui_preferences(UIPreferences preferences) {
            _ui_preferences = preferences;
            ui_preferences_changed(preferences);
        }
        
        public UIPreferences get_ui_preferences() {
            return _ui_preferences;
        }
        
        private void load_adapter_configs() {
            _adapter_configs.remove_all();
            try {
                if (!_config_file.has_group(SECTION_ADAPTERS)) return;
                var keys = _config_file.get_keys(SECTION_ADAPTERS);
                var adapter_paths = new HashTable<string, bool>(str_hash, str_equal);
                foreach (var key in keys) {
                    var parts = key.split(".");
                    if (parts.length >= 2) {
                        adapter_paths.set(parts[0], true);
                    }
                }
                var paths = adapter_paths.get_keys();
                foreach (var path in paths) {
                    var config = new AdapterConfig();
                    var alias_key = path + ".alias";
                    var disc_key = path + ".discoverable_timeout";
                    var pair_key = path + ".pairable_timeout";
                    if (_config_file.has_key(SECTION_ADAPTERS, alias_key)) {
                        config.alias = _config_file.get_string(SECTION_ADAPTERS, alias_key);
                    }
                    if (_config_file.has_key(SECTION_ADAPTERS, disc_key)) {
                        config.discoverable_timeout = (uint32) _config_file.get_integer(SECTION_ADAPTERS, disc_key);
                    }
                    if (_config_file.has_key(SECTION_ADAPTERS, pair_key)) {
                        config.pairable_timeout = (uint32) _config_file.get_integer(SECTION_ADAPTERS, pair_key);
                    }
                    _adapter_configs.set(path, config);
                }
            } catch (Error e) { }
        }
        
        private void load_trusted_devices() {
            _trusted_devices.remove_all();
            try {
                if (!_config_file.has_group(SECTION_TRUSTED)) return;
                var keys = _config_file.get_keys(SECTION_TRUSTED);
                foreach (var key in keys) {
                    if (is_valid_mac_address(key)) {
                        _trusted_devices.set(key, true);
                    }
                }
            } catch (Error e) { }
        }
        
        private void load_blocked_devices() {
            _blocked_devices.remove_all();
            try {
                if (!_config_file.has_group(SECTION_BLOCKED)) return;
                var keys = _config_file.get_keys(SECTION_BLOCKED);
                foreach (var key in keys) {
                    if (is_valid_mac_address(key)) {
                        _blocked_devices.set(key, true);
                    }
                }
            } catch (Error e) { }
        }
        
        private void load_ui_preferences() {
            try {
                if (!_config_file.has_group(SECTION_UI)) return;
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
            } catch (Error e) { }
        }
        
        private void save_adapter_configs() {
            var adapter_paths = _adapter_configs.get_keys();
            foreach (var path in adapter_paths) {
                var config = _adapter_configs.get(path);
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
        }
        
        private DeviceTypeFilter parse_device_type_filter(string filter_str) {
            switch (filter_str.down()) {
                case "audio": return DeviceTypeFilter.AUDIO;
                case "input": return DeviceTypeFilter.INPUT;
                case "phone": return DeviceTypeFilter.PHONE;
                case "computer": return DeviceTypeFilter.COMPUTER;
                default: return DeviceTypeFilter.ALL;
            }
        }
        
        private string device_type_filter_to_string(DeviceTypeFilter filter) {
            switch (filter) {
                case DeviceTypeFilter.AUDIO: return "audio";
                case DeviceTypeFilter.INPUT: return "input";
                case DeviceTypeFilter.PHONE: return "phone";
                case DeviceTypeFilter.COMPUTER: return "computer";
                default: return "all";
            }
        }
        
        private SortOrder parse_sort_order(string sort_str) {
            switch (sort_str.down()) {
                case "signal_strength": return SortOrder.SIGNAL_STRENGTH;
                case "connection_status": return SortOrder.CONNECTION_STATUS;
                default: return SortOrder.NAME;
            }
        }
        
        private string sort_order_to_string(SortOrder order) {
            switch (order) {
                case SortOrder.SIGNAL_STRENGTH: return "signal_strength";
                case SortOrder.CONNECTION_STATUS: return "connection_status";
                default: return "name";
            }
        }
    }
}

void test_config_manager_initialization() {
    var config_manager = new EnhancedBluetooth.ConfigManager();
    assert(config_manager != null);
    
    // Verify default UI preferences
    var prefs = config_manager.get_ui_preferences();
    assert(prefs != null);
    assert(prefs.filter_type == EnhancedBluetooth.DeviceTypeFilter.ALL);
    assert(prefs.sort_order == EnhancedBluetooth.SortOrder.NAME);
    assert(prefs.show_only_paired == false);
    assert(prefs.show_only_connected == false);
    assert(prefs.notifications_enabled == true);
}

void test_adapter_config_management() {
    var config_manager = new EnhancedBluetooth.ConfigManager();
    
    // Create adapter config
    var adapter_config = new EnhancedBluetooth.AdapterConfig();
    adapter_config.alias = "Test Adapter";
    adapter_config.discoverable_timeout = 300;
    adapter_config.pairable_timeout = 60;
    
    // Set adapter config
    string adapter_path = "/org/bluez/hci0";
    config_manager.set_adapter_config(adapter_path, adapter_config);
    
    // Retrieve adapter config
    var retrieved_config = config_manager.get_adapter_config(adapter_path);
    assert(retrieved_config != null);
    assert(retrieved_config.alias == "Test Adapter");
    assert(retrieved_config.discoverable_timeout == 300);
    assert(retrieved_config.pairable_timeout == 60);
    
    // Remove adapter config
    config_manager.remove_adapter_config(adapter_path);
    var removed_config = config_manager.get_adapter_config(adapter_path);
    assert(removed_config == null);
}

void test_trusted_device_management() {
    var config_manager = new EnhancedBluetooth.ConfigManager();
    
    string device_address = "AA:BB:CC:DD:EE:FF";
    
    // Initially not trusted
    assert(config_manager.is_device_trusted(device_address) == false);
    
    // Add to trusted list
    config_manager.add_trusted_device(device_address);
    assert(config_manager.is_device_trusted(device_address) == true);
    
    // Get trusted devices list
    var trusted_list = config_manager.get_trusted_devices();
    assert(trusted_list.length() == 1);
    
    // Remove from trusted list
    config_manager.remove_trusted_device(device_address);
    assert(config_manager.is_device_trusted(device_address) == false);
    
    trusted_list = config_manager.get_trusted_devices();
    assert(trusted_list.length() == 0);
}

void test_blocked_device_management() {
    var config_manager = new EnhancedBluetooth.ConfigManager();
    
    string device_address = "11:22:33:44:55:66";
    
    // Initially not blocked
    assert(config_manager.is_device_blocked(device_address) == false);
    
    // Add to blocked list
    config_manager.add_blocked_device(device_address);
    assert(config_manager.is_device_blocked(device_address) == true);
    
    // Get blocked devices list
    var blocked_list = config_manager.get_blocked_devices();
    assert(blocked_list.length() == 1);
    
    // Remove from blocked list
    config_manager.remove_blocked_device(device_address);
    assert(config_manager.is_device_blocked(device_address) == false);
    
    blocked_list = config_manager.get_blocked_devices();
    assert(blocked_list.length() == 0);
}

void test_ui_preferences_management() {
    var config_manager = new EnhancedBluetooth.ConfigManager();
    
    // Create custom preferences
    var prefs = new EnhancedBluetooth.UIPreferences();
    prefs.filter_type = EnhancedBluetooth.DeviceTypeFilter.AUDIO;
    prefs.sort_order = EnhancedBluetooth.SortOrder.SIGNAL_STRENGTH;
    prefs.show_only_paired = true;
    prefs.show_only_connected = false;
    prefs.notifications_enabled = false;
    
    // Set preferences
    config_manager.set_ui_preferences(prefs);
    
    // Retrieve preferences
    var retrieved_prefs = config_manager.get_ui_preferences();
    assert(retrieved_prefs.filter_type == EnhancedBluetooth.DeviceTypeFilter.AUDIO);
    assert(retrieved_prefs.sort_order == EnhancedBluetooth.SortOrder.SIGNAL_STRENGTH);
    assert(retrieved_prefs.show_only_paired == true);
    assert(retrieved_prefs.show_only_connected == false);
    assert(retrieved_prefs.notifications_enabled == false);
}

void test_save_and_load_configuration() {
    // Create temporary config file path
    var temp_dir = DirUtils.make_tmp("bluetooth_config_test_XXXXXX");
    var config_file = Path.build_filename(temp_dir, "config.ini");
    
    // Create first config manager and populate it
    var config_manager1 = new EnhancedBluetooth.ConfigManager();
    
    // Add adapter config
    var adapter_config = new EnhancedBluetooth.AdapterConfig();
    adapter_config.alias = "My Bluetooth";
    adapter_config.discoverable_timeout = 240;
    adapter_config.pairable_timeout = 120;
    config_manager1.set_adapter_config("/org/bluez/hci0", adapter_config);
    
    // Add trusted devices
    config_manager1.add_trusted_device("AA:BB:CC:DD:EE:FF");
    config_manager1.add_trusted_device("11:22:33:44:55:66");
    
    // Add blocked devices
    config_manager1.add_blocked_device("FF:EE:DD:CC:BB:AA");
    
    // Set UI preferences
    var prefs = new EnhancedBluetooth.UIPreferences();
    prefs.filter_type = EnhancedBluetooth.DeviceTypeFilter.AUDIO;
    prefs.sort_order = EnhancedBluetooth.SortOrder.CONNECTION_STATUS;
    prefs.show_only_paired = true;
    prefs.notifications_enabled = false;
    config_manager1.set_ui_preferences(prefs);
    
    // Save configuration
    bool save_result = config_manager1.save_configuration();
    assert(save_result == true);
    
    // Create second config manager and load configuration
    var config_manager2 = new EnhancedBluetooth.ConfigManager();
    bool load_result = config_manager2.load_configuration();
    assert(load_result == true);
    
    // Verify adapter config
    var loaded_adapter_config = config_manager2.get_adapter_config("/org/bluez/hci0");
    assert(loaded_adapter_config != null);
    assert(loaded_adapter_config.alias == "My Bluetooth");
    assert(loaded_adapter_config.discoverable_timeout == 240);
    assert(loaded_adapter_config.pairable_timeout == 120);
    
    // Verify trusted devices
    assert(config_manager2.is_device_trusted("AA:BB:CC:DD:EE:FF") == true);
    assert(config_manager2.is_device_trusted("11:22:33:44:55:66") == true);
    var trusted_list = config_manager2.get_trusted_devices();
    assert(trusted_list.length() == 2);
    
    // Verify blocked devices
    assert(config_manager2.is_device_blocked("FF:EE:DD:CC:BB:AA") == true);
    var blocked_list = config_manager2.get_blocked_devices();
    assert(blocked_list.length() == 1);
    
    // Verify UI preferences
    var loaded_prefs = config_manager2.get_ui_preferences();
    assert(loaded_prefs.filter_type == EnhancedBluetooth.DeviceTypeFilter.AUDIO);
    assert(loaded_prefs.sort_order == EnhancedBluetooth.SortOrder.CONNECTION_STATUS);
    assert(loaded_prefs.show_only_paired == true);
    assert(loaded_prefs.notifications_enabled == false);
    
    // Cleanup
    FileUtils.remove(config_file);
    DirUtils.remove(temp_dir);
}

void test_corrupted_config_file_handling() {
    // Create temporary config file with corrupted content
    var temp_dir = DirUtils.make_tmp("bluetooth_config_test_XXXXXX");
    var config_file = Path.build_filename(temp_dir, "config.ini");
    
    // Write corrupted content
    FileUtils.set_contents(config_file, "{ invalid content !!!");
    
    // Try to load configuration
    var config_manager = new EnhancedBluetooth.ConfigManager();
    bool load_result = config_manager.load_configuration();
    
    // Should fail but not crash
    assert(load_result == false);
    
    // Should have safe defaults
    var prefs = config_manager.get_ui_preferences();
    assert(prefs != null);
    assert(prefs.filter_type == EnhancedBluetooth.DeviceTypeFilter.ALL);
    assert(prefs.notifications_enabled == true);
    
    // Cleanup
    FileUtils.remove(config_file);
    DirUtils.remove(temp_dir);
}

void test_invalid_mac_address_rejection() {
    var config_manager = new EnhancedBluetooth.ConfigManager();
    
    // Try to add invalid MAC addresses
    config_manager.add_trusted_device("invalid_mac");
    config_manager.add_blocked_device("AA:BB:CC");
    config_manager.add_trusted_device("ZZ:ZZ:ZZ:ZZ:ZZ:ZZ");
    
    // Should not be added
    assert(config_manager.is_device_trusted("invalid_mac") == false);
    assert(config_manager.is_device_blocked("AA:BB:CC") == false);
    assert(config_manager.is_device_trusted("ZZ:ZZ:ZZ:ZZ:ZZ:ZZ") == false);
    
    var trusted_list = config_manager.get_trusted_devices();
    var blocked_list = config_manager.get_blocked_devices();
    assert(trusted_list.length() == 0);
    assert(blocked_list.length() == 0);
}

void test_adapter_config_validation() {
    var config = new EnhancedBluetooth.AdapterConfig();
    
    // Valid configurations
    config.alias = "Test";
    config.discoverable_timeout = 0; // Unlimited
    config.pairable_timeout = 300;
    assert(config.is_valid() == true);
    
    config.alias = "";
    config.discoverable_timeout = 180;
    config.pairable_timeout = 0;
    assert(config.is_valid() == true);
}

void test_multiple_adapters_configuration() {
    var config_manager = new EnhancedBluetooth.ConfigManager();
    
    // Configure multiple adapters
    var config1 = new EnhancedBluetooth.AdapterConfig();
    config1.alias = "Adapter 1";
    config1.discoverable_timeout = 180;
    config_manager.set_adapter_config("/org/bluez/hci0", config1);
    
    var config2 = new EnhancedBluetooth.AdapterConfig();
    config2.alias = "Adapter 2";
    config2.discoverable_timeout = 300;
    config_manager.set_adapter_config("/org/bluez/hci1", config2);
    
    // Verify both configs exist
    var retrieved1 = config_manager.get_adapter_config("/org/bluez/hci0");
    var retrieved2 = config_manager.get_adapter_config("/org/bluez/hci1");
    
    assert(retrieved1 != null);
    assert(retrieved1.alias == "Adapter 1");
    assert(retrieved1.discoverable_timeout == 180);
    
    assert(retrieved2 != null);
    assert(retrieved2.alias == "Adapter 2");
    assert(retrieved2.discoverable_timeout == 300);
}

int main(string[] args) {
    Test.init(ref args);
    
    Test.add_func("/config_manager/initialization", test_config_manager_initialization);
    Test.add_func("/config_manager/adapter_config_management", test_adapter_config_management);
    Test.add_func("/config_manager/trusted_device_management", test_trusted_device_management);
    Test.add_func("/config_manager/blocked_device_management", test_blocked_device_management);
    Test.add_func("/config_manager/ui_preferences_management", test_ui_preferences_management);
    Test.add_func("/config_manager/save_and_load_configuration", test_save_and_load_configuration);
    Test.add_func("/config_manager/corrupted_config_file_handling", test_corrupted_config_file_handling);
    Test.add_func("/config_manager/invalid_mac_address_rejection", test_invalid_mac_address_rejection);
    Test.add_func("/config_manager/adapter_config_validation", test_adapter_config_validation);
    Test.add_func("/config_manager/multiple_adapters_configuration", test_multiple_adapters_configuration);
    
    return Test.run();
}
