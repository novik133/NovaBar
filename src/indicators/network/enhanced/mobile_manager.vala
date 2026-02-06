/**
 * Enhanced Network Indicator - Mobile Broadband Manager
 * 
 * This file implements the MobileManager component responsible for managing
 * mobile broadband connections, data usage tracking, and cellular modem detection.
 */

using GLib;
using NM;

namespace EnhancedNetwork {

    /**
     * Billing period configuration
     */
    public class BillingPeriod : GLib.Object {
        public DateTime start_date { get; set; }
        public uint8 reset_day { get; set; } // Day of month (1-31)
        public uint64 data_limit { get; set; }
        public bool limit_enabled { get; set; }
        
        public BillingPeriod() {
            start_date = new DateTime.now_local();
            reset_day = 1;
            data_limit = 0;
            limit_enabled = false;
        }
        
        public BillingPeriod.with_reset_day(uint8 day) {
            this();
            reset_day = day;
            calculate_period_start();
        }
        
        public DateTime get_current_period_start() {
            var now = new DateTime.now_local();
            var year = now.get_year();
            var month = now.get_month();
            
            // If we're past the reset day this month, period started this month
            // Otherwise, period started last month
            if (now.get_day_of_month() >= reset_day) {
                return new DateTime.local(year, month, reset_day, 0, 0, 0);
            } else {
                // Go to previous month
                if (month == 1) {
                    year--;
                    month = 12;
                } else {
                    month--;
                }
                return new DateTime.local(year, month, reset_day, 0, 0, 0);
            }
        }
        
        public DateTime get_current_period_end() {
            var period_start = get_current_period_start();
            var year = period_start.get_year();
            var month = period_start.get_month();
            
            // Go to next month
            if (month == 12) {
                year++;
                month = 1;
            } else {
                month++;
            }
            
            return new DateTime.local(year, month, reset_day, 0, 0, 0);
        }
        
        private void calculate_period_start() {
            start_date = get_current_period_start();
        }
    }

    /**
     * Mobile Manager for handling cellular connections and data usage
     * 
     * This class provides comprehensive mobile broadband management including
     * modem detection, network discovery, data usage tracking, and roaming control.
     */
    public class MobileManager : GLib.Object {
        private NetworkManagerClient nm_client;
        private GenericArray<MobileConnection> _mobile_connections;
        private MobileConnection? _active_connection;
        private BillingPeriod billing_period;
        private GLib.Settings? settings;
        private Timer? usage_update_timer;
        private GenericArray<APNConfiguration> known_apns;
        
        /**
         * Signal emitted when mobile connections list changes
         */
        public signal void connections_updated(GenericArray<MobileConnection> connections);
        
        /**
         * Signal emitted when mobile connection state changes
         */
        public signal void connection_state_changed(MobileConnection connection, MobileConnectionState state);
        
        /**
         * Signal emitted when data usage is updated
         */
        public signal void data_usage_updated(MobileConnection connection, MobileDataUsage usage);
        
        /**
         * Signal emitted when approaching data limit
         */
        public signal void data_limit_warning(MobileConnection connection, double usage_percentage);
        
        /**
         * Signal emitted when data limit is exceeded
         */
        public signal void data_limit_exceeded(MobileConnection connection);
        
        /**
         * Signal emitted when roaming status changes
         */
        public signal void roaming_status_changed(MobileConnection connection, bool is_roaming);
        
        /**
         * Signal emitted when cellular modem is detected
         */
        public signal void modem_detected(string device_path);
        
        /**
         * Signal emitted when cellular modem is removed
         */
        public signal void modem_removed(string device_path);
        
        public GenericArray<MobileConnection> mobile_connections { 
            get { return _mobile_connections; } 
        }
        
        public MobileConnection? active_connection { 
            get { return _active_connection; } 
        }
        
