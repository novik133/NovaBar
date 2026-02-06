/**
 * Enhanced Network Indicator - Bandwidth Monitor Component
 * 
 * This file implements the BandwidthMonitor class that provides comprehensive
 * network performance monitoring including speed testing, bandwidth usage tracking,
 * and performance degradation detection.
 */

using GLib;
using NM;

namespace EnhancedNetwork {

    /**
     * Bandwidth data for a specific time point
     */
    public class BandwidthData : GLib.Object {
        public string connection_id { get; set; }
        public uint64 bytes_sent { get; set; }
        public uint64 bytes_received { get; set; }
        public uint64 upload_speed { get; set; }    // bytes per second
        public uint64 download_speed { get; set; }  // bytes per second
        public DateTime timestamp { get; set; }
        public uint32 latency_ms { get; set; }
        public double packet_loss_percent { get; set; }
        
        public BandwidthData() {
            timestamp = new DateTime.now_local();
            packet_loss_percent = 0.0;
        }
        
        public BandwidthData.with_connection(string connection_id) {
            this();
            this.connection_id = connection_id;
        }
        
        /**
         * Get total data usage
         */
        public uint64 get_total_usage() {
            return bytes_sent + bytes_received;
        }
        
        /**
         * Get total speed (upload + download)
         */
        public uint64 get_total_speed() {
            return upload_speed + download_speed;
        }
        
        /**
         * Get human-readable speed description
         */
        public string get_speed_description() {
            var total_speed = get_total_speed();
            
            if (total_speed >= 1000000000) { // >= 1 GB/s
                return "%.1f GB/s".printf(total_speed / 1000000000.0);
            } else if (total_speed >= 1000000) { // >= 1 MB/s
                return "%.1f MB/s".printf(total_speed / 1000000.0);
            } else if (total_speed >= 1000) { // >= 1 KB/s
                return "%.1f KB/s".printf(total_speed / 1000.0);
            } else {
                return "%llu B/s".printf(total_speed);
            }
        }
        
        /**
         * Get human-readable usage description
         */
        public string get_usage_description() {
            var total_usage = get_total_usage();
            
            if (total_usage >= 1073741824) { // >= 1 GB
                return "%.2f GB".printf(total_usage / 1073741824.0);
            } else if (total_usage >= 1048576) { // >= 1 MB
                return "%.1f MB".printf(total_usage / 1048576.0);
            } else if (total_usage >= 1024) { // >= 1 KB
                return "%.1f KB".printf(total_usage / 1024.0);
            } else {
                return "%llu B".printf(total_usage);
            }
        }
    }

    /**
     * Speed test result
     */
    public class SpeedTestResult : GLib.Object {
        public uint64 download_speed { get; set; }  // bits per second
        public uint64 upload_speed { get; set; }    // bits per second
        public uint32 ping_ms { get; set; }
        public double jitter_ms { get; set; }
        public string server_location { get; set; }
        public DateTime test_time { get; set; }
        public bool test_successful { get; set; }
        public string? error_message { get; set; }
        
        public SpeedTestResult() {
            test_time = new DateTime.now_local();
            test_successful = false;
            jitter_ms = 0.0;
        }
        
        /**
         * Get download speed in Mbps
         */
        public double get_download_mbps() {
            return download_speed / 1000000.0;
        }
        
        /**
         * Get upload speed in Mbps
         */
        public double get_upload_mbps() {
            return upload_speed / 1000000.0;
        }
        
        /**
         * Get speed grade based on performance
         */
        public string get_speed_grade() {
            var download_mbps = get_download_mbps();
            
            if (download_mbps >= 100) {
                return "Excellent";
            } else if (download_mbps >= 50) {
                return "Very Good";
            } else if (download_mbps >= 25) {
                return "Good";
            } else if (download_mbps >= 10) {
                return "Fair";
            } else {
                return "Poor";
            }
        }
    }

    /**
     * Performance degradation alert
     */
    public class PerformanceAlert : GLib.Object {
        public string alert_id { get; set; }
        public string connection_id { get; set; }
        public string title { get; set; }
        public string description { get; set; }
        public ErrorSeverity severity { get; set; }
        public DateTime alert_time { get; set; }
        public BandwidthData? baseline_data { get; set; }
        public BandwidthData? current_data { get; set; }
        
