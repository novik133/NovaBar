/**
 * Enhanced Network Indicator - NetworkManager D-Bus Client Wrapper
 * 
 * This file provides a comprehensive wrapper around NetworkManager's D-Bus API,
 * handling client initialization, connection management, and signal processing
 * for the enhanced network indicator system.
 */

using GLib;
using NM;

namespace EnhancedNetwork {

    /**
     * Network state information
     */
    public class NetworkState : GLib.Object {
        public NM.ConnectivityState connectivity { get; set; }
        public bool networking_enabled { get; set; }
        public bool wireless_enabled { get; set; }
        public bool wireless_hardware_enabled { get; set; }
        public bool wwan_enabled { get; set; }
        public bool wwan_hardware_enabled { get; set; }
        public string? primary_connection_id { get; set; }
        public string? primary_connection_type { get; set; }
        
        public NetworkState() {
            connectivity = NM.ConnectivityState.UNKNOWN;
            networking_enabled = false;
            wireless_enabled = false;
            wireless_hardware_enabled = false;
            wwan_enabled = false;
            wwan_hardware_enabled = false;
        }
    }

    /**
     * NetworkManager client wrapper providing enhanced functionality
     * 
     * This class wraps the NetworkManager D-Bus client and provides
     * a higher-level interface for network management operations.
     */
    public class NetworkManagerClient : GLib.Object {
        private NM.Client? _nm_client;
        private bool _is_available;
        private NetworkState _current_state;
        private GenericArray<NM.Device> _devices;
        private GenericArray<NM.Connection> _connections;
        
        /**
         * Signal emitted when NetworkManager availability changes
         */
        public signal void availability_changed(bool available);
        
        /**
         * Signal emitted when network state changes
         */
        public signal void state_changed(NetworkState state);
        
        /**
         * Signal emitted when a device is added
         */
        public signal void device_added(NM.Device device);
        
        /**
         * Signal emitted when a device is removed
         */
        public signal void device_removed(NM.Device device);
        
        /**
         * Signal emitted when a connection is added
         */
        public signal void connection_added(NM.Connection connection);
        
        /**
         * Signal emitted when a connection is removed
         */
        public signal void connection_removed(NM.Connection connection);
        
        /**
         * Signal emitted when device state changes
         */
        public signal void device_state_changed(NM.Device device, NM.DeviceState state, NM.DeviceState old_state, NM.DeviceStateReason reason);
        
        /**
         * Signal emitted when connection state changes
         */
        public signal void connection_state_changed(NM.ActiveConnection connection, NM.ActiveConnectionState state, NM.ActiveConnectionStateReason reason);
        
        /**
         * Signal emitted when a connection is activated
         */
        public signal void connection_activated(NetworkConnection connection);
        
        /**
         * Signal emitted when a connection is deactivated
         */
        public signal void connection_deactivated(NetworkConnection connection);
        
        public bool is_available { 
            get { return _is_available; } 
        }
        
        public NetworkState current_state { 
            get { return _current_state; } 
        }
        
        public NM.Client? nm_client { 
            get { return _nm_client; } 
        }
        
        public NetworkManagerClient() {
            _is_available = false;
            _current_state = new NetworkState();
            _devices = new GenericArray<NM.Device>();
            _connections = new GenericArray<NM.Connection>();
        }
        
        /**
         * Initialize the NetworkManager client asynchronously
         * 
         * @return true if initialization was successful
         */
        public async bool initialize() {
            try {
                debug("NetworkManagerClient: Initializing NetworkManager client...");
                _nm_client = new NM.Client(null);
                
                if (_nm_client == null) {
                    warning("NetworkManagerClient: Failed to create NM.Client");
                    _is_available = false;
                    availability_changed(false);
                    return false;
                }
                
                _is_available = true;
                debug("NetworkManagerClient: NetworkManager client initialized successfully");
                
                // Setup signal handlers
                setup_signal_handlers();
                
                // Initialize device and connection lists
                refresh_devices();
                refresh_connections();
                
                // Update initial state
                update_network_state();
                
                availability_changed(true);
                return true;
                
            } catch (Error e) {
                warning("NetworkManagerClient: Failed to initialize NetworkManager: %s", e.message);
                _is_available = false;
                _nm_client = null;
                availability_changed(false);
                return false;
            }
        }
        