        public MobileManager(NetworkManagerClient nm_client) {
            this.nm_client = nm_client;
            this._mobile_connections = new GenericArray<MobileConnection>();
            
            // Try to load GSettings schema, but don't fail if it's not available
            try {
                var schema_source = GLib.SettingsSchemaSource.get_default();
                if (schema_source != null && schema_source.lookup("org.novadesktop.novabar.network.mobile", false) != null) {
                    this.settings = new GLib.Settings("org.novadesktop.novabar.network.mobile");
                    debug("MobileManager: GSettings schema loaded successfully");
                } else {
                    this.settings = null;
                    debug("MobileManager: GSettings schema not found, using defaults");
                }
            } catch (Error e) {
                this.settings = null;
                debug("MobileManager: Failed to load GSettings: %s, using defaults", e.message);
            }
            
            this.billing_period = new BillingPeriod();
            this.known_apns = new GenericArray<APNConfiguration>();
            
            // Load settings
            load_settings();
            
            // Load known APNs
            load_known_apns();
            
            // Setup NetworkManager signal handlers
            setup_nm_signals();
            
            // Start data usage monitoring
            start_usage_monitoring();
            
            // Discover existing mobile devices
            discover_mobile_devices.begin();
        }
        
        /**
         * Setup NetworkManager signal handlers for mobile events
         */
        private void setup_nm_signals() {
            nm_client.device_added.connect((device) => {
                if (is_mobile_device(device)) {
                    debug("MobileManager: Mobile device added: %s", device.get_iface());
                    handle_mobile_device_added(device);
                }
            });
            
            nm_client.device_removed.connect((device) => {
                if (is_mobile_device(device)) {
                    debug("MobileManager: Mobile device removed: %s", device.get_iface());
                    handle_mobile_device_removed(device);
                }
            });
            
            nm_client.device_state_changed.connect((device, new_state, old_state, reason) => {
                if (is_mobile_device(device)) {
                    handle_mobile_device_state_change(device, new_state, old_state, reason);
                }
            });
            
            nm_client.connection_state_changed.connect((active_connection, state, reason) => {
                if (is_mobile_active_connection(active_connection)) {
                    handle_mobile_connection_state_change(active_connection, state, reason);
                }
            });
        }
        
