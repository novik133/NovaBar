/**
 * Enhanced Network Indicator - Mobile Broadband Connection Model
 * 
 * This file defines the MobileConnection class and related data structures
 * for managing mobile broadband connections in the enhanced network indicator.
 */

using GLib;

namespace EnhancedNetwork {

    /**
     * APN (Access Point Name) configuration
     */
    public class APNConfiguration : GLib.Object {
        public string name { get; set; }
        public string apn { get; set; }
        public string? username { get; set; }
        public string? password { get; set; }
        public string? proxy { get; set; }
        public uint16 proxy_port { get; set; }
        public string? mmsc { get; set; }
        public string? mms_proxy { get; set; }
        public uint16 mms_proxy_port { get; set; }
        public bool is_default { get; set; }
        
        public APNConfiguration() {
            proxy_port = 0;
            mms_proxy_port = 0;
            is_default = false;
        }
        
        public APNConfiguration.with_apn(string name, string apn) {
            this();
            this.name = name;
            this.apn = apn;
        }
    }

    /**
     * Mobile network operator information
     */
    public class MobileOperator : GLib.Object {
        public string? operator_code { get; set; }
        public string? operator_name { get; set; }
        public string? country_code { get; set; }
        public string? network_type { get; set; }
        public bool is_roaming { get; set; }
        public uint8 signal_strength { get; set; }
        
        public MobileOperator() {
            is_roaming = false;
            signal_strength = 0;
        }
        
        public string get_display_name() {
            if (operator_name != null && operator_name.length > 0) {
                return operator_name;
            } else if (operator_code != null && operator_code.length > 0) {
                return operator_code;
            } else {
                return "Unknown Operator";
            }
        }
        
        public string get_network_type_description() {
            if (network_type == null) {
                return "Unknown";
            }
            
            switch (network_type.up()) {
                case "GSM":
                    return "2G (GSM)";
                case "UMTS":
                case "HSPA":
                case "HSDPA":
                case "HSUPA":
                    return "3G (UMTS/HSPA)";
                case "LTE":
                    return "4G (LTE)";
                case "5GNR":
                    return "5G";
                default:
                    return network_type;
            }
        }
        
        public string get_signal_strength_description() {
            if (signal_strength >= 80) {
                return "Excellent";
            } else if (signal_strength >= 60) {
                return "Good";
            } else if (signal_strength >= 40) {
                return "Fair";
            } else if (signal_strength >= 20) {
                return "Poor";
            } else {
                return "No Signal";
            }
        }
    }

    /**
     * Mobile data usage statistics
     */
    public class MobileDataUsage : GLib.Object {
        public uint64 bytes_sent { get; set; }
        public uint64 bytes_received { get; set; }
        public DateTime? period_start { get; set; }
        public DateTime? period_end { get; set; }
        public uint64 monthly_limit { get; set; }
        public bool limit_enabled { get; set; }
        
        public MobileDataUsage() {
            bytes_sent = 0;
            bytes_received = 0;
            monthly_limit = 0;
            limit_enabled = false;
            period_start = new DateTime.now_local().add_days(-30);
            period_end = new DateTime.now_local();
        }
        
        public uint64 get_total_usage() {
            return bytes_sent + bytes_received;
        }
        
        public double get_usage_percentage() {
            if (!limit_enabled || monthly_limit == 0) {
                return 0.0;
            }
            return (double)get_total_usage() / (double)monthly_limit * 100.0;
        }
        
        public bool is_approaching_limit(double threshold = 80.0) {
            return limit_enabled && get_usage_percentage() >= threshold;
        }
        
        public bool is_over_limit() {
            return limit_enabled && get_total_usage() >= monthly_limit;
        }
        
        public string format_usage() {
            return format_bytes(get_total_usage());
        }
        
        public string format_limit() {
            if (!limit_enabled) {
                return "No limit";
            }
            return format_bytes(monthly_limit);
        }
        
