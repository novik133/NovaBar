/**
 * Enhanced Network Indicator - VPN Profile Model
 * 
 * This file defines the VPNProfile class and related data structures
 * for managing VPN connections in the enhanced network indicator.
 */

using GLib;

namespace EnhancedNetwork {

    /**
     * VPN configuration data
     */
    public class VPNConfiguration : GLib.Object {
        public string server_address { get; set; }
        public uint16 port { get; set; }
        public string? username { get; set; }
        public string? password { get; set; }
        public string? certificate_path { get; set; }
        public string? private_key_path { get; set; }
        public string? ca_certificate_path { get; set; }
        public string? config_file_path { get; set; }
        public HashTable<string, string>? additional_options { get; set; }
        
        public VPNConfiguration() {
            additional_options = new HashTable<string, string>(str_hash, str_equal);
        }
        
        public VPNConfiguration.for_openvpn(string server, uint16 port = 1194) {
            this();
            this.server_address = server;
            this.port = port;
        }
        
        public VPNConfiguration.for_wireguard(string server, uint16 port = 51820) {
            this();
            this.server_address = server;
            this.port = port;
        }
    }

    /**
     * VPN connection statistics
     */
    public class VPNStats : GLib.Object {
        public uint64 bytes_sent { get; set; }
        public uint64 bytes_received { get; set; }
        public DateTime? connected_since { get; set; }
        public string? virtual_ip { get; set; }
        public string? server_location { get; set; }
        public uint32 latency_ms { get; set; }
        
        public VPNStats() {
            connected_since = new DateTime.now_local();
        }
    }

    /**
     * VPN Profile for managing VPN connections
     * 
     * Represents a configured VPN connection with all necessary
     * authentication and configuration details.
     */
    public class VPNProfile : NetworkConnection {
        public VPNType vpn_type { get; set; }
        public string server_address { get; set; }
        public string? username { get; set; }
        public DateTime created_date { get; set; }
        public new DateTime? last_connected { get; set; }
        
        private VPNConfiguration? _configuration;
        private VPNStats? _stats;
        
        /**
         * Signal emitted when VPN state changes
         */
        public signal void vpn_state_changed(ConnectionState old_state, ConnectionState new_state);
        
        /**
         * Signal emitted when VPN statistics are updated
         */
        public signal void stats_updated(VPNStats stats);
        
        /**
         * Signal emitted when connection error occurs
         */
        public signal void connection_error(string error_message);
        
        public VPNProfile() {
            base();
            connection_type = ConnectionType.VPN;
            created_date = new DateTime.now_local();
            state = ConnectionState.DISCONNECTED;
        }
        
        public VPNProfile.with_name_and_type(string name, VPNType vpn_type) {
            this();
            this.name = name;
            this.vpn_type = vpn_type;
            this.id = generate_id_from_name(name);
        }
        
        /**
         * Connect to this VPN
         */
        public async bool connect_to_vpn() throws Error {
            update_state(ConnectionState.CONNECTING);
            
            // TODO: Implement actual NetworkManager D-Bus VPN connection logic
            // This is a placeholder implementation for the data model setup
            
            // Validate configuration
            if (_configuration == null) {
                connection_error("VPN configuration not set");
                update_state(ConnectionState.FAILED);
                return false;
            }
            
            // Simulate connection delay
            yield wait_async(2000);
            
            // For now, simulate successful connection
            update_state(ConnectionState.CONNECTED);
            last_connected = new DateTime.now_local();
            
            // Initialize stats
            _stats = new VPNStats();
            _stats.virtual_ip = "10.8.0.2"; // Placeholder
            _stats.server_location = "Unknown"; // Placeholder
            stats_updated(_stats);
            
            return true;
        }
        
        /**
         * Disconnect from this VPN
         */
        public async bool disconnect_from_vpn() throws Error {
            update_state(ConnectionState.DISCONNECTING);
            
            // TODO: Implement actual NetworkManager D-Bus VPN disconnection logic
            
            // Simulate disconnection delay
            yield wait_async(1000);
            
            update_state(ConnectionState.DISCONNECTED);
            _stats = null;
            
            return true;
        }
        
