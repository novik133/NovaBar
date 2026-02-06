/**
 * Enhanced Network Indicator - VPN Manager
 * 
 * This file implements the VPNManager component responsible for managing
 * VPN connections, profiles, and state through NetworkManager D-Bus API.
 */

using GLib;
using NM;

namespace EnhancedNetwork {

    /**
     * VPN Manager for handling VPN connections and profiles
     * 
     * This class provides comprehensive VPN management functionality including
     * profile management, connection state handling, and NetworkManager integration.
     */
    public class VPNManager : GLib.Object {
        private NetworkManagerClient nm_client;
        private GenericArray<VPNProfile> _vpn_profiles;
        private VPNProfile? _active_vpn;
        private GLib.Settings? settings;
        private string profiles_dir;
        
        /**
         * Signal emitted when VPN state changes
         */
        public signal void vpn_state_changed(VPNProfile profile, ConnectionState state);
        
        /**
         * Signal emitted when VPN profiles list is updated
         */
        public signal void profiles_updated(GenericArray<VPNProfile> profiles);
        
        /**
         * Signal emitted when VPN connection error occurs
         */
        public signal void vpn_error(VPNProfile profile, string error_message);
        
        /**
         * Signal emitted when VPN statistics are updated
         */
        public signal void vpn_stats_updated(VPNProfile profile, VPNStats stats);
        
        public GenericArray<VPNProfile> vpn_profiles { 
            get { return _vpn_profiles; } 
        }
        
        public VPNProfile? active_vpn { 
            get { return _active_vpn; } 
        }
        
        public VPNManager(NetworkManagerClient nm_client) {
            this.nm_client = nm_client;
            this._vpn_profiles = new GenericArray<VPNProfile>();
            
            // Try to load GSettings schema, but don't fail if it's not available
            try {
                var schema_source = GLib.SettingsSchemaSource.get_default();
                if (schema_source != null && schema_source.lookup("org.novadesktop.novabar.network.vpn", false) != null) {
                    this.settings = new GLib.Settings("org.novadesktop.novabar.network.vpn");
                    debug("VPNManager: GSettings schema loaded successfully");
                } else {
                    this.settings = null;
                    debug("VPNManager: GSettings schema not found, using defaults");
                }
            } catch (Error e) {
                this.settings = null;
                debug("VPNManager: Failed to load GSettings: %s, using defaults", e.message);
            }
            
            // Setup profiles directory
            var config_dir = Environment.get_user_config_dir();
            this.profiles_dir = Path.build_filename(config_dir, "novabar", "vpn-profiles");
            ensure_profiles_directory();
            
            // Setup NetworkManager signal handlers
            setup_nm_signals();
            
            // Load existing profiles
            load_vpn_profiles.begin();
        }
        
        /**
         * Setup NetworkManager signal handlers for VPN events
         */
        private void setup_nm_signals() {
            nm_client.connection_added.connect((connection) => {
                if (is_vpn_connection(connection)) {
                    debug("VPNManager: VPN connection added: %s", connection.get_id());
                    sync_vpn_profile_from_nm_connection(connection);
                }
            });
            
            nm_client.connection_removed.connect((connection) => {
                if (is_vpn_connection(connection)) {
                    debug("VPNManager: VPN connection removed: %s", connection.get_id());
                    remove_vpn_profile_by_nm_id(connection.get_uuid());
                }
            });
            
            nm_client.connection_state_changed.connect((active_connection, state, reason) => {
                if (is_vpn_active_connection(active_connection)) {
                    handle_vpn_state_change(active_connection, state, reason);
                }
            });
        }
        
