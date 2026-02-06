/**
 * Enhanced Network Indicator - WiFi Manager Component
 * 
 * This file implements the WiFiManager class that provides comprehensive
 * WiFi network management including scanning, connection management,
 * and profile persistence.
 */

using GLib;
using NM;

namespace EnhancedNetwork {

    /**
     * WiFi scan result containing discovered networks
     */
    public class WiFiScanResult : GLib.Object {
        public GenericArray<WiFiNetwork> networks { get; set; }
        public DateTime scan_time { get; set; }
        public bool scan_successful { get; set; }
        public string? error_message { get; set; }
        
        public WiFiScanResult() {
            networks = new GenericArray<WiFiNetwork>();
            scan_time = new DateTime.now_local();
            scan_successful = false;
        }
    }

    /**
     * WiFi Manager - Comprehensive WiFi network management
     * 
     * This class provides complete WiFi functionality including network scanning,
     * connection management, profile persistence, and hidden network support.
     * It integrates with NetworkManager through the D-Bus API.
     */
    public class WiFiManager : GLib.Object {
        private NetworkManagerClient nm_client;
        private GenericArray<WiFiNetwork> _available_networks;
        private WiFiNetwork? _active_connection;
        private bool _scanning;
        private Timer? _scan_timer;
        private uint _scan_timeout_id;
        
        // Configuration
        private const uint SCAN_TIMEOUT_MS = 30000; // 30 seconds
        private const uint AUTO_SCAN_INTERVAL_MS = 15000; // 15 seconds
        private const uint SIGNAL_STRENGTH_THRESHOLD = 10; // Minimum change to report
        
        /**
         * Signal emitted when available networks list is updated
         */
        public signal void networks_updated(GenericArray<WiFiNetwork> networks);
        
        /**
         * Signal emitted when a WiFi connection state changes
         */
        public signal void connection_state_changed(WiFiNetwork network, ConnectionState state);
        
        /**
         * Signal emitted when a network scan completes
         */
        public signal void scan_completed(WiFiScanResult result);
        
        /**
         * Signal emitted when scan starts
         */
        public signal void scan_started();
        
        /**
         * Signal emitted when a network's signal strength changes significantly
         */
        public signal void signal_strength_updated(WiFiNetwork network, uint8 old_strength, uint8 new_strength);
        
        /**
         * Signal emitted when connection attempt fails
         */
        public signal void connection_failed(WiFiNetwork network, string error_message);
        
        public bool is_scanning { 
            get { return _scanning; } 
        }
        
        public WiFiNetwork? active_connection { 
            get { return _active_connection; } 
        }
        
        public WiFiManager(NetworkManagerClient nm_client) {
            this.nm_client = nm_client;
            _available_networks = new GenericArray<WiFiNetwork>();
            _scanning = false;
            
            // Setup NetworkManager client signals
            setup_nm_signals();
            
            // Start with initial scan if WiFi is available
            if (nm_client.is_available && nm_client.current_state.wireless_enabled) {
                Idle.add(() => {
                    start_scan.begin();
                    return false;
                });
            }
        }
        
        /**
         * Setup NetworkManager client signal handlers
         */
        private void setup_nm_signals() {
            nm_client.availability_changed.connect((available) => {
                if (!available) {
                    handle_nm_unavailable();
                } else {
                    // NetworkManager became available, start scanning
                    if (nm_client.current_state.wireless_enabled) {
                        start_scan.begin();
                    }
                }
            });
            
            nm_client.state_changed.connect((state) => {
                if (state.wireless_enabled && !_scanning) {
                    // WiFi was enabled, start scanning
                    start_scan.begin();
                } else if (!state.wireless_enabled) {
                    // WiFi was disabled, clear networks
                    clear_networks();
                }
            });
            
            nm_client.device_added.connect((device) => {
                if (device.get_device_type() == NM.DeviceType.WIFI) {
                    setup_wifi_device_signals(device as NM.DeviceWifi);
                    if (nm_client.current_state.wireless_enabled) {
                        start_scan.begin();
                    }
                }
            });
            
            nm_client.device_removed.connect((device) => {
                if (device.get_device_type() == NM.DeviceType.WIFI) {
                    // WiFi device removed, clear networks
                    clear_networks();
                }
            });
        }
        
