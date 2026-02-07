/**
 * Enhanced Bluetooth Indicator - Audio Manager
 * 
 * Manages audio device profiles and routing for Bluetooth audio devices.
 */

using GLib;

namespace EnhancedBluetooth {

    /**
     * Audio Manager for Bluetooth audio device profile management
     * 
     * This class handles audio profile detection, profile management,
     * and audio device monitoring for Bluetooth audio devices.
     */
    public class AudioManager : Object {
        // D-Bus constants
        private const string DEVICE_INTERFACE = "org.bluez.Device1";
        
        // Audio profile UUIDs
        private const string A2DP_SINK_UUID = "0000110b-0000-1000-8000-00805f9b34fb";
        private const string A2DP_SOURCE_UUID = "0000110a-0000-1000-8000-00805f9b34fb";
        private const string HFP_UUID = "0000111e-0000-1000-8000-00805f9b34fb";
        private const string HSP_UUID = "00001108-0000-1000-8000-00805f9b34fb";
        private const string AVRCP_UUID = "0000110e-0000-1000-8000-00805f9b34fb";
        
        // BlueZ client reference
        private BlueZClient client;
        
        // Device profiles storage: device_path -> list of AudioProfile
        private HashTable<string, GenericArray<AudioProfile>> device_profiles;
        
        // Connected audio devices tracking
        private HashTable<string, bool> connected_audio_devices;
        
        // Initialization state
        private bool is_initialized;
        
        /**
         * Signal emitted when an audio device connects
         */
        public signal void audio_device_connected(string device_path, string profile);
        
        /**
         * Signal emitted when an audio device disconnects
         */
        public signal void audio_device_disconnected(string device_path);
        
        /**
         * Signal emitted when the active profile changes
         */
        public signal void profile_changed(string device_path, string profile);
        
        /**
         * Constructor
         */
        public AudioManager() {
            device_profiles = new HashTable<string, GenericArray<AudioProfile>>(str_hash, str_equal);
            connected_audio_devices = new HashTable<string, bool>(str_hash, str_equal);
            is_initialized = false;
        }
        
        /**
         * Initialize the audio manager with a BlueZ client
         * 
         * @param client The BlueZ D-Bus client
         */
        public async void initialize(BlueZClient client) throws Error {
            if (is_initialized) {
                warning("AudioManager: Already initialized");
                return;
            }
            
            debug("AudioManager: Initializing...");
            
            this.client = client;
            
            // Subscribe to BlueZ object events
            client.object_added.connect(on_object_added);
            client.object_removed.connect(on_object_removed);
            client.properties_changed.connect(on_properties_changed);
            
            // Scan for existing audio devices
            yield scan_audio_devices();
            
            is_initialized = true;
            debug("AudioManager: Initialization complete");
        }
        
        /**
         * Shutdown the audio manager
         */
        public void shutdown() {
            debug("AudioManager: Shutting down...");
            
            // Clear data
            device_profiles.remove_all();
            connected_audio_devices.remove_all();
            
            is_initialized = false;
            debug("AudioManager: Shutdown complete");
        }
        
        /**
         * Scan for existing audio devices
         */
        private async void scan_audio_devices() throws Error {
            debug("AudioManager: Scanning for existing audio devices...");
            
            var device_paths = client.get_objects_by_interface(DEVICE_INTERFACE);
            
            for (uint i = 0; i < device_paths.length; i++) {
                try {
                    yield detect_profiles(device_paths[i]);
                } catch (Error e) {
                    warning("AudioManager: Failed to detect profiles for %s: %s", 
                            device_paths[i], e.message);
                }
            }
            
            debug("AudioManager: Found %u audio devices", device_profiles.size());
        }
        
