/**
 * Enhanced Bluetooth Indicator - Error Handler Component
 * 
 * This file implements comprehensive error handling and recovery mechanisms
 * for the enhanced Bluetooth indicator system. It provides error categorization,
 * user-friendly messaging, and diagnostic capabilities.
 */

using GLib;

namespace EnhancedBluetooth {

    /**
     * Comprehensive Error Handler for Enhanced Bluetooth Indicator
     * 
     * This class provides centralized error handling, error categorization,
     * user-friendly error messaging, and diagnostic capabilities for all Bluetooth
     * operations in the enhanced Bluetooth indicator system.
     */
    public class ErrorHandler : Object {
        private GenericArray<BluetoothError> error_history;
        private HashTable<string, BluetoothError> active_errors;
        
        // Configuration constants
        private const uint MAX_ERROR_HISTORY = 100;
        private const uint ERROR_CLEANUP_INTERVAL_MS = 300000; // 5 minutes
        
        /**
         * Signal emitted when an error occurs
         */
        public signal void error_occurred(BluetoothError error);
        
        /**
         * Signal emitted when user notification is required
         */
        public signal void user_notification_required(BluetoothError error);
        
        /**
         * Signal emitted when error is resolved
         */
        public signal void error_resolved(string error_id);
        
        /**
         * Constructor
         */
        public ErrorHandler() {
            error_history = new GenericArray<BluetoothError>();
            active_errors = new HashTable<string, BluetoothError>(str_hash, str_equal);
            
            // Setup periodic error cleanup
            Timeout.add(ERROR_CLEANUP_INTERVAL_MS, cleanup_old_errors);
        }
        
        /**
         * Create and handle an error with full categorization
         */
        public BluetoothError create_error(
            ErrorCategory category,
            string code,
            string message,
            string? details = null
        ) {
            var error = new BluetoothError(category, code, message, details);
            handle_error(error);
            return error;
        }
        
        /**
         * Handle a D-Bus error with automatic categorization
         */
        public BluetoothError handle_dbus_error(Error error, string? context = null) {
            var category = categorize_dbus_error(error);
            var code = extract_error_code(error);
            var message = build_error_message(error, context);
            var details = error.message;
            
            var bt_error = new BluetoothError(category, code, message, details);
            handle_error(bt_error);
            return bt_error;
        }
        
        /**
         * Handle a BlueZ-specific error with automatic categorization
         */
        public BluetoothError handle_bluez_error(Error error, string? operation = null) {
            var category = categorize_bluez_error(error);
            var code = extract_bluez_error_code(error);
            var message = build_bluez_error_message(error, operation);
            var details = error.message;
            
            var bt_error = new BluetoothError(category, code, message, details);
            handle_error(bt_error);
            return bt_error;
        }
        
        /**
         * Handle a timeout error
         */
        public BluetoothError handle_timeout_error(string operation, uint timeout_ms) {
            var message = "Operation timed out: %s".printf(operation);
            var details = "The operation did not complete within %u milliseconds.".printf(timeout_ms);
            
            var error = new BluetoothError(
                ErrorCategory.TIMEOUT_ERROR,
                "TIMEOUT",
                message,
                details
            );
            
            handle_error(error);
            return error;
        }
        
        /**
         * Handle a service unavailable error
         */
        public BluetoothError handle_service_unavailable_error() {
            var error = BluetoothError.service_unavailable();
            handle_error(error);
            return error;
        }
        
        /**
         * Handle a permission error
         */
        public BluetoothError handle_permission_error(string operation, string? action_id = null) {
            var details = action_id != null 
                ? "PolicyKit action: %s".printf(action_id)
                : null;
            
            var error = new BluetoothError(
                ErrorCategory.PERMISSION_ERROR,
                "PERMISSION_DENIED",
                "Permission denied: %s".printf(operation),
                details
            );
            
            handle_error(error);
            return error;
        }
        
