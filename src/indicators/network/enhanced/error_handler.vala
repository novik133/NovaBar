/**
 * Enhanced Network Indicator - Error Handler Component
 * 
 * This file implements comprehensive error handling and recovery mechanisms
 * for the enhanced network indicator system. It provides error categorization,
 * automatic recovery, user-friendly messaging, and diagnostic capabilities.
 */

using GLib;

namespace EnhancedNetwork {

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
     * Comprehensive network error information
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
                    return get_configuration_error_message();
                case NetworkErrorCategory.SYSTEM_ERROR:
                    return get_system_error_message();
                case NetworkErrorCategory.USER_INPUT_ERROR:
                    return get_user_input_error_message();
                case NetworkErrorCategory.PERMISSION_ERROR:
                    return get_permission_error_message();
                case NetworkErrorCategory.HARDWARE_ERROR:
                    return get_hardware_error_message();
                case NetworkErrorCategory.PROTOCOL_ERROR:
                    return get_protocol_error_message();
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
        
        private string get_configuration_error_message() {
            return "Network configuration is invalid. Please check your settings and correct any errors.";
        }
        
        private string get_system_error_message() {
            return "Network system error occurred. The network service may be unavailable.";
        }
        
        private string get_user_input_error_message() {
            return "Invalid input provided. Please check your entries and try again.";
        }
        
        private string get_permission_error_message() {
            return "Insufficient permissions to perform this network operation. Authentication may be required.";
        }
        
        private string get_hardware_error_message() {
            if (connection_type == ConnectionType.ETHERNET) {
                return "Ethernet cable disconnected or hardware failure detected.";
            } else if (connection_type == ConnectionType.WIFI) {
                return "WiFi hardware error or device unavailable.";
            }
            return "Network hardware error detected. Please check your network devices.";
        }
        