        /**
         * Setup D-Bus signal handlers for NetworkManager events
         */
        private void setup_signal_handlers() {
            if (_nm_client == null) return;
            
            debug("NetworkManagerClient: Setting up signal handlers...");
            
            // NetworkManager state changes
            _nm_client.notify["connectivity"].connect(() => {
                update_network_state();
            });
            
            _nm_client.notify["networking-enabled"].connect(() => {
                update_network_state();
            });
            
            _nm_client.notify["wireless-enabled"].connect(() => {
                update_network_state();
            });
            
            _nm_client.notify["wireless-hardware-enabled"].connect(() => {
                update_network_state();
            });
            
            _nm_client.notify["wwan-enabled"].connect(() => {
                update_network_state();
            });
            
            _nm_client.notify["wwan-hardware-enabled"].connect(() => {
                update_network_state();
            });
            
            _nm_client.notify["primary-connection"].connect(() => {
                update_network_state();
            });
            
            // Device management
            _nm_client.device_added.connect((device) => {
                debug("NetworkManagerClient: Device added: %s (%s)", 
                      device.get_iface(), device.get_type_description());
                _devices.add(device);
                setup_device_signals(device);
                device_added(device);
            });
            
            _nm_client.device_removed.connect((device) => {
                debug("NetworkManagerClient: Device removed: %s", device.get_iface());
                _devices.remove(device);
                device_removed(device);
            });
            
            // Connection management
            _nm_client.connection_added.connect((connection) => {
                debug("NetworkManagerClient: Connection added: %s", connection.get_id());
                _connections.add(connection);
                connection_added(connection);
            });
            
            _nm_client.connection_removed.connect((connection) => {
                debug("NetworkManagerClient: Connection removed: %s", connection.get_id());
                _connections.remove(connection);
                connection_removed(connection);
            });
            
            // Active connection state changes
            _nm_client.notify["active-connections"].connect(() => {
                var active_connections = _nm_client.get_active_connections();
                foreach (var ac in active_connections) {
                    setup_active_connection_signals(ac);
                }
            });
            
            debug("NetworkManagerClient: Signal handlers setup complete");
        }
        
        /**
         * Setup signal handlers for a specific device
         */
        private void setup_device_signals(NM.Device device) {
            device.state_changed.connect((new_state, old_state, reason) => {
                debug("NetworkManagerClient: Device %s state changed: %s -> %s (reason: %s)",
                      device.get_iface(),
                      old_state.to_string(),
                      new_state.to_string(),
                      reason.to_string());
                device_state_changed(device, new_state, old_state, reason);
                update_network_state();
            });
        }
        
        /**
         * Setup signal handlers for active connections
         */
        private void setup_active_connection_signals(NM.ActiveConnection connection) {
            connection.state_changed.connect((state, reason) => {
                debug("NetworkManagerClient: Active connection %s state changed: %s (reason: %s)",
                      connection.get_id() ?? "unknown",
                      state.to_string(),
                      reason.to_string());
                connection_state_changed(connection, state, reason);
                
                // Emit activation/deactivation signals
                if (state == NM.ActiveConnectionState.ACTIVATED) {
                    // Create a NetworkConnection wrapper - this is a simplified approach
                    // In a real implementation, you'd have proper mapping between NM.ActiveConnection and NetworkConnection
                    var network_connection = create_network_connection_from_active(connection);
                    if (network_connection != null) {
                        connection_activated(network_connection);
                    }
                } else if (state == NM.ActiveConnectionState.DEACTIVATED) {
                    var network_connection = create_network_connection_from_active(connection);
                    if (network_connection != null) {
                        connection_deactivated(network_connection);
                    }
                }
                
                update_network_state();
            });
        }
        
        /**
         * Refresh the list of available devices
         */
        private void refresh_devices() {
            if (_nm_client == null) return;
            
            _devices.remove_range(0, _devices.length);
            
            var devices = _nm_client.get_devices();
            foreach (var device in devices) {
                _devices.add(device);
                setup_device_signals(device);
            }
            
            debug("NetworkManagerClient: Refreshed %u devices", _devices.length);
        }
        
