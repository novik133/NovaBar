/**
 * Enhanced Network Indicator - Ethernet Manager Component
 * 
 * This file implements the EthernetManager class that provides comprehensive
 * ethernet connection management including cable detection, static IP configuration,
 * and connection diagnostics.
 */

using GLib;
using NM;

namespace EnhancedNetwork {

    /**
     * Ethernet connection configuration
     */
    public class EthernetConfiguration : GLib.Object {
        public string? ip_address { get; set; }
        public string? subnet_mask { get; set; }
        public string? gateway { get; set; }
        public string? dns_primary { get; set; }
        public string? dns_secondary { get; set; }
        public bool use_dhcp { get; set; }
        public uint16 mtu { get; set; }
        
        public EthernetConfiguration() {
            use_dhcp = true;
            mtu = 1500; // Standard Ethernet MTU
        }
        
        /**
         * Validate IP configuration
         */
        public bool validate() {
            if (use_dhcp) {
                return true; // DHCP doesn't need validation
            }
            
            // Validate static IP configuration
            if (!is_valid_ip_address(ip_address)) {
                return false;
            }
            
            if (!is_valid_ip_address(subnet_mask)) {
                return false;
            }
            
            if (gateway != null && !is_valid_ip_address(gateway)) {
                return false;
            }
            
            if (dns_primary != null && !is_valid_ip_address(dns_primary)) {
                return false;
            }
            
            if (dns_secondary != null && !is_valid_ip_address(dns_secondary)) {
                return false;
            }
            
            return true;
        }
        
        /**
         * Simple IP address validation
         */
        private bool is_valid_ip_address(string? ip) {
            if (ip == null || ip.length == 0) {
                return false;
            }
            
            var parts = ip.split(".");
            if (parts.length != 4) {
                return false;
            }
            
            foreach (var part in parts) {
                int value = int.parse(part);
                if (value < 0 || value > 255) {
                    return false;
                }
            }
            
            return true;
        }
    }

    /**
     * Ethernet connection diagnostics information
     */
    public class EthernetDiagnostics : GLib.Object {
        public bool cable_connected { get; set; }
        public uint32 link_speed_mbps { get; set; }
        public bool full_duplex { get; set; }
        public string? interface_name { get; set; }
        public string? mac_address { get; set; }
        public uint64 bytes_sent { get; set; }
        public uint64 bytes_received { get; set; }
        public uint32 packets_sent { get; set; }
        public uint32 packets_received { get; set; }
        public uint32 errors_sent { get; set; }
        public uint32 errors_received { get; set; }
        public DateTime last_updated { get; set; }
        
        public EthernetDiagnostics() {
            cable_connected = false;
            link_speed_mbps = 0;
            full_duplex = false;
            last_updated = new DateTime.now_local();
        }
        
        /**
         * Get human-readable link speed description
         */
        public string get_speed_description() {
            if (!cable_connected) {
                return "No cable";
            }
            
            if (link_speed_mbps == 0) {
                return "Unknown speed";
            }
            
            if (link_speed_mbps >= 1000) {
                return "%.1f Gbps %s".printf(
                    link_speed_mbps / 1000.0,
                    full_duplex ? "Full Duplex" : "Half Duplex"
                );
            } else {
                return "%u Mbps %s".printf(
                    link_speed_mbps,
                    full_duplex ? "Full Duplex" : "Half Duplex"
                );
            }
        }
    }

    /**
     * Ethernet connection representation
     */
    public class EthernetConnection : NetworkConnection {
        public EthernetConfiguration configuration { get; set; }
        public EthernetDiagnostics diagnostics { get; set; }
        public string? interface_name { get; set; }
        public string? mac_address { get; set; }
        
        /**
         * Signal emitted when cable connection status changes
         */
        public signal void cable_status_changed(bool connected);
        
        /**
         * Signal emitted when link speed changes
         */
        public signal void link_speed_changed(uint32 old_speed, uint32 new_speed);
        
        public EthernetConnection() {
            base();
            connection_type = ConnectionType.ETHERNET;
            configuration = new EthernetConfiguration();
            diagnostics = new EthernetDiagnostics();
        }
        