        /**
         * Main error handling method
         */
        private void handle_error(BluetoothError error) {
            debug("ErrorHandler: Handling error - %s: %s", 
                  error.category.to_string(), error.message);
            
            // Add to error tracking
            add_error_to_history(error);
            
            var error_id = generate_error_id(error);
            active_errors.insert(error_id, error);
            
            // Log error for diagnostics
            log_error_for_diagnostics(error);
            
            // Emit error signal
            error_occurred(error);
            
            // Emit user notification signal if needed
            if (should_notify_user(error)) {
                user_notification_required(error);
            }
        }
        
        /**
         * Categorize D-Bus errors
         */
        private ErrorCategory categorize_dbus_error(Error error) {
            var error_name = error.message.down();
            
            // Check for common D-Bus error patterns
            if ("timeout" in error_name || "timed out" in error_name) {
                return ErrorCategory.TIMEOUT_ERROR;
            }
            
            if ("service unknown" in error_name || "name has no owner" in error_name) {
                return ErrorCategory.DBUS_ERROR;
            }
            
            if ("not found" in error_name || "unknown" in error_name) {
                return ErrorCategory.DEVICE_ERROR;
            }
            
            if ("permission" in error_name || "access denied" in error_name) {
                return ErrorCategory.PERMISSION_ERROR;
            }
            
            if ("disconnected" in error_name || "connection" in error_name) {
                return ErrorCategory.DBUS_ERROR;
            }
            
            return ErrorCategory.DBUS_ERROR;
        }
        
        /**
         * Categorize BlueZ-specific errors
         */
        private ErrorCategory categorize_bluez_error(Error error) {
            var error_name = error.message.down();
            
            // BlueZ error name patterns
            if ("org.bluez.error.failed" in error_name) {
                return ErrorCategory.DEVICE_ERROR;
            }
            
            if ("org.bluez.error.inprogress" in error_name) {
                return ErrorCategory.DEVICE_ERROR;
            }
            
            if ("org.bluez.error.alreadyconnected" in error_name) {
                return ErrorCategory.CONNECTION_ERROR;
            }
            
            if ("org.bluez.error.notconnected" in error_name) {
                return ErrorCategory.CONNECTION_ERROR;
            }
            
            if ("org.bluez.error.notavailable" in error_name) {
                return ErrorCategory.DEVICE_ERROR;
            }
            
            if ("org.bluez.error.notready" in error_name) {
                return ErrorCategory.ADAPTER_ERROR;
            }
            
            if ("org.bluez.error.authenticationfailed" in error_name ||
                "org.bluez.error.authenticationcanceled" in error_name ||
                "org.bluez.error.authenticationrejected" in error_name ||
                "org.bluez.error.authenticationtimeout" in error_name) {
                return ErrorCategory.PAIRING_ERROR;
            }
            
            if ("org.bluez.error.connectionattemptfailed" in error_name) {
                return ErrorCategory.CONNECTION_ERROR;
            }
            
            if ("org.bluez.error.doesnotexist" in error_name) {
                return ErrorCategory.DEVICE_ERROR;
            }
            
            if ("org.bluez.error.invalidarguments" in error_name) {
                return ErrorCategory.DEVICE_ERROR;
            }
            
            if ("org.bluez.error.notauthorized" in error_name ||
                "org.bluez.error.notpermitted" in error_name) {
                return ErrorCategory.PERMISSION_ERROR;
            }
            
            if ("org.bluez.error.notsupported" in error_name) {
                return ErrorCategory.DEVICE_ERROR;
            }
            
            // Check for pairing-related errors
            if ("pair" in error_name || "bond" in error_name) {
                return ErrorCategory.PAIRING_ERROR;
            }
            
            // Check for connection-related errors
            if ("connect" in error_name) {
                return ErrorCategory.CONNECTION_ERROR;
            }
            
            // Check for adapter-related errors
            if ("adapter" in error_name || "power" in error_name) {
                return ErrorCategory.ADAPTER_ERROR;
            }
            
            // Check for transfer-related errors
            if ("transfer" in error_name || "obex" in error_name) {
                return ErrorCategory.TRANSFER_ERROR;
            }
            
            return ErrorCategory.UNKNOWN_ERROR;
        }
        
