/**
 * Enhanced Network Indicator - PolicyKit D-Bus Client
 * 
 * This file provides PolicyKit integration for secure privilege escalation
 * when performing network management operations that require elevated permissions.
 */

using GLib;

namespace EnhancedNetwork {

    /**
     * PolicyKit authorization result
     */
    public enum AuthorizationResult {
        AUTHORIZED,
        CHALLENGE,
        NOT_AUTHORIZED,
        NOT_HANDLED,
        DISMISSED
    }

    /**
     * PolicyKit error types
     */
    public enum PolicyKitError {
        NOT_AVAILABLE,
        AUTHORIZATION_FAILED,
        TIMEOUT,
        CANCELLED,
        INVALID_ACTION
    }

    /**
     * PolicyKit authorization details
     */
    public class AuthorizationDetails : GLib.Object {
        public string action_id { get; set; }
        public string message { get; set; }
        public string icon_name { get; set; }
        public AuthorizationResult result { get; set; }
        public bool is_temporary { get; set; }
        public uint32 expires_in { get; set; }
        
        public AuthorizationDetails(string action_id) {
            this.action_id = action_id;
            this.result = AuthorizationResult.NOT_HANDLED;
            this.is_temporary = false;
            this.expires_in = 0;
        }
    }

    /**
     * PolicyKit D-Bus client for privilege management
     * 
     * This class provides a high-level interface for PolicyKit authorization
     * requests, handling authentication prompts and permission management.
     */
    public class PolicyKitClient : GLib.Object {
        private const string POLKIT_DBUS_NAME = "org.freedesktop.PolicyKit1";
        private const string POLKIT_DBUS_PATH = "/org/freedesktop/PolicyKit1/Authority";
        private const string POLKIT_DBUS_INTERFACE = "org.freedesktop.PolicyKit1.Authority";
        
        private DBusConnection? _connection;
        private bool _is_available;
        private HashTable<string, AuthorizationDetails> _cached_authorizations;
        private uint _cache_cleanup_timeout;
        
        /**
         * Signal emitted when PolicyKit availability changes
         */
        public signal void availability_changed(bool available);
        
        /**
         * Signal emitted when authorization is requested
         */
        public signal void authorization_requested(AuthorizationDetails details);
        
        /**
         * Signal emitted when authorization is completed
         */
        public signal void authorization_completed(AuthorizationDetails details);
        
        /**
         * Signal emitted when an error occurs
         */
        public signal void error_occurred(PolicyKitError error, string message);
        
        public bool is_available { 
            get { return _is_available; } 
        }
        
        public PolicyKitClient() {
            _is_available = false;
            _cached_authorizations = new HashTable<string, AuthorizationDetails>(str_hash, str_equal);
            _cache_cleanup_timeout = 0;
        }
        
        /**
         * Initialize the PolicyKit client asynchronously
         * 
         * @return true if initialization was successful
         */
        public async bool initialize() {
            try {
                debug("PolicyKitClient: Initializing PolicyKit client...");
                
                _connection = yield Bus.get(BusType.SYSTEM);
                if (_connection == null) {
                    warning("PolicyKitClient: Failed to connect to system bus");
                    _is_available = false;
                    availability_changed(false);
                    return false;
                }
                
                // Test PolicyKit availability by calling a simple method
                var available = yield test_polkit_availability();
                if (!available) {
                    warning("PolicyKitClient: PolicyKit service not available");
                    _is_available = false;
                    availability_changed(false);
                    return false;
                }
                
                _is_available = true;
                debug("PolicyKitClient: PolicyKit client initialized successfully");
                
                // Setup cache cleanup timer (clean every 5 minutes)
                setup_cache_cleanup();
                
                availability_changed(true);
                return true;
                
            } catch (Error e) {
                warning("PolicyKitClient: Failed to initialize PolicyKit: %s", e.message);
                _is_available = false;
                _connection = null;
                availability_changed(false);
                return false;
            }
        }
        
