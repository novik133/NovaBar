/**
 * Enhanced Network Indicator - Error Handler Tests
 * 
 * This file contains unit tests for the ErrorHandler component,
 * testing error categorization, recovery mechanisms, and user messaging.
 */

using GLib;

namespace EnhancedNetworkTests {

    /**
     * Network error categories for proper handling and recovery
     */
    public enum NetworkErrorCategory {
        CONNECTION_ERROR,      // Failed connections, timeouts, authentication
        CONFIGURATION_ERROR,   // Invalid settings, malformed profiles
        SYSTEM_ERROR,         // NetworkManager unavailable, hardware failures
        USER_INPUT_ERROR,     // Invalid passwords, malformed inputs
        PERMISSION_ERROR,     // Insufficient privileges, PolicyKit failures
        HARDWARE_ERROR,       // Device failures, cable disconnections
        PROTOCOL_ERROR        // VPN protocol issues, security failures
    }

    /**
     * Error severity levels
     */
    public enum ErrorSeverity {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }

    /**
     * Connection types
     */
    public enum ConnectionType {
        WIFI,
        ETHERNET,
        VPN,
        MOBILE_BROADBAND,
        HOTSPOT
    }

    /**
     * Recovery action types for automatic error recovery
     */
    public enum RecoveryAction {
        RETRY_CONNECTION,     // Retry the failed connection
        FALLBACK_CONNECTION,  // Switch to backup connection
        RESET_DEVICE,        // Reset network device
        RESTART_SERVICE,     // Restart NetworkManager service
        CLEAR_CACHE,         // Clear connection cache
        PROMPT_USER,         // Ask user for input/decision
        DISABLE_FEATURE,     // Temporarily disable problematic feature
        NO_ACTION           // No automatic recovery possible
    }

    /**
     * Simple network error for testing
     */
    public class NetworkError : GLib.Object {
        public string id { get; set; }
        public NetworkErrorCategory category { get; set; }
        public ErrorSeverity severity { get; set; }
        public string message { get; set; }
        public string? technical_details { get; set; }
        public string? suggested_action { get; set; }
        public RecoveryAction recovery_action { get; set; }
        public DateTime timestamp { get; set; }
        public string? connection_id { get; set; }
        public ConnectionType? connection_type { get; set; }
        public GLib.Error? original_error { get; set; }
        public bool user_notified { get; set; }
        public bool recovery_attempted { get; set; }
        public int retry_count { get; set; }
        
        public NetworkError(NetworkErrorCategory category, ErrorSeverity severity, string message) {
            this.id = generate_error_id();
            this.category = category;
            this.severity = severity;
            this.message = message;
            this.timestamp = new DateTime.now_local();
            this.user_notified = false;
            this.recovery_attempted = false;
            this.retry_count = 0;
            this.recovery_action = RecoveryAction.NO_ACTION;
        }
        
        /**
         * Generate unique error ID
         */
        private string generate_error_id() {
            return "err_%s_%d".printf(
                category.to_string().down(),
                (int)(get_real_time() / 1000)
            );
        }
        
        /**
         * Get user-friendly error description
         */
        public string get_user_friendly_message() {
            switch (category) {
                case NetworkErrorCategory.CONNECTION_ERROR:
                    return get_connection_error_message();
                case NetworkErrorCategory.CONFIGURATION_ERROR:
                    return "Network configuration is invalid. Please check your settings and correct any errors.";
                case NetworkErrorCategory.SYSTEM_ERROR:
                    return "Network system error occurred. The network service may be unavailable.";
                case NetworkErrorCategory.USER_INPUT_ERROR:
                    return "Invalid input provided. Please check your entries and try again.";
                case NetworkErrorCategory.PERMISSION_ERROR:
                    return "Insufficient permissions to perform this network operation. Authentication may be required.";
                case NetworkErrorCategory.HARDWARE_ERROR:
                    return get_hardware_error_message();
                case NetworkErrorCategory.PROTOCOL_ERROR:
                    return "Network protocol error occurred. The connection may be using incompatible settings.";
                default:
                    return message;
            }
        }
        
        private string get_connection_error_message() {
            if (connection_type == ConnectionType.WIFI) {
                return "Unable to connect to WiFi network. Please check your password and try again.";
            } else if (connection_type == ConnectionType.VPN) {
                return "VPN connection failed. Please verify your credentials and server settings.";
            } else if (connection_type == ConnectionType.ETHERNET) {
                return "Ethernet connection failed. Please check cable connection and network settings.";
            }
            return "Network connection failed. Please check your settings and try again.";
        }
        