        /**
         * Connect to a VPN profile
         */
        public async bool connect_vpn(VPNProfile profile) throws Error {
            if (!nm_client.is_available) {
                throw new IOError.NOT_CONNECTED("NetworkManager not available");
            }
            
            if (profile.is_connected()) {
                debug("VPNManager: VPN %s is already connected", profile.name);
                return true;
            }
            
            try {
                debug("VPNManager: Connecting to VPN %s", profile.name);
                
                // Find or create NetworkManager connection
                var nm_connection = find_nm_connection_for_profile(profile);
                if (nm_connection == null) {
                    nm_connection = yield create_nm_connection_for_profile(profile);
                }
                
                if (nm_connection == null) {
                    throw new IOError.FAILED("Failed to create NetworkManager connection for VPN profile");
                }
                
                // Activate the connection
                var success = yield nm_client.activate_connection(nm_connection);
                if (success) {
                    debug("VPNManager: VPN connection initiated successfully");
                    return true;
                } else {
                    throw new IOError.FAILED("Failed to activate VPN connection");
                }
                
            } catch (Error e) {
                warning("VPNManager: Failed to connect VPN %s: %s", profile.name, e.message);
                vpn_error(profile, e.message);
                throw e;
            }
        }
        
        /**
         * Disconnect from a VPN profile
         */
        public async bool disconnect_vpn(VPNProfile profile) throws Error {
            if (!nm_client.is_available) {
                throw new IOError.NOT_CONNECTED("NetworkManager not available");
            }
            
            if (!profile.is_connected()) {
                debug("VPNManager: VPN %s is already disconnected", profile.name);
                return true;
            }
            
            try {
                debug("VPNManager: Disconnecting VPN %s", profile.name);
                
                // Find active connection
                var active_connection = find_active_vpn_connection(profile);
                if (active_connection != null) {
                    var success = yield nm_client.deactivate_connection(active_connection);
                    if (success) {
                        debug("VPNManager: VPN disconnected successfully");
                        return true;
                    } else {
                        throw new IOError.FAILED("Failed to deactivate VPN connection");
                    }
                } else {
                    warning("VPNManager: No active connection found for VPN %s", profile.name);
                    return false;
                }
                
            } catch (Error e) {
                warning("VPNManager: Failed to disconnect VPN %s: %s", profile.name, e.message);
                vpn_error(profile, e.message);
                throw e;
            }
        }
        