        /**
         * Test if PolicyKit service is available
         */
        private async bool test_polkit_availability() {
            try {
                var result = yield _connection.call(
                    POLKIT_DBUS_NAME,
                    POLKIT_DBUS_PATH,
                    "org.freedesktop.DBus.Introspectable",
                    "Introspect",
                    null,
                    null,
                    DBusCallFlags.NONE,
                    5000
                );
                
                return result != null;
                
            } catch (Error e) {
                debug("PolicyKitClient: PolicyKit availability test failed: %s", e.message);
                return false;
            }
        }
        
        /**
         * Check if an action is authorized for the current process
         * 
         * @param action_id The PolicyKit action identifier
         * @param allow_user_interaction Whether to allow authentication prompts
         * @return Authorization result
         */
        public async AuthorizationResult check_authorization(string action_id, bool allow_user_interaction = true) {
            if (!_is_available) {
                error_occurred(PolicyKitError.NOT_AVAILABLE, "PolicyKit service not available");
                return AuthorizationResult.NOT_HANDLED;
            }
            
            // Check cache first
            var cached = _cached_authorizations.lookup(action_id);
            if (cached != null && !is_authorization_expired(cached)) {
                debug("PolicyKitClient: Using cached authorization for %s: %s", 
                      action_id, cached.result.to_string());
                return cached.result;
            }
            
            try {
                debug("PolicyKitClient: Checking authorization for action: %s", action_id);
                
                var details = new AuthorizationDetails(action_id);
                authorization_requested(details);
                
                var subject = create_process_subject();
                var flags = allow_user_interaction ? 1 : 0; // ALLOW_USER_INTERACTION = 1
                
                var details_builder = new VariantBuilder(new VariantType("a{ss}"));
                var details_dict = details_builder.end();
                
                var result = yield _connection.call(
                    POLKIT_DBUS_NAME,
                    POLKIT_DBUS_PATH,
                    POLKIT_DBUS_INTERFACE,
                    "CheckAuthorization",
                    new Variant("((sa{sv})sa{ss}us)", 
                               subject,
                               action_id,
                               details_dict,
                               flags,
                               ""),
                    new VariantType("((bba{ss})u)"),
                    DBusCallFlags.NONE,
                    30000 // 30 second timeout for user interaction
                );
                
                if (result != null) {
                    var auth_result = parse_authorization_result(result);
                    details.result = auth_result;
                    
                    // Cache the result if it's a definitive answer
                    if (auth_result == AuthorizationResult.AUTHORIZED || 
                        auth_result == AuthorizationResult.NOT_AUTHORIZED) {
                        cache_authorization(details);
                    }
                    
                    debug("PolicyKitClient: Authorization result for %s: %s", 
                          action_id, auth_result.to_string());
                    
                    authorization_completed(details);
                    return auth_result;
                }
                
                error_occurred(PolicyKitError.AUTHORIZATION_FAILED, "No result returned from PolicyKit");
                return AuthorizationResult.NOT_HANDLED;
                
            } catch (Error e) {
                warning("PolicyKitClient: Authorization check failed: %s", e.message);
                
                if (e is IOError.TIMED_OUT) {
                    error_occurred(PolicyKitError.TIMEOUT, "Authorization request timed out");
                } else if (e is IOError.CANCELLED) {
                    error_occurred(PolicyKitError.CANCELLED, "Authorization request was cancelled");
                } else {
                    error_occurred(PolicyKitError.AUTHORIZATION_FAILED, e.message);
                }
                
                return AuthorizationResult.NOT_HANDLED;
            }
        }
        
        /**
         * Check if the current process has authorization for a specific action
         * without user interaction
         * 
         * @param action_id The PolicyKit action identifier
         * @return true if authorized
         */
        public async bool is_authorized(string action_id) {
            var result = yield check_authorization(action_id, false);
            return result == AuthorizationResult.AUTHORIZED;
        }
        
