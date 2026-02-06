/**
 * Enhanced Network Indicator - Network Discovery and Monitoring
 * 
 * This file provides comprehensive network discovery, device detection,
 * and bandwidth monitoring capabilities for the enhanced network indicator.
 */

using GLib;
using NM;

namespace EnhancedNetwork {



    /**
     * Connection data usage tracking for monitoring
     */
    public class ConnectionDataUsage : GLib.Object {
        public uint64 total_bytes { get; set; }
        public uint64 session_bytes { get; set; }
        public DateTime session_start { get; set; }
        public DateTime last_reset { get; set; }
        public string connection_id { get; set; }
        
        public ConnectionDataUsage(string connection_id) {
            this.connection_id = connection_id;
            this.session_start = new DateTime.now_local();
            this.last_reset = new DateTime.now_local();
        }
        
        public void reset_session() {
            session_bytes = 0;
            session_start = new DateTime.now_local();
        }
        
        public double get_session_duration_hours() {
            var now = new DateTime.now_local();
            var duration = now.difference(session_start);
            return (double)duration / TimeSpan.HOUR;
        }
    }

    /**
     * Connection quality metrics
     */
    public class ConnectionQuality : GLib.Object {
        public uint32 latency_ms { get; set; }
        public double packet_loss_percent { get; set; }
        public uint32 jitter_ms { get; set; }
        public uint8 signal_strength { get; set; }
        public string connection_id { get; set; }
        public DateTime last_updated { get; set; }
        
        public ConnectionQuality(string connection_id) {
            this.connection_id = connection_id;
            this.last_updated = new DateTime.now_local();
        }
        
        public string get_quality_description() {
            if (packet_loss_percent > 5.0 || latency_ms > 200) {
                return "Poor";
            } else if (packet_loss_percent > 1.0 || latency_ms > 100) {
                return "Fair";
            } else if (latency_ms > 50) {
                return "Good";
            } else {
                return "Excellent";
            }
        }
    }

    /**
     * Network discovery and monitoring service
     * 
     * This class provides comprehensive network discovery, device detection,
     * and continuous monitoring of network performance and usage.
     */
    public class NetworkMonitor : GLib.Object {
        private NetworkManagerClient nm_client;
        private HashTable<string, BandwidthData> bandwidth_data;
        private HashTable<string, ConnectionDataUsage> usage_data;
        private HashTable<string, ConnectionQuality> quality_data;
        private HashTable<string, uint64?> last_rx_bytes;
        private HashTable<string, uint64?> last_tx_bytes;
        private HashTable<string, DateTime> last_measurement_time;
        
        private uint monitoring_timer_id;
        private uint discovery_timer_id;
        private bool is_monitoring;
        private uint monitoring_interval_ms;
        private uint discovery_interval_ms;
        
        /**
         * Signal emitted when bandwidth data is updated
         */
        public signal void bandwidth_updated(BandwidthData data);
        
        /**
         * Signal emitted when data usage is updated
         */
        public signal void usage_updated(ConnectionDataUsage usage);
        
        /**
         * Signal emitted when connection quality is updated
         */
        public signal void quality_updated(ConnectionQuality quality);
        
        /**
         * Signal emitted when a new network is discovered
         */
        public signal void network_discovered(NM.Device device, string network_id);
        
        /**
         * Signal emitted when a network is lost
         */
        public signal void network_lost(NM.Device device, string network_id);
        
        /**
         * Signal emitted when device availability changes
         */
        public signal void device_availability_changed(NM.Device device, bool available);
        
        /**
         * Signal emitted when performance degradation is detected
         */
        public signal void performance_degraded(string connection_id, string reason);
        
        public bool monitoring_enabled { 
            get { return is_monitoring; } 
        }
        
        public NetworkMonitor(NetworkManagerClient nm_client) {
            this.nm_client = nm_client;
            this.bandwidth_data = new HashTable<string, BandwidthData>(str_hash, str_equal);
            this.usage_data = new HashTable<string, ConnectionDataUsage>(str_hash, str_equal);
            this.quality_data = new HashTable<string, ConnectionQuality>(str_hash, str_equal);
            this.last_rx_bytes = new HashTable<string, uint64?>(str_hash, str_equal);
            this.last_tx_bytes = new HashTable<string, uint64?>(str_hash, str_equal);
            this.last_measurement_time = new HashTable<string, DateTime>(str_hash, str_equal);
            
            this.is_monitoring = false;
            this.monitoring_interval_ms = 2000; // 2 seconds
            this.discovery_interval_ms = 10000; // 10 seconds
            
            // Connect to NetworkManager client signals
            nm_client.device_added.connect(on_device_added);
            nm_client.device_removed.connect(on_device_removed);
            nm_client.device_state_changed.connect(on_device_state_changed);
            nm_client.connection_state_changed.connect(on_connection_state_changed);
        }
        