        /**
         * Extract error code from GLib.Error
         */
        private string extract_error_code(Error error) {
            // Try to extract a meaningful code from the error domain
            var domain = error.domain.to_string();
            
            if (domain.length > 0) {
                return domain.up();
            }
            
            return "DBUS_ERROR";
        }
        
        /**
         * Extract BlueZ error code
         */
        private string extract_bluez_error_code(Error error) {
            var message = error.message;
            
            // Try to extract BlueZ error name (e.g., "org.bluez.Error.Failed")
            if ("org.bluez.error." in message.down()) {
                var parts = message.split(".");
                if (parts.length > 0) {
                    return parts[parts.length - 1].up();
                }
            }
            
            return "BLUEZ_ERROR";
        }
        
        /**
         * Build user-friendly error message
         */
        private string build_error_message(Error error, string? context) {
            var msg = new StringBuilder();
            
            if (context != null && context.length > 0) {
                msg.append(context);
                msg.append(": ");
            }
            
            // Simplify D-Bus error messages for users
            var error_msg = error.message;
            
            if ("timeout" in error_msg.down()) {
                msg.append("Operation timed out");
            } else if ("not found" in error_msg.down()) {
                msg.append("Resource not found");
            } else if ("permission" in error_msg.down() || "access denied" in error_msg.down()) {
                msg.append("Permission denied");
            } else if ("service unknown" in error_msg.down() || "name has no owner" in error_msg.down()) {
                msg.append("Bluetooth service is not available");
            } else {
                msg.append("D-Bus communication error");
            }
            
            return msg.str;
        }
        
        /**
         * Build user-friendly BlueZ error message
         */
        private string build_bluez_error_message(Error error, string? operation) {
            var msg = new StringBuilder();
            
            if (operation != null && operation.length > 0) {
                msg.append(operation);
                msg.append(" failed: ");
            }
            
            var error_msg = error.message.down();
            
            // Map BlueZ errors to user-friendly messages
            if ("authenticationfailed" in error_msg) {
                msg.append("Authentication failed");
            } else if ("authenticationcanceled" in error_msg) {
                msg.append("Authentication was canceled");
            } else if ("authenticationrejected" in error_msg) {
                msg.append("Authentication was rejected");
            } else if ("authenticationtimeout" in error_msg) {
                msg.append("Authentication timed out");
            } else if ("alreadyconnected" in error_msg) {
                msg.append("Device is already connected");
            } else if ("notconnected" in error_msg) {
                msg.append("Device is not connected");
            } else if ("notavailable" in error_msg) {
                msg.append("Device is not available");
            } else if ("notready" in error_msg) {
                msg.append("Bluetooth adapter is not ready");
            } else if ("connectionattemptfailed" in error_msg) {
                msg.append("Connection attempt failed");
            } else if ("doesnotexist" in error_msg) {
                msg.append("Device does not exist");
            } else if ("notauthorized" in error_msg || "notpermitted" in error_msg) {
                msg.append("Operation not authorized");
            } else if ("notsupported" in error_msg) {
                msg.append("Operation not supported");
            } else if ("inprogress" in error_msg) {
                msg.append("Operation already in progress");
            } else {
                msg.append("Bluetooth operation failed");
            }
            
            return msg.str;
        }
        
        /**
         * Log error for diagnostics and troubleshooting
         */
        private void log_error_for_diagnostics(BluetoothError error) {
            var log_message = "BluetoothError: %s | Category: %s | Code: %s".printf(
                error.message,
                error.category.to_string(),
                error.code
            );
            
            if (error.details != null && error.details.length > 0) {
                log_message += " | Details: %s".printf(error.details);
            }
            
            if (error.recovery_suggestion != null && error.recovery_suggestion.length > 0) {
                log_message += " | Suggestion: %s".printf(error.recovery_suggestion);
            }
            
            // Log based on category severity
            switch (error.category) {
                case ErrorCategory.DBUS_ERROR:
                case ErrorCategory.PERMISSION_ERROR:
                    warning("ErrorHandler: %s", log_message);
                    break;
                
                case ErrorCategory.ADAPTER_ERROR:
                case ErrorCategory.CONNECTION_ERROR:
                    message("ErrorHandler: %s", log_message);
                    break;
                
                default:
                    debug("ErrorHandler: %s", log_message);
                    break;
            }
        }
        