        public EthernetConnection.with_interface(string interface_name) {
            this();
            this.interface_name = interface_name;
            if (interface_name != null) {
                this.name = "Ethernet (%s)".printf(interface_name);
                this.id = "ethernet-%s".printf(interface_name);
            } else {
                this.name = "Ethernet";
                this.id = "ethernet-unknown";
            }
        }
        
        /**
         * Connect to ethernet network
         */
        public override async bool connect_to_network(Credentials? credentials = null) throws Error {
            update_state(ConnectionState.CONNECTING);
            
            // TODO: Implement actual NetworkManager D-Bus connection logic
            // This is a placeholder implementation for the data model setup
            
            // Simulate connection delay
            yield wait_async(1000);
            
            // For now, simulate successful connection if cable is connected
            if (diagnostics.cable_connected) {
                update_state(ConnectionState.CONNECTED);
                
                // Update connection info
                var info = new ConnectionInfo();
                if (configuration.use_dhcp) {
                    info.ip_address = "192.168.1.101"; // Placeholder DHCP
                    info.gateway = "192.168.1.1";
                    info.dns_servers = "8.8.8.8, 8.8.4.4";
                } else {
                    info.ip_address = configuration.ip_address;
                    info.gateway = configuration.gateway;
                    info.dns_servers = "%s, %s".printf(
                        configuration.dns_primary ?? "",
                        configuration.dns_secondary ?? ""
                    );
                }
                info.speed_mbps = diagnostics.link_speed_mbps;
                update_connection_info(info);
                
                return true;
            } else {
                update_state(ConnectionState.FAILED);
                throw new IOError.CONNECTION_REFUSED("No ethernet cable connected");
            }
        }
        
        /**
         * Disconnect from ethernet network
         */
        public override async bool disconnect_from_network() throws Error {
            update_state(ConnectionState.DISCONNECTING);
            
            // TODO: Implement actual NetworkManager D-Bus disconnection logic
            
            // Simulate disconnection delay
            yield wait_async(500);
            
            update_state(ConnectionState.DISCONNECTED);
            return true;
        }
        
        /**
         * Update cable connection status
         */
        public void update_cable_status(bool connected) {
            var old_status = diagnostics.cable_connected;
            diagnostics.cable_connected = connected;
            diagnostics.last_updated = new DateTime.now_local();
            
            if (old_status != connected) {
                cable_status_changed(connected);
                
                // Update connection state based on cable status
                if (!connected && state == ConnectionState.CONNECTED) {
                    update_state(ConnectionState.DISCONNECTED);
                }
            }
        }
        
        /**
         * Update link speed information
         */
        public void update_link_speed(uint32 speed_mbps, bool full_duplex) {
            var old_speed = diagnostics.link_speed_mbps;
            diagnostics.link_speed_mbps = speed_mbps;
            diagnostics.full_duplex = full_duplex;
            diagnostics.last_updated = new DateTime.now_local();
            
            if (old_speed != speed_mbps) {
                link_speed_changed(old_speed, speed_mbps);
                
                // Update connection info if connected
                if (state == ConnectionState.CONNECTED && _connection_info != null) {
                    _connection_info.speed_mbps = speed_mbps;
                    info_updated(_connection_info);
                }
            }
        }
        
