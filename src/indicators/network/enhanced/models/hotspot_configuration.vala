/**
 * Enhanced Network Indicator - Hotspot Configuration Model
 * 
 * This file defines the HotspotConfiguration class and related data structures
 * for managing WiFi hotspot functionality in the enhanced network indicator.
 */

using GLib;

namespace EnhancedNetwork {

    /**
     * Information about a device connected to the hotspot
     */
    public class ConnectedDevice : GLib.Object {
        public string mac_address { get; set; }
        public string? hostname { get; set; }
        public string ip_address { get; set; }
        public DateTime connected_since { get; set; }
        public uint64 bytes_sent { get; set; }
        public uint64 bytes_received { get; set; }
        
        public ConnectedDevice() {
            connected_since = new DateTime.now_local();
        }
        
        public ConnectedDevice.with_mac(string mac_address) {
            this();
            this.mac_address = mac_address;
        }
        
        /**
         * Get total data usage for this device
         */
        public uint64 get_total_usage() {
            return bytes_sent + bytes_received;
        }
        
        /**
         * Get human-readable device name
         */
        public string get_display_name() {
            if (hostname != null && hostname.length > 0) {
                return hostname;
            }
            return mac_address;
        }
        
        /**
         * Get connection duration
         */
        public TimeSpan get_connection_duration() {
            var now = new DateTime.now_local();
            return now.difference(connected_since);
        }
    }

    /**
     * Data usage tracking for hotspot
     */
    public class DataUsage : GLib.Object {
        public uint64 total_bytes_sent { get; set; }
        public uint64 total_bytes_received { get; set; }
        public DateTime period_start { get; set; }
        public DateTime? period_end { get; set; }
        public uint64 usage_limit { get; set; }
        public bool limit_enabled { get; set; }
        
        public DataUsage() {
            period_start = new DateTime.now_local();
            limit_enabled = false;
        }
        
        /**
         * Get total data usage
         */
        public uint64 get_total_usage() {
            return total_bytes_sent + total_bytes_received;
        }
        
        /**
         * Check if usage limit is exceeded
         */
        public bool is_limit_exceeded() {
            if (!limit_enabled || usage_limit == 0) {
                return false;
            }
            return get_total_usage() >= usage_limit;
        }
        
        /**
         * Get usage percentage of limit
         */
        public double get_usage_percentage() {
            if (!limit_enabled || usage_limit == 0) {
                return 0.0;
            }
            return (double)get_total_usage() / (double)usage_limit * 100.0;
        }
        
        /**
         * Reset usage statistics
         */
        public void reset() {
            total_bytes_sent = 0;
            total_bytes_received = 0;
            period_start = new DateTime.now_local();
            period_end = null;
        }
    }

    /**
     * Hotspot Configuration for creating and managing WiFi hotspots
     * 
     * Contains all configuration parameters needed to create and manage
     * a WiFi hotspot, including security settings and connection sharing.
     */
    public class HotspotConfiguration : GLib.Object {
        public string ssid { get; set; }
        public string? password { get; set; }
        public SecurityType security_type { get; set; }
        public string device_interface { get; set; }
        public string? shared_connection_id { get; set; }
        public uint8 channel { get; set; }
        public bool hidden { get; set; }
        public uint32 max_clients { get; set; }
        public HotspotState state { get; set; }
        
        private List<ConnectedDevice> _connected_devices;
        private DataUsage _data_usage;
        
        /**
         * Signal emitted when hotspot state changes
         */
        public signal void state_changed(HotspotState old_state, HotspotState new_state);
        
        /**
         * Signal emitted when a device connects
         */
        public signal void device_connected(ConnectedDevice device);
        
        /**
         * Signal emitted when a device disconnects
         */
        public signal void device_disconnected(ConnectedDevice device);
        
        /**
         * Signal emitted when data usage is updated
         */
        public signal void usage_updated(DataUsage usage);
        
        /**
         * Signal emitted when usage limit is approached or exceeded
         */
        public signal void usage_threshold_reached(double percentage);
        
        public HotspotConfiguration() {
            _connected_devices = new List<ConnectedDevice>();
            _data_usage = new DataUsage();
            
            // Default values
            ssid = "NovaBar Hotspot";
            security_type = SecurityType.WPA2_PSK;
            channel = 6; // Default WiFi channel
            hidden = false;
            max_clients = 10;
            state = HotspotState.INACTIVE;
            device_interface = "wlan0"; // Default interface
        }
        
        public HotspotConfiguration.with_ssid(string ssid) {
            this();
            this.ssid = ssid;
        }
        
        /**
         * Start the hotspot with current configuration
         */
        public async bool start() throws Error {
            update_state(HotspotState.STARTING);
            
            // Validate configuration
            if (!is_configuration_valid()) {
                update_state(HotspotState.FAILED);
                throw new IOError.INVALID_DATA("Invalid hotspot configuration");
            }
            
            // TODO: Implement actual NetworkManager D-Bus hotspot creation logic
            // This is a placeholder implementation for the data model setup
            
            // Simulate startup delay
            yield wait_async(3000);
            
            // For now, simulate successful startup
            update_state(HotspotState.ACTIVE);
            _data_usage.reset();
            
            return true;
        }
        
