/**
 * Enhanced Bluetooth Indicator - Pairing Request Model
 * 
 * Represents a pairing authentication request from a device.
 */

namespace EnhancedBluetooth {

    /**
     * Represents a pairing authentication request
     */
    public class PairingRequest : Object {
        public string device_path { get; set; }
        public string device_name { get; set; }
        public PairingMethod method { get; set; }
        public uint32? passkey { get; set; }
        public string? pin_code { get; set; }
        public DateTime requested { get; set; }

        // Response handling
        public signal void response_provided(bool accepted, string? value);

        /**
         * Constructor
         */
        public PairingRequest() {
            requested = new DateTime.now_local();
        }

        /**
         * Get prompt text for the user
         */
        public string get_prompt_text() {
            switch (method) {
                case PairingMethod.PIN_CODE:
                    return "Enter PIN code to pair with %s".printf(device_name);
                
                case PairingMethod.PASSKEY_ENTRY:
                    return "Enter the passkey displayed on %s".printf(device_name);
                
                case PairingMethod.PASSKEY_DISPLAY:
                    return "Confirm this passkey is displayed on %s:\n%06u".printf(
                        device_name,
                        passkey ?? 0
                    );
                
                case PairingMethod.PASSKEY_CONFIRMATION:
                    return "Does %s show passkey %06u?".printf(
                        device_name,
                        passkey ?? 0
                    );
                
                case PairingMethod.AUTHORIZATION:
                    return "Authorize pairing with %s?".printf(device_name);
                
                case PairingMethod.SERVICE_AUTHORIZATION:
                    return "Authorize service access for %s?".printf(device_name);
                
                default:
                    return "Pair with %s?".printf(device_name);
            }
        }

        /**
         * Check if this pairing method requires user input
         */
        public bool requires_user_input() {
            return method == PairingMethod.PIN_CODE || 
                   method == PairingMethod.PASSKEY_ENTRY;
        }

        /**
         * Get dialog title based on method
         */
        public string get_dialog_title() {
            switch (method) {
                case PairingMethod.PIN_CODE:
                    return "Enter PIN Code";
                case PairingMethod.PASSKEY_ENTRY:
                    return "Enter Passkey";
                case PairingMethod.PASSKEY_DISPLAY:
                case PairingMethod.PASSKEY_CONFIRMATION:
                    return "Confirm Passkey";
                case PairingMethod.AUTHORIZATION:
                case PairingMethod.SERVICE_AUTHORIZATION:
                    return "Authorize Pairing";
                default:
                    return "Bluetooth Pairing";
            }
        }

        /**
         * Get button labels for the dialog
         */
        public void get_button_labels(out string accept_label, out string reject_label) {
            switch (method) {
                case PairingMethod.PIN_CODE:
                case PairingMethod.PASSKEY_ENTRY:
                    accept_label = "Pair";
                    reject_label = "Cancel";
                    break;
                
                case PairingMethod.PASSKEY_DISPLAY:
                case PairingMethod.PASSKEY_CONFIRMATION:
                case PairingMethod.AUTHORIZATION:
                case PairingMethod.SERVICE_AUTHORIZATION:
                    accept_label = "Confirm";
                    reject_label = "Reject";
                    break;
                
                default:
                    accept_label = "Accept";
                    reject_label = "Reject";
                    break;
            }
        }
    }
}
