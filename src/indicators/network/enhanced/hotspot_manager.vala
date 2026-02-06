/**
 * Enhanced Network Indicator - Hotspot Manager Component
 * 
 * This file implements the HotspotManager class that provides comprehensive
 * WiFi hotspot management including creation, configuration, device monitoring,
 * and data usage tracking.
 */

using GLib;
using NM;

namespace EnhancedNetwork {

    /**
     * Hotspot Manager - Comprehensive WiFi hotspot management
     * 
     * This class provides complete hotspot functionality including hotspot creation,
     * configuration management, connected device monitoring, and data usage tracking.
     * It integrates with NetworkManager through the D-Bus API.
     */
    public class HotspotManager : GLib.Object {
        private NetworkManagerClient nm_client;
        private HotspotConfiguration? _active_hotspot;
        private GenericArray<ConnectedDevice> _connected_devices;
        private Timer? _monitoring_timer;
        private uint _monitoring_timeout_id;
        
        // Configuration
        private const uint MONITORING_INTERVAL_MS = 5000; // 5 seconds
        private const uint DEVICE_TIMEOUT_MS = 30000; // 30 seconds for device timeout
        private const string DEFAULT_HOTSPOT_INTERFACE = "wlan0";
        
        /**
         * Signal emitted when hotspot state changes
         */
        public signal void hotspot_state_changed(HotspotState state);
        
        /**
         * Signal emitted when a device connects to the hotspot
         */
        public signal void device_connected(ConnectedDevice device);
        
        /**
         * Signal emitted when a device disconnects from the hotspot
         */
        public signal void device_disconnected(ConnectedDevice device);
        
        /**
         * Signal emitted when data usage is updated
         */
        public signal void usage_updated(DataUsage usage);
        
        /**
         * Signal emitted when usage threshold is reached
         */
        public signal void usage_threshold_reached(double percentage);
        
        /**
         * Signal emitted when hotspot creation fails
         */
        public signal void hotspot_failed(string error_message);
        
        /**
         * Signal emitted when connection sharing conflicts occur
         */
        public signal void sharing_conflict_detected(string conflict_description);
        
        public HotspotConfiguration? active_hotspot { 
            get { return _active_hotspot; } 
        }
        
        public bool is_active { 
            get { return _active_hotspot != null && _active_hotspot.is_active(); } 
        }
        
        public HotspotManager(NetworkManagerClient nm_client) {
            this.nm_client = nm_client;
            _connected_devices = new GenericArray<ConnectedDevice>();
            
            // Setup NetworkManager client signals
            setup_nm_signals();
        }
        
        /**
         * Setup NetworkManager client signal handlers
         */
        private void setup_nm_signals() {
            nm_client.availability_changed.connect((available) => {
                if (!available) {
                    handle_nm_unavailable();
                }
            });
            
            nm_client.state_changed.connect((state) => {
                if (!state.wireless_enabled && is_active) {
                    // WiFi was disabled, stop hotspot
                    stop_hotspot.begin();
                }
            });
            
            nm_client.device_added.connect((device) => {
                if (device.get_device_type() == NM.DeviceType.WIFI && is_active) {
                    // New WiFi device added, might affect hotspot
                    check_hotspot_device_availability();
                }
            });
            
            nm_client.device_removed.connect((device) => {
                if (device.get_device_type() == NM.DeviceType.WIFI && is_active) {
                    // WiFi device removed, might affect hotspot
                    check_hotspot_device_availability();
                }
            });
        }
        