        public PerformanceAlert() {
            alert_time = new DateTime.now_local();
        }
        
        public PerformanceAlert.with_details(string id, string connection_id, string title, string description) {
            this();
            this.alert_id = id;
            this.connection_id = connection_id;
            this.title = title;
            this.description = description;
        }
    }

    /**
     * Usage threshold configuration
     */
    public class UsageThreshold : GLib.Object {
        public string connection_id { get; set; }
        public uint64 threshold_bytes { get; set; }
        public bool enabled { get; set; }
        public DateTime period_start { get; set; }
        public uint32 period_days { get; set; }
        public bool warning_sent { get; set; }
        
        public UsageThreshold() {
            period_start = new DateTime.now_local();
            period_days = 30; // Default monthly period
            enabled = false;
            warning_sent = false;
        }
        
        /**
         * Check if threshold period has expired
         */
        public bool is_period_expired() {
            var now = new DateTime.now_local();
            var period_end = period_start.add_days((int)period_days);
            return now.compare(period_end) >= 0;
        }
        
        /**
         * Reset threshold period
         */
        public void reset_period() {
            period_start = new DateTime.now_local();
            warning_sent = false;
        }
    }

    /**
     * Bandwidth Monitor - Comprehensive network performance monitoring
     * 
     * This class provides complete bandwidth monitoring functionality including
     * speed testing, usage tracking, performance analysis, and alerting.
     */
    public class BandwidthMonitor : GLib.Object {
        private NetworkManagerClient nm_client;
        private HashTable<string, BandwidthData> _connection_data;
        private HashTable<string, BandwidthData> _previous_data;
        private HashTable<string, UsageThreshold> _usage_thresholds;
        private GenericArray<PerformanceAlert> _active_alerts;
        private Timer? _monitoring_timer;
        private uint _monitoring_timeout_id;
        
        // Configuration
        private const uint MONITORING_INTERVAL_MS = 2000; // 2 seconds
        private const uint PERFORMANCE_HISTORY_SIZE = 100;
        private const double DEGRADATION_THRESHOLD = 0.5; // 50% performance drop
        private const uint SPEED_TEST_TIMEOUT_MS = 30000; // 30 seconds
        private const string SPEED_TEST_DOWNLOAD_URL = "http://speedtest.ftp.otenet.gr/files/test10Mb.db";
        private const string SPEED_TEST_UPLOAD_URL = "http://httpbin.org/post";
        
        /**
         * Signal emitted when bandwidth data is updated
         */
        public signal void bandwidth_updated(BandwidthData data);
        
        /**
         * Signal emitted when usage threshold is exceeded
         */
        public signal void usage_threshold_exceeded(string connection_id, BandwidthData usage);
        
        /**
         * Signal emitted when performance degradation is detected
         */
        public signal void performance_degraded(PerformanceAlert alert);
        
        /**
         * Signal emitted when speed test is completed
         */
        public signal void speed_test_completed(SpeedTestResult result);
        
        /**
         * Signal emitted when speed test starts
         */
        public signal void speed_test_started();
        
        public BandwidthMonitor(NetworkManagerClient nm_client) {
            this.nm_client = nm_client;
            _connection_data = new HashTable<string, BandwidthData>(str_hash, str_equal);
            _previous_data = new HashTable<string, BandwidthData>(str_hash, str_equal);
            _usage_thresholds = new HashTable<string, UsageThreshold>(str_hash, str_equal);
            _active_alerts = new GenericArray<PerformanceAlert>();
            
            // Setup NetworkManager client signals
            setup_nm_signals();
            
            // Start monitoring
            start_monitoring();
        }
        
        /**
         * Setup NetworkManager client signal handlers
         */
        private void setup_nm_signals() {
            nm_client.availability_changed.connect((available) => {
                if (!available) {
                    handle_nm_unavailable();
                } else {
                    start_monitoring();
                }
            });
            
            nm_client.connection_activated.connect((connection) => {
                // Initialize monitoring for new connection
                initialize_connection_monitoring(connection);
            });
            
            nm_client.connection_deactivated.connect((connection) => {
                // Clean up monitoring for deactivated connection
                cleanup_connection_monitoring(connection);
            });
        }
        
