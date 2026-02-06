/**
 * Enhanced Network Indicator - Network Profile Manager
 * 
 * This file implements the NetworkProfileManager class that handles
 * creation, management, and automatic switching of network profiles.
 */

using GLib;

namespace EnhancedNetwork {

    /**
     * Profile import/export formats
     */
    public enum ProfileFormat {
        JSON,
        XML,
        INI
    }

    /**
     * Profile switching events
     */
    public class ProfileSwitchEvent : GLib.Object {
        public NetworkProfile? from_profile { get; set; }
        public NetworkProfile to_profile { get; set; }
        public string reason { get; set; }
        public DateTime timestamp { get; set; }
        
        public ProfileSwitchEvent(NetworkProfile? from, NetworkProfile to, string reason) {
            this.from_profile = from;
            this.to_profile = to;
            this.reason = reason;
            this.timestamp = new DateTime.now_local();
        }
    }

    /**
     * Network Profile Manager
     * 
     * Manages multiple network profiles with automatic switching based on
     * network conditions, time, location, and other configurable criteria.
     */
    public class NetworkProfileManager : GLib.Object {
        private GenericArray<NetworkProfile> _profiles;
        private NetworkProfile? _active_profile;
        private NetworkManagerClient _nm_client;
        private GLib.Settings? _settings;
        private Timer? _condition_check_timer;
        private GenericArray<ProfileSwitchEvent> _switch_history;
        
        private const string SETTINGS_SCHEMA = "org.novabar.enhanced-network-indicator.profiles";
        private const string PROFILES_KEY = "saved-profiles";
        private const string ACTIVE_PROFILE_KEY = "active-profile-id";
        private const uint CONDITION_CHECK_INTERVAL = 30; // seconds
        private const uint MAX_SWITCH_HISTORY = 100;
        
        /**
         * Signal emitted when a profile is created
         */
        public signal void profile_created(NetworkProfile profile);
        
        /**
         * Signal emitted when a profile is deleted
         */
        public signal void profile_deleted(string profile_id);
        
        /**
         * Signal emitted when a profile is updated
         */
        public signal void profile_updated(NetworkProfile profile);
        
        /**
         * Signal emitted when the active profile changes
         */
        public signal void active_profile_changed(NetworkProfile? old_profile, NetworkProfile? new_profile);
        
        /**
         * Signal emitted when automatic profile switching occurs
         */
        public signal void profile_auto_switched(ProfileSwitchEvent switch_event);
        
        /**
         * Signal emitted when profile import/export operations complete
         */
        public signal void import_export_completed(bool success, string message);
        
        public NetworkProfile? active_profile { 
            get { return _active_profile; } 
        }
        
        public uint profile_count { 
            get { return _profiles.length; } 
        }
        
        public NetworkProfileManager(NetworkManagerClient nm_client) {
            _nm_client = nm_client;
            _profiles = new GenericArray<NetworkProfile>();
            _switch_history = new GenericArray<ProfileSwitchEvent>();
            
            // Initialize settings - check if schema exists first
            try {
                var schema_source = GLib.SettingsSchemaSource.get_default();
                if (schema_source != null && schema_source.lookup(SETTINGS_SCHEMA, false) != null) {
                    _settings = new GLib.Settings(SETTINGS_SCHEMA);
                    debug("NetworkProfileManager: GSettings schema loaded successfully");
                } else {
                    _settings = null;
                    debug("NetworkProfileManager: GSettings schema not found, using defaults");
                }
            } catch (Error e) {
                _settings = null;
                warning("NetworkProfileManager: Failed to initialize settings: %s", e.message);
            }
            
            // Load saved profiles
            load_profiles();
            
            // Setup automatic condition checking
            setup_condition_monitoring();
            
            // Connect to network state changes
            _nm_client.state_changed.connect(on_network_state_changed);
            
            debug("NetworkProfileManager: Initialized with %u profiles", _profiles.length);
        }
        
        /**
         * Create a new network profile
         */
        public NetworkProfile create_profile(string name, string description = "") {
            var profile = new NetworkProfile.with_name(name);
            profile.description = description;
            
            // Connect to profile signals
            connect_profile_signals(profile);
            
            _profiles.add(profile);
            save_profiles();
            
            debug("NetworkProfileManager: Created profile: %s", name);
            profile_created(profile);
            
            return profile;
        }
        