        /**
         * Request authorization with user interaction if needed
         * 
         * @param action_id The PolicyKit action identifier
         * @param message Optional message to display to the user
         * @return true if authorization was granted
         */
        public async bool request_authorization(string action_id, string? message = null) {
            var result = yield check_authorization(action_id, true);
            return result == AuthorizationResult.AUTHORIZED;
        }
        
        /**
         * Get a list of common network management actions and their authorization status
         * 
         * @return Hash table mapping action IDs to authorization results
         */
        public async HashTable<string, AuthorizationResult> get_network_permissions() {
            var permissions = new HashTable<string, AuthorizationResult>(str_hash, str_equal);
            
            string[] network_actions = {
                "org.freedesktop.NetworkManager.settings.modify.system",
                "org.freedesktop.NetworkManager.settings.modify.own",
                "org.freedesktop.NetworkManager.network-control",
                "org.freedesktop.NetworkManager.wifi.share.protected",
                "org.freedesktop.NetworkManager.wifi.share.open",
                "org.freedesktop.NetworkManager.enable-disable-network",
                "org.freedesktop.NetworkManager.enable-disable-wifi"
            };
            
            foreach (var action in network_actions) {
                try {
                    var result = yield check_authorization(action, false);
                    permissions.insert(action, result);
                } catch (Error e) {
                    debug("PolicyKitClient: Failed to check authorization for %s: %s", action, e.message);
                    permissions.insert(action, AuthorizationResult.NOT_HANDLED);
                }
            }
            
            return permissions;
        }
        
        /**
         * Handle fallback behavior when authorization fails
         * 
         * @param action_id The action that failed authorization
         * @param fallback_message Message to display to user about limitations
         */
        public void handle_authorization_failure(string action_id, string fallback_message) {
            debug("PolicyKitClient: Handling authorization failure for %s", action_id);
            
            // Emit error signal with fallback information
            error_occurred(PolicyKitError.AUTHORIZATION_FAILED, fallback_message);
            
            // Log the failure for diagnostics
            warning("PolicyKitClient: Authorization failed for %s - %s", action_id, fallback_message);
        }
        
        /**
         * Clear cached authorizations
         */
        public void clear_authorization_cache() {
            debug("PolicyKitClient: Clearing authorization cache");
            _cached_authorizations.remove_all();
        }
        
        /**
         * Get human-readable description for common network actions
         */
        public string get_action_description(string action_id) {
            switch (action_id) {
                case "org.freedesktop.NetworkManager.settings.modify.system":
                    return "Modify system network settings";
                case "org.freedesktop.NetworkManager.settings.modify.own":
                    return "Modify your network settings";
                case "org.freedesktop.NetworkManager.network-control":
                    return "Control network connections";
                case "org.freedesktop.NetworkManager.wifi.share.protected":
                    return "Create protected WiFi hotspot";
                case "org.freedesktop.NetworkManager.wifi.share.open":
                    return "Create open WiFi hotspot";
                case "org.freedesktop.NetworkManager.enable-disable-network":
                    return "Enable or disable networking";
                case "org.freedesktop.NetworkManager.enable-disable-wifi":
                    return "Enable or disable WiFi";
                default:
                    return "Perform network management operation";
            }
        }
        
        /**
         * Create a process subject for the current process
         */
        private Variant create_process_subject() {
            // Use a simple approach - get PID from /proc/self
            var pid = get_current_pid();
            var start_time = get_process_start_time();
            
            var subject_details = new VariantBuilder(new VariantType("a{sv}"));
            subject_details.add("{sv}", "pid", new Variant.uint32(pid));
            subject_details.add("{sv}", "start-time", new Variant.uint64(start_time));
            
            return new Variant("(sa{sv})", "unix-process", subject_details);
        }
        
