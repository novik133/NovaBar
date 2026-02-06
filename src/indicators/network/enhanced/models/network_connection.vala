/**
 * Enhanced Network Indicator - Core Network Connection Model
 * 
 * This file defines the base NetworkConnection class and related data structures
 * that represent network connections in the enhanced network indicator system.
 */

using GLib;

namespace EnhancedNetwork {

    /**
     * Credentials for network authentication
     */
    public class Credentials : GLib.Object {
        public string? password { get; set; }
        public string? username { get; set; }
        public string? certificate_path { get; set; }
        public string? private_key_path { get; set; }
        public string? ca_certificate_path { get; set; }
        
        public Credentials() {}
        
        public Credentials.with_password(string password) {
            this.password = password;
        }
        
        public Credentials.with_username_password(string username, string password) {
            this.username = username;
            this.password = password;
        }
    }

    /**
     * Connection information and statistics
     */
    public class ConnectionInfo : GLib.Object {
        public string? ip_address { get; set; }
        public string? subnet_mask { get; set; }
        public string? gateway { get; set; }
        public string? dns_servers { get; set; }
        public uint64 bytes_sent { get; set; }
        public uint64 bytes_received { get; set; }
        public uint32 speed_mbps { get; set; }
        public uint32 latency_ms { get; set; }
        public DateTime? connected_since { get; set; }
        
        public ConnectionInfo() {
            connected_since = new DateTime.now_local();
        }
    }

    /**
     * Base class for all network connections
     * 
     * This abstract class provides the common interface and properties
     * for all types of network connections in the system.
     */
    public abstract class NetworkConnection : GLib.Object {
        public string id { get; set; }
        public string name { get; set; }
        public ConnectionType connection_type { get; set; }
        public ConnectionState state { get; set; }
        public string? device_path { get; set; }
        public DateTime last_connected { get; set; }
        public bool auto_connect { get; set; }
        public SecurityLevel security_level { get; set; }
        
        protected ConnectionInfo? _connection_info;
        
        /**
         * Signal emitted when connection state changes
         */
        public signal void state_changed(ConnectionState old_state, ConnectionState new_state);
        
        /**
         * Signal emitted when connection information is updated
         */
        public signal void info_updated(ConnectionInfo info);
        
        protected NetworkConnection() {
            last_connected = new DateTime.now_local();
            auto_connect = false;
            security_level = SecurityLevel.UNKNOWN;
            state = ConnectionState.DISCONNECTED;
        }
        
        /**
         * Initiate connection to this network
         * 
         * @param credentials Optional authentication credentials
         * @return true if connection was initiated successfully
         */
        public abstract async bool connect_to_network(Credentials? credentials = null) throws Error;
        
        /**
         * Disconnect from this network
         * 
         * @return true if disconnection was initiated successfully
         */
        public abstract async bool disconnect_from_network() throws Error;
        
        /**
         * Get current connection information
         * 
         * @return ConnectionInfo object with current connection details
         */
        public virtual ConnectionInfo? get_connection_info() {
            return _connection_info;
        }
        
        /**
         * Update the connection state and emit signal
         */
        public void update_state(ConnectionState new_state) {
            var old_state = state;
            state = new_state;
            
            if (new_state == ConnectionState.CONNECTED) {
                last_connected = new DateTime.now_local();
            }
            
            state_changed(old_state, new_state);
        }
        
        /**
         * Update connection information and emit signal
         */
        public void update_connection_info(ConnectionInfo info) {
            _connection_info = info;
            info_updated(info);
        }
        
        /**
         * Get a human-readable description of the connection state
         */
        public string get_state_description() {
            switch (state) {
                case ConnectionState.DISCONNECTED:
                    return "Disconnected";
                case ConnectionState.CONNECTING:
                    return "Connecting...";
                case ConnectionState.CONNECTED:
                    return "Connected";
                case ConnectionState.DISCONNECTING:
                    return "Disconnecting...";
                case ConnectionState.FAILED:
                    return "Connection Failed";
                default:
                    return "Unknown";
            }
        }
        
        /**
         * Get a human-readable description of the security level
         */
        public string get_security_description() {
            switch (security_level) {
                case SecurityLevel.SECURE:
                    return "Secure";
                case SecurityLevel.WARNING:
                    return "Warning";
                case SecurityLevel.INSECURE:
                    return "Insecure";
                case SecurityLevel.UNKNOWN:
                default:
                    return "Unknown";
            }
        }
    }
}
    /**
     * Basic NetworkConnection implementation for simple cases
     */
    public class BasicNetworkConnection : EnhancedNetwork.NetworkConnection {
        public BasicNetworkConnection() {
            base();
        }
        
        public override async bool connect_to_network(EnhancedNetwork.Credentials? credentials = null) throws Error {
            // Basic implementation - would be overridden by specific connection types
            return false;
        }
        
        public override async bool disconnect_from_network() throws Error {
            // Basic implementation - would be overridden by specific connection types
            return false;
        }
    }