        /**
         * Delete a network profile
         */
        public bool delete_profile(string profile_id) {
            for (uint i = 0; i < _profiles.length; i++) {
                var profile = _profiles[i];
                if (profile.id == profile_id) {
                    // Deactivate if currently active
                    if (_active_profile == profile) {
                        deactivate_profile();
                    }
                    
                    _profiles.remove_index(i);
                    save_profiles();
                    
                    debug("NetworkProfileManager: Deleted profile: %s", profile.name);
                    profile_deleted(profile_id);
                    return true;
                }
            }
            
            warning("NetworkProfileManager: Profile not found for deletion: %s", profile_id);
            return false;
        }
        
        /**
         * Get a profile by ID
         */
        public NetworkProfile? get_profile(string profile_id) {
            for (uint i = 0; i < _profiles.length; i++) {
                var profile = _profiles[i];
                if (profile.id == profile_id) {
                    return profile;
                }
            }
            return null;
        }
        
        /**
         * Get all profiles
         */
        public GenericArray<NetworkProfile> get_all_profiles() {
            return _profiles;
        }
        
        /**
         * Get profiles sorted by priority
         */
        public GenericArray<NetworkProfile> get_profiles_by_priority() {
            var sorted_profiles = new GenericArray<NetworkProfile>();
            
            // Copy all profiles to new array
            for (uint i = 0; i < _profiles.length; i++) {
                sorted_profiles.add(_profiles[i]);
            }
            
            // Sort by priority (highest first)
            sorted_profiles.sort((a, b) => {
                return (int)b.priority - (int)a.priority;
            });
            
            return sorted_profiles;
        }
        
        /**
         * Activate a specific profile
         */
        public async bool activate_profile(string profile_id) {
            var profile = get_profile(profile_id);
            if (profile == null) {
                warning("NetworkProfileManager: Cannot activate unknown profile: %s", profile_id);
                return false;
            }
            
            if (!profile.enabled) {
                warning("NetworkProfileManager: Cannot activate disabled profile: %s", profile.name);
                return false;
            }
            
            if (!profile.is_valid()) {
                warning("NetworkProfileManager: Cannot activate invalid profile: %s", profile.name);
                return false;
            }
            
            debug("NetworkProfileManager: Activating profile: %s", profile.name);
            
            var old_profile = _active_profile;
            
            // Deactivate current profile
            if (_active_profile != null) {
                _active_profile.deactivate();
            }
            
            // Apply profile configuration
            bool success = yield apply_profile_configuration(profile);
            
            if (success) {
                _active_profile = profile;
                profile.activate();
                
                // Save active profile ID
                if (_settings != null) {
                    _settings.set_string(ACTIVE_PROFILE_KEY, profile_id);
                }
                
                // Record switch event
                var switch_event = new ProfileSwitchEvent(old_profile, profile, "Manual activation");
                record_switch_event(switch_event);
                
                debug("NetworkProfileManager: Profile activated successfully: %s", profile.name);
                active_profile_changed(old_profile, profile);
                return true;
            } else {
                warning("NetworkProfileManager: Failed to apply profile configuration: %s", profile.name);
                return false;
            }
        }
        
        /**
         * Deactivate the current profile
         */
        public void deactivate_profile() {
            if (_active_profile == null) return;
            
            debug("NetworkProfileManager: Deactivating profile: %s", _active_profile.name);
            
            var old_profile = _active_profile;
            _active_profile.deactivate();
            _active_profile = null;
            
            // Clear active profile ID
            if (_settings != null) {
                _settings.set_string(ACTIVE_PROFILE_KEY, "");
            }
            
            active_profile_changed(old_profile, null);
        }
        