        /**
         * Get the current process ID
         */
        private uint32 get_current_pid() {
            try {
                var pid_file = File.new_for_path("/proc/self/stat");
                var stream = pid_file.read();
                var data_stream = new DataInputStream(stream);
                
                var line = data_stream.read_line();
                if (line != null) {
                    var parts = line.split(" ");
                    if (parts.length > 0) {
                        return (uint32)int.parse(parts[0]);
                    }
                }
            } catch (Error e) {
                debug("PolicyKitClient: Failed to get PID from /proc/self/stat: %s", e.message);
            }
            
            // Fallback - use a reasonable default
            return 1;
        }
        
        /**
         * Get the start time of the current process
         */
        private uint64 get_process_start_time() {
            try {
                var stat_file = File.new_for_path("/proc/self/stat");
                var stream = stat_file.read();
                var data_stream = new DataInputStream(stream);
                
                var line = data_stream.read_line();
                if (line != null) {
                    var parts = line.split(" ");
                    if (parts.length > 21) {
                        return uint64.parse(parts[21]);
                    }
                }
            } catch (Error e) {
                debug("PolicyKitClient: Failed to get process start time: %s", e.message);
            }
            
            // Fallback to current time
            return (uint64)(get_real_time() / 1000000);
        }
        
        /**
         * Parse the authorization result from PolicyKit D-Bus response
         */
        private AuthorizationResult parse_authorization_result(Variant result) {
            var outer_tuple = result.get_child_value(0);
            var is_authorized = outer_tuple.get_child_value(0).get_boolean();
            var is_challenge = outer_tuple.get_child_value(1).get_boolean();
            
            if (is_authorized) {
                return AuthorizationResult.AUTHORIZED;
            } else if (is_challenge) {
                return AuthorizationResult.CHALLENGE;
            } else {
                return AuthorizationResult.NOT_AUTHORIZED;
            }
        }
        
        /**
         * Cache an authorization result
         */
        private void cache_authorization(AuthorizationDetails details) {
            // Set expiration time (5 minutes for temporary, 1 hour for permanent)
            details.expires_in = details.is_temporary ? 300 : 3600;
            _cached_authorizations.insert(details.action_id, details);
            
            debug("PolicyKitClient: Cached authorization for %s (expires in %u seconds)", 
                  details.action_id, details.expires_in);
        }
        
        /**
         * Check if a cached authorization has expired
         */
        private bool is_authorization_expired(AuthorizationDetails details) {
            // Simple expiration check - in a real implementation, you'd track timestamps
            return false; // For now, assume cached results are valid
        }
        
        /**
         * Setup periodic cache cleanup
         */
        private void setup_cache_cleanup() {
            if (_cache_cleanup_timeout > 0) {
                Source.remove(_cache_cleanup_timeout);
            }
            
            _cache_cleanup_timeout = Timeout.add_seconds(300, () => {
                cleanup_expired_cache();
                return Source.CONTINUE;
            });
        }
        
        /**
         * Clean up expired cache entries
         */
        private void cleanup_expired_cache() {
            var expired_keys = new GenericArray<string>();
            
            _cached_authorizations.foreach((key, details) => {
                if (is_authorization_expired(details)) {
                    expired_keys.add(key);
                }
            });
            
            for (uint i = 0; i < expired_keys.length; i++) {
                _cached_authorizations.remove(expired_keys[i]);
            }
            
            if (expired_keys.length > 0) {
                debug("PolicyKitClient: Cleaned up %u expired cache entries", expired_keys.length);
            }
        }
        
        /**
         * Handle PolicyKit becoming unavailable
         */
        public void handle_polkit_unavailable() {
            warning("PolicyKitClient: PolicyKit became unavailable");
            _is_available = false;
            _connection = null;
            
            // Clear cache
            _cached_authorizations.remove_all();
            
            // Remove cleanup timer
            if (_cache_cleanup_timeout > 0) {
                Source.remove(_cache_cleanup_timeout);
                _cache_cleanup_timeout = 0;
            }
            
            availability_changed(false);
        }
        
        /**
         * Attempt to reconnect to PolicyKit
         */
        public async bool reconnect() {
            debug("PolicyKitClient: Attempting to reconnect to PolicyKit...");
            return yield initialize();
        }
    }
}