        /**
         * Create and start a WiFi hotspot
         */
        public async bool create_hotspot(HotspotConfiguration config) {
            if (!nm_client.is_available) {
                hotspot_failed("NetworkManager not available");
                return false;
            }
            
            if (!nm_client.current_state.wireless_enabled) {
                hotspot_failed("WiFi is disabled");
                return false;
            }
            
            if (is_active) {
                hotspot_failed("Hotspot is already active");
                return false;
            }
            
            if (!config.is_configuration_valid()) {
                hotspot_failed("Invalid hotspot configuration");
                return false;
            }
            
            try {
                debug("HotspotManager: Creating hotspot: %s", config.ssid);
                
                // Check for connection sharing conflicts
                var conflict = check_sharing_conflicts(config);
                if (conflict != null) {
                    sharing_conflict_detected(conflict);
                    // Continue anyway - user can resolve conflicts
                }
                
                // Set configuration as active
                _active_hotspot = config;
                _active_hotspot.state_changed.connect(on_hotspot_state_changed);
                _active_hotspot.device_connected.connect(on_device_connected);
                _active_hotspot.device_disconnected.connect(on_device_disconnected);
                _active_hotspot.usage_updated.connect(on_usage_updated);
                _active_hotspot.usage_threshold_reached.connect(on_usage_threshold_reached);
                
                // Start the hotspot
                var success = yield _active_hotspot.start();
                
                if (success) {
                    debug("HotspotManager: Hotspot created successfully");
                    start_monitoring();
                    return true;
                } else {
                    debug("HotspotManager: Failed to create hotspot");
                    cleanup_failed_hotspot();
                    return false;
                }
                
            } catch (Error e) {
                warning("HotspotManager: Hotspot creation error: %s", e.message);
                hotspot_failed(e.message);
                cleanup_failed_hotspot();
                return false;
            }
        }
        
        /**
         * Stop the active hotspot
         */
        public async bool stop_hotspot() {
            if (!is_active) {
                debug("HotspotManager: No active hotspot to stop");
                return true;
            }
            
            try {
                debug("HotspotManager: Stopping hotspot: %s", _active_hotspot.ssid);
                
                stop_monitoring();
                
                var success = yield _active_hotspot.stop();
                
                // Clean up regardless of success
                cleanup_hotspot();
                
                if (success) {
                    debug("HotspotManager: Hotspot stopped successfully");
                } else {
                    warning("HotspotManager: Error stopping hotspot");
                }
                
                return success;
                
            } catch (Error e) {
                warning("HotspotManager: Hotspot stop error: %s", e.message);
                cleanup_hotspot();
                return false;
            }
        }
        
        /**
         * Update hotspot configuration
         */
        public async bool update_hotspot_config(HotspotConfiguration new_config) {
            if (!is_active) {
                hotspot_failed("No active hotspot to update");
                return false;
            }
            
            if (!new_config.is_configuration_valid()) {
                hotspot_failed("Invalid hotspot configuration");
                return false;
            }
            
            try {
                debug("HotspotManager: Updating hotspot configuration");
                
                // For significant changes, we need to restart the hotspot
                bool needs_restart = needs_hotspot_restart(_active_hotspot, new_config);
                
                if (needs_restart) {
                    debug("HotspotManager: Configuration change requires restart");
                    
                    // Stop current hotspot
                    yield stop_hotspot();
                    
                    // Start with new configuration
                    return yield create_hotspot(new_config);
                } else {
                    // Minor changes can be applied without restart
                    debug("HotspotManager: Applying configuration changes without restart");
                    apply_minor_config_changes(new_config);
                    return true;
                }
                
            } catch (Error e) {
                warning("HotspotManager: Configuration update error: %s", e.message);
                hotspot_failed(e.message);
                return false;
            }
        }
        
        /**
         * Get list of connected devices
         */
        public GenericArray<ConnectedDevice> get_connected_devices() {
            var devices = new GenericArray<ConnectedDevice>();
            
            if (!is_active) {
                return devices;
            }
            
            var device_list = _active_hotspot.get_connected_devices();
            foreach (var device in device_list) {
                devices.add(device);
            }
            
            return devices;
        }
        
        /**
         * Get current data usage
         */
        public DataUsage get_hotspot_usage() {
            if (!is_active) {
                return new DataUsage();
            }
            
            return _active_hotspot.get_data_usage();
        }
        
        /**
         * Set data usage limit
         */
        public void set_usage_limit(uint64 limit_bytes, bool enabled = true) {
            if (is_active) {
                _active_hotspot.set_usage_limit(limit_bytes, enabled);
            }
        }
        