        /**
         * Check for automatic profile switching based on current conditions
         */
        public async void check_automatic_switching() {
            if (_profiles.length == 0) return;
            
            debug("NetworkProfileManager: Checking automatic profile switching conditions");
            
            var candidates = new GenericArray<NetworkProfile>();
            
            // Find profiles that should be activated
            for (uint i = 0; i < _profiles.length; i++) {
                var profile = _profiles[i];
                if (profile.should_activate() && profile != _active_profile) {
                    candidates.add(profile);
                }
            }
            
            if (candidates.length == 0) {
                debug("NetworkProfileManager: No profiles match current conditions");
                return;
            }
            
            // Sort candidates by priority
            candidates.sort((a, b) => {
                return (int)b.priority - (int)a.priority;
            });
            
            var best_candidate = candidates[0];
            
            // Only switch if the candidate has higher priority than current profile
            if (_active_profile != null && best_candidate.priority <= _active_profile.priority) {
                debug("NetworkProfileManager: Current profile has higher priority, not switching");
                return;
            }
            
            debug("NetworkProfileManager: Auto-switching to profile: %s", best_candidate.name);
            
            var old_profile = _active_profile;
            bool success = yield activate_profile(best_candidate.id);
            
            if (success) {
                var switch_event = new ProfileSwitchEvent(old_profile, best_candidate, "Automatic condition match");
                record_switch_event(switch_event);
                profile_auto_switched(switch_event);
            }
        }
        
        /**
         * Import profiles from a file
         */
        public async bool import_profiles(string file_path, ProfileFormat format) {
            try {
                debug("NetworkProfileManager: Importing profiles from: %s", file_path);
                
                var file = File.new_for_path(file_path);
                if (!file.query_exists()) {
                    throw new IOError.NOT_FOUND("Import file does not exist");
                }
                
                var content = yield read_file_content(file);
                var imported_profiles = parse_profile_data(content, format);
                
                uint imported_count = 0;
                foreach (var profile in imported_profiles) {
                    if (profile.is_valid()) {
                        // Generate new ID to avoid conflicts
                        profile.id = Uuid.string_random();
                        profile.name = ensure_unique_name(profile.name);
                        
                        connect_profile_signals(profile);
                        _profiles.add(profile);
                        imported_count++;
                        
                        profile_created(profile);
                    }
                }
                
                if (imported_count > 0) {
                    save_profiles();
                }
                
                string message = "Imported %u profiles successfully".printf(imported_count);
                debug("NetworkProfileManager: %s", message);
                import_export_completed(true, message);
                
                return true;
                
            } catch (Error e) {
                string message = "Failed to import profiles: %s".printf(e.message);
                warning("NetworkProfileManager: %s", message);
                import_export_completed(false, message);
                return false;
            }
        }
        
        /**
         * Export profiles to a file
         */
        public async bool export_profiles(string file_path, ProfileFormat format, string[]? profile_ids = null) {
            try {
                debug("NetworkProfileManager: Exporting profiles to: %s", file_path);
                
                var profiles_to_export = new GenericArray<NetworkProfile>();
                
                if (profile_ids == null) {
                    // Export all profiles
                    for (uint i = 0; i < _profiles.length; i++) {
                        profiles_to_export.add(_profiles[i]);
                    }
                } else {
                    // Export specific profiles
                    foreach (string id in profile_ids) {
                        var profile = get_profile(id);
                        if (profile != null) {
                            profiles_to_export.add(profile);
                        }
                    }
                }
                
                if (profiles_to_export.length == 0) {
                    throw new IOError.INVALID_DATA("No profiles to export");
                }
                
                var content = serialize_profiles(profiles_to_export, format);
                var file = File.new_for_path(file_path);
                
                yield write_file_content(file, content);
                
                string message = "Exported %u profiles successfully".printf(profiles_to_export.length);
                debug("NetworkProfileManager: %s", message);
                import_export_completed(true, message);
                
                return true;
                
            } catch (Error e) {
                string message = "Failed to export profiles: %s".printf(e.message);
                warning("NetworkProfileManager: %s", message);
                import_export_completed(false, message);
                return false;
            }
        }
        
        /**
         * Get profile switching history
         */
        public GenericArray<ProfileSwitchEvent> get_switch_history() {
            return _switch_history;
        }
        
        /**
         * Clear profile switching history
         */
        public void clear_switch_history() {
            _switch_history.remove_range(0, _switch_history.length);
            debug("NetworkProfileManager: Switch history cleared");
        }
        
        /**
         * Update a profile and save changes
         */
        public void update_profile(NetworkProfile profile) {
            profile.mark_modified();
            save_profiles();
            profile_updated(profile);
        }
        
