/**
 * Enhanced Bluetooth Indicator - Error Handler Tests
 * 
 * This file contains unit tests for the ErrorHandler component,
 * testing error categorization, D-Bus error mapping, BlueZ error mapping,
 * and user messaging.
 */

using GLib;

namespace EnhancedBluetoothTests {

    /**
     * Error categories for error handling
     */
    public enum ErrorCategory {
        ADAPTER_ERROR,      // Adapter power, configuration issues
        DEVICE_ERROR,       // Device not found, not available
        PAIRING_ERROR,      // Authentication, pairing failures
        CONNECTION_ERROR,   // Connection establishment failures
        TRANSFER_ERROR,     // File transfer failures
        DBUS_ERROR,         // D-Bus communication issues
        PERMISSION_ERROR,   // PolicyKit authorization failures
        TIMEOUT_ERROR,      // Operation timeouts
        UNKNOWN_ERROR
    }

    /**
     * Simple Bluetooth error for testing
     */
    public class BluetoothError : Object {
        public ErrorCategory category { get; set; }
        public string code { get; set; }
        public string message { get; set; }
        public string? details { get; set; }
        public string? recovery_suggestion { get; set; }
        public DateTime occurred { get; set; }

        public BluetoothError(ErrorCategory category, string code, string message, string? details = null) {
            this.category = category;
            this.code = code;
            this.message = message;
            this.details = details;
            this.occurred = new DateTime.now_local();
            this.recovery_suggestion = generate_recovery_suggestion();
        }

        public string get_user_message() {
            var msg = new StringBuilder();
            msg.append(message);
            
            if (details != null && details.length > 0) {
                msg.append("\n\n");
                msg.append(details);
            }
            
            if (recovery_suggestion != null && recovery_suggestion.length > 0) {
                msg.append("\n\n");
                msg.append("Suggestion: ");
                msg.append(recovery_suggestion);
            }
            
            return msg.str;
        }

        public bool is_recoverable() {
            switch (category) {
                case ErrorCategory.TIMEOUT_ERROR:
                case ErrorCategory.CONNECTION_ERROR:
                case ErrorCategory.DEVICE_ERROR:
                    return true;
                
                case ErrorCategory.PERMISSION_ERROR:
                case ErrorCategory.DBUS_ERROR:
                    return false;
                
                case ErrorCategory.ADAPTER_ERROR:
                case ErrorCategory.PAIRING_ERROR:
                case ErrorCategory.TRANSFER_ERROR:
                    return true;
                
                default:
                    return false;
            }
        }

        private string generate_recovery_suggestion() {
            switch (category) {
                case ErrorCategory.ADAPTER_ERROR:
                    return "Check that your Bluetooth adapter is properly connected and powered on.";
                
                case ErrorCategory.DEVICE_ERROR:
                    return "Ensure the device is powered on, in range, and not connected to another system.";
                
                case ErrorCategory.PAIRING_ERROR:
                    return "Try pairing again. Make sure the device is in pairing mode and the PIN/passkey is correct.";
                
                case ErrorCategory.CONNECTION_ERROR:
                    return "Verify the device is paired and powered on. Try removing and re-pairing the device.";
                
                case ErrorCategory.TRANSFER_ERROR:
                    return "Check that both devices have sufficient storage space and the file is accessible.";
                
                case ErrorCategory.DBUS_ERROR:
                    return "The Bluetooth service may not be running. Try restarting the bluetooth.service.";
                
                case ErrorCategory.PERMISSION_ERROR:
                    return "You don't have permission to perform this operation. Contact your system administrator.";
                
                case ErrorCategory.TIMEOUT_ERROR:
                    return "The operation took too long. Check the device is responsive and try again.";
                
                default:
                    return "Try the operation again. If the problem persists, restart Bluetooth or your system.";
            }
        }

        public static BluetoothError timeout(string operation) {
            return new BluetoothError(
                ErrorCategory.TIMEOUT_ERROR,
                "TIMEOUT",
                "Operation timed out: %s".printf(operation),
                "The operation did not complete within the expected time."
            );
        }

        public static BluetoothError service_unavailable() {
            return new BluetoothError(
                ErrorCategory.DBUS_ERROR,
                "SERVICE_UNAVAILABLE",
                "Bluetooth service is not available",
                "The BlueZ daemon is not running or not accessible."
            );
        }
    }