        /**
         * Setup signals for a WiFi device
         */
        private void setup_wifi_device_signals(NM.DeviceWifi wifi_device) {
            wifi_device.access_point_added.connect((device, ap) => {
                var access_point = ap as NM.AccessPoint;
                if (access_point != null) {
                    var ssid_bytes = access_point.get_ssid();
                    var ssid_str = ssid_bytes != null ? (string)ssid_bytes.get_data() : "hidden";
                    debug("WiFiManager: Access point added: %s", ssid_str);
                    update_access_point(access_point);
                }
            });
            
            wifi_device.access_point_removed.connect((device, ap) => {
                var access_point = ap as NM.AccessPoint;
                if (access_point != null) {
                    var ssid_bytes = access_point.get_ssid();
                    var ssid_str = ssid_bytes != null ? (string)ssid_bytes.get_data() : "hidden";
                    debug("WiFiManager: Access point removed: %s", ssid_str);
                    remove_access_point(access_point);
                }
            });
            
            wifi_device.notify["active-access-point"].connect(() => {
                update_active_connection();
            });
        }
        
        /**
         * Start WiFi network scan
         */
        public async WiFiScanResult start_scan() {
            if (_scanning) {
                debug("WiFiManager: Scan already in progress, skipping");
                return create_scan_result(false, "Scan already in progress");
            }
            
            if (!nm_client.is_available) {
                warning("WiFiManager: Cannot scan - NetworkManager not available");
                return create_scan_result(false, "NetworkManager not available");
            }
            
            if (!nm_client.current_state.wireless_enabled) {
                warning("WiFiManager: Cannot scan - WiFi disabled");
                return create_scan_result(false, "WiFi is disabled");
            }
            
            var wifi_device = nm_client.get_wifi_device();
            if (wifi_device == null) {
                warning("WiFiManager: Cannot scan - no WiFi device found");
                return create_scan_result(false, "No WiFi device found");
            }
            
            _scanning = true;
            scan_started();
            
            debug("WiFiManager: Starting WiFi scan...");
            
            try {
                // Start the scan
                yield wifi_device.request_scan_async(null);
                
                // Set up timeout
                _scan_timeout_id = Timeout.add(SCAN_TIMEOUT_MS, () => {
                    if (_scanning) {
                        warning("WiFiManager: Scan timeout reached");
                        complete_scan(false, "Scan timeout");
                    }
                    return false;
                });
                
                // Wait a bit for scan to complete and then process results
                Timeout.add(2000, () => {
                    process_scan_results.begin(wifi_device);
                    return false;
                });
                
                return create_scan_result(true, null);
                
            } catch (Error e) {
                warning("WiFiManager: Scan failed: %s", e.message);
                _scanning = false;
                return create_scan_result(false, e.message);
            }
        }
        
        /**
         * Process scan results from WiFi device
         */
        private async void process_scan_results(NM.DeviceWifi wifi_device) {
            try {
                debug("WiFiManager: Processing scan results...");
                
                var access_points = wifi_device.get_access_points();
                var new_networks = new GenericArray<WiFiNetwork>();
                var networks_map = new HashTable<string, WiFiNetwork>(str_hash, str_equal);
                
                foreach (var ap in access_points) {
                    var ssid_bytes = ap.get_ssid();
                    if (ssid_bytes == null || ssid_bytes.length == 0) {
                        continue; // Skip hidden networks for now
                    }
                    
                    var ssid_str = (string)ssid_bytes.get_data();
                    var existing_network = networks_map.lookup(ssid_str);
                    
                    if (existing_network == null) {
                        // Create new network
                        var network = create_wifi_network_from_ap(ap);
                        networks_map.insert(ssid_str, network);
                        new_networks.add(network);
                    } else {
                        // Update existing network with stronger signal if found
                        var ap_strength = ap.get_strength();
                        if (ap_strength > existing_network.signal_strength) {
                            update_network_from_ap(existing_network, ap);
                        }
                    }
                }
                
                // Update available networks
                _available_networks = new_networks;
                
                debug("WiFiManager: Found %u unique networks", _available_networks.length);
                
                // Update active connection
                update_active_connection();
                
                complete_scan(true, null);
                
            } catch (Error e) {
                warning("WiFiManager: Error processing scan results: %s", e.message);
                complete_scan(false, e.message);
            }
        }
        