        /**
         * Generate unique error ID
         */
        private string generate_error_id(BluetoothError error) {
            return "bt_err_%s_%lld".printf(
                error.category.to_string().down(),
                (int64)error.occurred.to_unix()
            );
        }
        
        /**
         * Add error to history
         */
        private void add_error_to_history(BluetoothError error) {
            error_history.add(error);
            
            // Maintain history size limit
            while (error_history.length > MAX_ERROR_HISTORY) {
                error_history.remove_index(0);
            }
        }
        
        /**
         * Determine if user should be notified
         */
        private bool should_notify_user(BluetoothError error) {
            // Always notify for critical categories
            switch (error.category) {
                case ErrorCategory.DBUS_ERROR:
                case ErrorCategory.PERMISSION_ERROR:
                case ErrorCategory.ADAPTER_ERROR:
                    return true;
                
                case ErrorCategory.PAIRING_ERROR:
                case ErrorCategory.CONNECTION_ERROR:
                case ErrorCategory.TRANSFER_ERROR:
                    return true;
                
                case ErrorCategory.TIMEOUT_ERROR:
                    return true;
                
                case ErrorCategory.DEVICE_ERROR:
                    // Only notify for device errors if they're not routine
                    return !("not found" in error.message.down());
                
                default:
                    return false;
            }
        }
        
        /**
         * Mark error as resolved
         */
        public void mark_error_resolved(string error_id) {
            if (active_errors.contains(error_id)) {
                active_errors.remove(error_id);
                error_resolved(error_id);
                debug("ErrorHandler: Error resolved: %s", error_id);
            }
        }
        
        /**
         * Get error history for diagnostics
         */
        public GenericArray<BluetoothError> get_error_history() {
            return error_history;
        }
        
        /**
         * Get active errors
         */
        public GenericArray<BluetoothError> get_active_errors() {
            var active = new GenericArray<BluetoothError>();
            active_errors.foreach((key, error) => {
                active.add(error);
            });
            return active;
        }
        
        /**
         * Clear all errors
         */
        public void clear_all_errors() {
            active_errors.remove_all();
            debug("ErrorHandler: All active errors cleared");
        }
        
        /**
         * Clear resolved errors (older than 30 minutes)
         */
        private bool cleanup_old_errors() {
            var cutoff_time = new DateTime.now_local().add_minutes(-30);
            var to_remove = new GenericArray<string>();
            
            active_errors.foreach((key, error) => {
                if (error.occurred.compare(cutoff_time) < 0) {
                    to_remove.add(key);
                }
            });
            
            for (uint i = 0; i < to_remove.length; i++) {
                active_errors.remove(to_remove[i]);
            }
            
            if (to_remove.length > 0) {
                debug("ErrorHandler: Cleaned up %u old errors", to_remove.length);
            }
            
            return true; // Continue periodic cleanup
        }
        
        /**
         * Get error count by category
         */
        public uint get_error_count_by_category(ErrorCategory category) {
            uint count = 0;
            
            active_errors.foreach((key, error) => {
                if (error.category == category) {
                    count++;
                }
            });
            
            return count;
        }
        
        /**
         * Check if there are any active errors
         */
        public bool has_active_errors() {
            return active_errors.size() > 0;
        }
        
        /**
         * Get most recent error
         */
        public BluetoothError? get_most_recent_error() {
            if (error_history.length == 0) {
                return null;
            }
            
            return error_history[error_history.length - 1];
        }
    }
}