        /**
         * Stop the hotspot
         */
        public async bool stop() throws Error {
            update_state(HotspotState.STOPPING);
            
            // TODO: Implement actual NetworkManager D-Bus hotspot teardown logic
            
            // Disconnect all devices
            foreach (var device in _connected_devices) {
                device_disconnected(device);
            }
            _connected_devices = new List<ConnectedDevice>();
            
            // Simulate shutdown delay
            yield wait_async(1000);
            
            update_state(HotspotState.INACTIVE);
            return true;
        }
        
        /**
         * Get list of connected devices
         */
        public List<ConnectedDevice> get_connected_devices() {
            var result = new List<ConnectedDevice>();
            foreach (var device in _connected_devices) {
                result.append(device);
            }
            return result;
        }
        
        /**
         * Get current data usage
         */
        public DataUsage get_data_usage() {
            return _data_usage;
        }
        
        /**
         * Add a connected device
         */
        public void add_connected_device(ConnectedDevice device) {
            _connected_devices.append(device);
            device_connected(device);
        }
        
        /**
         * Remove a connected device
         */
        public void remove_connected_device(string mac_address) {
            ConnectedDevice? to_remove = null;
            
            foreach (var device in _connected_devices) {
                if (device.mac_address == mac_address) {
                    to_remove = device;
                    break;
                }
            }
            
            if (to_remove != null) {
                _connected_devices.remove(to_remove);
                device_disconnected(to_remove);
            }
        }
        
        /**
         * Update data usage statistics
         */
        public void update_usage(uint64 bytes_sent, uint64 bytes_received) {
            _data_usage.total_bytes_sent += bytes_sent;
            _data_usage.total_bytes_received += bytes_received;
            
            usage_updated(_data_usage);
            
            // Check for threshold warnings
            if (_data_usage.limit_enabled) {
                var percentage = _data_usage.get_usage_percentage();
                if (percentage >= 90.0 || percentage >= 100.0) {
                    usage_threshold_reached(percentage);
                }
            }
        }
        
        /**
         * Set data usage limit
         */
        public void set_usage_limit(uint64 limit_bytes, bool enabled = true) {
            _data_usage.usage_limit = limit_bytes;
            _data_usage.limit_enabled = enabled;
        }
        
        /**
         * Check if hotspot is currently active
         */
        public bool is_active() {
            return state == HotspotState.ACTIVE;
        }
        
        /**
         * Get number of connected devices
         */
        public uint get_connected_device_count() {
            return _connected_devices.length();
        }
        
        /**
         * Check if configuration is valid
         */
        public bool is_configuration_valid() {
            // SSID is required and must be reasonable length
            if (ssid == null || ssid.length == 0 || ssid.length > 32) {
                return false;
            }
            
            // Password validation for secured networks
            if (security_type != SecurityType.NONE) {
                if (password == null || password.length < 8 || password.length > 63) {
                    return false;
                }
            }
            
            // Channel validation (1-14 for 2.4GHz)
            if (channel < 1 || channel > 14) {
                return false;
            }
            
            // Max clients validation
            if (max_clients == 0 || max_clients > 50) {
                return false;
            }
            
            // Device interface is required
            if (device_interface == null || device_interface.length == 0) {
                return false;
            }
            
            return true;
        }
        
        /**
         * Get human-readable state description
         */
        public string get_state_description() {
            switch (state) {
                case HotspotState.INACTIVE:
                    return "Inactive";
                case HotspotState.STARTING:
                    return "Starting...";
                case HotspotState.ACTIVE:
                    return "Active";
                case HotspotState.STOPPING:
                    return "Stopping...";
                case HotspotState.FAILED:
                    return "Failed";
                default:
                    return "Unknown";
            }
        }
        
        /**
         * Get security type description
         */
        public string get_security_description() {
            switch (security_type) {
                case SecurityType.NONE:
                    return "Open";
                case SecurityType.WPA_PSK:
                    return "WPA Personal";
                case SecurityType.WPA2_PSK:
                    return "WPA2 Personal";
                case SecurityType.WPA3_PSK:
                    return "WPA3 Personal";
                default:
                    return "Unknown";
            }
        }
        
        /**
         * Generate a random password for the hotspot
         */
        public void generate_random_password() {
            const string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            var sb = new StringBuilder();
            
            for (int i = 0; i < 12; i++) {
                sb.append_c(chars[Random.int_range(0, chars.length)]);
            }
            
            password = sb.str;
        }
        
        /**
         * Update hotspot state and emit signal
         */
        private void update_state(HotspotState new_state) {
            var old_state = state;
            state = new_state;
            state_changed(old_state, new_state);
        }
        
        /**
         * Async wait helper
         */
        private async void wait_async(uint milliseconds) {
            Timeout.add(milliseconds, () => {
                wait_async.callback();
                return false;
            });
            yield;
        }
    }
}