        /**
         * Duplicate an existing profile
         */
        public NetworkProfile? duplicate_profile(string profile_id) {
            var original = get_profile(profile_id);
            if (original == null) return null;
            
            var duplicate = original.copy();
            duplicate.name = ensure_unique_name(duplicate.name);
            
            connect_profile_signals(duplicate);
            _profiles.add(duplicate);
            save_profiles();
            
            debug("NetworkProfileManager: Duplicated profile: %s -> %s", original.name, duplicate.name);
            profile_created(duplicate);
            
            return duplicate;
        }
        
        // Private methods
        
        private void setup_condition_monitoring() {
            _condition_check_timer = new Timer();
            
            Timeout.add_seconds(CONDITION_CHECK_INTERVAL, () => {
                check_automatic_switching.begin();
                return Source.CONTINUE;
            });
            
            debug("NetworkProfileManager: Condition monitoring setup complete");
        }
        
        private void connect_profile_signals(NetworkProfile profile) {
            profile.configuration_changed.connect(() => {
                save_profiles();
                profile_updated(profile);
            });
        }
        
        private void on_network_state_changed(NetworkState state) {
            debug("NetworkProfileManager: Network state changed, checking automatic switching");
            check_automatic_switching.begin();
        }
        
        private async bool apply_profile_configuration(NetworkProfile profile) {
            debug("NetworkProfileManager: Applying configuration for profile: %s", profile.name);
            
            try {
                // Apply proxy configuration
                if (profile.proxy_config.enabled) {
                    yield apply_proxy_configuration(profile.proxy_config);
                }
                
                // Apply DNS configuration
                if (profile.dns_config.custom_dns) {
                    yield apply_dns_configuration(profile.dns_config);
                }
                
                // Apply enterprise authentication if needed
                if (profile.enterprise_auth.enabled) {
                    yield apply_enterprise_auth_configuration(profile.enterprise_auth);
                }
                
                return true;
                
            } catch (Error e) {
                warning("NetworkProfileManager: Failed to apply profile configuration: %s", e.message);
                return false;
            }
        }
        
        private async void apply_proxy_configuration(ProxyConfiguration config) throws Error {
            debug("NetworkProfileManager: Applying proxy configuration");
            
            // This would integrate with system proxy settings
            // Implementation depends on the desktop environment
            // For now, just log the configuration
            
            if (config.http_proxy.length > 0) {
                debug("NetworkProfileManager: HTTP Proxy: %s", config.http_proxy);
            }
            if (config.https_proxy.length > 0) {
                debug("NetworkProfileManager: HTTPS Proxy: %s", config.https_proxy);
            }
            if (config.socks_proxy.length > 0) {
                debug("NetworkProfileManager: SOCKS Proxy: %s", config.socks_proxy);
            }
        }
        
        private async void apply_dns_configuration(DNSConfiguration config) throws Error {
            debug("NetworkProfileManager: Applying DNS configuration");
            
            // This would integrate with NetworkManager to set DNS servers
            // For now, just log the configuration
            
            foreach (string server in config.dns_servers) {
                debug("NetworkProfileManager: DNS Server: %s", server);
            }
            
            if (config.dns_over_https) {
                debug("NetworkProfileManager: DNS-over-HTTPS: %s", config.doh_server);
            }
        }
        
        private async void apply_enterprise_auth_configuration(EnterpriseAuthConfiguration config) throws Error {
            debug("NetworkProfileManager: Applying enterprise authentication configuration");
            
            // This would configure 802.1X authentication
            // Implementation would depend on NetworkManager integration
            
            debug("NetworkProfileManager: EAP Method: %s", config.eap_method);
            debug("NetworkProfileManager: Identity: %s", config.identity);
        }
        
        private void load_profiles() {
            if (_settings == null) return;
            
            try {
                var profile_data = _settings.get_string(PROFILES_KEY);
                if (profile_data.length > 0) {
                    var loaded_profiles = parse_profile_data(profile_data, ProfileFormat.JSON);
                    
                    foreach (var profile in loaded_profiles) {
                        connect_profile_signals(profile);
                        _profiles.add(profile);
                    }
                    
                    debug("NetworkProfileManager: Loaded %u profiles from settings", _profiles.length);
                }
                
                // Load active profile
                var active_profile_id = _settings.get_string(ACTIVE_PROFILE_KEY);
                if (active_profile_id.length > 0) {
                    var profile = get_profile(active_profile_id);
                    if (profile != null && profile.enabled) {
                        _active_profile = profile;
                        profile.is_active = true;
                        debug("NetworkProfileManager: Restored active profile: %s", profile.name);
                    }
                }
                
            } catch (Error e) {
                warning("NetworkProfileManager: Failed to load profiles: %s", e.message);
            }
        }
        