        /**
         * Connect to mobile broadband network
         */
        public async bool connect_mobile(MobileConnection connection) throws Error {
            if (!nm_client.is_available) {
                throw new IOError.NOT_CONNECTED("NetworkManager not available");
            }
            
            if (connection.is_roaming() && !connection.is_data_roaming_allowed()) {
                throw new IOError.PERMISSION_DENIED("Data roaming is not allowed");
            }
            
            try {
                debug("MobileManager: Connecting to mobile network via %s", connection.name);
                
                // Find or create NetworkManager connection
                var nm_connection = find_nm_connection_for_mobile(connection);
                if (nm_connection == null) {
                    nm_connection = yield create_nm_connection_for_mobile(connection);
                }
                
                if (nm_connection == null) {
                    throw new IOError.FAILED("Failed to create NetworkManager connection for mobile");
                }
                
                // Find the mobile device
                var device = find_mobile_device_by_path(connection.device_path);
                if (device == null) {
                    throw new IOError.NOT_FOUND("Mobile device not found: %s", connection.device_path ?? "unknown");
                }
                
                // Activate the connection
                var success = yield nm_client.activate_connection(nm_connection, device);
                if (success) {
                    debug("MobileManager: Mobile connection initiated successfully");
                    return true;
                } else {
                    throw new IOError.FAILED("Failed to activate mobile connection");
                }
                
            } catch (Error e) {
                warning("MobileManager: Failed to connect mobile: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Disconnect from mobile broadband network
         */
        public async bool disconnect_mobile(MobileConnection connection) throws Error {
            if (!nm_client.is_available) {
                throw new IOError.NOT_CONNECTED("NetworkManager not available");
            }
            
            try {
                debug("MobileManager: Disconnecting mobile connection %s", connection.name);
                
                // Find active connection
                var active_connection = find_active_mobile_connection(connection);
                if (active_connection != null) {
                    var success = yield nm_client.deactivate_connection(active_connection);
                    if (success) {
                        debug("MobileManager: Mobile connection disconnected successfully");
                        return true;
                    } else {
                        throw new IOError.FAILED("Failed to deactivate mobile connection");
                    }
                } else {
                    warning("MobileManager: No active connection found for mobile %s", connection.name);
                    return false;
                }
                
            } catch (Error e) {
                warning("MobileManager: Failed to disconnect mobile: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Configure APN settings for a mobile connection
         */
        public async bool configure_apn(MobileConnection connection, APNConfiguration apn_config) throws Error {
            try {
                debug("MobileManager: Configuring APN %s for connection %s", apn_config.apn, connection.name);
                
                // Update connection APN configuration
                connection.set_apn_configuration(apn_config);
                
                // If connection is active, may need to reconnect
                if (connection.state == ConnectionState.CONNECTED) {
                    yield disconnect_mobile(connection);
                    yield connect_mobile(connection);
                }
                
                return true;
                
            } catch (Error e) {
                warning("MobileManager: Failed to configure APN: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Set data usage limit and billing period
         */
        public void set_data_limit(uint64 limit_bytes, uint8 billing_day = 1) {
            billing_period.data_limit = limit_bytes;
            billing_period.limit_enabled = (limit_bytes > 0);
            billing_period.reset_day = billing_day;
            
            // Update all mobile connections with new limit
            for (uint i = 0; i < _mobile_connections.length; i++) {
                var connection = _mobile_connections[i];
                connection.set_data_limit(limit_bytes, billing_period.limit_enabled);
            }
            
            // Save settings
            save_settings();
            
            debug("MobileManager: Data limit set to %s, billing day: %u", 
                  format_bytes(limit_bytes), billing_day);
        }
        
        /**
         * Reset data usage for new billing period
         */
        public void reset_data_usage() {
            debug("MobileManager: Resetting data usage for new billing period");
            
            for (uint i = 0; i < _mobile_connections.length; i++) {
                var connection = _mobile_connections[i];
                connection.reset_data_usage();
            }
            
            billing_period.start_date = new DateTime.now_local();
        }
        
        /**
         * Enable or disable data roaming for all connections
         */
        public void set_data_roaming_enabled(bool enabled) {
            debug("MobileManager: Setting data roaming enabled: %s", enabled.to_string());
            
            for (uint i = 0; i < _mobile_connections.length; i++) {
                var connection = _mobile_connections[i];
                connection.data_roaming_allowed = enabled;
                
                // If currently roaming and data roaming is disabled, disconnect
                if (connection.is_roaming() && !enabled && connection.state == ConnectionState.CONNECTED) {
                    connection.disconnect_from_network.begin();
                }
            }
            
            if (settings != null) {
                settings.set_boolean("data-roaming-enabled", enabled);
            }
        }
        
        /**
         * Get total data usage across all mobile connections
         */
        public MobileDataUsage get_total_data_usage() {
            var total_usage = new MobileDataUsage();
            total_usage.period_start = billing_period.get_current_period_start();
            total_usage.period_end = billing_period.get_current_period_end();
            total_usage.monthly_limit = billing_period.data_limit;
            total_usage.limit_enabled = billing_period.limit_enabled;
            
            for (uint i = 0; i < _mobile_connections.length; i++) {
                var connection = _mobile_connections[i];
                total_usage.bytes_sent += connection.data_usage.bytes_sent;
                total_usage.bytes_received += connection.data_usage.bytes_received;
            }
            
            return total_usage;
        }
        
        /**
         * Get available APN configurations
         */
        public GenericArray<APNConfiguration> get_known_apns() {
            return known_apns;
        }
        
        /**
         * Add custom APN configuration
         */
        public void add_custom_apn(APNConfiguration apn_config) {
            known_apns.add(apn_config);
            save_known_apns();
            debug("MobileManager: Added custom APN: %s", apn_config.name);
        }
        
        /**
         * Check if any mobile connection is active
         */
        public bool is_mobile_connected() {
            return _active_connection != null && _active_connection.state == ConnectionState.CONNECTED;
        }
        
        /**
         * Check if currently roaming on any connection
         */
        public bool is_roaming() {
            for (uint i = 0; i < _mobile_connections.length; i++) {
                var connection = _mobile_connections[i];
                if (connection.is_roaming()) {
                    return true;
                }
            }
            return false;
        }
        
        // Private helper methods
        
        /**
         * Discover existing mobile devices
         */
        private async void discover_mobile_devices() {
            if (!nm_client.is_available) {
                return;
            }
            
            debug("MobileManager: Discovering mobile devices...");
            
            var devices = nm_client.get_devices_by_type(NM.DeviceType.MODEM);
            for (uint i = 0; i < devices.length; i++) {
                var device = devices[i];
                handle_mobile_device_added(device);
            }
            
            debug("MobileManager: Discovered %u mobile devices", devices.length);
        }
        
        /**
         * Check if device is a mobile broadband device
         */
        private bool is_mobile_device(NM.Device device) {
            return device.get_device_type() == NM.DeviceType.MODEM;
        }
        
        /**
         * Handle mobile device added
         */
        private void handle_mobile_device_added(NM.Device device) {
            var device_path = device.get_path();
            debug("MobileManager: Handling mobile device added: %s", device_path);
            
            // Create mobile connection for this device
            var connection = new MobileConnection.with_device(device_path);
            var iface = device.get_iface();
            if (iface != null) {
                connection.name = "Mobile Broadband (%s)".printf(iface);
            } else {
                connection.name = "Mobile Broadband";
            }
            
            // Setup connection signals
            setup_mobile_connection_signals(connection);
            
            // Add to connections list
            _mobile_connections.add(connection);
            connections_updated(_mobile_connections);
            
            // Query device information
            query_device_info.begin(device, connection);
            
            modem_detected(device_path);
        }
        
        /**
         * Handle mobile device removed
         */
        private void handle_mobile_device_removed(NM.Device device) {
            var device_path = device.get_path();
            debug("MobileManager: Handling mobile device removed: %s", device_path);
            
            // Find and remove connection
            for (uint i = 0; i < _mobile_connections.length; i++) {
                var connection = _mobile_connections[i];
                if (connection.device_path == device_path) {
                    if (_active_connection == connection) {
                        _active_connection = null;
                    }
                    _mobile_connections.remove_index(i);
                    connections_updated(_mobile_connections);
                    break;
                }
            }
            
            modem_removed(device_path);
        }
        
        /**
         * Handle mobile device state changes
         */
        private void handle_mobile_device_state_change(NM.Device device, 
                                                     NM.DeviceState new_state, 
                                                     NM.DeviceState old_state, 
                                                     NM.DeviceStateReason reason) {
            var connection = find_mobile_connection_by_device_path(device.get_path());
            if (connection == null) return;
            
            debug("MobileManager: Device %s state changed: %s -> %s", 
                  device.get_iface(), old_state.to_string(), new_state.to_string());
            
            // Update connection state based on device state
            MobileConnectionState mobile_state;
            switch (new_state) {
                case NM.DeviceState.PREPARE:
                case NM.DeviceState.CONFIG:
                    mobile_state = MobileConnectionState.CONNECTING;
                    break;
                case NM.DeviceState.NEED_AUTH:
                    mobile_state = MobileConnectionState.REGISTERING;
                    break;
                case NM.DeviceState.IP_CONFIG:
                case NM.DeviceState.IP_CHECK:
                    mobile_state = MobileConnectionState.CONNECTING;
                    break;
                case NM.DeviceState.ACTIVATED:
                    mobile_state = MobileConnectionState.CONNECTED;
                    _active_connection = connection;
                    break;
                case NM.DeviceState.DEACTIVATING:
                    mobile_state = MobileConnectionState.DISCONNECTING;
                    break;
                case NM.DeviceState.DISCONNECTED:
                case NM.DeviceState.UNMANAGED:
                    mobile_state = MobileConnectionState.DISCONNECTED;
                    if (_active_connection == connection) {
                        _active_connection = null;
                    }
                    break;
                case NM.DeviceState.FAILED:
                    mobile_state = MobileConnectionState.FAILED;
                    break;
                default:
                    mobile_state = MobileConnectionState.DISCONNECTED;
                    break;
            }
            
            connection.mobile_state = mobile_state;
            connection_state_changed(connection, mobile_state);
        }
        
        /**
         * Handle mobile connection state changes
         */
        private void handle_mobile_connection_state_change(NM.ActiveConnection active_connection,
                                                         NM.ActiveConnectionState state,
                                                         NM.ActiveConnectionStateReason reason) {
            var nm_connection = active_connection.get_connection();
            if (nm_connection == null) return;
            
            var connection = find_mobile_connection_by_nm_connection(nm_connection);
            if (connection == null) return;
            
            debug("MobileManager: Connection %s state changed: %s", 
                  nm_connection.get_id(), state.to_string());
            
            // Update connection statistics if connected
            if (state == NM.ActiveConnectionState.ACTIVATED) {
                update_connection_statistics.begin(connection, active_connection);
            }
        }
        
        /**
         * Query device information from modem
         */
        private async void query_device_info(NM.Device device, MobileConnection connection) {
            try {
                // In a real implementation, this would query ModemManager D-Bus
                // to get detailed modem information like IMEI, operator, signal strength
                
                debug("MobileManager: Querying device info for %s", device.get_iface());
                
                // Simulate getting device information
                yield wait_async(1000);
                
                // Create mock operator info
                var operator = new MobileOperator();
                operator.operator_name = "Mock Carrier";
                operator.operator_code = "12345";
                operator.network_type = "LTE";
                operator.signal_strength = 75;
                operator.is_roaming = false;
                
                connection.update_operator_info(operator);
                
                // Set mock IMEI
                connection.imei = "123456789012345";
                connection.sim_identifier = "89012345678901234567";
                
            } catch (Error e) {
                warning("MobileManager: Failed to query device info: %s", e.message);
            }
        }
        
        /**
         * Update connection statistics
         */
        private async void update_connection_statistics(MobileConnection connection, 
                                                      NM.ActiveConnection active_connection) {
            try {
                // In a real implementation, this would get actual statistics
                // from NetworkManager or the device
                
                // For now, simulate some data usage
                var current_time = new DateTime.now_local();
                var time_diff = current_time.difference(connection.data_usage.period_start ?? current_time);
                var hours = time_diff / TimeSpan.HOUR;
                
                // Simulate gradual data usage increase
                var simulated_usage = (uint64)(hours * 1024 * 1024); // 1MB per hour
                connection.update_data_usage(simulated_usage / 2, simulated_usage / 2);
                
            } catch (Error e) {
                warning("MobileManager: Failed to update connection statistics: %s", e.message);
            }
        }
        
        /**
         * Setup signal handlers for mobile connection
         */
        private void setup_mobile_connection_signals(MobileConnection connection) {
            connection.data_usage_updated.connect((usage) => {
                data_usage_updated(connection, usage);
                
                // Check for data limit warnings
                if (usage.limit_enabled) {
                    var percentage = usage.get_usage_percentage();
                    if (percentage >= 100.0) {
                        data_limit_exceeded(connection);
                    } else if (percentage >= 80.0) {
                        data_limit_warning(connection, percentage);
                    }
                }
            });
            
            connection.roaming_status_changed.connect((is_roaming) => {
                roaming_status_changed(connection, is_roaming);
            });
        }
        
        /**
         * Start data usage monitoring timer
         */
        private void start_usage_monitoring() {
            // Update usage statistics every 30 seconds
            usage_update_timer = new Timer();
            Timeout.add_seconds(30, () => {
                update_all_usage_statistics.begin();
                return true;
            });
        }
        
        /**
         * Update usage statistics for all connections
         */
        private async void update_all_usage_statistics() {
            for (uint i = 0; i < _mobile_connections.length; i++) {
                var connection = _mobile_connections[i];
                if (connection.state == ConnectionState.CONNECTED) {
                    // In practice, query actual statistics from NetworkManager
                    // For now, just trigger the existing mock update
                    var active_connection = find_active_mobile_connection(connection);
                    if (active_connection != null) {
                        yield update_connection_statistics(connection, active_connection);
                    }
                }
            }
        }
        
        /**
         * Find mobile connection by device path
         */
        private MobileConnection? find_mobile_connection_by_device_path(string device_path) {
            for (uint i = 0; i < _mobile_connections.length; i++) {
                var connection = _mobile_connections[i];
                if (connection.device_path == device_path) {
                    return connection;
                }
            }
            return null;
        }
        
        /**
         * Find mobile device by path
         */
        private NM.Device? find_mobile_device_by_path(string? device_path) {
            if (device_path == null) return null;
            
            var devices = nm_client.get_devices_by_type(NM.DeviceType.MODEM);
            for (uint i = 0; i < devices.length; i++) {
                var device = devices[i];
                if (device.get_path() == device_path) {
                    return device;
                }
            }
            return null;
        }
        
        /**
         * Check if active connection is mobile
         */
        private bool is_mobile_active_connection(NM.ActiveConnection active_connection) {
            var connection = active_connection.get_connection();
            return connection != null && connection.get_connection_type() == "gsm";
        }
        
        /**
         * Find NetworkManager connection for mobile connection
         */
        private NM.Connection? find_nm_connection_for_mobile(MobileConnection connection) {
            var connections = nm_client.get_connections_by_type("gsm");
            for (uint i = 0; i < connections.length; i++) {
                var nm_connection = connections[i];
                if (nm_connection.get_id() == connection.name) {
                    return nm_connection;
                }
            }
            return null;
        }
        
        /**
         * Find mobile connection by NetworkManager connection
         */
        private MobileConnection? find_mobile_connection_by_nm_connection(NM.Connection nm_connection) {
            var connection_id = nm_connection.get_id();
            for (uint i = 0; i < _mobile_connections.length; i++) {
                var connection = _mobile_connections[i];
                if (connection.name == connection_id) {
                    return connection;
                }
            }
            return null;
        }
        
        /**
         * Find active mobile connection
         */
        private NM.ActiveConnection? find_active_mobile_connection(MobileConnection connection) {
            if (!nm_client.is_available || nm_client.nm_client == null) {
                return null;
            }
            
            var active_connections = nm_client.nm_client.get_active_connections();
            foreach (var ac in active_connections) {
                if (is_mobile_active_connection(ac)) {
                    var nm_connection = ac.get_connection();
                    if (nm_connection != null && nm_connection.get_id() == connection.name) {
                        return ac;
                    }
                }
            }
            return null;
        }
        
        /**
         * Create NetworkManager connection for mobile connection
         */
        private async NM.Connection? create_nm_connection_for_mobile(MobileConnection connection) throws Error {
            // This would create the appropriate NetworkManager GSM connection
            debug("MobileManager: Creating NetworkManager connection for mobile %s", connection.name);
            
            // Placeholder implementation - actual implementation would create
            // proper NM.Connection objects with GSM-specific settings
            return null;
        }
        
        /**
         * Load settings from GSettings
         */
        private void load_settings() {
            if (settings != null) {
                var billing_day = settings.get_int("billing-day");
                var data_limit = settings.get_uint64("data-limit");
                var limit_enabled = settings.get_boolean("limit-enabled");
                
                billing_period.reset_day = (uint8)billing_day.clamp(1, 31);
                billing_period.data_limit = data_limit;
                billing_period.limit_enabled = limit_enabled;
                
                debug("MobileManager: Loaded settings - billing day: %u, limit: %s", 
                      billing_period.reset_day, format_bytes(billing_period.data_limit));
            } else {
                // Use defaults
                billing_period.reset_day = 1;
                billing_period.data_limit = 5 * 1024 * 1024 * 1024; // 5 GB default
                billing_period.limit_enabled = false;
                debug("MobileManager: Using default settings");
            }
        }
        
        /**
         * Save settings to GSettings
         */
        private void save_settings() {
            if (settings != null) {
                settings.set_int("billing-day", billing_period.reset_day);
                settings.set_uint64("data-limit", billing_period.data_limit);
                settings.set_boolean("limit-enabled", billing_period.limit_enabled);
            }
        }
        
        /**
         * Load known APN configurations
         */
        private void load_known_apns() {
            // In practice, this would load from a database or configuration file
            // For now, add some common APNs
            
            var tmobile = new APNConfiguration.with_apn("T-Mobile", "fast.t-mobile.com");
            known_apns.add(tmobile);
            
            var verizon = new APNConfiguration.with_apn("Verizon", "vzwinternet");
            known_apns.add(verizon);
            
            var att = new APNConfiguration.with_apn("AT&T", "broadband");
            known_apns.add(att);
            
            debug("MobileManager: Loaded %u known APNs", known_apns.length);
        }
        
        /**
         * Save known APN configurations
         */
        private void save_known_apns() {
            // In practice, this would save to a configuration file
            debug("MobileManager: Saving %u known APNs", known_apns.length);
        }
        
        /**
         * Format bytes for display
         */
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
        
        /**
         * Get all available mobile networks
         */
        public List<MobileConnection> get_available_networks() {
            var networks = new List<MobileConnection>();
            for (uint i = 0; i < _mobile_connections.length; i++) {
                networks.append(_mobile_connections[i]);
            }
            return (owned) networks;
        }
        
        /**
         * Connect to a mobile network
         */
        public async bool connect_to_network(MobileConnection connection) throws Error {
            if (!nm_client.is_available) {
                throw new IOError.NOT_CONNECTED("NetworkManager not available");
            }
            
            try {
                debug("MobileManager: Connecting to mobile network: %s", connection.name);
                
                // This is a placeholder implementation
                // In a real implementation, this would activate the mobile connection
                // through NetworkManager
                
                connection.update_state(ConnectionState.CONNECTING);
                
                // Simulate connection delay
                Timeout.add(2000, () => {
                    connection.update_state(ConnectionState.CONNECTED);
                    _active_connection = connection;
                    return Source.REMOVE;
                });
                
                return true;
                
            } catch (Error e) {
                warning("MobileManager: Failed to connect to mobile network: %s", e.message);
                connection.update_state(ConnectionState.FAILED);
                throw e;
            }
        }
    }
}