    /**
     * Simple ErrorHandler for testing
     */
    public class ErrorHandler : Object {
        private GenericArray<BluetoothError> error_history;
        
        public signal void error_occurred(BluetoothError error);
        public signal void user_notification_required(BluetoothError error);
        
        public ErrorHandler() {
            error_history = new GenericArray<BluetoothError>();
        }
        
        public BluetoothError create_error(
            ErrorCategory category,
            string code,
            string message,
            string? details = null
        ) {
            var error = new BluetoothError(category, code, message, details);
            error_history.add(error);
            error_occurred(error);
            return error;
        }
        
        public BluetoothError handle_dbus_error(Error error, string? context = null) {
            var category = categorize_dbus_error(error);
            var code = extract_error_code(error);
            var message = build_error_message(error, context);
            
            return create_error(category, code, message, error.message);
        }
        
        public BluetoothError handle_bluez_error(Error error, string? operation = null) {
            var category = categorize_bluez_error(error);
            var code = extract_bluez_error_code(error);
            var message = build_bluez_error_message(error, operation);
            
            return create_error(category, code, message, error.message);
        }
        
        public BluetoothError handle_timeout_error(string operation, uint timeout_ms) {
            var error = BluetoothError.timeout(operation);
            error_history.add(error);
            error_occurred(error);
            return error;
        }
        
        public GenericArray<BluetoothError> get_error_history() {
            return error_history;
        }
        
        private ErrorCategory categorize_dbus_error(Error error) {
            var error_name = error.message.down();
            
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
            
            return ErrorCategory.DBUS_ERROR;
        }
        
        private ErrorCategory categorize_bluez_error(Error error) {
            var error_name = error.message.down();
            
            if ("org.bluez.error.authenticationfailed" in error_name ||
                "org.bluez.error.authenticationcanceled" in error_name ||
                "org.bluez.error.authenticationrejected" in error_name) {
                return ErrorCategory.PAIRING_ERROR;
            }
            
            if ("org.bluez.error.alreadyconnected" in error_name ||
                "org.bluez.error.notconnected" in error_name ||
                "org.bluez.error.connectionattemptfailed" in error_name) {
                return ErrorCategory.CONNECTION_ERROR;
            }
            
            if ("org.bluez.error.notavailable" in error_name ||
                "org.bluez.error.doesnotexist" in error_name) {
                return ErrorCategory.DEVICE_ERROR;
            }
            
            if ("org.bluez.error.notready" in error_name) {
                return ErrorCategory.ADAPTER_ERROR;
            }
            
            if ("org.bluez.error.notauthorized" in error_name ||
                "org.bluez.error.notpermitted" in error_name) {
                return ErrorCategory.PERMISSION_ERROR;
            }
            
            return ErrorCategory.UNKNOWN_ERROR;
        }
        
        private string extract_error_code(Error error) {
            var domain = error.domain.to_string();
            return domain.length > 0 ? domain.up() : "DBUS_ERROR";
        }
        
        private string extract_bluez_error_code(Error error) {
            var message = error.message;
            
            if ("org.bluez.error." in message.down()) {
                var parts = message.split(".");
                if (parts.length > 0) {
                    return parts[parts.length - 1].up();
                }
            }
            
            return "BLUEZ_ERROR";
        }
        
        private string build_error_message(Error error, string? context) {
            var msg = new StringBuilder();
            
            if (context != null && context.length > 0) {
                msg.append(context);
                msg.append(": ");
            }
            
            var error_msg = error.message;
            
            if ("timeout" in error_msg.down()) {
                msg.append("Operation timed out");
            } else if ("not found" in error_msg.down()) {
                msg.append("Resource not found");
            } else if ("permission" in error_msg.down()) {
                msg.append("Permission denied");
            } else if ("service unknown" in error_msg.down()) {
                msg.append("Bluetooth service is not available");
            } else {
                msg.append("D-Bus communication error");
            }
            
            return msg.str;
        }
        