        private void save_profiles() {
            if (_settings == null) return;
            
            try {
                var profile_data = serialize_profiles(_profiles, ProfileFormat.JSON);
                _settings.set_string(PROFILES_KEY, profile_data);
                debug("NetworkProfileManager: Saved %u profiles to settings", _profiles.length);
                
            } catch (Error e) {
                warning("NetworkProfileManager: Failed to save profiles: %s", e.message);
            }
        }
        
        private GenericArray<NetworkProfile> parse_profile_data(string data, ProfileFormat format) throws Error {
            var profiles = new GenericArray<NetworkProfile>();
            
            switch (format) {
                case ProfileFormat.JSON:
                    profiles = parse_json_profiles(data);
                    break;
                    
                case ProfileFormat.XML:
                    throw new IOError.NOT_SUPPORTED("XML format not yet implemented");
                    
                case ProfileFormat.INI:
                    throw new IOError.NOT_SUPPORTED("INI format not yet implemented");
            }
            
            return profiles;
        }
        
        private string serialize_profiles(GenericArray<NetworkProfile> profiles, ProfileFormat format) throws Error {
            switch (format) {
                case ProfileFormat.JSON:
                    return serialize_json_profiles(profiles);
                    
                case ProfileFormat.XML:
                    throw new IOError.NOT_SUPPORTED("XML format not yet implemented");
                    
                case ProfileFormat.INI:
                    throw new IOError.NOT_SUPPORTED("INI format not yet implemented");
                    
                default:
                    throw new IOError.INVALID_ARGUMENT("Unknown profile format");
            }
        }
        
        private GenericArray<NetworkProfile> parse_json_profiles(string json_data) throws Error {
            var profiles = new GenericArray<NetworkProfile>();
            
            // Basic JSON parsing - in a real implementation, you'd use a proper JSON library
            // For now, just return empty array
            debug("NetworkProfileManager: JSON parsing not fully implemented");
            
            return profiles;
        }
        
        private string serialize_json_profiles(GenericArray<NetworkProfile> profiles) throws Error {
            // Basic JSON serialization - in a real implementation, you'd use a proper JSON library
            // For now, just return empty JSON array
            debug("NetworkProfileManager: JSON serialization not fully implemented");
            return "[]";
        }
        
        private async string read_file_content(File file) throws Error {
            var stream = yield file.read_async();
            var data_stream = new DataInputStream(stream);
            
            var content = new StringBuilder();
            string line;
            
            while ((line = yield data_stream.read_line_async()) != null) {
                content.append(line);
                content.append("\n");
            }
            
            return content.str;
        }
        
        private async void write_file_content(File file, string content) throws Error {
            var stream = yield file.replace_async(null, false, FileCreateFlags.NONE);
            var data_stream = new DataOutputStream(stream);
            
            data_stream.put_string(content);
            yield data_stream.close_async();
        }
        
        private string ensure_unique_name(string base_name) {
            string name = base_name;
            int counter = 1;
            
            while (is_name_taken(name)) {
                name = "%s (%d)".printf(base_name, counter);
                counter++;
            }
            
            return name;
        }
        
        private bool is_name_taken(string name) {
            for (uint i = 0; i < _profiles.length; i++) {
                if (_profiles[i].name == name) {
                    return true;
                }
            }
            return false;
        }
        
        private void record_switch_event(ProfileSwitchEvent event) {
            _switch_history.add(event);
            
            // Keep history size manageable
            if (_switch_history.length > MAX_SWITCH_HISTORY) {
                _switch_history.remove_index(0);
            }
            
            debug("NetworkProfileManager: Recorded switch event: %s -> %s (%s)",
                  event.from_profile?.name ?? "None",
                  event.to_profile.name,
                  event.reason);
        }
    }
}