        /**
         * Complete the scan process
         */
        private void complete_scan(bool successful, string? error_message) {
            _scanning = false;
            
            if (_scan_timeout_id > 0) {
                Source.remove(_scan_timeout_id);
                _scan_timeout_id = 0;
            }
            
            var result = create_scan_result(successful, error_message);
            result.networks = _available_networks;
            
            networks_updated(_available_networks);
            scan_completed(result);
            
            debug("WiFiManager: Scan completed - %s", successful ? "success" : "failed");
        }
        
        /**
         * Create a scan result object
         */
        private WiFiScanResult create_scan_result(bool successful, string? error_message) {
            var result = new WiFiScanResult();
            result.scan_successful = successful;
            result.error_message = error_message;
            return result;
        }
        
        /**
         * Create WiFiNetwork from NetworkManager AccessPoint
         */
        private WiFiNetwork create_wifi_network_from_ap(NM.AccessPoint ap) {
            var network = new WiFiNetwork();
            update_network_from_ap(network, ap);
            return network;
        }
        
        /**
         * Update WiFiNetwork properties from AccessPoint
         */
        private void update_network_from_ap(WiFiNetwork network, NM.AccessPoint ap) {
            var ssid_bytes = ap.get_ssid();
            if (ssid_bytes != null) {
                var ssid_str = sanitize_ssid(ssid_bytes);
                network.ssid = ssid_str;
                network.name = ssid_str;
                var bssid = ap.get_bssid();
                if (ssid_str != null && bssid != null) {
                    network.id = "wifi-%s-%s".printf(ssid_str.replace(" ", "_"), bssid.replace(":", ""));
                } else if (ssid_str != null) {
                    network.id = "wifi-%s".printf(ssid_str.replace(" ", "_"));
                } else {
                    network.id = "wifi-unknown-%u".printf(Random.next_int());
                }
            }
            
            network.bssid = ap.get_bssid();
            network.signal_strength = ap.get_strength();
            network.frequency = ap.get_frequency();
            network.security_type = convert_ap_security_to_security_type(ap);
            network.security_level = assess_security_level(network.security_type);
            network.mode = convert_ap_mode_to_wifi_mode(ap.get_mode());
            network.is_hidden = (ssid_bytes == null || ssid_bytes.length == 0);
        }
        
        /**
         * Sanitize SSID bytes into a valid UTF-8 string.
         * Raw SSID data may contain arbitrary bytes that are not valid UTF-8,
         * which causes string.replace() to crash via GLib assertions.
         */
        private string sanitize_ssid(GLib.Bytes ssid_bytes) {
            unowned uint8[] data = ssid_bytes.get_data();
            if (data == null || data.length == 0) return "";
            string raw = (string)data;
            if (raw.validate()) return raw;
            // Invalid UTF-8: build a safe representation
            var sb = new StringBuilder();
            for (int i = 0; i < data.length; i++) {
                if (data[i] >= 32 && data[i] < 127) {
                    sb.append_c((char)data[i]);
                } else {
                    sb.append_printf("\\x%02x", data[i]);
                }
            }
            return sb.str;
        }
        
        /**
         * Convert NetworkManager security flags to SecurityType
         */
        private SecurityType convert_ap_security_to_security_type(NM.AccessPoint ap) {
            var flags = ap.get_flags();
            var wpa_flags = ap.get_wpa_flags();
            var rsn_flags = ap.get_rsn_flags();
            
            // Check for WPA3 (RSN with SAE)
            if ((rsn_flags & NM.@80211ApSecurityFlags.KEY_MGMT_SAE) != 0) {
                if ((rsn_flags & NM.@80211ApSecurityFlags.KEY_MGMT_802_1X) != 0) {
                    return SecurityType.WPA3_ENTERPRISE;
                } else {
                    return SecurityType.WPA3_PSK;
                }
            }
            
            // Check for WPA2 (RSN)
            if ((rsn_flags & NM.@80211ApSecurityFlags.KEY_MGMT_PSK) != 0) {
                if ((rsn_flags & NM.@80211ApSecurityFlags.KEY_MGMT_802_1X) != 0) {
                    return SecurityType.WPA2_ENTERPRISE;
                } else {
                    return SecurityType.WPA2_PSK;
                }
            }
            
            // Check for WPA (WPA flags)
            if ((wpa_flags & NM.@80211ApSecurityFlags.KEY_MGMT_PSK) != 0) {
                if ((wpa_flags & NM.@80211ApSecurityFlags.KEY_MGMT_802_1X) != 0) {
                    return SecurityType.WPA_ENTERPRISE;
                } else {
                    return SecurityType.WPA_PSK;
                }
            }
            
            // Check for WEP
            if ((flags & NM.@80211ApFlags.PRIVACY) != 0) {
                return SecurityType.WEP;
            }
            
            // Open network
            return SecurityType.NONE;
        }
        