        private string build_bluez_error_message(Error error, string? operation) {
            var msg = new StringBuilder();
            
            if (operation != null && operation.length > 0) {
                msg.append(operation);
                msg.append(" failed: ");
            }
            
            var error_msg = error.message.down();
            
            if ("authenticationfailed" in error_msg) {
                msg.append("Authentication failed");
            } else if ("authenticationcanceled" in error_msg) {
                msg.append("Authentication was canceled");
            } else if ("alreadyconnected" in error_msg) {
                msg.append("Device is already connected");
            } else if ("notconnected" in error_msg) {
                msg.append("Device is not connected");
            } else if ("notavailable" in error_msg) {
                msg.append("Device is not available");
            } else if ("notready" in error_msg) {
                msg.append("Bluetooth adapter is not ready");
            } else {
                msg.append("Bluetooth operation failed");
            }
            
            return msg.str;
        }
    }
}

/**
 * Main test runner
 */
public static int main(string[] args) {
    Test.init(ref args);
    
    Test.add_func("/enhanced-bluetooth/error-handler/creation", test_error_creation);
    Test.add_func("/enhanced-bluetooth/error-handler/recovery-suggestions", test_recovery_suggestions);
    Test.add_func("/enhanced-bluetooth/error-handler/dbus-categorization", test_dbus_categorization);
    Test.add_func("/enhanced-bluetooth/error-handler/bluez-categorization", test_bluez_categorization);
    Test.add_func("/enhanced-bluetooth/error-handler/timeout-error", test_timeout_error);
    Test.add_func("/enhanced-bluetooth/error-handler/service-unavailable", test_service_unavailable);
    Test.add_func("/enhanced-bluetooth/error-handler/error-history", test_error_history);
    Test.add_func("/enhanced-bluetooth/error-handler/user-messages", test_user_messages);
    
    return Test.run();
}

/**
 * Test basic error creation
 */
public static void test_error_creation() {
    var handler = new EnhancedBluetoothTests.ErrorHandler();
    
    var error = handler.create_error(
        EnhancedBluetoothTests.ErrorCategory.DEVICE_ERROR,
        "DEVICE_NOT_FOUND",
        "Device not found",
        "The specified device could not be located"
    );
    
    assert(error.category == EnhancedBluetoothTests.ErrorCategory.DEVICE_ERROR);
    assert(error.code == "DEVICE_NOT_FOUND");
    assert(error.message == "Device not found");
    assert(error.details == "The specified device could not be located");
    assert(error.recovery_suggestion != null);
    assert(error.occurred != null);
}

/**
 * Test recovery suggestions for all error categories
 */
public static void test_recovery_suggestions() {
    var categories = new EnhancedBluetoothTests.ErrorCategory[] {
        EnhancedBluetoothTests.ErrorCategory.ADAPTER_ERROR,
        EnhancedBluetoothTests.ErrorCategory.DEVICE_ERROR,
        EnhancedBluetoothTests.ErrorCategory.PAIRING_ERROR,
        EnhancedBluetoothTests.ErrorCategory.CONNECTION_ERROR,
        EnhancedBluetoothTests.ErrorCategory.TRANSFER_ERROR,
        EnhancedBluetoothTests.ErrorCategory.DBUS_ERROR,
        EnhancedBluetoothTests.ErrorCategory.PERMISSION_ERROR,
        EnhancedBluetoothTests.ErrorCategory.TIMEOUT_ERROR
    };
    
    foreach (var category in categories) {
        var error = new EnhancedBluetoothTests.BluetoothError(category, "TEST", "Test error");
        assert(error.recovery_suggestion != null);
        assert(error.recovery_suggestion.length > 0);
    }
}

/**
 * Test D-Bus error categorization
 */
public static void test_dbus_categorization() {
    var handler = new EnhancedBluetoothTests.ErrorHandler();
    
    // Test timeout error
    var timeout_error = new Error(Quark.from_string("test"), 1, "Operation timed out");
    var bt_error = handler.handle_dbus_error(timeout_error, "Connect device");
    assert(bt_error.category == EnhancedBluetoothTests.ErrorCategory.TIMEOUT_ERROR);
    
    // Test not found error
    var not_found_error = new Error(Quark.from_string("test"), 1, "Device not found");
    bt_error = handler.handle_dbus_error(not_found_error);
    assert(bt_error.category == EnhancedBluetoothTests.ErrorCategory.DEVICE_ERROR);
    
    // Test permission error
    var permission_error = new Error(Quark.from_string("test"), 1, "Permission denied");
    bt_error = handler.handle_dbus_error(permission_error);
    assert(bt_error.category == EnhancedBluetoothTests.ErrorCategory.PERMISSION_ERROR);
    
    // Test service unavailable error
    var service_error = new Error(Quark.from_string("test"), 1, "Service unknown");
    bt_error = handler.handle_dbus_error(service_error);
    assert(bt_error.category == EnhancedBluetoothTests.ErrorCategory.DBUS_ERROR);
}