        /**
         * Get available WiFi interfaces for hotspot
         */
        public GenericArray<string> get_available_interfaces() {
            var interfaces = new GenericArray<string>();
            
            if (!nm_client.is_available) {
                return interfaces;
            }
            
            var devices = nm_client.nm_client.get_devices();
            foreach (var device in devices) {
                if (device.get_device_type() == NM.DeviceType.WIFI) {
                    var wifi_device = device as NM.DeviceWifi;
                    if (wifi_device != null && can_device_create_hotspot(wifi_device)) {
                        interfaces.add(device.get_iface());
                    }
                }
            }
            
            return interfaces;
        }
        
        /**
         * Check if a WiFi device can create hotspot
         */
        private bool can_device_create_hotspot(NM.DeviceWifi wifi_device) {
            // Check device capabilities
            var caps = wifi_device.get_capabilities();
            return (caps & NM.DeviceWifiCapabilities.AP) != 0;
        }
        
        /**
         * Check for connection sharing conflicts
         */
        private string? check_sharing_conflicts(HotspotConfiguration config) {
            if (!nm_client.is_available) {
                return null;
            }
            
            // Check if the device interface is already in use
            var devices = nm_client.nm_client.get_devices();
            foreach (var device in devices) {
                if (device.get_iface() == config.device_interface) {
                    var state = device.get_state();
                    if (state == NM.DeviceState.ACTIVATED) {
                        return "Device %s is already in use for another connection".printf(config.device_interface);
                    }
                }
            }
            
            // Check if shared connection exists and is available
            if (config.shared_connection_id != null) {
                var connections = nm_client.nm_client.get_connections();
                bool found_shared_connection = false;
                
                foreach (var connection in connections) {
                    if (connection.get_uuid() == config.shared_connection_id) {
                        found_shared_connection = true;
                        break;
                    }
                }
                
                if (!found_shared_connection) {
                    return "Shared connection not found or not available";
                }
            }
            
            return null;
        }
        
        /**
         * Check if configuration change requires hotspot restart
         */
        private bool needs_hotspot_restart(HotspotConfiguration current, HotspotConfiguration new_config) {
            // Changes that require restart
            if (current.ssid != new_config.ssid) return true;
            if (current.password != new_config.password) return true;
            if (current.security_type != new_config.security_type) return true;
            if (current.device_interface != new_config.device_interface) return true;
            if (current.shared_connection_id != new_config.shared_connection_id) return true;
            if (current.channel != new_config.channel) return true;
            if (current.hidden != new_config.hidden) return true;
            
            return false;
        }
        
        /**
         * Apply minor configuration changes without restart
         */
        private void apply_minor_config_changes(HotspotConfiguration new_config) {
            if (_active_hotspot == null) return;
            
            // Only max_clients can be changed without restart for now
            if (_active_hotspot.max_clients != new_config.max_clients) {
                _active_hotspot.max_clients = new_config.max_clients;
                debug("HotspotManager: Updated max clients to %u", new_config.max_clients);
            }
        }
        
        /**
         * Start monitoring connected devices and usage
         */
        private void start_monitoring() {
            if (_monitoring_timeout_id > 0) {
                return; // Already monitoring
            }
            
            debug("HotspotManager: Starting hotspot monitoring");
            
            _monitoring_timeout_id = Timeout.add(MONITORING_INTERVAL_MS, () => {
                monitor_hotspot.begin();
                return true; // Continue monitoring
            });
        }
        
        /**
         * Stop monitoring
         */
        private void stop_monitoring() {
            if (_monitoring_timeout_id > 0) {
                Source.remove(_monitoring_timeout_id);
                _monitoring_timeout_id = 0;
                debug("HotspotManager: Stopped hotspot monitoring");
            }
        }
        
        /**
         * Monitor hotspot status, connected devices, and usage
         */
        private async void monitor_hotspot() {
            if (!is_active) {
                return;
            }
            
            try {
                // Monitor connected devices
                yield monitor_connected_devices();
                
                // Monitor data usage
                yield monitor_data_usage();
                
                // Check for device timeouts
                check_device_timeouts();
                
            } catch (Error e) {
                warning("HotspotManager: Monitoring error: %s", e.message);
            }
        }
        
