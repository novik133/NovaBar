/**
 * Enhanced Bluetooth Indicator - Bluetooth Error Model
 * 
 * Represents categorized Bluetooth errors with recovery suggestions.
 */

namespace EnhancedBluetooth {

    /**
     * Represents categorized Bluetooth errors
     */
    public class BluetoothError : Object {
        public ErrorCategory category { get; set; }
        public string code { get; set; }
        public string message { get; set; }
        public string? details { get; set; }
        public string? recovery_suggestion { get; set; }
        public DateTime occurred { get; set; }

        /**
         * Constructor
         */
        public BluetoothError(ErrorCategory category, string code, string message, string? details = null) {
            this.category = category;
            this.code = code;
            this.message = message;
            this.details = details;
            this.occurred = new DateTime.now_local();
            this.recovery_suggestion = generate_recovery_suggestion();
        }

        /**
         * Get user-friendly error message
         */
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

        /**
         * Check if error is recoverable
         */
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

        /**
         * Generate recovery suggestion based on error category
         */
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

        /**
         * Get category display name
         */
        public string get_category_name() {
            switch (category) {
                case ErrorCategory.ADAPTER_ERROR:
                    return "Adapter Error";
                case ErrorCategory.DEVICE_ERROR:
                    return "Device Error";
                case ErrorCategory.PAIRING_ERROR:
                    return "Pairing Error";
                case ErrorCategory.CONNECTION_ERROR:
                    return "Connection Error";
                case ErrorCategory.TRANSFER_ERROR:
                    return "Transfer Error";
                case ErrorCategory.DBUS_ERROR:
                    return "Service Error";
                case ErrorCategory.PERMISSION_ERROR:
                    return "Permission Error";
                case ErrorCategory.TIMEOUT_ERROR:
                    return "Timeout Error";
                default:
                    return "Unknown Error";
            }
        }

        /**
         * Create error from GLib.Error
         */
        public static BluetoothError from_gerror(Error error, ErrorCategory? category = null) {
            var cat = category ?? ErrorCategory.UNKNOWN_ERROR;
            return new BluetoothError(cat, error.domain.to_string(), error.message);
        }

        /**
         * Create timeout error
         */
        public static BluetoothError timeout(string operation) {
            return new BluetoothError(
                ErrorCategory.TIMEOUT_ERROR,
                "TIMEOUT",
                "Operation timed out: %s".printf(operation),
                "The operation did not complete within the expected time."
            );
        }

        /**
         * Create service unavailable error
         */
        public static BluetoothError service_unavailable() {
            return new BluetoothError(
                ErrorCategory.DBUS_ERROR,
                "SERVICE_UNAVAILABLE",
                "Bluetooth service is not available",
                "The BlueZ daemon is not running or not accessible."
            );
        }

        /**
         * Create permission denied error
         */
        public static BluetoothError permission_denied(string operation) {
            return new BluetoothError(
                ErrorCategory.PERMISSION_ERROR,
                "PERMISSION_DENIED",
                "Permission denied: %s".printf(operation),
                "You don't have the required permissions to perform this operation."
            );
        }
    }
}