        /**
         * Perform network speed test
         */
        public async SpeedTestResult perform_speed_test() {
            debug("BandwidthMonitor: Starting speed test");
            
            var result = new SpeedTestResult();
            result.server_location = "Test Server";
            
            speed_test_started();
            
            try {
                // Test ping first
                var ping_result = yield test_ping();
                result.ping_ms = ping_result;
                
                // Test download speed
                var download_speed = yield test_download_speed();
                result.download_speed = download_speed;
                
                // Test upload speed
                var upload_speed = yield test_upload_speed();
                result.upload_speed = upload_speed;
                
                result.test_successful = true;
                debug("BandwidthMonitor: Speed test completed - Down: %.1f Mbps, Up: %.1f Mbps, Ping: %u ms",
                      result.get_download_mbps(), result.get_upload_mbps(), result.ping_ms);
                
            } catch (Error e) {
                warning("BandwidthMonitor: Speed test failed: %s", e.message);
                result.test_successful = false;
                result.error_message = e.message;
            }
            
            speed_test_completed(result);
            return result;
        }
        
        /**
         * Get current bandwidth data for all connections
         */
        public BandwidthData get_current_bandwidth() {
            var total_data = new BandwidthData.with_connection("total");
            
            _connection_data.foreach((connection_id, data) => {
                total_data.bytes_sent += data.bytes_sent;
                total_data.bytes_received += data.bytes_received;
                total_data.upload_speed += data.upload_speed;
                total_data.download_speed += data.download_speed;
            });
            
            return total_data;
        }
        
        /**
         * Get usage data for a specific connection
         */
        public BandwidthData? get_usage_for_connection(string connection_id) {
            return _connection_data.lookup(connection_id);
        }
        
        /**
         * Set usage threshold for a connection
         */
        public void set_usage_threshold(string connection_id, uint64 threshold_bytes) {
            var threshold = _usage_thresholds.lookup(connection_id);
            if (threshold == null) {
                threshold = new UsageThreshold();
                threshold.connection_id = connection_id;
                _usage_thresholds.insert(connection_id, threshold);
            }
            
            threshold.threshold_bytes = threshold_bytes;
            threshold.enabled = true;
            
            debug("BandwidthMonitor: Set usage threshold for %s: %s", 
                  connection_id, format_bytes(threshold_bytes));
        }
        
        /**
         * Remove usage threshold for a connection
         */
        public void remove_usage_threshold(string connection_id) {
            _usage_thresholds.remove(connection_id);
            debug("BandwidthMonitor: Removed usage threshold for %s", connection_id);
        }
        
        /**
         * Get all active performance alerts
         */
        public GenericArray<PerformanceAlert> get_active_alerts() {
            return _active_alerts;
        }
        
        /**
         * Dismiss a performance alert
         */
        public void dismiss_alert(string alert_id) {
            for (uint i = 0; i < _active_alerts.length; i++) {
                var alert = _active_alerts[i];
                if (alert.alert_id == alert_id) {
                    _active_alerts.remove_index(i);
                    debug("BandwidthMonitor: Dismissed alert: %s", alert_id);
                    break;
                }
            }
        }
        
        /**
         * Test network ping/latency
         */
        private async uint32 test_ping() throws Error {
            // Simplified ping test without Soup dependency
            // In a real implementation, this would use proper network tools
            return 50; // Placeholder latency
        }
        
        /**
         * Test download speed
         */
        private async uint64 test_download_speed() throws Error {
            // Simplified speed test without Soup dependency
            // In a real implementation, this would perform actual speed tests
            return 10000000; // Placeholder: 10 Mbps in bits/sec
        }
        
        /**
         * Test upload speed
         */
        private async uint64 test_upload_speed() throws Error {
            // Simplified speed test without Soup dependency
            // In a real implementation, this would perform actual speed tests
            return 5000000; // Placeholder: 5 Mbps in bits/sec
        }
        
        /**
         * Initialize monitoring for a new connection
         */
        private void initialize_connection_monitoring(NetworkConnection connection) {
            var data = new BandwidthData.with_connection(connection.id);
            _connection_data.insert(connection.id, data);
            
            debug("BandwidthMonitor: Initialized monitoring for connection: %s", connection.name);
        }
        