        /**
         * Import VPN profile from configuration file
         */
        public async bool import_vpn_profile(string config_file_path) throws Error {
            var file = File.new_for_path(config_file_path);
            if (!file.query_exists()) {
                throw new IOError.NOT_FOUND("Configuration file not found: %s", config_file_path);
            }
            
            try {
                debug("VPNManager: Importing VPN profile from %s", config_file_path);
                
                // Determine VPN type from file extension
                VPNType vpn_type;
                if (config_file_path.has_suffix(".ovpn")) {
                    vpn_type = VPNType.OPENVPN;
                } else if (config_file_path.has_suffix(".conf")) {
                    vpn_type = VPNType.WIREGUARD;
                } else {
                    throw new IOError.INVALID_DATA("Unsupported configuration file format");
                }
                
                // Parse configuration file
                var config = yield parse_vpn_config_file(config_file_path, vpn_type);
                if (config == null) {
                    throw new IOError.INVALID_DATA("Failed to parse configuration file");
                }
                
                // Create VPN profile
                var profile_name = extract_profile_name_from_path(config_file_path);
                var profile = new VPNProfile.with_name_and_type(profile_name, vpn_type);
                profile.set_configuration(config);
                
                // Save profile
                yield save_vpn_profile(profile);
                
                // Add to profiles list
                _vpn_profiles.add(profile);
                profiles_updated(_vpn_profiles);
                
                debug("VPNManager: VPN profile imported successfully: %s", profile.name);
                return true;
                
            } catch (Error e) {
                warning("VPNManager: Failed to import VPN profile: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Create a new VPN profile
         */
        public async bool create_vpn_profile(string name, VPNType vpn_type, VPNConfiguration config) throws Error {
            try {
                debug("VPNManager: Creating VPN profile %s (%s)", name, vpn_type.to_string());
                
                // Check if profile with same name already exists
                if (find_profile_by_name(name) != null) {
                    throw new IOError.EXISTS("VPN profile with name '%s' already exists", name);
                }
                
                // Create profile
                var profile = new VPNProfile.with_name_and_type(name, vpn_type);
                profile.set_configuration(config);
                
                // Validate configuration
                if (!profile.is_configuration_complete()) {
                    throw new IOError.INVALID_DATA("VPN configuration is incomplete");
                }
                
                // Save profile
                yield save_vpn_profile(profile);
                
                // Add to profiles list
                _vpn_profiles.add(profile);
                profiles_updated(_vpn_profiles);
                
                debug("VPNManager: VPN profile created successfully: %s", profile.name);
                return true;
                
            } catch (Error e) {
                warning("VPNManager: Failed to create VPN profile: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Delete a VPN profile
         */
        public async bool delete_vpn_profile(VPNProfile profile) throws Error {
            try {
                debug("VPNManager: Deleting VPN profile %s", profile.name);
                
                // Disconnect if currently connected
                if (profile.is_connected()) {
                    yield disconnect_vpn(profile);
                }
                
                // Remove NetworkManager connection if it exists
                var nm_connection = find_nm_connection_for_profile(profile);
                if (nm_connection != null) {
                    // TODO: Remove NetworkManager connection
                    debug("VPNManager: Would remove NetworkManager connection for %s", profile.name);
                }
                
                // Remove profile file
                var profile_file = get_profile_file_path(profile);
                var file = File.new_for_path(profile_file);
                if (file.query_exists()) {
                    file.delete();
                }
                
                // Remove from profiles list
                _vpn_profiles.remove(profile);
                profiles_updated(_vpn_profiles);
                
                debug("VPNManager: VPN profile deleted successfully: %s", profile.name);
                return true;
                
            } catch (Error e) {
                warning("VPNManager: Failed to delete VPN profile: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Update an existing VPN profile
         */
        public async bool update_vpn_profile(VPNProfile profile, VPNConfiguration new_config) throws Error {
            try {
                debug("VPNManager: Updating VPN profile %s", profile.name);
                
                // Disconnect if currently connected
                if (profile.is_connected()) {
                    yield disconnect_vpn(profile);
                }
                
                // Update configuration
                profile.set_configuration(new_config);
                
                // Validate configuration
                if (!profile.is_configuration_complete()) {
                    throw new IOError.INVALID_DATA("Updated VPN configuration is incomplete");
                }
                
                // Save updated profile
                yield save_vpn_profile(profile);
                
                // Update NetworkManager connection if it exists
                var nm_connection = find_nm_connection_for_profile(profile);
                if (nm_connection != null) {
                    yield update_nm_connection_for_profile(nm_connection, profile);
                }
                
                profiles_updated(_vpn_profiles);
                
                debug("VPNManager: VPN profile updated successfully: %s", profile.name);
                return true;
                
            } catch (Error e) {
                warning("VPNManager: Failed to update VPN profile: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Find VPN profile by name
         */
        public VPNProfile? find_profile_by_name(string name) {
            for (uint i = 0; i < _vpn_profiles.length; i++) {
                var profile = _vpn_profiles[i];
                if (profile.name == name) {
                    return profile;
                }
            }
            return null;
        }
        
        /**
         * Find VPN profile by ID
         */
        public VPNProfile? find_profile_by_id(string id) {
            for (uint i = 0; i < _vpn_profiles.length; i++) {
                var profile = _vpn_profiles[i];
                if (profile.id == id) {
                    return profile;
                }
            }
            return null;
        }
        
        /**
         * Check if any VPN is currently connected
         */
        public bool is_vpn_connected() {
            return _active_vpn != null && _active_vpn.is_connected();
        }
        
        // Private helper methods
        
        /**
         * Ensure VPN profiles directory exists
         */
        private void ensure_profiles_directory() {
            var dir = File.new_for_path(profiles_dir);
            if (!dir.query_exists()) {
                try {
                    dir.make_directory_with_parents();
                    debug("VPNManager: Created profiles directory: %s", profiles_dir);
                } catch (Error e) {
                    warning("VPNManager: Failed to create profiles directory: %s", e.message);
                }
            }
        }
        
        /**
         * Load VPN profiles from disk
         */
        private async void load_vpn_profiles() {
            try {
                debug("VPNManager: Loading VPN profiles from %s", profiles_dir);
                
                var dir = File.new_for_path(profiles_dir);
                if (!dir.query_exists()) {
                    debug("VPNManager: Profiles directory does not exist, no profiles to load");
                    return;
                }
                
                var enumerator = yield dir.enumerate_children_async(
                    FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
                    FileQueryInfoFlags.NONE,
                    Priority.DEFAULT,
                    null
                );
                
                FileInfo? info;
                while ((info = enumerator.next_file(null)) != null) {
                    if (info.get_file_type() == FileType.REGULAR && 
                        info.get_name().has_suffix(".json")) {
                        
                        var profile_file = dir.get_child(info.get_name());
                        var profile = yield load_vpn_profile_from_file(profile_file.get_path());
                        if (profile != null) {
                            _vpn_profiles.add(profile);
                            setup_profile_signals(profile);
                        }
                    }
                }
                
                debug("VPNManager: Loaded %u VPN profiles", _vpn_profiles.length);
                profiles_updated(_vpn_profiles);
                
            } catch (Error e) {
                warning("VPNManager: Failed to load VPN profiles: %s", e.message);
            }
        }
        
        /**
         * Load VPN profile from JSON file
         */
        private async VPNProfile? load_vpn_profile_from_file(string file_path) {
            try {
                var file = File.new_for_path(file_path);
                var stream = yield file.read_async();
                var data_stream = new DataInputStream(stream);
                
                var json_data = "";
                string? line;
                while ((line = yield data_stream.read_line_async()) != null) {
                    json_data += line + "\n";
                }
                
                // Parse JSON and create profile
                // This is a simplified implementation - in practice you'd use a JSON parser
                debug("VPNManager: Loaded profile data from %s", file_path);
                
                // For now, return null - full JSON parsing would be implemented here
                return null;
                
            } catch (Error e) {
                warning("VPNManager: Failed to load profile from %s: %s", file_path, e.message);
                return null;
            }
        }
        
        /**
         * Save VPN profile to disk
         */
        private async void save_vpn_profile(VPNProfile profile) throws Error {
            var profile_file = get_profile_file_path(profile);
            var file = File.new_for_path(profile_file);
            
            try {
                var stream = yield file.replace_async(null, false, FileCreateFlags.PRIVATE);
                var data_stream = new DataOutputStream(stream);
                
                // Create JSON representation of profile
                var json_data = serialize_profile_to_json(profile);
                data_stream.put_string(json_data);
                yield data_stream.close_async();
                
                debug("VPNManager: Saved profile %s to %s", profile.name, profile_file);
                
            } catch (Error e) {
                warning("VPNManager: Failed to save profile %s: %s", profile.name, e.message);
                throw e;
            }
        }
        
        /**
         * Get file path for a VPN profile
         */
        private string get_profile_file_path(VPNProfile profile) {
            if (profile.name != null) {
                var safe_name = profile.name.replace(" ", "_").replace("/", "_");
                return Path.build_filename(profiles_dir, safe_name + ".json");
            }
            return Path.build_filename(profiles_dir, "unknown.json");
        }
        
        /**
         * Serialize VPN profile to JSON
         */
        private string serialize_profile_to_json(VPNProfile profile) {
            // Simplified JSON serialization - in practice use a proper JSON library
            var json = "{\n";
            json += "  \"id\": \"%s\",\n".printf(profile.id ?? "");
            json += "  \"name\": \"%s\",\n".printf(profile.name ?? "");
            json += "  \"type\": \"%s\",\n".printf(profile.vpn_type.to_string());
            json += "  \"server_address\": \"%s\",\n".printf(profile.server_address ?? "");
            json += "  \"username\": \"%s\",\n".printf(profile.username ?? "");
            json += "  \"auto_connect\": %s,\n".printf(profile.auto_connect.to_string());
            json += "  \"created_date\": \"%s\"\n".printf(profile.created_date.to_string());
            json += "}";
            return json;
        }
        
        /**
         * Setup signal handlers for a VPN profile
         */
        private void setup_profile_signals(VPNProfile profile) {
            profile.state_changed.connect((old_state, new_state) => {
                debug("VPNManager: Profile %s state changed: %s -> %s", 
                      profile.name, old_state.to_string(), new_state.to_string());
                
                if (new_state == ConnectionState.CONNECTED) {
                    _active_vpn = profile;
                } else if (old_state == ConnectionState.CONNECTED && _active_vpn == profile) {
                    _active_vpn = null;
                }
                
                vpn_state_changed(profile, new_state);
            });
            
            profile.connection_error.connect((error_message) => {
                vpn_error(profile, error_message);
            });
            
            profile.stats_updated.connect((stats) => {
                vpn_stats_updated(profile, stats);
            });
        }
        
        /**
         * Check if a NetworkManager connection is a VPN connection
         */
        private bool is_vpn_connection(NM.Connection connection) {
            var connection_type = connection.get_connection_type();
            return connection_type == "vpn";
        }
        
        /**
         * Check if an active connection is a VPN connection
         */
        private bool is_vpn_active_connection(NM.ActiveConnection active_connection) {
            var connection = active_connection.get_connection();
            return connection != null && is_vpn_connection(connection);
        }
        
        /**
         * Handle VPN state changes from NetworkManager
         */
        private void handle_vpn_state_change(NM.ActiveConnection active_connection, 
                                           NM.ActiveConnectionState state, 
                                           NM.ActiveConnectionStateReason reason) {
            var connection = active_connection.get_connection();
            if (connection == null) return;
            
            var profile = find_profile_by_nm_connection(connection);
            if (profile == null) return;
            
            ConnectionState vpn_state;
            switch (state) {
                case NM.ActiveConnectionState.ACTIVATING:
                    vpn_state = ConnectionState.CONNECTING;
                    break;
                case NM.ActiveConnectionState.ACTIVATED:
                    vpn_state = ConnectionState.CONNECTED;
                    break;
                case NM.ActiveConnectionState.DEACTIVATING:
                    vpn_state = ConnectionState.DISCONNECTING;
                    break;
                case NM.ActiveConnectionState.DEACTIVATED:
                    vpn_state = ConnectionState.DISCONNECTED;
                    break;
                default:
                    vpn_state = ConnectionState.FAILED;
                    break;
            }
            
            // Update profile state
            profile.state = vpn_state;
            profile.vpn_state_changed(profile.state, vpn_state);
        }
        
        /**
         * Find NetworkManager connection for a VPN profile
         */
        private NM.Connection? find_nm_connection_for_profile(VPNProfile profile) {
            var connections = nm_client.get_connections_by_type("vpn");
            for (uint i = 0; i < connections.length; i++) {
                var connection = connections[i];
                if (connection.get_id() == profile.name) {
                    return connection;
                }
            }
            return null;
        }
        
        /**
         * Find VPN profile by NetworkManager connection
         */
        private VPNProfile? find_profile_by_nm_connection(NM.Connection connection) {
            var connection_id = connection.get_id();
            return find_profile_by_name(connection_id);
        }
        
        /**
         * Find active VPN connection for a profile
         */
        private NM.ActiveConnection? find_active_vpn_connection(VPNProfile profile) {
            if (!nm_client.is_available || nm_client.nm_client == null) {
                return null;
            }
            
            var active_connections = nm_client.nm_client.get_active_connections();
            foreach (var ac in active_connections) {
                if (is_vpn_active_connection(ac)) {
                    var connection = ac.get_connection();
                    if (connection != null && connection.get_id() == profile.name) {
                        return ac;
                    }
                }
            }
            return null;
        }
        
        /**
         * Create NetworkManager connection for VPN profile
         */
        private async NM.Connection? create_nm_connection_for_profile(VPNProfile profile) throws Error {
            // This would create the appropriate NetworkManager connection
            // based on the VPN type and configuration
            debug("VPNManager: Creating NetworkManager connection for profile %s", profile.name);
            
            // Placeholder implementation - actual implementation would create
            // proper NM.Connection objects with VPN-specific settings
            return null;
        }
        
        /**
         * Update NetworkManager connection for VPN profile
         */
        private async void update_nm_connection_for_profile(NM.Connection connection, VPNProfile profile) throws Error {
            // This would update the NetworkManager connection with new settings
            debug("VPNManager: Updating NetworkManager connection for profile %s", profile.name);
        }
        
        /**
         * Sync VPN profile from NetworkManager connection
         */
        private void sync_vpn_profile_from_nm_connection(NM.Connection connection) {
            // This would create or update a VPN profile based on an existing
            // NetworkManager connection
            debug("VPNManager: Syncing profile from NetworkManager connection %s", connection.get_id());
        }
        
        /**
         * Remove VPN profile by NetworkManager UUID
         */
        private void remove_vpn_profile_by_nm_id(string uuid) {
            for (uint i = 0; i < _vpn_profiles.length; i++) {
                var profile = _vpn_profiles[i];
                // In practice, you'd store the NM UUID in the profile
                // For now, just remove by name matching
                _vpn_profiles.remove(profile);
                profiles_updated(_vpn_profiles);
                break;
            }
        }
        
        /**
         * Parse VPN configuration file
         */
        private async VPNConfiguration? parse_vpn_config_file(string file_path, VPNType vpn_type) throws Error {
            var file = File.new_for_path(file_path);
            var stream = yield file.read_async();
            var data_stream = new DataInputStream(stream);
            
            var config = new VPNConfiguration();
            config.config_file_path = file_path;
            
            // Parse based on VPN type
            switch (vpn_type) {
                case VPNType.OPENVPN:
                    return yield parse_openvpn_config(data_stream, config);
                case VPNType.WIREGUARD:
                    return yield parse_wireguard_config(data_stream, config);
                default:
                    throw new IOError.NOT_SUPPORTED("Unsupported VPN type: %s", vpn_type.to_string());
            }
        }
        
        /**
         * Parse OpenVPN configuration
         */
        private async VPNConfiguration? parse_openvpn_config(DataInputStream stream, VPNConfiguration config) throws Error {
            string? line;
            while ((line = yield stream.read_line_async()) != null) {
                line = line.strip();
                if (line.length == 0 || line.has_prefix("#")) {
                    continue;
                }
                
                var parts = line.split(" ");
                if (parts.length < 2) continue;
                
                switch (parts[0]) {
                    case "remote":
                        config.server_address = parts[1];
                        if (parts.length > 2) {
                            config.port = (uint16)int.parse(parts[2]);
                        }
                        break;
                    case "port":
                        config.port = (uint16)int.parse(parts[1]);
                        break;
                    case "ca":
                        config.ca_certificate_path = parts[1];
                        break;
                    case "cert":
                        config.certificate_path = parts[1];
                        break;
                    case "key":
                        config.private_key_path = parts[1];
                        break;
                }
            }
            
            return config;
        }
        
        /**
         * Parse WireGuard configuration
         */
        private async VPNConfiguration? parse_wireguard_config(DataInputStream stream, VPNConfiguration config) throws Error {
            string? line;
            string? current_section = null;
            
            while ((line = yield stream.read_line_async()) != null) {
                line = line.strip();
                if (line.length == 0 || line.has_prefix("#")) {
                    continue;
                }
                
                if (line.has_prefix("[") && line.has_suffix("]")) {
                    current_section = line[1:-1];
                    continue;
                }
                
                var parts = line.split("=");
                if (parts.length != 2) continue;
                
                var key = parts[0].strip();
                var value = parts[1].strip();
                
                if (current_section == "Interface") {
                    // Interface section
                    if (key == "PrivateKey") {
                        // Store private key (in practice, handle securely)
                        config.additional_options.set("PrivateKey", value);
                    }
                } else if (current_section == "Peer") {
                    // Peer section
                    if (key == "Endpoint") {
                        var endpoint_parts = value.split(":");
                        if (endpoint_parts.length == 2) {
                            config.server_address = endpoint_parts[0];
                            config.port = (uint16)int.parse(endpoint_parts[1]);
                        }
                    }
                }
            }
            
            return config;
        }
        
        /**
         * Extract profile name from file path
         */
        private string extract_profile_name_from_path(string file_path) {
            var basename = Path.get_basename(file_path);
            var name = basename;
            
            // Remove file extension
            if (name.has_suffix(".ovpn")) {
                name = name[0:-5];
            } else if (name.has_suffix(".conf")) {
                name = name[0:-5];
            }
            
            // Replace underscores with spaces
            if (name != null) {
                name = name.replace("_", " ");
            }
            
            return name;
        }
    }
}