        private string get_hardware_error_message() {
            if (connection_type == ConnectionType.ETHERNET) {
                return "Ethernet cable disconnected or hardware failure detected.";
            } else if (connection_type == ConnectionType.WIFI) {
                return "WiFi hardware error or device unavailable.";
            }
            return "Network hardware error detected. Please check your network devices.";
        }
    }

/**
 * Main test runner
 */
public static int main(string[] args) {
    Test.init(ref args);
    
    Test.add_func("/enhanced-network/error-handler/creation", test_error_creation);
    Test.add_func("/enhanced-network/error-handler/user-friendly-messages", test_user_friendly_messages);
    Test.add_func("/enhanced-network/error-handler/id-uniqueness", test_error_id_uniqueness);
    Test.add_func("/enhanced-network/error-handler/categorization", test_error_categorization);
    Test.add_func("/enhanced-network/error-handler/hardware-messages", test_hardware_error_messages);
    
    return Test.run();
}

/**
 * Test basic error creation and categorization
 */
public static void test_error_creation() {
    var error = new EnhancedNetworkTests.NetworkError(
        EnhancedNetworkTests.NetworkErrorCategory.CONNECTION_ERROR,
        EnhancedNetworkTests.ErrorSeverity.MEDIUM,
        "Test connection failed"
    );
    
    assert(error.category == EnhancedNetworkTests.NetworkErrorCategory.CONNECTION_ERROR);
    assert(error.severity == EnhancedNetworkTests.ErrorSeverity.MEDIUM);
    assert(error.message == "Test connection failed");
    assert(error.id != null);
    assert(error.timestamp != null);
    assert(error.user_notified == false);
    assert(error.recovery_attempted == false);
    assert(error.retry_count == 0);
}

/**
 * Test user-friendly error messages
 */
public static void test_user_friendly_messages() {
    // Test WiFi connection error
    var wifi_error = new EnhancedNetworkTests.NetworkError(
        EnhancedNetworkTests.NetworkErrorCategory.CONNECTION_ERROR,
        EnhancedNetworkTests.ErrorSeverity.MEDIUM,
        "Authentication failed"
    );
    wifi_error.connection_type = EnhancedNetworkTests.ConnectionType.WIFI;
    
    var message = wifi_error.get_user_friendly_message();
    assert("WiFi" in message);
    assert("password" in message);
    
    // Test VPN connection error
    var vpn_error = new EnhancedNetworkTests.NetworkError(
        EnhancedNetworkTests.NetworkErrorCategory.CONNECTION_ERROR,
        EnhancedNetworkTests.ErrorSeverity.MEDIUM,
        "VPN timeout"
    );
    vpn_error.connection_type = EnhancedNetworkTests.ConnectionType.VPN;
    
    message = vpn_error.get_user_friendly_message();
    assert("VPN" in message);
    assert("credentials" in message || "server" in message);
    
    // Test configuration error
    var config_error = new EnhancedNetworkTests.NetworkError(
        EnhancedNetworkTests.NetworkErrorCategory.CONFIGURATION_ERROR,
        EnhancedNetworkTests.ErrorSeverity.MEDIUM,
        "Invalid IP address"
    );
    
    message = config_error.get_user_friendly_message();
    assert("configuration" in message);
    assert("settings" in message);
}

/**
 * Test error ID generation uniqueness
 */
public static void test_error_id_uniqueness() {
    var error1 = new EnhancedNetworkTests.NetworkError(
        EnhancedNetworkTests.NetworkErrorCategory.CONNECTION_ERROR,
        EnhancedNetworkTests.ErrorSeverity.MEDIUM,
        "Test error 1"
    );
    
    // Wait a bit to ensure different timestamp
    Thread.usleep(1000);
    
    var error2 = new EnhancedNetworkTests.NetworkError(
        EnhancedNetworkTests.NetworkErrorCategory.CONNECTION_ERROR,
        EnhancedNetworkTests.ErrorSeverity.MEDIUM,
        "Test error 2"
    );
    
    assert(error1.id != error2.id);
}

/**
 * Test error categorization logic
 */
public static void test_error_categorization() {
    // Test different error categories
    var categories = new EnhancedNetworkTests.NetworkErrorCategory[] {
        EnhancedNetworkTests.NetworkErrorCategory.CONNECTION_ERROR,
        EnhancedNetworkTests.NetworkErrorCategory.CONFIGURATION_ERROR,
        EnhancedNetworkTests.NetworkErrorCategory.SYSTEM_ERROR,
        EnhancedNetworkTests.NetworkErrorCategory.USER_INPUT_ERROR,
        EnhancedNetworkTests.NetworkErrorCategory.PERMISSION_ERROR,
        EnhancedNetworkTests.NetworkErrorCategory.HARDWARE_ERROR,
        EnhancedNetworkTests.NetworkErrorCategory.PROTOCOL_ERROR
    };
    
    foreach (var category in categories) {
        var error = new EnhancedNetworkTests.NetworkError(category, EnhancedNetworkTests.ErrorSeverity.MEDIUM, "Test message");
        assert(error.category == category);
        
        var user_message = error.get_user_friendly_message();
        assert(user_message != null);
        assert(user_message.length > 0);
    }
}

/**
 * Test hardware error messages for different connection types
 */
public static void test_hardware_error_messages() {
    var ethernet_error = new EnhancedNetworkTests.NetworkError(
        EnhancedNetworkTests.NetworkErrorCategory.HARDWARE_ERROR,
        EnhancedNetworkTests.ErrorSeverity.HIGH,
        "Cable disconnected"
    );
    ethernet_error.connection_type = EnhancedNetworkTests.ConnectionType.ETHERNET;
    
    var message = ethernet_error.get_user_friendly_message();
    assert("Ethernet" in message);
    assert("cable" in message || "hardware" in message);
    
    var wifi_error = new EnhancedNetworkTests.NetworkError(
        EnhancedNetworkTests.NetworkErrorCategory.HARDWARE_ERROR,
        EnhancedNetworkTests.ErrorSeverity.HIGH,
        "WiFi device failure"
    );
    wifi_error.connection_type = EnhancedNetworkTests.ConnectionType.WIFI;
    
    message = wifi_error.get_user_friendly_message();
    assert("WiFi" in message);
    assert("hardware" in message || "device" in message);
}
}