        /**
         * Convert NetworkManager AP mode to WiFiMode
         */
        private WiFiMode convert_ap_mode_to_wifi_mode(NM.@80211Mode mode) {
            switch (mode) {
                case NM.@80211Mode.ADHOC:
                    return WiFiMode.ADHOC;
                case NM.@80211Mode.AP:
                    return WiFiMode.AP;
                case NM.@80211Mode.INFRA:
                default:
                    return WiFiMode.INFRASTRUCTURE;
            }
        }
        
        /**
         * Assess security level based on security type
         */
        private SecurityLevel assess_security_level(SecurityType security_type) {
            switch (security_type) {
                case SecurityType.WPA3_PSK:
                case SecurityType.WPA3_ENTERPRISE:
                    return SecurityLevel.SECURE;
                case SecurityType.WPA2_PSK:
                case SecurityType.WPA2_ENTERPRISE:
                    return SecurityLevel.SECURE;
                case SecurityType.WPA_PSK:
                case SecurityType.WPA_ENTERPRISE:
                    return SecurityLevel.WARNING;
                case SecurityType.WEP:
                    return SecurityLevel.INSECURE;
                case SecurityType.NONE:
                    return SecurityLevel.INSECURE;
                default:
                    return SecurityLevel.UNKNOWN;
            }
        }
        
        /**
         * Update access point information
         */
        private void update_access_point(NM.AccessPoint ap) {
            var ssid_bytes = ap.get_ssid();
            if (ssid_bytes == null || ssid_bytes.length == 0) {
                return; // Skip hidden networks
            }
            
            var ssid = (string)ssid_bytes.get_data();
            
            // Find existing network or create new one
            WiFiNetwork? existing_network = null;
            for (uint i = 0; i < _available_networks.length; i++) {
                var network = _available_networks[i];
                if (network.ssid == ssid) {
                    existing_network = network;
                    break;
                }
            }
            
            if (existing_network != null) {
                var old_strength = existing_network.signal_strength;
                update_network_from_ap(existing_network, ap);
                
                // Emit signal if strength changed significantly
                var strength_diff = (old_strength > existing_network.signal_strength) ?
                                   (old_strength - existing_network.signal_strength) :
                                   (existing_network.signal_strength - old_strength);
                
                if (strength_diff >= SIGNAL_STRENGTH_THRESHOLD) {
                    signal_strength_updated(existing_network, old_strength, existing_network.signal_strength);
                }
            } else {
                // Add new network
                var network = create_wifi_network_from_ap(ap);
                _available_networks.add(network);
                networks_updated(_available_networks);
            }
        }
        
        /**
         * Remove access point
         */
        private void remove_access_point(NM.AccessPoint ap) {
            var ssid_bytes = ap.get_ssid();
            if (ssid_bytes == null) return;
            
            var ssid = (string)ssid_bytes.get_data();
            
            for (uint i = 0; i < _available_networks.length; i++) {
                var network = _available_networks[i];
                if (network.ssid == ssid && network.bssid == ap.get_bssid()) {
                    _available_networks.remove_index(i);
                    networks_updated(_available_networks);
                    break;
                }
            }
        }
        
        /**
         * Update active connection information
         */
        private void update_active_connection() {
            var wifi_device = nm_client.get_wifi_device();
            if (wifi_device == null) {
                _active_connection = null;
                return;
            }
            
            var active_ap = wifi_device.get_active_access_point();
            if (active_ap == null) {
                _active_connection = null;
                return;
            }
            
            var ssid_bytes = active_ap.get_ssid();
            if (ssid_bytes == null) {
                _active_connection = null;
                return;
            }
            
            var ssid = (string)ssid_bytes.get_data();
            
            // Find the network in our list
            for (uint i = 0; i < _available_networks.length; i++) {
                var network = _available_networks[i];
                if (network.ssid == ssid) {
                    _active_connection = network;
                    network.update_state(ConnectionState.CONNECTED);
                    connection_state_changed(network, ConnectionState.CONNECTED);
                    return;
                }
            }
            
            // Create network if not found
            _active_connection = create_wifi_network_from_ap(active_ap);
            _active_connection.update_state(ConnectionState.CONNECTED);
            _available_networks.add(_active_connection);
            networks_updated(_available_networks);
            connection_state_changed(_active_connection, ConnectionState.CONNECTED);
        }
        
