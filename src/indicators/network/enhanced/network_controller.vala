/**
 * Enhanced Network Indicator - Network Controller Integration
 * 
 * This file provides the main network controller that coordinates between
 * the UI components and backend network management services.
 */

using GLib;
using NM;

namespace EnhancedNetwork {

    /**
     * Connection status for UI updates
     */
    public enum ConnectionStatus {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        DISCONNECTING,
        FAILED,
        UNKNOWN
    }

    /**
     * Security severity levels
     */
    public enum SecuritySeverity {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }

    /**
     * Progress information for long-running operations
     */
    public class ProgressInfo : GLib.Object {
        public string operation_id { get; set; }
        public string description { get; set; }
        public double progress { get; set; } // 0.0 to 1.0
        public bool cancellable { get; set; }
        public DateTime started { get; set; }
        
        public ProgressInfo(string operation_id, string description, bool cancellable = false) {
            this.operation_id = operation_id;
            this.description = description;
            this.progress = 0.0;
            this.cancellable = cancellable;
            this.started = new DateTime.now_local();
        }
    }

    /**
     * Main network controller coordinating UI and backend services
     * 
     * This class implements controller initialization and signal connections,
     * network state synchronization between backend and UI, and progress
     * indication and cancellation support.
     */
    public class NetworkController : GLib.Object {
        // Backend components
        public NetworkManagerClient nm_client { get; private set; }
        public WiFiManager? wifi_manager { get; private set; }
        public EthernetManager? ethernet_manager { get; private set; }
        public VPNManager? vpn_manager { get; private set; }
        public MobileManager? mobile_manager { get; private set; }
        public HotspotManager? hotspot_manager { get; private set; }
        private SecurityAnalyzer? security_analyzer;
        public BandwidthMonitor? bandwidth_monitor { get; private set; }
        public NetworkProfileManager? profile_manager { get; private set; }
        public AdvancedConfigManager? advanced_config_manager { get; private set; }
        private PolicyKitClient? polkit_client;
        private ErrorHandler? error_handler;
        private NetworkMonitor? network_monitor;
        
        // State management
        private NetworkState _current_state;
        private HashTable<string, ProgressInfo> active_operations;
        private HashTable<string, NetworkConnection> known_connections;
        private bool _is_initialized;
        
        /**
         * Signal emitted when network state changes
         */
        public signal void state_changed(NetworkState state);
        
        /**
         * Signal emitted when a connection is added
         */
        public signal void connection_added(NetworkConnection connection);
        
        /**
         * Signal emitted when a connection is removed
         */
        public signal void connection_removed(string connection_id);
        
        /**
         * Signal emitted when a security alert occurs
         */
        public signal void security_alert(SecurityAlert alert);
        
        /**
         * Signal emitted when progress information is updated
         */
        public signal void progress_updated(ProgressInfo progress);
        
        /**
         * Signal emitted when an operation is completed
         */
        public signal void operation_completed(string operation_id, bool success, string? error_message);
        
        /**
         * Signal emitted when bandwidth data is updated
         */
        public signal void bandwidth_updated(BandwidthData data);
        
        public NetworkState? current_state { 
            get { return _current_state; } 
        }
        
        public bool is_initialized { 
            get { return _is_initialized; } 
        }
        
        public NetworkController() {
            _is_initialized = false;
            active_operations = new HashTable<string, ProgressInfo>(str_hash, str_equal);
            known_connections = new HashTable<string, NetworkConnection>(str_hash, str_equal);
            
            debug("NetworkController: Controller created");
        }
        