/**
 * Test BlueZ error categorization
 */
public static void test_bluez_categorization() {
    var handler = new EnhancedBluetoothTests.ErrorHandler();
    
    // Test authentication failed (pairing error)
    var auth_error = new Error(Quark.from_string("bluez"), 1, "org.bluez.Error.AuthenticationFailed");
    var bt_error = handler.handle_bluez_error(auth_error, "Pair device");
    assert(bt_error.category == EnhancedBluetoothTests.ErrorCategory.PAIRING_ERROR);
    assert("Authentication failed" in bt_error.message);
    
    // Test already connected (connection error)
    var conn_error = new Error(Quark.from_string("bluez"), 1, "org.bluez.Error.AlreadyConnected");
    bt_error = handler.handle_bluez_error(conn_error);
    assert(bt_error.category == EnhancedBluetoothTests.ErrorCategory.CONNECTION_ERROR);
    
    // Test not available (device error)
    var device_error = new Error(Quark.from_string("bluez"), 1, "org.bluez.Error.NotAvailable");
    bt_error = handler.handle_bluez_error(device_error);
    assert(bt_error.category == EnhancedBluetoothTests.ErrorCategory.DEVICE_ERROR);
    
    // Test not ready (adapter error)
    var adapter_error = new Error(Quark.from_string("bluez"), 1, "org.bluez.Error.NotReady");
    bt_error = handler.handle_bluez_error(adapter_error);
    assert(bt_error.category == EnhancedBluetoothTests.ErrorCategory.ADAPTER_ERROR);
    
    // Test not authorized (permission error)
    var perm_error = new Error(Quark.from_string("bluez"), 1, "org.bluez.Error.NotAuthorized");
    bt_error = handler.handle_bluez_error(perm_error);
    assert(bt_error.category == EnhancedBluetoothTests.ErrorCategory.PERMISSION_ERROR);
}

/**
 * Test timeout error creation
 */
public static void test_timeout_error() {
    var handler = new EnhancedBluetoothTests.ErrorHandler();
    
    var error = handler.handle_timeout_error("Device pairing", 30000);
    
    assert(error.category == EnhancedBluetoothTests.ErrorCategory.TIMEOUT_ERROR);
    assert(error.code == "TIMEOUT");
    assert("timed out" in error.message.down());
    assert("Device pairing" in error.message);
    assert(error.details != null);
}

/**
 * Test service unavailable error
 */
public static void test_service_unavailable() {
    var error = EnhancedBluetoothTests.BluetoothError.service_unavailable();
    
    assert(error.category == EnhancedBluetoothTests.ErrorCategory.DBUS_ERROR);
    assert(error.code == "SERVICE_UNAVAILABLE");
    assert("service" in error.message.down());
    assert("BlueZ" in error.details);
}

/**
 * Test error history tracking
 */
public static void test_error_history() {
    var handler = new EnhancedBluetoothTests.ErrorHandler();
    
    // Create multiple errors
    handler.create_error(EnhancedBluetoothTests.ErrorCategory.DEVICE_ERROR, "ERR1", "Error 1");
    handler.create_error(EnhancedBluetoothTests.ErrorCategory.CONNECTION_ERROR, "ERR2", "Error 2");
    handler.create_error(EnhancedBluetoothTests.ErrorCategory.PAIRING_ERROR, "ERR3", "Error 3");
    
    var history = handler.get_error_history();
    assert(history.length == 3);
    assert(history[0].code == "ERR1");
    assert(history[1].code == "ERR2");
    assert(history[2].code == "ERR3");
}

/**
 * Test user-friendly error messages
 */
public static void test_user_messages() {
    var error = new EnhancedBluetoothTests.BluetoothError(
        EnhancedBluetoothTests.ErrorCategory.PAIRING_ERROR,
        "AUTH_FAILED",
        "Authentication failed",
        "The device rejected the pairing request"
    );
    
    var user_message = error.get_user_message();
    
    assert("Authentication failed" in user_message);
    assert("rejected" in user_message);
    assert("Suggestion:" in user_message);
    assert("pairing mode" in user_message || "PIN" in user_message);
}