        /**
         * Start network monitoring and discovery
         */
        public void start_monitoring() {
            if (is_monitoring) {
                debug("NetworkMonitor: Already monitoring");
                return;
            }
            
            debug("NetworkMonitor: Starting network monitoring...");
            is_monitoring = true;
            
            // Initialize monitoring data for existing connections
            initialize_monitoring_data();
            
            // Start periodic monitoring
            monitoring_timer_id = Timeout.add(monitoring_interval_ms, () => {
                update_bandwidth_data();
                update_connection_quality();
                return Source.CONTINUE;
            });
            
            // Start periodic network discovery
            discovery_timer_id = Timeout.add(discovery_interval_ms, () => {
                perform_network_discovery();
                return Source.CONTINUE;
            });
            
            debug("NetworkMonitor: Network monitoring started");
        }
        
        /**
         * Stop network monitoring and discovery
         */
        public void stop_monitoring() {
            if (!is_monitoring) {
                debug("NetworkMonitor: Not currently monitoring");
                return;
            }
            
            debug("NetworkMonitor: Stopping network monitoring...");
            is_monitoring = false;
            
            if (monitoring_timer_id > 0) {
                Source.remove(monitoring_timer_id);
                monitoring_timer_id = 0;
            }
            
            if (discovery_timer_id > 0) {
                Source.remove(discovery_timer_id);
                discovery_timer_id = 0;
            }
            
            debug("NetworkMonitor: Network monitoring stopped");
        }
        
        /**
         * Initialize monitoring data for existing connections
         */
        private void initialize_monitoring_data() {
            if (!nm_client.is_available) return;
            
            var devices = nm_client.get_devices();
            for (uint i = 0; i < devices.length; i++) {
                var device = devices[i];
                if (device.get_state() == NM.DeviceState.ACTIVATED) {
                    initialize_device_monitoring(device);
                }
            }
        }
        
        /**
         * Initialize monitoring for a specific device
         */
        private void initialize_device_monitoring(NM.Device device) {
            var device_id = device.get_iface();
            
            // Initialize bandwidth data
            if (!bandwidth_data.contains(device_id)) {
                bandwidth_data[device_id] = new BandwidthData.with_connection(device_id);
            }
            
            // Initialize usage data
            if (!usage_data.contains(device_id)) {
                usage_data[device_id] = new ConnectionDataUsage(device_id);
            }
            
            // Initialize quality data
            if (!quality_data.contains(device_id)) {
                quality_data[device_id] = new ConnectionQuality(device_id);
            }
            
            // Initialize with placeholder values since direct statistics API is not available
            last_rx_bytes[device_id] = 0;
            last_tx_bytes[device_id] = 0;
            last_measurement_time[device_id] = new DateTime.now_local();
            
            debug("NetworkMonitor: Initialized monitoring for device %s", device_id);
        }
        
        /**
         * Update bandwidth data for all monitored connections
         */
        private void update_bandwidth_data() {
            if (!nm_client.is_available) return;
            
            var devices = nm_client.get_devices();
            for (uint i = 0; i < devices.length; i++) {
                var device = devices[i];
                if (device.get_state() == NM.DeviceState.ACTIVATED) {
                    update_device_bandwidth(device);
                }
            }
        }
        