        private string get_protocol_error_message() {
            return "Network protocol error occurred. The connection may be using incompatible settings.";
        }
    }

    /**
     * Error recovery result information
     */
    public class RecoveryResult : GLib.Object {
        public bool success { get; set; }
        public RecoveryAction action_taken { get; set; }
        public string? message { get; set; }
        public DateTime timestamp { get; set; }
        
        public RecoveryResult(bool success, RecoveryAction action, string? message = null) {
            this.success = success;
            this.action_taken = action;
            this.message = message;
            this.timestamp = new DateTime.now_local();
        }
    }

    /**
     * Comprehensive Error Handler for Enhanced Network Indicator
     * 
     * This class provides centralized error handling, automatic recovery mechanisms,
     * user-friendly error messaging, and diagnostic capabilities for all network
     * operations in the enhanced network indicator system.
     */
    public class ErrorHandler : GLib.Object {
        private GenericArray<NetworkError> error_history;
        private HashTable<string, NetworkError> active_errors;
        private GLib.Settings? settings;
        private Timer? recovery_timer;
        
        // Configuration constants
        private const uint MAX_ERROR_HISTORY = 100;
        private const uint MAX_RETRY_ATTEMPTS = 3;
        private const uint RECOVERY_DELAY_MS = 2000;
        private const uint ERROR_CLEANUP_INTERVAL_MS = 300000; // 5 minutes
        
        /**
         * Signal emitted when an error occurs
         */
        public signal void error_occurred(NetworkError error);
        
        /**
         * Signal emitted when recovery is attempted
         */
        public signal void recovery_attempted(NetworkError error, RecoveryAction action);
        
        /**
         * Signal emitted when recovery completes
         */
        public signal void recovery_completed(NetworkError error, RecoveryResult result);
        
        /**
         * Signal emitted when user intervention is required
         */
        public signal void user_intervention_required(NetworkError error);
        
        /**
         * Signal emitted when error is resolved
         */
        public signal void error_resolved(NetworkError error);
        
        public ErrorHandler() {
            error_history = new GenericArray<NetworkError>();
            active_errors = new HashTable<string, NetworkError>(str_hash, str_equal);
            
            // Try to load GSettings schema, but don't fail if it's not available
            try {
                var schema_source = GLib.SettingsSchemaSource.get_default();
                if (schema_source != null && schema_source.lookup("org.novadesktop.novabar.network.errors", false) != null) {
                    settings = new GLib.Settings("org.novadesktop.novabar.network.errors");
                    debug("ErrorHandler: GSettings schema loaded successfully");
                } else {
                    settings = null;
                    debug("ErrorHandler: GSettings schema not found, using defaults");
                }
            } catch (Error e) {
                settings = null;
                debug("ErrorHandler: Failed to load GSettings: %s, using defaults", e.message);
            }
            
            // Setup periodic error cleanup
            Timeout.add(ERROR_CLEANUP_INTERVAL_MS, cleanup_old_errors);
        }
        
        /**
         * Handle a connection error with automatic categorization and recovery
         */
        public async bool handle_connection_error(GLib.Error error, string? connection_id = null, ConnectionType? connection_type = null) {
            var network_error = categorize_connection_error(error, connection_id, connection_type);
            return yield handle_error(network_error);
        }
        
        /**
         * Handle a configuration error
         */
        public async bool handle_configuration_error(string message, string? connection_id = null, string? technical_details = null) {
            var network_error = new NetworkError(
                NetworkErrorCategory.CONFIGURATION_ERROR,
                ErrorSeverity.MEDIUM,
                message
            );
            network_error.connection_id = connection_id;
            network_error.technical_details = technical_details;
            network_error.recovery_action = RecoveryAction.PROMPT_USER;
            
            return yield handle_error(network_error);
        }
        
        /**
         * Handle a system error (NetworkManager unavailable, etc.)
         */
        public async bool handle_system_error(string message, ErrorSeverity severity = ErrorSeverity.HIGH) {
            var network_error = new NetworkError(
                NetworkErrorCategory.SYSTEM_ERROR,
                severity,
                message
            );
            network_error.recovery_action = determine_system_recovery_action(message);
            
            return yield handle_error(network_error);
        }
        
        /**
         * Handle user input validation error
         */
        public bool handle_user_input_error(string message, string? field_name = null) {
            var network_error = new NetworkError(
                NetworkErrorCategory.USER_INPUT_ERROR,
                ErrorSeverity.LOW,
                message
            );
            network_error.technical_details = field_name != null ? "Field: %s".printf(field_name) : null;
            network_error.recovery_action = RecoveryAction.PROMPT_USER;
            
            // User input errors are handled synchronously
            handle_error.begin(network_error);
            return false; // Always return false for input validation
        }
        
        /**
         * Handle permission/PolicyKit error
         */
        public async bool handle_permission_error(string message, string? action_id = null) {
            var network_error = new NetworkError(
                NetworkErrorCategory.PERMISSION_ERROR,
                ErrorSeverity.MEDIUM,
                message
            );
            network_error.technical_details = action_id != null ? "Action: %s".printf(action_id) : null;
            network_error.recovery_action = RecoveryAction.PROMPT_USER;
            
            return yield handle_error(network_error);
        }
        
        /**
         * Handle hardware error (cable disconnection, device failure)
         */
        public async bool handle_hardware_error(string message, ConnectionType? connection_type = null, string? device_name = null) {
            var network_error = new NetworkError(
                NetworkErrorCategory.HARDWARE_ERROR,
                ErrorSeverity.HIGH,
                message
            );
            network_error.connection_type = connection_type;
            network_error.technical_details = device_name != null ? "Device: %s".printf(device_name) : null;
            network_error.recovery_action = determine_hardware_recovery_action(connection_type);
            
            return yield handle_error(network_error);
        }
        
        /**
         * Main error handling method
         */
        private async bool handle_error(NetworkError error) {
            debug("ErrorHandler: Handling error - %s: %s", error.category.to_string(), error.message);
            
            // Add to error tracking
            add_error_to_history(error);
            active_errors.insert(error.id, error);
            
            // Emit error signal
            error_occurred(error);
            
            // Attempt automatic recovery if configured
            var recovery_enabled = settings != null ? settings.get_boolean("enable-automatic-recovery") : true;
            if (recovery_enabled && error.recovery_action != RecoveryAction.NO_ACTION) {
                var recovery_result = yield attempt_automatic_recovery(error);
                
                if (recovery_result.success) {
                    mark_error_resolved(error);
                    return true;
                } else if (error.retry_count < MAX_RETRY_ATTEMPTS) {
                    // Schedule retry
                    Timeout.add(RECOVERY_DELAY_MS, () => {
                        attempt_automatic_recovery.begin(error);
                        return false;
                    });
                }
            }
            
            // Show user notification if required
            if (should_notify_user(error)) {
                show_user_error_dialog(error);
            }
            
            return false;
        }
        
        /**
         * Attempt automatic recovery for an error
         */
        public async RecoveryResult attempt_automatic_recovery(NetworkError error) {
            debug("ErrorHandler: Attempting recovery for error %s with action %s", 
                  error.id, error.recovery_action.to_string());
            
            error.recovery_attempted = true;
            error.retry_count++;
            
            recovery_attempted(error, error.recovery_action);
            
            RecoveryResult result;
            
            try {
                switch (error.recovery_action) {
                    case RecoveryAction.RETRY_CONNECTION:
                        result = yield retry_connection_recovery(error);
                        break;
                    case RecoveryAction.FALLBACK_CONNECTION:
                        result = yield fallback_connection_recovery(error);
                        break;
                    case RecoveryAction.RESET_DEVICE:
                        result = yield reset_device_recovery(error);
                        break;
                    case RecoveryAction.RESTART_SERVICE:
                        result = yield restart_service_recovery(error);
                        break;
                    case RecoveryAction.CLEAR_CACHE:
                        result = yield clear_cache_recovery(error);
                        break;
                    case RecoveryAction.PROMPT_USER:
                        result = prompt_user_recovery(error);
                        break;
                    case RecoveryAction.DISABLE_FEATURE:
                        result = disable_feature_recovery(error);
                        break;
                    default:
                        result = new RecoveryResult(false, RecoveryAction.NO_ACTION, "No recovery action available");
                        break;
                }
            } catch (Error e) {
                warning("ErrorHandler: Recovery attempt failed: %s", e.message);
                result = new RecoveryResult(false, error.recovery_action, e.message);
            }
            
            recovery_completed(error, result);
            
            if (result.success) {
                mark_error_resolved(error);
            }
            
            return result;
        }
        
        /**
         * Show user-friendly error dialog
         */
        public void show_user_error_dialog(NetworkError error) {
            error.user_notified = true;
            
            var message = error.get_user_friendly_message();
            var severity = error.severity;
            
            debug("ErrorHandler: Showing user dialog - %s: %s", severity.to_string(), message);
            
            // In a real implementation, this would show a GTK dialog
            // For now, we'll emit a signal that the UI can handle
            user_intervention_required(error);
        }
        
        /**
         * Log error for diagnostics and troubleshooting
         */
        public void log_error_for_diagnostics(NetworkError error) {
            var log_message = "NetworkError[%s]: %s | Category: %s | Severity: %s | Connection: %s | Type: %s".printf(
                error.id,
                error.message,
                error.category.to_string(),
                error.severity.to_string(),
                error.connection_id ?? "unknown",
                error.connection_type != null ? error.connection_type.to_string() : "unknown"
            );
            
            if (error.technical_details != null) {
                log_message += " | Details: %s".printf(error.technical_details);
            }
            
            // Log based on severity
            switch (error.severity) {
                case ErrorSeverity.CRITICAL:
                    critical("ErrorHandler: %s", log_message);
                    break;
                case ErrorSeverity.HIGH:
                    warning("ErrorHandler: %s", log_message);
                    break;
                case ErrorSeverity.MEDIUM:
                    message("ErrorHandler: %s", log_message);
                    break;
                case ErrorSeverity.LOW:
                    debug("ErrorHandler: %s", log_message);
                    break;
            }
        }
        
        /**
         * Get error history for diagnostics
         */
        public GenericArray<NetworkError> get_error_history() {
            return error_history;
        }
        
        /**
         * Get active errors
         */
        public GenericArray<NetworkError> get_active_errors() {
            var active = new GenericArray<NetworkError>();
            active_errors.foreach((key, error) => {
                active.add(error);
            });
            return active;
        }
        
        /**
         * Clear resolved errors
         */
        public void clear_resolved_errors() {
            var to_remove = new GenericArray<string>();
            
            active_errors.foreach((key, error) => {
                if (error.user_notified && error.recovery_attempted) {
                    to_remove.add(key);
                }
            });
            
            for (uint i = 0; i < to_remove.length; i++) {
                active_errors.remove(to_remove[i]);
            }
        }
        
        // Private helper methods
        
        private NetworkError categorize_connection_error(GLib.Error error, string? connection_id, ConnectionType? connection_type) {
            var category = NetworkErrorCategory.CONNECTION_ERROR;
            var severity = ErrorSeverity.MEDIUM;
            var recovery_action = RecoveryAction.RETRY_CONNECTION;
            
            // Analyze error message to determine specifics
            var error_message = (error.message ?? "").down();
            
            if ("timeout" in error_message || "timed out" in error_message) {
                severity = ErrorSeverity.MEDIUM;
                recovery_action = RecoveryAction.RETRY_CONNECTION;
            } else if ("authentication" in error_message || "password" in error_message) {
                severity = ErrorSeverity.MEDIUM;
                recovery_action = RecoveryAction.PROMPT_USER;
            } else if ("permission" in error_message || "not authorized" in error_message) {
                category = NetworkErrorCategory.PERMISSION_ERROR;
                recovery_action = RecoveryAction.PROMPT_USER;
            } else if ("not found" in error_message || "unavailable" in error_message) {
                category = NetworkErrorCategory.SYSTEM_ERROR;
                severity = ErrorSeverity.HIGH;
                recovery_action = RecoveryAction.FALLBACK_CONNECTION;
            }
            
            var network_error = new NetworkError(category, severity, error.message);
            network_error.connection_id = connection_id;
            network_error.connection_type = connection_type;
            network_error.original_error = error;
            network_error.recovery_action = recovery_action;
            
            return network_error;
        }
        
        private RecoveryAction determine_system_recovery_action(string message) {
            var msg = message.down();
            
            if ("networkmanager" in msg) {
                return RecoveryAction.RESTART_SERVICE;
            } else if ("device" in msg || "hardware" in msg) {
                return RecoveryAction.RESET_DEVICE;
            } else if ("cache" in msg || "profile" in msg) {
                return RecoveryAction.CLEAR_CACHE;
            }
            
            return RecoveryAction.PROMPT_USER;
        }
        
        private RecoveryAction determine_hardware_recovery_action(ConnectionType? connection_type) {
            if (connection_type == ConnectionType.ETHERNET) {
                return RecoveryAction.FALLBACK_CONNECTION; // Try WiFi
            } else if (connection_type == ConnectionType.WIFI) {
                return RecoveryAction.RESET_DEVICE;
            }
            
            return RecoveryAction.PROMPT_USER;
        }
        
        private void add_error_to_history(NetworkError error) {
            error_history.add(error);
            
            // Maintain history size limit
            while (error_history.length > MAX_ERROR_HISTORY) {
                error_history.remove_index(0);
            }
            
            // Log for diagnostics
            log_error_for_diagnostics(error);
        }
        
        private bool should_notify_user(NetworkError error) {
            // Don't spam user with notifications
            if (error.user_notified) {
                return false;
            }
            
            // Always notify for critical and high severity errors
            if (error.severity == ErrorSeverity.CRITICAL || error.severity == ErrorSeverity.HIGH) {
                return true;
            }
            
            // Notify for medium severity if user notifications are enabled
            if (error.severity == ErrorSeverity.MEDIUM) {
                return settings != null ? settings.get_boolean("show-medium-severity-notifications") : true;
            }
            
            // Don't notify for low severity errors by default
            return false;
        }
        
        private void mark_error_resolved(NetworkError error) {
            active_errors.remove(error.id);
            error_resolved(error);
            debug("ErrorHandler: Error resolved: %s", error.id);
        }
        
        private bool cleanup_old_errors() {
            var cutoff_time = new DateTime.now_local().add_minutes(-30);
            var to_remove = new GenericArray<string>();
            
            active_errors.foreach((key, error) => {
                if (error.timestamp.compare(cutoff_time) < 0 && error.user_notified) {
                    to_remove.add(key);
                }
            });
            
            for (uint i = 0; i < to_remove.length; i++) {
                active_errors.remove(to_remove[i]);
            }
            
            return true; // Continue periodic cleanup
        }
        
        // Recovery action implementations
        
        private async RecoveryResult retry_connection_recovery(NetworkError error) {
            // This would integrate with the appropriate manager to retry the connection
            debug("ErrorHandler: Retrying connection for error %s", error.id);
            
            // Simulate recovery attempt
            yield wait_async(1000);
            
            // In a real implementation, this would call the appropriate manager's retry method
            return new RecoveryResult(false, RecoveryAction.RETRY_CONNECTION, "Retry not yet implemented");
        }
        
        private async RecoveryResult fallback_connection_recovery(NetworkError error) {
            debug("ErrorHandler: Attempting fallback connection for error %s", error.id);
            
            yield wait_async(1000);
            
            return new RecoveryResult(false, RecoveryAction.FALLBACK_CONNECTION, "Fallback not yet implemented");
        }
        
        private async RecoveryResult reset_device_recovery(NetworkError error) {
            debug("ErrorHandler: Resetting device for error %s", error.id);
            
            yield wait_async(2000);
            
            return new RecoveryResult(false, RecoveryAction.RESET_DEVICE, "Device reset not yet implemented");
        }
        
        private async RecoveryResult restart_service_recovery(NetworkError error) {
            debug("ErrorHandler: Restarting service for error %s", error.id);
            
            yield wait_async(3000);
            
            return new RecoveryResult(false, RecoveryAction.RESTART_SERVICE, "Service restart not yet implemented");
        }
        
        private async RecoveryResult clear_cache_recovery(NetworkError error) {
            debug("ErrorHandler: Clearing cache for error %s", error.id);
            
            yield wait_async(500);
            
            return new RecoveryResult(true, RecoveryAction.CLEAR_CACHE, "Cache cleared successfully");
        }
        
        private RecoveryResult prompt_user_recovery(NetworkError error) {
            debug("ErrorHandler: Prompting user for error %s", error.id);
            
            user_intervention_required(error);
            
            return new RecoveryResult(false, RecoveryAction.PROMPT_USER, "User intervention required");
        }
        
        private RecoveryResult disable_feature_recovery(NetworkError error) {
            debug("ErrorHandler: Disabling feature for error %s", error.id);
            
            return new RecoveryResult(true, RecoveryAction.DISABLE_FEATURE, "Feature temporarily disabled");
        }
        
        /**
         * Utility method for async delays
         */
        private async void wait_async(uint milliseconds) {
            Timeout.add(milliseconds, () => {
                wait_async.callback();
                return false;
            });
            yield;
        }
    }
}