        /**
         * Detect audio profiles for a device
         * 
         * @param device_path The D-Bus object path of the device
         */
        public async void detect_profiles(string device_path) throws Error {
            debug("AudioManager: Detecting profiles for device %s", device_path);
            
            // Get device UUIDs
            Variant uuids_variant;
            try {
                uuids_variant = yield client.get_property(
                    device_path,
                    DEVICE_INTERFACE,
                    "UUIDs"
                );
            } catch (Error e) {
                debug("AudioManager: Failed to get UUIDs for %s: %s", device_path, e.message);
                return;
            }
            
            // Parse UUIDs
            string[] uuids = {};
            var iter = uuids_variant.iterator();
            string? uuid_str = null;
            while (iter.next("s", &uuid_str)) {
                if (uuid_str != null) {
                    uuids += uuid_str;
                }
            }
            
            // Map UUIDs to AudioProfile objects
            var profiles = new GenericArray<AudioProfile>();
            
            foreach (var uuid in uuids) {
                var profile = map_uuid_to_profile(uuid);
                if (profile != null) {
                    profiles.add(profile);
                }
            }
            
            // Store profiles if any audio profiles found
            if (profiles.length > 0) {
                device_profiles[device_path] = profiles;
                debug("AudioManager: Device %s has %u audio profiles", 
                      device_path, profiles.length);
            }
        }
        
        /**
         * Map a UUID to an AudioProfile object
         * 
         * @param uuid The Bluetooth service UUID
         * @return AudioProfile object or null if not an audio UUID
         */
        private AudioProfile? map_uuid_to_profile(string uuid) {
            var normalized_uuid = uuid.down();
            
            switch (normalized_uuid) {
                case A2DP_SINK_UUID:
                    return create_profile(uuid, AudioProfileType.A2DP_SINK, "A2DP Sink");
                    
                case A2DP_SOURCE_UUID:
                    return create_profile(uuid, AudioProfileType.A2DP_SOURCE, "A2DP Source");
                    
                case HFP_UUID:
                    return create_profile(uuid, AudioProfileType.HFP, "Hands-Free");
                    
                case HSP_UUID:
                    return create_profile(uuid, AudioProfileType.HSP, "Headset");
                    
                case AVRCP_UUID:
                    return create_profile(uuid, AudioProfileType.AVRCP, "Remote Control");
                    
                default:
                    return null;
            }
        }
        
        /**
         * Create an AudioProfile object
         */
        private AudioProfile create_profile(string uuid, AudioProfileType type, string name) {
            var profile = new AudioProfile();
            profile.uuid = uuid;
            profile.profile_type = type;
            profile.name = name;
            profile.connected = false;
            return profile;
        }
        
        /**
         * Get audio profiles for a device
         * 
         * @param device_path The D-Bus object path of the device
         * @return List of AudioProfile objects
         */
        public GenericArray<AudioProfile> get_profiles(string device_path) {
            var profiles = device_profiles[device_path];
            if (profiles == null) {
                return new GenericArray<AudioProfile>();
            }
            return profiles;
        }
        
        /**
         * Connect to a specific audio profile
         * 
         * @param device_path The D-Bus object path of the device
         * @param profile_uuid The UUID of the profile to connect
         */
        public async void connect_profile(string device_path, string profile_uuid) throws Error {
            debug("AudioManager: Connecting profile %s for device %s", profile_uuid, device_path);
            
            // Verify device has this profile
            var profiles = device_profiles[device_path];
            if (profiles == null) {
                throw new IOError.NOT_FOUND("Device %s has no audio profiles".printf(device_path));
            }
            
            bool profile_found = false;
            for (uint i = 0; i < profiles.length; i++) {
                if (profiles[i].uuid.down() == profile_uuid.down()) {
                    profile_found = true;
                    break;
                }
            }
            
            if (!profile_found) {
                throw new IOError.NOT_FOUND("Device %s does not support profile %s".printf(
                    device_path, profile_uuid));
            }
            
            // Connect to the profile via BlueZ Device1.ConnectProfile method
            try {
                yield client.call_method(
                    device_path,
                    DEVICE_INTERFACE,
                    "ConnectProfile",
                    new Variant("(s)", profile_uuid)
                );
                
                // Update profile connected state
                update_profile_connection_state(device_path, profile_uuid, true);
                
                debug("AudioManager: Successfully connected profile %s", profile_uuid);
                profile_changed(device_path, profile_uuid);
                
            } catch (Error e) {
                warning("AudioManager: Failed to connect profile %s: %s", profile_uuid, e.message);
                throw e;
            }
        }
        