        /**
         * Initialize the network controller and all backend components
         */
        public async bool initialize() {
            if (_is_initialized) {
                debug("NetworkController: Already initialized");
                return true;
            }
            
            debug("NetworkController: Initializing controller...");
            
            try {
                // Initialize NetworkManager client first
                nm_client = new NetworkManagerClient();
                var nm_success = yield nm_client.initialize();
                
                if (!nm_success) {
                    warning("NetworkController: Failed to initialize NetworkManager client");
                    return false;
                }
                
                // Setup NetworkManager client signals
                setup_nm_client_signals();
                
                // Initialize backend components
                yield initialize_backend_components();
                
                // Setup component signals
                setup_component_signals();
                
                // Get initial state
                _current_state = nm_client.current_state;
                
                // Start monitoring
                if (network_monitor != null) {
                    network_monitor.start_monitoring();
                }
                
                _is_initialized = true;
                debug("NetworkController: Controller initialized successfully");
                
                // Emit initial state
                state_changed(_current_state);
                
                return true;
                
            } catch (Error e) {
                warning("NetworkController: Initialization failed: %s", e.message);
                _is_initialized = false;
                return false;
            }
        }
        
        /**
         * Initialize all backend components
         */
        private async void initialize_backend_components() {
            debug("NetworkController: Initializing backend components...");
            
            // Initialize error handler first
            error_handler = new ErrorHandler();
            
            // Initialize PolicyKit client
            polkit_client = new PolicyKitClient();
            yield polkit_client.initialize();
            
            // Initialize network managers
            wifi_manager = new WiFiManager(nm_client);
            ethernet_manager = new EthernetManager(nm_client);
            vpn_manager = new VPNManager(nm_client);
            mobile_manager = new MobileManager(nm_client);
            hotspot_manager = new HotspotManager(nm_client);
            
            // Initialize monitoring and analysis components
            security_analyzer = new SecurityAnalyzer(nm_client);
            bandwidth_monitor = new BandwidthMonitor(nm_client);
            network_monitor = new NetworkMonitor(nm_client);
            profile_manager = new NetworkProfileManager(nm_client);
            advanced_config_manager = new AdvancedConfigManager(nm_client);
            
            debug("NetworkController: Backend components initialized");
        }
        
        /**
         * Setup NetworkManager client signal handlers
         */
        private void setup_nm_client_signals() {
            nm_client.state_changed.connect(on_nm_state_changed);
            nm_client.connection_activated.connect(on_connection_activated);
            nm_client.connection_deactivated.connect(on_connection_deactivated);
            nm_client.availability_changed.connect(on_nm_availability_changed);
            
            debug("NetworkController: NetworkManager client signals connected");
        }
        
        /**
         * Setup backend component signal handlers
         */
        private void setup_component_signals() {
            // WiFi manager signals
            if (wifi_manager != null) {
                wifi_manager.connection_state_changed.connect(on_wifi_state_changed);
            }
            
            // Security analyzer signals
            if (security_analyzer != null) {
                security_analyzer.security_alert.connect(on_security_alert_received);
            }
            
            // Bandwidth monitor signals
            if (bandwidth_monitor != null) {
                bandwidth_monitor.bandwidth_updated.connect(on_bandwidth_data_updated);
            }
            
            // Network monitor signals
            if (network_monitor != null) {
                network_monitor.performance_degraded.connect(on_performance_degraded);
            }
            
            debug("NetworkController: Component signals connected");
        }
        