        /**
         * Update bandwidth data for a specific device
         */
        private void update_device_bandwidth(NM.Device device) {
            var device_id = device.get_iface();
            
            // For now, use placeholder bandwidth monitoring since direct statistics API is not available
            // In a real implementation, this would read from /proc/net/dev or use other system interfaces
            var current_time = new DateTime.now_local();
            
            if (!last_measurement_time.contains(device_id)) {
                // First measurement, just store values
                last_rx_bytes[device_id] = 0;
                last_tx_bytes[device_id] = 0;
                last_measurement_time[device_id] = current_time;
                return;
            }
            
            // Simulate bandwidth data for demonstration
            // In production, this would read actual network statistics
            var bandwidth = bandwidth_data[device_id];
            if (bandwidth == null) {
                bandwidth = new BandwidthData.with_connection(device_id);
                bandwidth_data[device_id] = bandwidth;
            }
            
            // Placeholder values - in real implementation, read from system
            bandwidth.bytes_received = 1024 * 1024; // 1MB placeholder
            bandwidth.bytes_sent = 512 * 1024; // 512KB placeholder
            bandwidth.upload_speed = 500 * 1000; // 500kbps in bytes/sec
            bandwidth.download_speed = 1000 * 1000; // 1Mbps in bytes/sec
            bandwidth.timestamp = current_time;
            
            // Update usage data
            var usage = usage_data[device_id];
            if (usage == null) {
                usage = new ConnectionDataUsage(device_id);
                usage_data[device_id] = usage;
            }
            
            usage.total_bytes = bandwidth.bytes_received + bandwidth.bytes_sent;
            usage.session_bytes += 1024; // Placeholder increment
            
            // Store current values for next calculation
            last_measurement_time[device_id] = current_time;
            
            // Emit signals
            bandwidth_updated(bandwidth);
            usage_updated(usage);
            
            // Check for performance degradation
            check_performance_degradation(device_id, bandwidth);
        }
        
        /**
         * Update connection quality metrics
         */
        private void update_connection_quality() {
            if (!nm_client.is_available) return;
            
            var devices = nm_client.get_devices();
            for (uint i = 0; i < devices.length; i++) {
                var device = devices[i];
                if (device.get_state() == NM.DeviceState.ACTIVATED) {
                    update_device_quality(device);
                }
            }
        }
        
        /**
         * Update quality metrics for a specific device
         */
        private void update_device_quality(NM.Device device) {
            var device_id = device.get_iface();
            
            var quality = quality_data[device_id];
            if (quality == null) {
                quality = new ConnectionQuality(device_id);
                quality_data[device_id] = quality;
            }
            
            // Update signal strength for WiFi devices
            if (device is NM.DeviceWifi) {
                var wifi_device = device as NM.DeviceWifi;
                var active_ap = wifi_device.get_active_access_point();
                if (active_ap != null) {
                    quality.signal_strength = active_ap.get_strength();
                }
            }
            
            // TODO: Implement latency and packet loss measurement
            // This would require additional network tools or ping functionality
            // For now, we'll use placeholder values
            quality.latency_ms = 50; // Placeholder
            quality.packet_loss_percent = 0.0; // Placeholder
            quality.jitter_ms = 5; // Placeholder
            quality.last_updated = new DateTime.now_local();
            
            quality_updated(quality);
        }
        
        /**
         * Perform network discovery to find new networks
         */
        private void perform_network_discovery() {
            if (!nm_client.is_available) return;
            
            debug("NetworkMonitor: Performing network discovery...");
            
            var devices = nm_client.get_devices();
            for (uint i = 0; i < devices.length; i++) {
                var device = devices[i];
                discover_networks_for_device(device);
            }
        }
        
        /**
         * Discover networks for a specific device
         */
        private void discover_networks_for_device(NM.Device device) {
            if (device is NM.DeviceWifi) {
                var wifi_device = device as NM.DeviceWifi;
                
                // Request WiFi scan
                wifi_device.request_scan_async.begin(null, (obj, res) => {
                    try {
                        wifi_device.request_scan_async.end(res);
                        debug("NetworkMonitor: WiFi scan completed for device %s", device.get_iface());
                        
                        // Process discovered access points
                        var access_points = wifi_device.get_access_points();
                        foreach (var ap in access_points) {
                            var ssid_bytes = ap.get_ssid();
                            if (ssid_bytes != null) {
                                var ssid = (string)ssid_bytes.get_data();
                                if (ssid.length > 0) {
                                    network_discovered(device, ssid);
                                }
                            }
                        }
                    } catch (Error e) {
                        debug("NetworkMonitor: WiFi scan failed for device %s: %s", 
                              device.get_iface(), e.message);
                    }
                });
            }
        }
        
        /**
         * Check for performance degradation
         */
        private void check_performance_degradation(string device_id, BandwidthData bandwidth) {
            // Define thresholds for performance degradation
            const uint64 MIN_EXPECTED_SPEED_BPS = 1000000; // 1 Mbps in bytes/sec
            const uint64 VERY_LOW_SPEED_BPS = 100000; // 100 kbps in bytes/sec
            
            var total_speed = bandwidth.get_total_speed();
            
            if (total_speed < VERY_LOW_SPEED_BPS) {
                performance_degraded(device_id, "Very low network speed detected");
            } else if (total_speed < MIN_EXPECTED_SPEED_BPS) {
                performance_degraded(device_id, "Network speed below expected threshold");
            }
        }
        