        /**
         * Disconnect from a specific audio profile
         * 
         * @param device_path The D-Bus object path of the device
         * @param profile_uuid The UUID of the profile to disconnect
         */
        public async void disconnect_profile(string device_path, string profile_uuid) throws Error {
            debug("AudioManager: Disconnecting profile %s for device %s", profile_uuid, device_path);
            
            // Verify device has this profile
            var profiles = device_profiles[device_path];
            if (profiles == null) {
                throw new IOError.NOT_FOUND("Device %s has no audio profiles".printf(device_path));
            }
            
            // Disconnect from the profile via BlueZ Device1.DisconnectProfile method
            try {
                yield client.call_method(
                    device_path,
                    DEVICE_INTERFACE,
                    "DisconnectProfile",
                    new Variant("(s)", profile_uuid)
                );
                
                // Update profile connected state
                update_profile_connection_state(device_path, profile_uuid, false);
                
                debug("AudioManager: Successfully disconnected profile %s", profile_uuid);
                profile_changed(device_path, profile_uuid);
                
            } catch (Error e) {
                warning("AudioManager: Failed to disconnect profile %s: %s", profile_uuid, e.message);
                throw e;
            }
        }
        
        /**
         * Set the active audio profile for a device
         * 
         * This switches between available profiles (e.g., A2DP to HFP for phone calls)
         * 
         * @param device_path The D-Bus object path of the device
         * @param profile_uuid The UUID of the profile to activate
         */
        public async void set_active_profile(string device_path, string profile_uuid) throws Error {
            debug("AudioManager: Setting active profile %s for device %s", profile_uuid, device_path);
            
            // Verify device has this profile
            var profiles = device_profiles[device_path];
            if (profiles == null) {
                throw new IOError.NOT_FOUND("Device %s has no audio profiles".printf(device_path));
            }
            
            bool profile_found = false;
            for (uint i = 0; i < profiles.length; i++) {
                if (profiles[i].uuid.down() == profile_uuid.down()) {
                    profile_found = true;
                    break;
                }
            }
            
            if (!profile_found) {
                throw new IOError.NOT_FOUND("Device %s does not support profile %s".printf(
                    device_path, profile_uuid));
            }
            
            // First, ensure the profile is connected
            try {
                yield connect_profile(device_path, profile_uuid);
            } catch (Error e) {
                // Profile might already be connected, continue
                debug("AudioManager: Profile connection attempt: %s", e.message);
            }
            
            // Update all profiles' connected state
            for (uint i = 0; i < profiles.length; i++) {
                if (profiles[i].uuid.down() == profile_uuid.down()) {
                    profiles[i].connected = true;
                } else {
                    // Note: We don't disconnect other profiles as multiple can be active
                    // The audio system will handle routing
                }
            }
            
            debug("AudioManager: Active profile set to %s", profile_uuid);
            profile_changed(device_path, profile_uuid);
        }
        
        /**
         * Update the connection state of a profile
         */
        private void update_profile_connection_state(string device_path, string profile_uuid, bool connected) {
            var profiles = device_profiles[device_path];
            if (profiles == null) {
                return;
            }
            
            for (uint i = 0; i < profiles.length; i++) {
                if (profiles[i].uuid.down() == profile_uuid.down()) {
                    profiles[i].connected = connected;
                    break;
                }
            }
        }
        
        /**
         * Handle object added events from BlueZ
         */
        private void on_object_added(string object_path, string interface_name) {
            if (interface_name == DEVICE_INTERFACE) {
                detect_profiles.begin(object_path, (obj, res) => {
                    try {
                        detect_profiles.end(res);
                    } catch (Error e) {
                        warning("AudioManager: Failed to detect profiles for new device %s: %s",
                                object_path, e.message);
                    }
                });
            }
        }
        