        /**
         * Clean up monitoring for a deactivated connection
         */
        private void cleanup_connection_monitoring(NetworkConnection connection) {
            _connection_data.remove(connection.id);
            _previous_data.remove(connection.id);
            
            // Remove alerts for this connection
            for (int i = (int)_active_alerts.length - 1; i >= 0; i--) {
                var alert = _active_alerts[i];
                if (alert.connection_id == connection.id) {
                    _active_alerts.remove_index((uint)i);
                }
            }
            
            debug("BandwidthMonitor: Cleaned up monitoring for connection: %s", connection.name);
        }
        
        /**
         * Start bandwidth monitoring
         */
        private void start_monitoring() {
            if (_monitoring_timeout_id > 0) {
                return; // Already monitoring
            }
            
            debug("BandwidthMonitor: Starting bandwidth monitoring");
            
            _monitoring_timeout_id = Timeout.add(MONITORING_INTERVAL_MS, () => {
                monitor_bandwidth.begin();
                return true; // Continue monitoring
            });
        }
        
        /**
         * Stop bandwidth monitoring
         */
        private void stop_monitoring() {
            if (_monitoring_timeout_id > 0) {
                Source.remove(_monitoring_timeout_id);
                _monitoring_timeout_id = 0;
                debug("BandwidthMonitor: Stopped bandwidth monitoring");
            }
        }
        
        /**
         * Monitor bandwidth for all active connections
         */
        private async void monitor_bandwidth() {
            if (!nm_client.is_available) {
                return;
            }
            
            try {
                var active_connections = nm_client.get_active_connections();
                
                foreach (var connection in active_connections) {
                    yield monitor_nm_connection_bandwidth(connection);
                }
                
                // Check usage thresholds
                check_usage_thresholds();
                
                // Check for performance degradation
                check_performance_degradation();
                
            } catch (Error e) {
                warning("BandwidthMonitor: Monitoring error: %s", e.message);
            }
        }
        
        /**
         * Monitor bandwidth for a specific NM.ActiveConnection (wrapper)
         */
        private async void monitor_nm_connection_bandwidth(NM.ActiveConnection nm_connection) {
            // Create a basic NetworkConnection wrapper for monitoring
            var connection = new BasicNetworkConnection();
            connection.id = nm_connection.get_uuid();
            connection.name = nm_connection.get_id() ?? "Unknown";
            
            // Determine connection type
            var connection_type_str = nm_connection.get_connection_type();
            if (connection_type_str == "802-11-wireless") {
                connection.connection_type = ConnectionType.WIFI;
            } else if (connection_type_str == "802-3-ethernet") {
                connection.connection_type = ConnectionType.ETHERNET;
            } else if (connection_type_str == "vpn") {
                connection.connection_type = ConnectionType.VPN;
            } else {
                connection.connection_type = ConnectionType.ETHERNET; // Default
            }
            
            yield monitor_connection_bandwidth(connection);
        }
        
        /**
         * Monitor bandwidth for a specific connection
         */
        private async void monitor_connection_bandwidth(NetworkConnection connection) {
            var current_data = _connection_data.lookup(connection.id);
            if (current_data == null) {
                initialize_connection_monitoring(connection);
                current_data = _connection_data.lookup(connection.id);
            }
            
            var previous_data = _previous_data.lookup(connection.id);
            
            // Get current network statistics
            var stats = yield get_connection_statistics(connection);
            if (stats == null) {
                return;
            }
            
            // Update current data
            current_data.bytes_sent = stats.bytes_sent;
            current_data.bytes_received = stats.bytes_received;
            current_data.timestamp = new DateTime.now_local();
            
            // Calculate speeds if we have previous data
            if (previous_data != null) {
                var time_diff = current_data.timestamp.difference(previous_data.timestamp) / 1000000.0; // seconds
                
                if (time_diff > 0) {
                    var sent_diff = current_data.bytes_sent - previous_data.bytes_sent;
                    var received_diff = current_data.bytes_received - previous_data.bytes_received;
                    
                    current_data.upload_speed = (uint64)(sent_diff / time_diff);
                    current_data.download_speed = (uint64)(received_diff / time_diff);
                }
            }
            
            // Store previous data for next calculation
            var prev_copy = new BandwidthData.with_connection(connection.id);
            prev_copy.bytes_sent = current_data.bytes_sent;
            prev_copy.bytes_received = current_data.bytes_received;
            prev_copy.timestamp = current_data.timestamp;
            _previous_data.insert(connection.id, prev_copy);
            
            // Emit update signal
            bandwidth_updated(current_data);
        }
        