        private string format_bytes(uint64 bytes) {
            if (bytes < 1024) {
                return "%llu B".printf(bytes);
            } else if (bytes < 1024 * 1024) {
                return "%.1f KB".printf((double)bytes / 1024.0);
            } else if (bytes < 1024 * 1024 * 1024) {
                return "%.1f MB".printf((double)bytes / (1024.0 * 1024.0));
            } else {
                return "%.2f GB".printf((double)bytes / (1024.0 * 1024.0 * 1024.0));
            }
        }
    }

    /**
     * Mobile broadband connection states
     */
    public enum MobileConnectionState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        DISCONNECTING,
        FAILED,
        SEARCHING,
        REGISTERING
    }

    /**
     * Mobile broadband connection representing a cellular data connection
     */
    public class MobileConnection : NetworkConnection {
        public string? sim_identifier { get; set; }
        public string? imei { get; set; }
        public MobileOperator? operator_info { get; set; }
        public APNConfiguration? apn_config { get; set; }
        public MobileDataUsage data_usage { get; set; }
        public MobileConnectionState mobile_state { get; set; }
        public bool roaming_enabled { get; set; }
        public bool data_roaming_allowed { get; set; }
        
        /**
         * Signal emitted when operator information changes
         */
        public signal void operator_changed(MobileOperator? operator);
        
        /**
         * Signal emitted when data usage is updated
         */
        public signal void data_usage_updated(MobileDataUsage usage);
        
        /**
         * Signal emitted when roaming status changes
         */
        public signal void roaming_status_changed(bool is_roaming);
        
        /**
         * Signal emitted when signal strength changes
         */
        public signal void signal_strength_changed(uint8 strength);
        
        public MobileConnection() {
            base();
            connection_type = ConnectionType.MOBILE_BROADBAND;
            data_usage = new MobileDataUsage();
            mobile_state = MobileConnectionState.DISCONNECTED;
            roaming_enabled = true;
            data_roaming_allowed = false;
        }
        
        public MobileConnection.with_device(string device_path) {
            this();
            this.device_path = device_path;
            if (device_path != null) {
                this.id = "mobile-%s".printf(device_path.replace("/", "_"));
            } else {
                this.id = "mobile-unknown";
            }
        }
        
        /**
         * Connect to mobile broadband network
         */
        public override async bool connect_to_network(Credentials? credentials = null) throws Error {
            update_mobile_state(MobileConnectionState.CONNECTING);
            
            try {
                // TODO: Implement actual NetworkManager mobile connection logic
                // This would involve:
                // 1. Finding the modem device
                // 2. Registering with the network
                // 3. Activating the data connection with APN settings
                
                // Simulate connection process
                update_mobile_state(MobileConnectionState.SEARCHING);
                yield wait_async(1000);
                
                update_mobile_state(MobileConnectionState.REGISTERING);
                yield wait_async(2000);
                
                update_mobile_state(MobileConnectionState.CONNECTED);
                state = ConnectionState.CONNECTED;
                last_connected = new DateTime.now_local();
                
                return true;
                
            } catch (Error e) {
                warning("MobileConnection: Failed to connect: %s", e.message);
                update_mobile_state(MobileConnectionState.FAILED);
                state = ConnectionState.FAILED;
                return false;
            }
        }
        
        /**
         * Disconnect from mobile broadband network
         */
        public override async bool disconnect_from_network() throws Error {
            update_mobile_state(MobileConnectionState.DISCONNECTING);
            
            try {
                // TODO: Implement actual NetworkManager mobile disconnection logic
                
                // Simulate disconnection
                yield wait_async(1000);
                
                update_mobile_state(MobileConnectionState.DISCONNECTED);
                state = ConnectionState.DISCONNECTED;
                
                return true;
                
            } catch (Error e) {
                warning("MobileConnection: Failed to disconnect: %s", e.message);
                return false;
            }
        }
        
        /**
         * Get connection information
         */
        public override ConnectionInfo? get_connection_info() {
            var info = new ConnectionInfo();
            
            if (operator_info != null) {
                // Set basic connection info
                info.connected_since = last_connected;
            }
            
            if (apn_config != null) {
                // APN information would be added to connection info
            }
            
            info.bytes_sent = data_usage.bytes_sent;
            info.bytes_received = data_usage.bytes_received;
            
            return info;
        }
        
        /**
         * Update APN configuration
         */
        public void set_apn_configuration(APNConfiguration config) {
            apn_config = config;
            
            // If connected, may need to reconnect with new APN settings
            if (state == ConnectionState.CONNECTED) {
                // In practice, this would update the active connection
                debug("MobileConnection: APN configuration updated, connection may need restart");
            }
        }
        
        /**
         * Update operator information
         */
        public void update_operator_info(MobileOperator operator) {
            var old_roaming = (operator_info != null) ? operator_info.is_roaming : false;
            var old_signal = (operator_info != null) ? operator_info.signal_strength : 0;
            
            operator_info = operator;
            operator_changed(operator_info);
            
            // Check for roaming status change
            if (operator_info.is_roaming != old_roaming) {
                roaming_status_changed(operator_info.is_roaming);
            }
            
            // Check for signal strength change
            if (operator_info.signal_strength != old_signal) {
                signal_strength_changed(operator_info.signal_strength);
            }
        }
        
        /**
         * Update data usage statistics
         */
        public void update_data_usage(uint64 bytes_sent, uint64 bytes_received) {
            data_usage.bytes_sent = bytes_sent;
            data_usage.bytes_received = bytes_received;
            data_usage_updated(data_usage);
        }
        
        /**
         * Set data usage limit
         */
        public void set_data_limit(uint64 limit_bytes, bool enabled = true) {
            data_usage.monthly_limit = limit_bytes;
            data_usage.limit_enabled = enabled;
            data_usage_updated(data_usage);
        }
        
        /**
         * Reset data usage for new billing period
         */
        public void reset_data_usage() {
            data_usage.bytes_sent = 0;
            data_usage.bytes_received = 0;
            data_usage.period_start = new DateTime.now_local();
            data_usage_updated(data_usage);
        }
        
        /**
         * Check if currently roaming
         */
        public bool is_roaming() {
            return operator_info != null && operator_info.is_roaming;
        }
        
        /**
         * Check if data roaming is allowed
         */
        public bool is_data_roaming_allowed() {
            return data_roaming_allowed;
        }
        
        /**
         * Get mobile connection state description
         */
        public string get_mobile_state_description() {
            switch (mobile_state) {
                case MobileConnectionState.DISCONNECTED:
                    return "Disconnected";
                case MobileConnectionState.CONNECTING:
                    return "Connecting...";
                case MobileConnectionState.CONNECTED:
                    return "Connected";
                case MobileConnectionState.DISCONNECTING:
                    return "Disconnecting...";
                case MobileConnectionState.FAILED:
                    return "Connection Failed";
                case MobileConnectionState.SEARCHING:
                    return "Searching for Network...";
                case MobileConnectionState.REGISTERING:
                    return "Registering...";
                default:
                    return "Unknown";
            }
        }
        
        /**
         * Check if connection can be used (not roaming or roaming allowed)
         */
        public bool can_connect() {
            if (!is_roaming()) {
                return true;
            }
            return data_roaming_allowed;
        }
        
        /**
         * Update mobile connection state
         */
        private void update_mobile_state(MobileConnectionState new_state) {
            mobile_state = new_state;
            
            // Update base connection state based on mobile state
            switch (new_state) {
                case MobileConnectionState.CONNECTING:
                case MobileConnectionState.SEARCHING:
                case MobileConnectionState.REGISTERING:
                    state = ConnectionState.CONNECTING;
                    break;
                case MobileConnectionState.CONNECTED:
                    state = ConnectionState.CONNECTED;
                    break;
                case MobileConnectionState.DISCONNECTING:
                    state = ConnectionState.DISCONNECTING;
                    break;
                case MobileConnectionState.DISCONNECTED:
                    state = ConnectionState.DISCONNECTED;
                    break;
                case MobileConnectionState.FAILED:
                    state = ConnectionState.FAILED;
                    break;
            }
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