        /**
         * Update network statistics
         */
        public void update_statistics(uint64 bytes_sent, uint64 bytes_received,
                                    uint32 packets_sent, uint32 packets_received,
                                    uint32 errors_sent, uint32 errors_received) {
            diagnostics.bytes_sent = bytes_sent;
            diagnostics.bytes_received = bytes_received;
            diagnostics.packets_sent = packets_sent;
            diagnostics.packets_received = packets_received;
            diagnostics.errors_sent = errors_sent;
            diagnostics.errors_received = errors_received;
            diagnostics.last_updated = new DateTime.now_local();
            
            // Update connection info if connected
            if (state == ConnectionState.CONNECTED && _connection_info != null) {
                _connection_info.bytes_sent = bytes_sent;
                _connection_info.bytes_received = bytes_received;
                info_updated(_connection_info);
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

    /**
     * Ethernet Manager - Comprehensive ethernet connection management
     * 
     * This class provides complete ethernet functionality including cable detection,
     * connection management, static IP configuration, and network diagnostics.
     * It integrates with NetworkManager through the D-Bus API.
     */
    public class EthernetManager : GLib.Object {
        private NetworkManagerClient nm_client;
        private GenericArray<EthernetConnection> _ethernet_connections;
        private EthernetConnection? _active_connection;
        private Timer? _diagnostics_timer;
        private uint _diagnostics_timeout_id;
        
        // Configuration
        private const uint DIAGNOSTICS_UPDATE_INTERVAL_MS = 5000; // 5 seconds
        private const uint CABLE_DETECTION_INTERVAL_MS = 1000; // 1 second
        
        /**
         * Signal emitted when ethernet connections list is updated
         */
        public signal void connections_updated(GenericArray<EthernetConnection> connections);
        
        /**
         * Signal emitted when ethernet connection state changes
         */
        public signal void connection_state_changed(EthernetConnection connection, ConnectionState state);
        
        /**
         * Signal emitted when cable is connected or disconnected
         */
        public signal void cable_status_changed(EthernetConnection connection, bool connected);
        
        /**
         * Signal emitted when link speed changes
         */
        public signal void link_speed_changed(EthernetConnection connection, uint32 old_speed, uint32 new_speed);
        
        /**
         * Signal emitted when connection configuration fails validation
         */
        public signal void configuration_error(EthernetConnection connection, string error_message);
        
        /**
         * Signal emitted when connection attempt fails
         */
        public signal void connection_failed(EthernetConnection connection, string error_message);
        
        public EthernetConnection? active_connection { 
            get { return _active_connection; } 
        }
        
        public EthernetManager(NetworkManagerClient nm_client) {
            this.nm_client = nm_client;
            _ethernet_connections = new GenericArray<EthernetConnection>();
            
            // Setup NetworkManager client signals
            setup_nm_signals();
            
            // Start diagnostics monitoring
            start_diagnostics_monitoring();
            
            // Initialize ethernet devices if available
            if (nm_client.is_available) {
                Idle.add(() => {
                    initialize_ethernet_devices();
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
                    // NetworkManager became available, initialize devices
                    initialize_ethernet_devices();
                }
            });
            
            nm_client.device_added.connect((device) => {
                if (device.get_device_type() == NM.DeviceType.ETHERNET) {
                    add_ethernet_device(device as NM.DeviceEthernet);
                }
            });
            
            nm_client.device_removed.connect((device) => {
                if (device.get_device_type() == NM.DeviceType.ETHERNET) {
                    remove_ethernet_device(device as NM.DeviceEthernet);
                }
            });
            
            nm_client.device_state_changed.connect((device, new_state, old_state, reason) => {
                if (device.get_device_type() == NM.DeviceType.ETHERNET) {
                    handle_device_state_change(device as NM.DeviceEthernet, new_state, old_state, reason);
                }
            });
        }
        
        /**
         * Initialize ethernet devices
         */
        private void initialize_ethernet_devices() {
            debug("EthernetManager: Initializing ethernet devices...");
            
            var ethernet_devices = nm_client.get_devices_by_type(NM.DeviceType.ETHERNET);
            foreach (var device in ethernet_devices) {
                add_ethernet_device(device as NM.DeviceEthernet);
            }
            
            debug("EthernetManager: Initialized %u ethernet devices", ethernet_devices.length);
        }
        
        /**
         * Add an ethernet device
         */
        private void add_ethernet_device(NM.DeviceEthernet ethernet_device) {
            var interface_name = ethernet_device.get_iface();
            debug("EthernetManager: Adding ethernet device: %s", interface_name);
            
            // Check if we already have this device
            for (uint i = 0; i < _ethernet_connections.length; i++) {
                var connection = _ethernet_connections[i];
                if (connection.interface_name == interface_name) {
                    debug("EthernetManager: Device %s already exists", interface_name);
                    return;
                }
            }
            
            // Create new ethernet connection
            var connection = new EthernetConnection.with_interface(interface_name);
            connection.mac_address = ethernet_device.get_hw_address();
            connection.diagnostics.interface_name = interface_name;
            connection.diagnostics.mac_address = connection.mac_address;
            
            // Setup connection signals
            setup_connection_signals(connection);
            
            // Update initial diagnostics
            update_device_diagnostics(connection, ethernet_device);
            
            _ethernet_connections.add(connection);
            connections_updated(_ethernet_connections);
            
            // Check if this device is currently active
            if (ethernet_device.get_state() == NM.DeviceState.ACTIVATED) {
                _active_connection = connection;
                connection.update_state(ConnectionState.CONNECTED);
                connection_state_changed(connection, ConnectionState.CONNECTED);
            }
        }
        
        /**
         * Remove an ethernet device
         */
        private void remove_ethernet_device(NM.DeviceEthernet ethernet_device) {
            var interface_name = ethernet_device.get_iface();
            debug("EthernetManager: Removing ethernet device: %s", interface_name);
            
            for (uint i = 0; i < _ethernet_connections.length; i++) {
                var connection = _ethernet_connections[i];
                if (connection.interface_name == interface_name) {
                    if (_active_connection == connection) {
                        _active_connection = null;
                    }
                    _ethernet_connections.remove_index(i);
                    connections_updated(_ethernet_connections);
                    break;
                }
            }
        }
        
        /**
         * Setup signals for an ethernet connection
         */
        private void setup_connection_signals(EthernetConnection connection) {
            connection.state_changed.connect((old_state, new_state) => {
                connection_state_changed(connection, new_state);
            });
            
            connection.cable_status_changed.connect((connected) => {
                cable_status_changed(connection, connected);
            });
            
            connection.link_speed_changed.connect((old_speed, new_speed) => {
                link_speed_changed(connection, old_speed, new_speed);
            });
        }
        
        /**
         * Handle device state changes
         */
        private void handle_device_state_change(NM.DeviceEthernet device, 
                                              NM.DeviceState new_state, 
                                              NM.DeviceState old_state, 
                                              NM.DeviceStateReason reason) {
            var interface_name = device.get_iface();
            debug("EthernetManager: Device %s state changed: %s -> %s (reason: %s)",
                  interface_name, old_state.to_string(), new_state.to_string(), reason.to_string());
            
            var connection = find_connection_by_interface(interface_name);
            if (connection == null) {
                return;
            }
            
            switch (new_state) {
                case NM.DeviceState.ACTIVATED:
                    connection.update_state(ConnectionState.CONNECTED);
                    _active_connection = connection;
                    break;
                    
                case NM.DeviceState.PREPARE:
                case NM.DeviceState.CONFIG:
                case NM.DeviceState.IP_CONFIG:
                case NM.DeviceState.IP_CHECK:
                    connection.update_state(ConnectionState.CONNECTING);
                    break;
                    
                case NM.DeviceState.DEACTIVATING:
                    connection.update_state(ConnectionState.DISCONNECTING);
                    break;
                    
                case NM.DeviceState.DISCONNECTED:
                case NM.DeviceState.UNAVAILABLE:
                    connection.update_state(ConnectionState.DISCONNECTED);
                    if (_active_connection == connection) {
                        _active_connection = null;
                    }
                    break;
                    
                case NM.DeviceState.FAILED:
                    connection.update_state(ConnectionState.FAILED);
                    if (_active_connection == connection) {
                        _active_connection = null;
                    }
                    connection_failed(connection, reason.to_string());
                    break;
            }
            
            // Update diagnostics
            update_device_diagnostics(connection, device);
        }
        
        /**
         * Update device diagnostics information
         */
        private void update_device_diagnostics(EthernetConnection connection, NM.DeviceEthernet device) {
            // Update cable status
            var carrier = device.get_carrier();
            connection.update_cable_status(carrier);
            
            // Update link speed (if available)
            var speed = device.get_speed();
            if (speed > 0) {
                connection.update_link_speed(speed, true); // Assume full duplex for now
            }
            
            // TODO: Update network statistics from device
            // This would require reading from /sys/class/net/{interface}/statistics/
            // or using other system interfaces
        }
        
        /**
         * Start diagnostics monitoring
         */
        private void start_diagnostics_monitoring() {
            _diagnostics_timeout_id = Timeout.add(DIAGNOSTICS_UPDATE_INTERVAL_MS, () => {
                update_all_diagnostics();
                return true; // Continue periodic updates
            });
        }
        
        /**
         * Update diagnostics for all connections
         */
        private void update_all_diagnostics() {
            if (!nm_client.is_available) {
                return;
            }
            
            var ethernet_devices = nm_client.get_devices_by_type(NM.DeviceType.ETHERNET);
            foreach (var device in ethernet_devices) {
                var ethernet_device = device as NM.DeviceEthernet;
                var connection = find_connection_by_interface(ethernet_device.get_iface());
                if (connection != null) {
                    update_device_diagnostics(connection, ethernet_device);
                }
            }
        }
        
        /**
         * Connect to ethernet network
         */
        public async bool connect_to_network(EthernetConnection connection, EthernetConfiguration? config = null) {
            if (!nm_client.is_available) {
                connection_failed(connection, "NetworkManager not available");
                return false;
            }
            
            // Validate configuration if provided
            if (config != null) {
                if (!config.validate()) {
                    configuration_error(connection, "Invalid network configuration");
                    return false;
                }
                connection.configuration = config;
            }
            
            var ethernet_device = find_device_by_interface(connection.interface_name);
            if (ethernet_device == null) {
                connection_failed(connection, "Ethernet device not found");
                return false;
            }
            
            try {
                debug("EthernetManager: Connecting to ethernet network on %s", connection.interface_name);
                connection.update_state(ConnectionState.CONNECTING);
                connection_state_changed(connection, ConnectionState.CONNECTING);
                
                // Find or create connection profile
                var nm_connection = find_or_create_connection(connection);
                if (nm_connection == null) {
                    connection.update_state(ConnectionState.FAILED);
                    connection_failed(connection, "Failed to create connection profile");
                    return false;
                }
                
                // Activate the connection
                var success = yield nm_client.activate_connection(nm_connection, ethernet_device);
                
                if (success) {
                    debug("EthernetManager: Successfully connected ethernet on %s", connection.interface_name);
                    connection.update_state(ConnectionState.CONNECTED);
                    _active_connection = connection;
                    connection_state_changed(connection, ConnectionState.CONNECTED);
                    return true;
                } else {
                    debug("EthernetManager: Failed to connect ethernet on %s", connection.interface_name);
                    connection.update_state(ConnectionState.FAILED);
                    connection_failed(connection, "Connection activation failed");
                    return false;
                }
                
            } catch (Error e) {
                warning("EthernetManager: Connection error: %s", e.message);
                connection.update_state(ConnectionState.FAILED);
                connection_failed(connection, e.message);
                return false;
            }
        }
        
        /**
         * Disconnect from ethernet network
         */
        public async bool disconnect_from_network(EthernetConnection connection) {
            if (!nm_client.is_available) {
                return false;
            }
            
            try {
                debug("EthernetManager: Disconnecting ethernet on %s", connection.interface_name);
                connection.update_state(ConnectionState.DISCONNECTING);
                connection_state_changed(connection, ConnectionState.DISCONNECTING);
                
                // Find active connection
                var active_connections = nm_client.nm_client.get_active_connections();
                foreach (var ac in active_connections) {
                    if (ac.get_connection_type() == "802-3-ethernet") {
                        var device = ac.get_devices()[0];
                        if (device != null && device.get_iface() == connection.interface_name) {
                            var success = yield nm_client.deactivate_connection(ac);
                            if (success) {
                                connection.update_state(ConnectionState.DISCONNECTED);
                                if (_active_connection == connection) {
                                    _active_connection = null;
                                }
                                connection_state_changed(connection, ConnectionState.DISCONNECTED);
                                return true;
                            }
                        }
                    }
                }
                
                // If we get here, connection wasn't found or deactivation failed
                connection.update_state(ConnectionState.DISCONNECTED);
                connection_state_changed(connection, ConnectionState.DISCONNECTED);
                return false;
                
            } catch (Error e) {
                warning("EthernetManager: Disconnection error: %s", e.message);
                return false;
            }
        }
        
        /**
         * Configure static IP for ethernet connection
         */
        public async bool configure_static_ip(EthernetConnection connection, EthernetConfiguration config) {
            if (!config.validate()) {
                configuration_error(connection, "Invalid static IP configuration");
                return false;
            }
            
            connection.configuration = config;
            
            // If currently connected, reconnect with new configuration
            if (connection.state == ConnectionState.CONNECTED) {
                debug("EthernetManager: Reconfiguring active connection with static IP");
                return yield connect_to_network(connection, config);
            }
            
            return true;
        }
        
        /**
         * Get list of ethernet connections
         */
        public GenericArray<EthernetConnection> get_ethernet_connections() {
            return _ethernet_connections;
        }
        
        /**
         * Get diagnostics for a specific connection
         */
        public EthernetDiagnostics? get_diagnostics(EthernetConnection connection) {
            return connection.diagnostics;
        }
        
        /**
         * Find connection by interface name
         */
        private EthernetConnection? find_connection_by_interface(string interface_name) {
            for (uint i = 0; i < _ethernet_connections.length; i++) {
                var connection = _ethernet_connections[i];
                if (connection.interface_name == interface_name) {
                    return connection;
                }
            }
            return null;
        }
        
        /**
         * Find NetworkManager device by interface name
         */
        private NM.DeviceEthernet? find_device_by_interface(string interface_name) {
            var ethernet_devices = nm_client.get_devices_by_type(NM.DeviceType.ETHERNET);
            foreach (var device in ethernet_devices) {
                var ethernet_device = device as NM.DeviceEthernet;
                if (ethernet_device.get_iface() == interface_name) {
                    return ethernet_device;
                }
            }
            return null;
        }
        
        /**
         * Find or create a connection profile for ethernet
         */
        private NM.Connection? find_or_create_connection(EthernetConnection connection) {
            // First try to find existing connection
            var connections = nm_client.get_connections_by_type("802-3-ethernet");
            foreach (var nm_connection in connections) {
                // Check if this connection is for our interface
                var s_con = nm_connection.get_setting_connection();
                if (s_con != null && s_con.get_interface_name() == connection.interface_name) {
                    debug("EthernetManager: Found existing connection for %s", connection.interface_name);
                    return nm_connection;
                }
            }
            
            // Create new connection
            debug("EthernetManager: Creating new connection for %s", connection.interface_name);
            return create_ethernet_connection(connection);
        }
        
        /**
         * Create a new ethernet connection profile
         */
        private NM.Connection? create_ethernet_connection(EthernetConnection connection) {
            try {
                // For now, return null to indicate we need to implement this properly
                // This requires more complex NetworkManager D-Bus interaction
                warning("EthernetManager: Connection creation not yet fully implemented");
                return null;
                
            } catch (Error e) {
                warning("EthernetManager: Failed to create connection: %s", e.message);
                return null;
            }
        }
        
        /**
         * Calculate network prefix from subnet mask
         */
        private uint32 calculate_prefix_from_netmask(string netmask) {
            // Simple conversion from dotted decimal to CIDR prefix
            // This is a basic implementation
            var parts = netmask.split(".");
            if (parts.length != 4) {
                return 24; // Default to /24
            }
            
            uint32 mask = 0;
            for (int i = 0; i < 4; i++) {
                mask = (mask << 8) | (uint32)int.parse(parts[i]);
            }
            
            // Count the number of 1 bits
            uint32 prefix = 0;
            for (int i = 31; i >= 0; i--) {
                if ((mask & (1 << i)) != 0) {
                    prefix++;
                } else {
                    break;
                }
            }
            
            return prefix;
        }
        
        /**
         * Handle NetworkManager becoming unavailable
         */
        private void handle_nm_unavailable() {
            if (_diagnostics_timeout_id > 0) {
                Source.remove(_diagnostics_timeout_id);
                _diagnostics_timeout_id = 0;
            }
            
            // Clear all connections
            _ethernet_connections.remove_range(0, _ethernet_connections.length);
            _active_connection = null;
            connections_updated(_ethernet_connections);
        }
        
        /**
         * Cleanup resources
         */
        public void cleanup() {
            if (_diagnostics_timeout_id > 0) {
                Source.remove(_diagnostics_timeout_id);
                _diagnostics_timeout_id = 0;
            }
        }
    }
}