        /**
         * Get VPN configuration
         */
        public VPNConfiguration? get_configuration() {
            return _configuration;
        }
        
        /**
         * Set VPN configuration
         */
        public void set_configuration(VPNConfiguration config) {
            _configuration = config;
            server_address = config.server_address;
            username = config.username;
        }
        
        /**
         * Get current VPN statistics
         */
        public VPNStats? get_stats() {
            return _stats;
        }
        
        /**
         * Import VPN configuration from file
         */
        public async bool import_from_file(string file_path) throws Error {
            var file = File.new_for_path(file_path);
            if (!file.query_exists()) {
                throw new IOError.NOT_FOUND("Configuration file not found: %s", file_path);
            }
            
            // Read file content
            string content;
            try {
                FileUtils.get_contents(file_path, out content);
            } catch (FileError e) {
                throw new IOError.FAILED("Failed to read configuration file: %s", e.message);
            }
            
            var config = new VPNConfiguration();
            config.config_file_path = file_path;
            
            // Determine VPN type from file extension and parse accordingly
            if (file_path.has_suffix(".ovpn")) {
                vpn_type = VPNType.OPENVPN;
                if (!parse_openvpn_config(content, config)) {
                    throw new IOError.INVALID_DATA("Failed to parse OpenVPN configuration");
                }
            } else if (file_path.has_suffix(".conf")) {
                vpn_type = VPNType.WIREGUARD;
                if (!parse_wireguard_config(content, config)) {
                    throw new IOError.INVALID_DATA("Failed to parse WireGuard configuration");
                }
            } else {
                throw new IOError.NOT_SUPPORTED("Unsupported configuration file format");
            }
            
            set_configuration(config);
            return true;
        }
        
        /**
         * Parse OpenVPN configuration content
         */
        private bool parse_openvpn_config(string content, VPNConfiguration config) {
            var lines = content.split("\n");
            
            foreach (var line in lines) {
                var trimmed = line.strip();
                if (trimmed.length == 0 || trimmed.has_prefix("#") || trimmed.has_prefix(";")) {
                    continue; // Skip empty lines and comments
                }
                
                var parts = trimmed.split(" ");
                if (parts.length < 1) {
                    continue;
                }
                
                var directive = parts[0].down();
                
                switch (directive) {
                    case "remote":
                        if (parts.length >= 2) {
                            config.server_address = parts[1];
                            if (parts.length >= 3) {
                                config.port = (uint16)int.parse(parts[2]);
                            } else {
                                config.port = 1194; // Default OpenVPN port
                            }
                        }
                        break;
                    
                    case "port":
                        if (parts.length >= 2) {
                            config.port = (uint16)int.parse(parts[1]);
                        }
                        break;
                    
                    case "ca":
                        if (parts.length >= 2) {
                            config.ca_certificate_path = parts[1];
                        }
                        break;
                    
                    case "cert":
                        if (parts.length >= 2) {
                            config.certificate_path = parts[1];
                        }
                        break;
                    
                    case "key":
                        if (parts.length >= 2) {
                            config.private_key_path = parts[1];
                        }
                        break;
                    
                    case "auth-user-pass":
                        // This indicates username/password authentication
                        // The actual credentials would be prompted or stored separately
                        break;
                    
                    default:
                        // Store other directives as additional options
                        if (config.additional_options != null) {
                            config.additional_options.set(directive, trimmed.substring(directive.length).strip());
                        }
                        break;
                }
            }
            
            // Validate that we have at least a server address
            return config.server_address != null && config.server_address.length > 0;
        }
        