        /**
         * Refresh the list of available connections
         */
        private void refresh_connections() {
            if (_nm_client == null) return;
            
            _connections.remove_range(0, _connections.length);
            
            var connections = _nm_client.get_connections();
            foreach (var connection in connections) {
                _connections.add(connection);
            }
            
            debug("NetworkManagerClient: Refreshed %u connections", _connections.length);
        }
        
        /**
         * Update the current network state and emit signal
         */
        private void update_network_state() {
            if (_nm_client == null) return;
            
            var old_connectivity = _current_state.connectivity;
            
            _current_state.connectivity = _nm_client.get_connectivity();
            _current_state.networking_enabled = _nm_client.networking_get_enabled();
            _current_state.wireless_enabled = _nm_client.wireless_get_enabled();
            _current_state.wireless_hardware_enabled = _nm_client.wireless_hardware_enabled;
            _current_state.wwan_enabled = _nm_client.wwan_enabled;
            _current_state.wwan_hardware_enabled = _nm_client.wwan_hardware_enabled;
            
            var primary_connection = _nm_client.get_primary_connection();
            if (primary_connection != null) {
                _current_state.primary_connection_id = primary_connection.get_id();
                _current_state.primary_connection_type = primary_connection.get_connection_type();
            } else {
                _current_state.primary_connection_id = null;
                _current_state.primary_connection_type = null;
            }
            
            // Only emit signal if connectivity actually changed to avoid spam
            if (old_connectivity != _current_state.connectivity) {
                debug("NetworkManagerClient: Connectivity changed: %s -> %s",
                      old_connectivity.to_string(),
                      _current_state.connectivity.to_string());
            }
            
            state_changed(_current_state);
        }
        
        /**
         * Get all available devices
         */
        public GenericArray<NM.Device> get_devices() {
            return _devices;
        }
        
        /**
         * Get devices of a specific type
         */
        public GenericArray<NM.Device> get_devices_by_type(NM.DeviceType device_type) {
            var filtered_devices = new GenericArray<NM.Device>();
            
            for (uint i = 0; i < _devices.length; i++) {
                var device = _devices[i];
                if (device.get_device_type() == device_type) {
                    filtered_devices.add(device);
                }
            }
            
            return filtered_devices;
        }
        
        /**
         * Get all available connections
         */
        public GenericArray<NM.Connection> get_connections() {
            return _connections;
        }
        
        /**
         * Get connections of a specific type
         */
        public GenericArray<NM.Connection> get_connections_by_type(string connection_type) {
            var filtered_connections = new GenericArray<NM.Connection>();
            
            for (uint i = 0; i < _connections.length; i++) {
                var connection = _connections[i];
                if (connection.get_connection_type() == connection_type) {
                    filtered_connections.add(connection);
                }
            }
            
            return filtered_connections;
        }
        
        /**
         * Get the primary WiFi device
         */
        public NM.DeviceWifi? get_wifi_device() {
            var wifi_devices = get_devices_by_type(NM.DeviceType.WIFI);
            if (wifi_devices.length > 0) {
                return wifi_devices[0] as NM.DeviceWifi;
            }
            return null;
        }
        
        /**
         * Get the primary ethernet device
         */
        public NM.DeviceEthernet? get_ethernet_device() {
            var ethernet_devices = get_devices_by_type(NM.DeviceType.ETHERNET);
            if (ethernet_devices.length > 0) {
                return ethernet_devices[0] as NM.DeviceEthernet;
            }
            return null;
        }
        
