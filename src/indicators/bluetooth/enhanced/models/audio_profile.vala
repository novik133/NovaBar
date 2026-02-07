/**
 * Enhanced Bluetooth Indicator - Audio Profile Model
 * 
 * Represents an audio profile supported by a Bluetooth device.
 */

namespace EnhancedBluetooth {

    /**
     * Represents an audio profile supported by a device
     */
    public class AudioProfile : Object {
        public string uuid { get; set; }
        public string name { get; set; }
        public AudioProfileType profile_type { get; set; default = AudioProfileType.UNKNOWN; }
        public bool connected { get; set; }
        public string? codec { get; set; }

        /**
         * Get display name for the profile
         */
        public string get_display_name() {
            if (name != null && name.length > 0) {
                return name;
            }
            
            switch (profile_type) {
                case AudioProfileType.A2DP_SINK:
                    return "A2DP (Audio Playback)";
                case AudioProfileType.A2DP_SOURCE:
                    return "A2DP (Audio Recording)";
                case AudioProfileType.HFP:
                    return "Hands-Free";
                case AudioProfileType.HSP:
                    return "Headset";
                case AudioProfileType.AVRCP:
                    return "Remote Control";
                default:
                    return "Unknown Profile";
            }
        }

        /**
         * Get description for the profile
         */
        public string get_description() {
            switch (profile_type) {
                case AudioProfileType.A2DP_SINK:
                    return "High-quality audio playback";
                case AudioProfileType.A2DP_SOURCE:
                    return "High-quality audio recording";
                case AudioProfileType.HFP:
                    return "Phone calls and voice commands";
                case AudioProfileType.HSP:
                    return "Basic headset functionality";
                case AudioProfileType.AVRCP:
                    return "Media playback control";
                default:
                    return "Audio profile";
            }
        }

        /**
         * Create AudioProfile from UUID
         */
        public static AudioProfile? from_uuid(string uuid) {
            var profile = new AudioProfile();
            profile.uuid = uuid;
            
            switch (uuid.down()) {
                case "0000110b-0000-1000-8000-00805f9b34fb":
                    profile.profile_type = AudioProfileType.A2DP_SINK;
                    profile.name = "A2DP Sink";
                    break;
                case "0000110a-0000-1000-8000-00805f9b34fb":
                    profile.profile_type = AudioProfileType.A2DP_SOURCE;
                    profile.name = "A2DP Source";
                    break;
                case "0000111e-0000-1000-8000-00805f9b34fb":
                    profile.profile_type = AudioProfileType.HFP;
                    profile.name = "Hands-Free";
                    break;
                case "00001108-0000-1000-8000-00805f9b34fb":
                    profile.profile_type = AudioProfileType.HSP;
                    profile.name = "Headset";
                    break;
                case "0000110e-0000-1000-8000-00805f9b34fb":
                    profile.profile_type = AudioProfileType.AVRCP;
                    profile.name = "Remote Control";
                    break;
                default:
                    return null;
            }
            
            return profile;
        }
    }
}