        /**
         * Parse WireGuard configuration content
         */
        private bool parse_wireguard_config(string content, VPNConfiguration config) {
            var lines = content.split("\n");
            string? current_section = null;
            
            foreach (var line in lines) {
                var trimmed = line.strip();
                if (trimmed.length == 0 || trimmed.has_prefix("#")) {
                    continue; // Skip empty lines and comments
                }
                
                // Check for section headers
                if (trimmed.has_prefix("[") && trimmed.has_suffix("]")) {
                    current_section = trimmed.substring(1, trimmed.length - 2).down();
                    continue;
                }
                
                // Parse key-value pairs
                var parts = trimmed.split("=", 2);
                if (parts.length != 2) {
                    continue;
                }
                
                var key = parts[0].strip().down();
                var value = parts[1].strip();
                
                if (current_section == "interface") {
                    switch (key) {
                        case "privatekey":
                            // Store private key info (would be handled securely in real implementation)
                            config.additional_options.set("private_key", value);
                            break;
                    }
                } else if (current_section == "peer") {
                    switch (key) {
                        case "endpoint":
                            // Parse server:port format
                            var endpoint_parts = value.split(":");
                            if (endpoint_parts.length >= 2) {
                                config.server_address = endpoint_parts[0];
                                config.port = (uint16)int.parse(endpoint_parts[1]);
                            } else {
                                config.server_address = value;
                                config.port = 51820; // Default WireGuard port
                            }
                            break;
                        
                        case "publickey":
                            config.additional_options.set("public_key", value);
                            break;
                    }
                }
                
                // Store all options for completeness
                if (config.additional_options != null) {
                    config.additional_options.set(key, value);
                }
            }
            
            // Validate that we have at least a server address
            return config.server_address != null && config.server_address.length > 0;
        }
        
        /**
         * Export VPN configuration to file
         */
        public async bool export_to_file(string file_path) throws Error {
            if (_configuration == null) {
                throw new IOError.INVALID_DATA("No configuration to export");
            }
            
            // TODO: Implement configuration file generation
            // This would generate appropriate config files based on VPN type
            
            return true;
        }
        
        /**
         * Get human-readable VPN type description
         */
        public string get_type_description() {
            switch (vpn_type) {
                case VPNType.OPENVPN:
                    return "OpenVPN";
                case VPNType.WIREGUARD:
                    return "WireGuard";
                case VPNType.PPTP:
                    return "PPTP";
                case VPNType.L2TP:
                    return "L2TP";
                case VPNType.SSTP:
                    return "SSTP";
                default:
                    return "Unknown";
            }
        }
        
        /**
         * Get human-readable state description
         */
        public new string get_state_description() {
            switch (state) {
                case ConnectionState.DISCONNECTED:
                    return "Disconnected";
                case ConnectionState.CONNECTING:
                    return "Connecting...";
                case ConnectionState.CONNECTED:
                    return "Connected";
                case ConnectionState.DISCONNECTING:
                    return "Disconnecting...";
                case ConnectionState.FAILED:
                    return "Connection Failed";
                default:
                    return "Unknown";
            }
        }
        
        /**
         * Check if VPN is currently connected
         */
        public bool is_connected() {
            return state == ConnectionState.CONNECTED;
        }
        
        /**
         * Check if VPN configuration is complete
         */
        public bool is_configuration_complete() {
            if (_configuration == null) {
                return false;
            }
            
            // Basic validation - server address is required
            if (_configuration.server_address == null || _configuration.server_address.length == 0) {
                return false;
            }
            
            // Type-specific validation
            switch (vpn_type) {
                case VPNType.OPENVPN:
                    // OpenVPN needs either config file or certificates
                    return _configuration.config_file_path != null || 
                           _configuration.ca_certificate_path != null;
                
                case VPNType.WIREGUARD:
                    // WireGuard needs config file or private key
                    return _configuration.config_file_path != null ||
                           _configuration.private_key_path != null;
                
                default:
                    return true;
            }
        }
        
        /**
         * Update VPN state and emit signal
         */
        private new void update_state(ConnectionState new_state) {
            var old_state = state;
            state = new_state;
            state_changed(old_state, new_state);
            vpn_state_changed(old_state, new_state);
        }
        
        /**
         * Generate unique ID from name
         */
        private string generate_id_from_name(string name) {
            if (name != null) {
                return "vpn-%s-%u".printf(name.replace(" ", "_"), name.hash());
            }
            return "vpn-unknown-%u".printf(Random.next_int());
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
         * Implement abstract method from NetworkConnection
         */
        public override async bool connect_to_network(Credentials? credentials = null) throws Error {
            return yield connect_to_vpn();
        }
        
        /**
         * Implement abstract method from NetworkConnection
         */
        public override async bool disconnect_from_network() throws Error {
            return yield disconnect_from_vpn();
        }
    }
}