        /**
         * Handle device added event
         */
        private void on_device_added(NM.Device device) {
            debug("NetworkMonitor: Device added: %s", device.get_iface());
            device_availability_changed(device, true);
            
            if (is_monitoring && device.get_state() == NM.DeviceState.ACTIVATED) {
                initialize_device_monitoring(device);
            }
        }
        
        /**
         * Handle device removed event
         */
        private void on_device_removed(NM.Device device) {
            debug("NetworkMonitor: Device removed: %s", device.get_iface());
            var device_id = device.get_iface();
            
            // Clean up monitoring data
            bandwidth_data.remove(device_id);
            usage_data.remove(device_id);
            quality_data.remove(device_id);
            last_rx_bytes.remove(device_id);
            last_tx_bytes.remove(device_id);
            last_measurement_time.remove(device_id);
            
            device_availability_changed(device, false);
        }
        
        /**
         * Handle device state change event
         */
        private void on_device_state_changed(NM.Device device, NM.DeviceState state, 
                                           NM.DeviceState old_state, NM.DeviceStateReason reason) {
            debug("NetworkMonitor: Device %s state changed: %s -> %s", 
                  device.get_iface(), old_state.to_string(), state.to_string());
            
            if (is_monitoring) {
                if (state == NM.DeviceState.ACTIVATED && old_state != NM.DeviceState.ACTIVATED) {
                    initialize_device_monitoring(device);
                } else if (state != NM.DeviceState.ACTIVATED && old_state == NM.DeviceState.ACTIVATED) {
                    // Device disconnected, clean up monitoring data
                    var device_id = device.get_iface();
                    bandwidth_data.remove(device_id);
                    usage_data.remove(device_id);
                    quality_data.remove(device_id);
                    last_rx_bytes.remove(device_id);
                    last_tx_bytes.remove(device_id);
                    last_measurement_time.remove(device_id);
                }
            }
        }
        
        /**
         * Handle connection state change event
         */
        private void on_connection_state_changed(NM.ActiveConnection connection, 
                                               NM.ActiveConnectionState state, 
                                               NM.ActiveConnectionStateReason reason) {
            debug("NetworkMonitor: Connection %s state changed: %s", 
                  connection.get_id() ?? "unknown", state.to_string());
        }
        
        /**
         * Get bandwidth data for a specific connection
         */
        public BandwidthData? get_bandwidth_data(string connection_id) {
            return bandwidth_data[connection_id];
        }
        
        /**
         * Get usage data for a specific connection
         */
        public ConnectionDataUsage? get_usage_data(string connection_id) {
            return usage_data[connection_id];
        }
        
        /**
         * Get quality data for a specific connection
         */
        public ConnectionQuality? get_quality_data(string connection_id) {
            return quality_data[connection_id];
        }
        
        /**
         * Get all monitored connections
         */
        public List<string> get_monitored_connections() {
            var connections = new List<string>();
            bandwidth_data.foreach((key, value) => {
                connections.append(key);
            });
            return (owned) connections;
        }
        
        /**
         * Reset usage data for a specific connection
         */
        public void reset_usage_data(string connection_id) {
            var usage = usage_data[connection_id];
            if (usage != null) {
                usage.reset_session();
                usage_updated(usage);
            }
        }
        
        /**
         * Set monitoring interval
         */
        public void set_monitoring_interval(uint interval_ms) {
            monitoring_interval_ms = interval_ms;
            
            if (is_monitoring) {
                // Restart monitoring with new interval
                stop_monitoring();
                start_monitoring();
            }
        }
        
        /**
         * Set discovery interval
         */
        public void set_discovery_interval(uint interval_ms) {
            discovery_interval_ms = interval_ms;
            
            if (is_monitoring) {
                // Restart discovery with new interval
                if (discovery_timer_id > 0) {
                    Source.remove(discovery_timer_id);
                }
                
                discovery_timer_id = Timeout.add(discovery_interval_ms, () => {
                    perform_network_discovery();
                    return Source.CONTINUE;
                });
            }
        }
    }
}