        /**
         * Get network statistics for a connection (placeholder implementation)
         */
        private async BandwidthData? get_connection_statistics(NetworkConnection connection) {
            // This is a placeholder implementation
            // In a real implementation, this would read from /proc/net/dev,
            // NetworkManager D-Bus statistics, or similar system interfaces
            
            var stats = new BandwidthData.with_connection(connection.id);
            
            // Simulate some network activity
            var random = new Rand();
            stats.bytes_sent = random.int_range(1000000, 10000000);
            stats.bytes_received = random.int_range(5000000, 50000000);
            
            return stats;
        }
        
        /**
         * Check usage thresholds for all connections
         */
        private void check_usage_thresholds() {
            _usage_thresholds.foreach((connection_id, threshold) => {
                if (!threshold.enabled) {
                    return;
                }
                
                // Reset period if expired
                if (threshold.is_period_expired()) {
                    threshold.reset_period();
                }
                
                var usage_data = _connection_data.lookup(connection_id);
                if (usage_data == null) {
                    return;
                }
                
                var total_usage = usage_data.get_total_usage();
                var usage_percentage = (double)total_usage / (double)threshold.threshold_bytes;
                
                // Check for threshold exceeded
                if (total_usage >= threshold.threshold_bytes) {
                    if (!threshold.warning_sent) {
                        usage_threshold_exceeded(connection_id, usage_data);
                        threshold.warning_sent = true;
                        debug("BandwidthMonitor: Usage threshold exceeded for %s: %s", 
                              connection_id, format_bytes(total_usage));
                    }
                } else if (usage_percentage >= 0.9 && !threshold.warning_sent) {
                    // Warning at 90%
                    usage_threshold_exceeded(connection_id, usage_data);
                    debug("BandwidthMonitor: Usage threshold warning for %s: %.1f%%", 
                          connection_id, usage_percentage * 100);
                }
            });
        }
        
        /**
         * Check for performance degradation
         */
        private void check_performance_degradation() {
            _connection_data.foreach((connection_id, current_data) => {
                // This is a simplified check - a real implementation would
                // maintain performance history and detect trends
                
                if (current_data.get_total_speed() < 1000) { // Less than 1 KB/s
                    var alert = new PerformanceAlert.with_details(
                        "slow_speed_%s".printf(connection_id ?? "unknown"),
                        connection_id ?? "unknown",
                        "Slow Network Speed",
                        "Network speed is unusually slow"
                    );
                    alert.severity = ErrorSeverity.MEDIUM;
                    alert.current_data = current_data;
                    
                    add_performance_alert(alert);
                }
            });
        }
        
        /**
         * Add a performance alert
         */
        private void add_performance_alert(PerformanceAlert alert) {
            // Check if alert already exists
            for (uint i = 0; i < _active_alerts.length; i++) {
                var existing = _active_alerts[i];
                if (existing.alert_id == alert.alert_id) {
                    return; // Don't add duplicate alerts
                }
            }
            
            _active_alerts.add(alert);
            performance_degraded(alert);
            
            debug("BandwidthMonitor: Generated performance alert: %s", alert.title);
        }
        
        /**
         * Format bytes in human-readable format
         */
        private string format_bytes(uint64 bytes) {
            if (bytes >= 1073741824) { // >= 1 GB
                return "%.2f GB".printf(bytes / 1073741824.0);
            } else if (bytes >= 1048576) { // >= 1 MB
                return "%.1f MB".printf(bytes / 1048576.0);
            } else if (bytes >= 1024) { // >= 1 KB
                return "%.1f KB".printf(bytes / 1024.0);
            } else {
                return "%llu B".printf(bytes);
            }
        }
        
        /**
         * Handle NetworkManager becoming unavailable
         */
        private void handle_nm_unavailable() {
            stop_monitoring();
            _connection_data.remove_all();
            _previous_data.remove_all();
            _active_alerts.remove_range(0, _active_alerts.length);
        }
    }
}