        /**
         * Activate a connection on a specific device
         */
        public async bool activate_connection(NM.Connection connection, NM.Device? device = null) throws Error {
            if (_nm_client == null) {
                throw new IOError.NOT_CONNECTED("NetworkManager not available");
            }
            
            try {
                debug("NetworkManagerClient: Activating connection %s on device %s",
                      connection.get_id(),
                      device != null ? device.get_iface() : "auto");
                
                var active_connection = yield _nm_client.activate_connection_async(connection, device, null, null);
                
                if (active_connection != null) {
                    debug("NetworkManagerClient: Connection activated successfully");
                    setup_active_connection_signals(active_connection);
                    return true;
                } else {
                    warning("NetworkManagerClient: Failed to activate connection - no active connection returned");
                    return false;
                }
                
            } catch (Error e) {
                warning("NetworkManagerClient: Failed to activate connection: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Deactivate an active connection
         */
        public async bool deactivate_connection(NM.ActiveConnection active_connection) throws Error {
            if (_nm_client == null) {
                throw new IOError.NOT_CONNECTED("NetworkManager not available");
            }
            
            try {
                debug("NetworkManagerClient: Deactivating connection %s",
                      active_connection.get_id() ?? "unknown");
                
                yield _nm_client.deactivate_connection_async(active_connection, null);
                debug("NetworkManagerClient: Connection deactivated successfully");
                return true;
                
            } catch (Error e) {
                warning("NetworkManagerClient: Failed to deactivate connection: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Enable or disable wireless networking
         */
        public void set_wireless_enabled(bool enabled) {
            if (_nm_client == null) return;
            
            debug("NetworkManagerClient: Setting wireless enabled: %s", enabled.to_string());
            _nm_client.wireless_enabled = enabled;
        }
        
        /**
         * Enable or disable mobile broadband
         */
        public void set_wwan_enabled(bool enabled) {
            if (_nm_client == null) return;
            
            debug("NetworkManagerClient: Setting WWAN enabled: %s", enabled.to_string());
            _nm_client.wwan_enabled = enabled;
        }
        
        /**
         * Check connectivity and return the result
         */
        public async NM.ConnectivityState check_connectivity() throws Error {
            if (_nm_client == null) {
                throw new IOError.NOT_CONNECTED("NetworkManager not available");
            }
            
            try {
                debug("NetworkManagerClient: Checking connectivity...");
                var connectivity = yield _nm_client.check_connectivity_async(null);
                debug("NetworkManagerClient: Connectivity check result: %s", connectivity.to_string());
                return connectivity;
            } catch (Error e) {
                warning("NetworkManagerClient: Connectivity check failed: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Handle NetworkManager becoming unavailable
         */
        public void handle_nm_unavailable() {
            warning("NetworkManagerClient: NetworkManager became unavailable");
            _is_available = false;
            _nm_client = null;
            _devices.remove_range(0, _devices.length);
            _connections.remove_range(0, _connections.length);
            
            // Reset state
            _current_state = new NetworkState();
            
            availability_changed(false);
            state_changed(_current_state);
        }
        
        /**
         * Attempt to reconnect to NetworkManager
         */
        public async bool reconnect() {
            debug("NetworkManagerClient: Attempting to reconnect to NetworkManager...");
            return yield initialize();
        }
        
        /**
         * Get all active connections
         */
        public GenericArray<NM.ActiveConnection> get_active_connections() {
            var active_connections = new GenericArray<NM.ActiveConnection>();
            
            if (_nm_client == null) return active_connections;
            
            var connections = _nm_client.get_active_connections();
            foreach (var connection in connections) {
                active_connections.add(connection);
            }
            
            return active_connections;
        }
        
        /**
         * Get a human-readable description of the current connectivity state
         */
        public string get_connectivity_description() {
            switch (_current_state.connectivity) {
                case NM.ConnectivityState.FULL:
                    return "Full connectivity";
                case NM.ConnectivityState.LIMITED:
                    return "Limited connectivity";
                case NM.ConnectivityState.PORTAL:
                    return "Captive portal detected";
                case NM.ConnectivityState.NONE:
                    return "No connectivity";
                case NM.ConnectivityState.UNKNOWN:
                default:
                    return "Connectivity unknown";
            }
        }
        
        /**
         * Create a NetworkConnection wrapper from NM.ActiveConnection
         * This is a simplified implementation for signal emission
         */
        private NetworkConnection? create_network_connection_from_active(NM.ActiveConnection active_connection) {
            var connection = active_connection.get_connection();
            if (connection == null) return null;
            
            var connection_type = connection.get_connection_type();
            
            // This is a simplified approach - in a real implementation,
            // you'd have proper factory methods for different connection types
            if (connection_type == "802-11-wireless") {
                var wifi_network = new WiFiNetwork();
                wifi_network.id = connection.get_uuid();
                wifi_network.name = connection.get_id();
                wifi_network.connection_type = ConnectionType.WIFI;
                return wifi_network;
            } else if (connection_type == "802-3-ethernet") {
                var network_connection = new BasicNetworkConnection();
                network_connection.id = connection.get_uuid();
                network_connection.name = connection.get_id();
                network_connection.connection_type = ConnectionType.ETHERNET;
                return network_connection;
            }
            
            return null;
        }
    }
}