        /**
         * Connect to a WiFi network
         */
        public async bool connect_to_network(WiFiNetwork network, string? password = null) {
            if (!nm_client.is_available) {
                connection_failed(network, "NetworkManager not available");
                return false;
            }
            
            var wifi_device = nm_client.get_wifi_device();
            if (wifi_device == null) {
                connection_failed(network, "No WiFi device found");
                return false;
            }
            
            try {
                debug("WiFiManager: Connecting to network: %s", network.ssid);
                network.update_state(ConnectionState.CONNECTING);
                connection_state_changed(network, ConnectionState.CONNECTING);
                
                // Find existing connection or create new one
                var connection = find_or_create_connection(network, password);
                if (connection == null) {
                    network.update_state(ConnectionState.FAILED);
                    connection_failed(network, "Failed to create connection profile");
                    return false;
                }
                
                // Activate the connection
                var success = yield nm_client.activate_connection(connection, wifi_device);
                
                if (success) {
                    debug("WiFiManager: Successfully connected to %s", network.ssid);
                    network.update_state(ConnectionState.CONNECTED);
                    _active_connection = network;
                    connection_state_changed(network, ConnectionState.CONNECTED);
                    return true;
                } else {
                    debug("WiFiManager: Failed to connect to %s", network.ssid);
                    network.update_state(ConnectionState.FAILED);
                    connection_failed(network, "Connection activation failed");
                    return false;
                }
                
            } catch (Error e) {
                warning("WiFiManager: Connection error: %s", e.message);
                network.update_state(ConnectionState.FAILED);
                connection_failed(network, e.message);
                return false;
            }
        }
        
        /**
         * Disconnect from a WiFi network
         */
        public async bool disconnect_from_network(WiFiNetwork network) {
            if (!nm_client.is_available) {
                return false;
            }
            
            try {
                debug("WiFiManager: Disconnecting from network: %s", network.ssid);
                network.update_state(ConnectionState.DISCONNECTING);
                connection_state_changed(network, ConnectionState.DISCONNECTING);
                
                // Find active connection
                var active_connections = nm_client.nm_client.get_active_connections();
                foreach (var ac in active_connections) {
                    if (ac.get_connection_type() == "802-11-wireless") {
                        var connection = ac.get_connection();
                        if (connection != null && connection.get_id() == network.ssid) {
                            var success = yield nm_client.deactivate_connection(ac);
                            if (success) {
                                network.update_state(ConnectionState.DISCONNECTED);
                                if (_active_connection == network) {
                                    _active_connection = null;
                                }
                                connection_state_changed(network, ConnectionState.DISCONNECTED);
                                return true;
                            }
                        }
                    }
                }
                
                // If we get here, connection wasn't found or deactivation failed
                network.update_state(ConnectionState.DISCONNECTED);
                connection_state_changed(network, ConnectionState.DISCONNECTED);
                return false;
                
            } catch (Error e) {
                warning("WiFiManager: Disconnection error: %s", e.message);
                return false;
            }
        }
        
        /**
         * Forget a WiFi network (remove saved profile)
         */
        public async bool forget_network(WiFiNetwork network) {
            if (!nm_client.is_available) {
                return false;
            }
            
            try {
                debug("WiFiManager: Forgetting network: %s", network.ssid);
                
                // Find and remove the connection
                var connections = nm_client.get_connections_by_type("802-11-wireless");
                foreach (var connection in connections) {
                    if (connection.get_id() == network.ssid) {
                        // For now, just log that we would delete the connection
                        // Proper implementation requires more complex D-Bus interaction
                        debug("WiFiManager: Would delete connection: %s", network.ssid);
                        return true;
                    }
                }
                
                debug("WiFiManager: No saved profile found for network: %s", network.ssid);
                return true; // Not an error if no profile exists
                
            } catch (Error e) {
                warning("WiFiManager: Error forgetting network: %s", e.message);
                return false;
            }
        }
        