        /**
         * Connect to a network with optional credentials
         */
        public async bool connect_to_network(string connection_id, Credentials? credentials = null) {
            debug("NetworkController: Connecting to network: %s", connection_id);
            
            var operation_id = @"connect_$(connection_id)_$(get_real_time())";
            var progress = new ProgressInfo(operation_id, @"Connecting to $(connection_id)", true);
            
            active_operations[operation_id] = progress;
            progress_updated(progress);
            
            try {
                // Find the connection
                var connection = known_connections[connection_id];
                if (connection == null) {
                    throw new IOError.NOT_FOUND(@"Connection not found: $(connection_id)");
                }
                
                // Update progress
                progress.progress = 0.3;
                progress.description = "Authenticating...";
                progress_updated(progress);
                
                // Attempt connection based on type
                bool success = false;
                
                switch (connection.connection_type) {
                    case ConnectionType.WIFI:
                        if (wifi_manager != null) {
                            var wifi_network = connection as WiFiNetwork;
                            if (wifi_network != null) {
                                var password = credentials?.password;
                                success = yield wifi_manager.connect_to_network(wifi_network, password);
                            }
                        }
                        break;
                        
                    case ConnectionType.VPN:
                        if (vpn_manager != null) {
                            var vpn_profile = connection as VPNProfile;
                            if (vpn_profile != null) {
                                success = yield vpn_manager.connect_vpn(vpn_profile);
                            }
                        }
                        break;
                        
                    case ConnectionType.MOBILE_BROADBAND:
                        if (mobile_manager != null) {
                            var mobile_connection = connection as MobileConnection;
                            if (mobile_connection != null) {
                                success = yield mobile_manager.connect_to_network(mobile_connection);
                            }
                        }
                        break;
                        
                    default:
                        throw new IOError.NOT_SUPPORTED(@"Connection type not supported: $(connection.connection_type)");
                }
                
                // Update final progress
                progress.progress = 1.0;
                progress.description = success ? "Connected" : "Connection failed";
                progress_updated(progress);
                
                // Clean up operation
                active_operations.remove(operation_id);
                operation_completed(operation_id, success, success ? null : "Connection failed");
                
                debug("NetworkController: Connection attempt completed: %s", success.to_string());
                return success;
                
            } catch (Error e) {
                warning("NetworkController: Connection failed: %s", e.message);
                
                progress.progress = 1.0;
                progress.description = "Connection failed";
                progress_updated(progress);
                
                active_operations.remove(operation_id);
                operation_completed(operation_id, false, e.message);
                
                return false;
            }
        }
        
        /**
         * Disconnect from a network
         */
        public async bool disconnect_from_network(string connection_id) {
            debug("NetworkController: Disconnecting from network: %s", connection_id);
            
            var operation_id = @"disconnect_$(connection_id)_$(get_real_time())";
            var progress = new ProgressInfo(operation_id, @"Disconnecting from $(connection_id)", false);
            
            active_operations[operation_id] = progress;
            progress_updated(progress);
            
            try {
                var connection = known_connections[connection_id];
                if (connection == null) {
                    throw new IOError.NOT_FOUND(@"Connection not found: $(connection_id)");
                }
                
                progress.progress = 0.5;
                progress_updated(progress);
                
                bool success = yield connection.disconnect_from_network();
                
                progress.progress = 1.0;
                progress.description = success ? "Disconnected" : "Disconnection failed";
                progress_updated(progress);
                
                active_operations.remove(operation_id);
                operation_completed(operation_id, success, success ? null : "Disconnection failed");
                
                return success;
                
            } catch (Error e) {
                warning("NetworkController: Disconnection failed: %s", e.message);
                
                progress.progress = 1.0;
                progress.description = "Disconnection failed";
                progress_updated(progress);
                
                active_operations.remove(operation_id);
                operation_completed(operation_id, false, e.message);
                
                return false;
            }
        }
        
        /**
         * Get list of available networks
         */
        public async List<NetworkConnection> get_available_networks() {
            debug("NetworkController: Getting available networks...");
            
            var networks = new List<NetworkConnection>();
            
            try {
                // Get WiFi networks
                if (wifi_manager != null) {
                    var wifi_networks = wifi_manager.get_available_networks();
                    foreach (var network in wifi_networks) {
                        networks.append(network);
                        known_connections[network.id] = network;
                    }
                }
                
                // Get VPN profiles
                if (vpn_manager != null) {
                    for (uint i = 0; i < vpn_manager.vpn_profiles.length; i++) {
                        var profile = vpn_manager.vpn_profiles[i];
                        networks.append(profile);
                        known_connections[profile.id] = profile;
                    }
                }
                
                // Get mobile connections
                if (mobile_manager != null) {
                    var mobile_connections = mobile_manager.get_available_networks();
                    foreach (var connection in mobile_connections) {
                        networks.append(connection);
                        known_connections[connection.id] = connection;
                    }
                }
                
                debug("NetworkController: Found %u available networks", networks.length());
                
            } catch (Error e) {
                warning("NetworkController: Failed to get available networks: %s", e.message);
            }
            
            return (owned) networks;
        }
        
