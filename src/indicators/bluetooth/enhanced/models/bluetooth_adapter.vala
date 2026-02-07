/**
 * Enhanced Bluetooth Indicator - Bluetooth Adapter Model
 * 
 * Represents a Bluetooth adapter (hardware controller) with its properties and state.
 */

namespace EnhancedBluetooth {

    /**
     * Represents a Bluetooth adapter (hardware controller)
     */
    public class BluetoothAdapter : Object {
        // Core properties from BlueZ
        public string object_path { get; set; }
        public string address { get; set; }
        public string alias { get; set; }
        public string name { get; set; }
        public bool powered { get; set; }
        public bool discoverable { get; set; }
        public bool pairable { get; set; }
        public uint32 discoverable_timeout { get; set; }
        public uint32 pairable_timeout { get; set; }
        public bool discovering { get; set; }
        public string[] uuids { get; set; }
        public string modalias { get; set; }

        // Computed properties
        public bool is_default { get; set; }
        public int device_count { get; set; }
        public int connected_device_count { get; set; }

        /**
         * Get display name for the adapter
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
         * Get human-readable status text
         */
        public string get_status_text() {
            if (!powered) {
                return "Off";
            }
            if (discovering) {
                return "Scanning...";
            }
            if (connected_device_count > 0) {
                return "%d device%s connected".printf(
                    connected_device_count,
                    connected_device_count == 1 ? "" : "s"
                );
            }
            return "On";
        }
    }
}