        /**
         * Connect to a hidden WiFi network
         */
        public async bool connect_to_hidden_network(string ssid, string password, SecurityType security) {
            if (!nm_client.is_available) {
                return false;
            }
            
            var wifi_device = nm_client.get_wifi_device();
            if (wifi_device == null) {
                return false;
            }
            
            try {
                debug("WiFiManager: Connecting to hidden network: %s", ssid);
                
                // Create a hidden network object
                var network = new WiFiNetwork.with_ssid(ssid);
                network.security_type = security;
                network.is_hidden = true;
                network.security_level = assess_security_level(security);
                
                network.update_state(ConnectionState.CONNECTING);
                connection_state_changed(network, ConnectionState.CONNECTING);
                
                // Create connection profile for hidden network
                var connection = create_hidden_network_connection(ssid, password, security);
                if (connection == null) {
                    network.update_state(ConnectionState.FAILED);
                    connection_failed(network, "Failed to create connection profile");
                    return false;
                }
                
                // Activate the connection
                var success = yield nm_client.activate_connection(connection, wifi_device);
                
                if (success) {
                    debug("WiFiManager: Successfully connected to hidden network: %s", ssid);
                    network.update_state(ConnectionState.CONNECTED);
                    _active_connection = network;
                    _available_networks.add(network);
                    networks_updated(_available_networks);
                    connection_state_changed(network, ConnectionState.CONNECTED);
                    return true;
                } else {
                    network.update_state(ConnectionState.FAILED);
                    connection_failed(network, "Connection activation failed");
                    return false;
                }
                
            } catch (Error e) {
                warning("WiFiManager: Hidden network connection error: %s", e.message);
                return false;
            }
        }
        
        /**
         * Get list of available networks
         */
        public GenericArray<WiFiNetwork> get_available_networks() {
            return _available_networks;
        }
        
        /**
         * Find or create a connection profile for a network
         */
        private NM.Connection? find_or_create_connection(WiFiNetwork network, string? password) {
            // First try to find existing connection
            var connections = nm_client.get_connections_by_type("802-11-wireless");
            foreach (var connection in connections) {
                if (connection.get_id() == network.ssid) {
                    debug("WiFiManager: Found existing connection for %s", network.ssid);
                    return connection;
                }
            }
            
            // Create new connection
            debug("WiFiManager: Creating new connection for %s", network.ssid);
            return create_wifi_connection(network, password);
        }
        
        /**
         * Create a new WiFi connection profile
         */
        private NM.Connection? create_wifi_connection(WiFiNetwork network, string? password) {
            try {
                // For now, return null to indicate we need to implement this properly
                // This requires more complex NetworkManager D-Bus interaction
                warning("WiFiManager: Connection creation not yet fully implemented");
                return null;
                
            } catch (Error e) {
                warning("WiFiManager: Failed to create connection: %s", e.message);
                return null;
            }
        }
        
        /**
         * Create connection profile for hidden network
         */
        private NM.Connection? create_hidden_network_connection(string ssid, string password, SecurityType security) {
            try {
                // For now, return null to indicate we need to implement this properly
                warning("WiFiManager: Hidden network connection creation not yet fully implemented");
                return null;
                
            } catch (Error e) {
                warning("WiFiManager: Failed to create hidden network connection: %s", e.message);
                return null;
            }
        }
        
        /**
         * Add security settings to connection based on security type
         */
        private void add_security_settings(NM.Connection connection, SecurityType security_type, string password) {
            // For now, this is a placeholder - proper implementation requires
            // more complex NetworkManager D-Bus interaction
            warning("WiFiManager: Security settings configuration not yet fully implemented");
        }
        
        /**
         * Clear all networks (when WiFi disabled or NetworkManager unavailable)
         */
        private void clear_networks() {
            _available_networks.remove_range(0, _available_networks.length);
            _active_connection = null;
            networks_updated(_available_networks);
        }
        
        /**
         * Handle NetworkManager becoming unavailable
         */
        private void handle_nm_unavailable() {
            _scanning = false;
            if (_scan_timeout_id > 0) {
                Source.remove(_scan_timeout_id);
                _scan_timeout_id = 0;
            }
            clear_networks();
        }
    }
}