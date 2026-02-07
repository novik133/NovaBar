/**
 * Enhanced Bluetooth Indicator - Bluetooth Device Model
 * 
 * Represents a remote Bluetooth device with its properties and state.
 */

namespace EnhancedBluetooth {

    /**
     * Represents a remote Bluetooth device
     */
    public class BluetoothDevice : Object {
        // Core properties from BlueZ
        public string object_path { get; set; }
        public string adapter_path { get; set; }
        public string address { get; set; }
        public string alias { get; set; }
        public string name { get; set; }
        public string icon { get; set; }
        public uint32 device_class { get; set; }
        public uint16 appearance { get; set; }
        public string[] uuids { get; set; }
        public bool paired { get; set; }
        public bool connected { get; set; }
        public bool trusted { get; set; }
        public bool blocked { get; set; }
        public int16 rssi { get; set; }
        public int8 tx_power { get; set; }
        public string modalias { get; set; }

        // Optional properties
        public uint8? battery_percentage { get; set; }
        public bool? services_resolved { get; set; }

        // Computed properties
        public DeviceType device_type { get; set; default = DeviceType.UNKNOWN; }
        public ConnectionState connection_state { get; set; default = ConnectionState.DISCONNECTED; }
        public SignalStrength signal_strength { get; set; default = SignalStrength.WEAK; }
        public DateTime? last_seen { get; set; }

        /**
         * Get display name for the device
         */
        public string get_display_name() {
            if (alias != null && alias.length > 0) {
                return alias;
            }
            if (name != null && name.length > 0) {
                return name;
            }
            return address;
        }

        /**
         * Get icon name based on device type
         */
        public string get_device_type_icon() {
            switch (device_type) {
                case DeviceType.AUDIO:
                    return "audio-headphones-symbolic";
                case DeviceType.INPUT:
                    return "input-keyboard-symbolic";
                case DeviceType.PHONE:
                    return "phone-symbolic";
                case DeviceType.COMPUTER:
                    return "computer-symbolic";
                case DeviceType.PERIPHERAL:
                    return "printer-symbolic";
                case DeviceType.WEARABLE:
                    return "watch-symbolic";
                default:
                    return "bluetooth-symbolic";
            }
        }

        /**
         * Get icon name based on signal strength
         */
        public string get_signal_strength_icon() {
            switch (signal_strength) {
                case SignalStrength.EXCELLENT:
                    return "network-wireless-signal-excellent-symbolic";
                case SignalStrength.GOOD:
                    return "network-wireless-signal-good-symbolic";
                case SignalStrength.FAIR:
                    return "network-wireless-signal-ok-symbolic";
                case SignalStrength.WEAK:
                    return "network-wireless-signal-weak-symbolic";
                case SignalStrength.VERY_WEAK:
                    return "network-wireless-signal-none-symbolic";
                default:
                    return "network-wireless-signal-none-symbolic";
            }
        }

        /**
         * Check if device has audio profile
         */
        public bool has_audio_profile() {
            if (uuids == null) {
                return false;
            }
            
            // Common audio UUIDs
            string[] audio_uuids = {
                "0000110b-0000-1000-8000-00805f9b34fb", // A2DP
                "0000110e-0000-1000-8000-00805f9b34fb", // AVRCP
                "0000111e-0000-1000-8000-00805f9b34fb", // HFP
                "00001108-0000-1000-8000-00805f9b34fb"  // HSP
            };
            
            foreach (var uuid in uuids) {
                if (uuid in audio_uuids) {
                    return true;
                }
            }
            return false;
        }

        /**
         * Check if device has input profile
         */
        public bool has_input_profile() {
            if (uuids == null) {
                return false;
            }
            
            // HID UUID
            string hid_uuid = "00001124-0000-1000-8000-00805f9b34fb";
            return hid_uuid in uuids;
        }

        /**
         * Check if device supports file transfer
         */
        public bool supports_file_transfer() {
            if (uuids == null) {
                return false;
            }
            
            // OBEX Object Push UUID
            string obex_uuid = "00001105-0000-1000-8000-00805f9b34fb";
            return obex_uuid in uuids;
        }

        /**
         * Update signal strength category based on RSSI
         */
        public void update_signal_strength() {
            if (rssi > -50) {
                signal_strength = SignalStrength.EXCELLENT;
            } else if (rssi > -60) {
                signal_strength = SignalStrength.GOOD;
            } else if (rssi > -70) {
                signal_strength = SignalStrength.FAIR;
            } else if (rssi > -80) {
                signal_strength = SignalStrength.WEAK;
            } else {
                signal_strength = SignalStrength.VERY_WEAK;
            }
        }

        /**
         * Update connection state based on connected property
         */
        public void update_connection_state() {
            if (connected) {
                connection_state = ConnectionState.CONNECTED;
            } else {
                connection_state = ConnectionState.DISCONNECTED;
            }
        }
    }
}