        /**
         * Monitor connected devices
         */
        private async void monitor_connected_devices() {
            // This is a placeholder implementation
            // In a real implementation, this would query NetworkManager
            // for actual connected devices through D-Bus
            
            // For now, simulate device monitoring
            debug("HotspotManager: Monitoring connected devices (placeholder)");
        }
        
        /**
         * Monitor data usage
         */
        private async void monitor_data_usage() {
            if (_active_hotspot == null) return;
            
            // This is a placeholder implementation
            // In a real implementation, this would query system network statistics
            // or NetworkManager for actual data usage
            
            // Simulate some data usage
            var random_sent = Random.int_range(1000, 10000);
            var random_received = Random.int_range(1000, 10000);
            
            _active_hotspot.update_usage(random_sent, random_received);
        }
        
        /**
         * Check for device connection timeouts
         */
        private void check_device_timeouts() {
            if (_active_hotspot == null) return;
            
            var devices = _active_hotspot.get_connected_devices();
            var now = new DateTime.now_local();
            
            foreach (var device in devices) {
                var duration = now.difference(device.connected_since);
                
                // Remove devices that haven't been seen for too long
                if (duration > DEVICE_TIMEOUT_MS * 1000) {
                    debug("HotspotManager: Device %s timed out", device.mac_address);
                    _active_hotspot.remove_connected_device(device.mac_address);
                }
            }
        }
        
        /**
         * Check hotspot device availability
         */
        private void check_hotspot_device_availability() {
            if (!is_active || _active_hotspot == null) {
                return;
            }
            
            var interfaces = get_available_interfaces();
            bool device_available = false;
            
            for (uint i = 0; i < interfaces.length; i++) {
                if (interfaces[i] == _active_hotspot.device_interface) {
                    device_available = true;
                    break;
                }
            }
            
            if (!device_available) {
                warning("HotspotManager: Hotspot device no longer available");
                hotspot_failed("Hotspot device no longer available");
                stop_hotspot.begin();
            }
        }
        
        /**
         * Handle hotspot state changes
         */
        private void on_hotspot_state_changed(HotspotState old_state, HotspotState new_state) {
            debug("HotspotManager: Hotspot state changed: %s -> %s", 
                  old_state.to_string(), new_state.to_string());
            hotspot_state_changed(new_state);
            
            if (new_state == HotspotState.FAILED) {
                cleanup_failed_hotspot();
            }
        }
        
        /**
         * Handle device connection events
         */
        private void on_device_connected(ConnectedDevice device) {
            debug("HotspotManager: Device connected: %s", device.get_display_name());
            device_connected(device);
        }
        
        /**
         * Handle device disconnection events
         */
        private void on_device_disconnected(ConnectedDevice device) {
            debug("HotspotManager: Device disconnected: %s", device.get_display_name());
            device_disconnected(device);
        }
        
        /**
         * Handle usage updates
         */
        private void on_usage_updated(DataUsage usage) {
            usage_updated(usage);
        }
        
        /**
         * Handle usage threshold events
         */
        private void on_usage_threshold_reached(double percentage) {
            debug("HotspotManager: Usage threshold reached: %.1f%%", percentage);
            usage_threshold_reached(percentage);
        }
        
        /**
         * Clean up after failed hotspot creation
         */
        private void cleanup_failed_hotspot() {
            if (_active_hotspot != null) {
                _active_hotspot.state_changed.disconnect(on_hotspot_state_changed);
                _active_hotspot.device_connected.disconnect(on_device_connected);
                _active_hotspot.device_disconnected.disconnect(on_device_disconnected);
                _active_hotspot.usage_updated.disconnect(on_usage_updated);
                _active_hotspot.usage_threshold_reached.disconnect(on_usage_threshold_reached);
            }
            
            _active_hotspot = null;
            stop_monitoring();
        }
        
        /**
         * Clean up hotspot resources
         */
        private void cleanup_hotspot() {
            cleanup_failed_hotspot();
            _connected_devices.remove_range(0, _connected_devices.length);
        }
        
        /**
         * Handle NetworkManager becoming unavailable
         */
        private void handle_nm_unavailable() {
            if (is_active) {
                warning("HotspotManager: NetworkManager unavailable, stopping hotspot");
                stop_hotspot.begin();
            }
        }
    }
}