        /**
         * Handle object removed events from BlueZ
         */
        private void on_object_removed(string object_path, string interface_name) {
            if (interface_name == DEVICE_INTERFACE) {
                if (device_profiles.contains(object_path)) {
                    debug("AudioManager: Removing audio device %s", object_path);
                    device_profiles.remove(object_path);
                }
            }
        }
        
        /**
         * Handle property changed events from BlueZ
         */
        private void on_properties_changed(string object_path, string interface_name, 
                                          HashTable<string, Variant> changed_properties) {
            if (interface_name != DEVICE_INTERFACE) {
                return;
            }
            
            // Check if UUIDs changed (device services resolved)
            if (changed_properties.contains("UUIDs")) {
                detect_profiles.begin(object_path, (obj, res) => {
                    try {
                        detect_profiles.end(res);
                    } catch (Error e) {
                        warning("AudioManager: Failed to update profiles for %s: %s",
                                object_path, e.message);
                    }
                });
            }
            
            // Check if device connection state changed
            if (changed_properties.contains("Connected")) {
                var connected = changed_properties["Connected"].get_boolean();
                handle_device_connection_change(object_path, connected);
            }
        }
        
        /**
         * Handle device connection state changes
         * 
         * Automatically detect profiles when audio devices connect
         */
        private void handle_device_connection_change(string device_path, bool connected) {
            // Check if this is an audio device
            var profiles = device_profiles[device_path];
            if (profiles == null || profiles.length == 0) {
                return;
            }
            
            var was_connected = connected_audio_devices.contains(device_path) && 
                               connected_audio_devices[device_path];
            
            if (connected && !was_connected) {
                // Audio device connected
                debug("AudioManager: Audio device connected: %s", device_path);
                connected_audio_devices[device_path] = true;
                
                // Automatically detect profiles on connection
                detect_profiles.begin(device_path, (obj, res) => {
                    try {
                        detect_profiles.end(res);
                        
                        // Emit signal with primary profile
                        var primary_profile = get_primary_profile(device_path);
                        if (primary_profile != null) {
                            audio_device_connected(device_path, primary_profile);
                        }
                        
                    } catch (Error e) {
                        warning("AudioManager: Failed to detect profiles on connection: %s", 
                                e.message);
                    }
                });
                
            } else if (!connected && was_connected) {
                // Audio device disconnected
                debug("AudioManager: Audio device disconnected: %s", device_path);
                connected_audio_devices[device_path] = false;
                
                // Update all profiles to disconnected state
                for (uint i = 0; i < profiles.length; i++) {
                    profiles[i].connected = false;
                }
                
                audio_device_disconnected(device_path);
            }
        }
        
        /**
         * Get the primary audio profile for a device
         * 
         * Priority: A2DP_SINK > HFP > HSP > AVRCP > A2DP_SOURCE
         */
        private string? get_primary_profile(string device_path) {
            var profiles = device_profiles[device_path];
            if (profiles == null || profiles.length == 0) {
                return null;
            }
            
            // Priority order for primary profile
            AudioProfileType[] priority = {
                AudioProfileType.A2DP_SINK,
                AudioProfileType.HFP,
                AudioProfileType.HSP,
                AudioProfileType.AVRCP,
                AudioProfileType.A2DP_SOURCE
            };
            
            foreach (var type in priority) {
                for (uint i = 0; i < profiles.length; i++) {
                    if (profiles[i].profile_type == type) {
                        return profiles[i].uuid;
                    }
                }
            }
            
            // Return first profile if no priority match
            return profiles[0].uuid;
        }
        
        /**
         * Get count of connected audio devices
         */
        public uint get_connected_audio_device_count() {
            uint count = 0;
            connected_audio_devices.foreach((key, value) => {
                if (value) {
                    count++;
                }
            });
            return count;
        }
        
        /**
         * Check if a device is a connected audio device
         */
        public bool is_audio_device_connected(string device_path) {
            return connected_audio_devices.contains(device_path) && 
                   connected_audio_devices[device_path];
        }
    }
}