        /**
         * Cancel an active operation
         */
        public bool cancel_operation(string operation_id) {
            var progress = active_operations[operation_id];
            if (progress == null) {
                debug("NetworkController: Operation not found: %s", operation_id);
                return false;
            }
            
            if (!progress.cancellable) {
                debug("NetworkController: Operation not cancellable: %s", operation_id);
                return false;
            }
            
            debug("NetworkController: Cancelling operation: %s", operation_id);
            
            // TODO: Implement actual cancellation logic for different operation types
            
            active_operations.remove(operation_id);
            operation_completed(operation_id, false, "Operation cancelled by user");
            
            return true;
        }
        
        /**
         * Get list of active operations
         */
        public List<ProgressInfo> get_active_operations() {
            var operations = new List<ProgressInfo>();
            
            active_operations.foreach((key, value) => {
                operations.append(value);
            });
            
            return (owned) operations;
        }
        
        /**
         * Handle NetworkManager state changes
         */
        private void on_nm_state_changed(NetworkState state) {
            debug("NetworkController: NetworkManager state changed");
            _current_state = state;
            state_changed(state);
        }
        
        /**
         * Handle connection activation
         */
        private void on_connection_activated(NetworkConnection connection) {
            debug("NetworkController: Connection activated: %s", connection.name);
            known_connections[connection.id] = connection;
            connection_added(connection);
        }
        
        /**
         * Handle connection deactivation
         */
        private void on_connection_deactivated(NetworkConnection connection) {
            debug("NetworkController: Connection deactivated: %s", connection.name);
            connection_removed(connection.id);
        }
        
        /**
         * Handle NetworkManager availability changes
         */
        private void on_nm_availability_changed(bool available) {
            debug("NetworkController: NetworkManager availability changed: %s", available.to_string());
            
            if (!available) {
                // Clear active operations when NetworkManager becomes unavailable
                active_operations.remove_all();
                
                // Create error state
                _current_state = new NetworkState();
                state_changed(_current_state);
            }
        }
        
        /**
         * Handle WiFi state changes
         */
        private void on_wifi_state_changed(WiFiNetwork network, ConnectionState state) {
            debug("NetworkController: WiFi state changed: %s -> %s", network.name, state.to_string());
            
            // Update known connection
            known_connections[network.id] = network;
            
            // Convert to connection status and emit signal if needed
            // This would be used by UI components to update their display
        }
        
        /**
         * Handle security alerts
         */
        private void on_security_alert_received(SecurityAlert alert) {
            debug("NetworkController: Security alert received: %s", alert.message);
            security_alert(alert);
        }
        
        /**
         * Handle bandwidth data updates
         */
        private void on_bandwidth_data_updated(BandwidthData data) {
            bandwidth_updated(data);
        }
        
        /**
         * Handle performance degradation alerts
         */
        private void on_performance_degraded(string connection_id, string reason) {
            debug("NetworkController: Performance degraded for %s: %s", connection_id, reason);
            
            var alert = new SecurityAlert.with_details(
                @"perf_$(connection_id)",
                "Performance Alert",
                @"Network performance degraded: $(reason)",
                ErrorSeverity.MEDIUM
            );
            alert.related_network = known_connections[connection_id];
            
            security_alert(alert);
        }
        
        /**
         * Cleanup resources when controller is destroyed
         */
        public void cleanup() {
            debug("NetworkController: Cleaning up resources...");
            
            // Stop monitoring
            if (network_monitor != null) {
                network_monitor.stop_monitoring();
            }
            
            // Cancel all active operations
            var operation_ids = new List<string>();
            active_operations.foreach((key, value) => {
                operation_ids.append(key);
            });
            
            foreach (var operation_id in operation_ids) {
                cancel_operation(operation_id);
            }
            
            // Clear collections
            active_operations.remove_all();
            known_connections.remove_all();
            
            _is_initialized = false;
            
            debug("NetworkController: Cleanup completed");
        }
    }
}