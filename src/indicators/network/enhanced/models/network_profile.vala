/**
 * Enhanced Network Indicator - Network Profile Model
 * 
 * This file defines the NetworkProfile class and related data structures
 * for managing multiple network profiles and configurations.
 */

using GLib;

namespace EnhancedNetwork {

    /**
     * Network profile priority levels
     */
    public enum ProfilePriority {
        LOW = 1,
        NORMAL = 5,
        HIGH = 10,
        CRITICAL = 15
    }

    /**
     * Profile activation conditions
     */
    public enum ProfileCondition {
        MANUAL,           // Manual activation only
        LOCATION_BASED,   // Activate based on location/SSID
        TIME_BASED,       // Activate based on time of day
        NETWORK_BASED,    // Activate based on available networks
        POWER_BASED       // Activate based on power state
    }

    /**
     * Proxy configuration for network profiles
     */
    public class ProxyConfiguration : GLib.Object {
        public bool enabled { get; set; default = false; }
        public string http_proxy { get; set; default = ""; }
        public string https_proxy { get; set; default = ""; }
        public string socks_proxy { get; set; default = ""; }
        public string no_proxy { get; set; default = ""; }
        public bool auto_config { get; set; default = false; }
        public string auto_config_url { get; set; default = ""; }
        
        public ProxyConfiguration() {}
        
        public ProxyConfiguration.with_http(string http_proxy) {
            this.enabled = true;
            this.http_proxy = http_proxy;
        }
        
        public bool is_valid() {
            if (!enabled) return true;
            
            return http_proxy.length > 0 || https_proxy.length > 0 || 
                   socks_proxy.length > 0 || auto_config;
        }
    }

    /**
     * DNS configuration for network profiles
     */
    public class DNSConfiguration : GLib.Object {
        public bool custom_dns { get; set; default = false; }
        public string[] dns_servers { get; set; }
        public bool dns_over_https { get; set; default = false; }
        public string doh_server { get; set; default = ""; }
        public bool dns_over_tls { get; set; default = false; }
        public string dot_server { get; set; default = ""; }
        
        public DNSConfiguration() {
            dns_servers = {};
        }
        
        public void add_dns_server(string server) {
            string[] new_servers = dns_servers;
            new_servers += server;
            dns_servers = new_servers;
        }
        
        public void remove_dns_server(string server) {
            string[] new_servers = {};
            foreach (string s in dns_servers) {
                if (s != server) {
                    new_servers += s;
                }
            }
            dns_servers = new_servers;
        }
        
        public bool is_valid() {
            if (!custom_dns) return true;
            
            foreach (string server in dns_servers) {
                if (!is_valid_ip_address(server)) {
                    return false;
                }
            }
            
            return dns_servers.length > 0;
        }
        
        private bool is_valid_ip_address(string ip) {
            // Basic IP validation - could be enhanced
            var parts = ip.split(".");
            if (parts.length != 4) return false;
            
            foreach (string part in parts) {
                int val = int.parse(part);
                if (val < 0 || val > 255) return false;
            }
            
            return true;
        }
    }

    /**
     * 802.1X enterprise authentication configuration
     */
    public class EnterpriseAuthConfiguration : GLib.Object {
        public bool enabled { get; set; default = false; }
        public string eap_method { get; set; default = ""; }
        public string identity { get; set; default = ""; }
        public string anonymous_identity { get; set; default = ""; }
        public string password { get; set; default = ""; }
        public string ca_certificate_path { get; set; default = ""; }
        public string client_certificate_path { get; set; default = ""; }
        public string private_key_path { get; set; default = ""; }
        public string private_key_password { get; set; default = ""; }
        public bool validate_server_certificate { get; set; default = true; }
        
        public EnterpriseAuthConfiguration() {}
        
        public bool is_valid() {
            if (!enabled) return true;
            
            return eap_method.length > 0 && identity.length > 0;
        }
    }

    /**
     * Profile activation condition configuration
     */
    public class ProfileConditionConfig : GLib.Object {
        public ProfileCondition condition_type { get; set; }
        public string[] ssid_list { get; set; }
        public string time_start { get; set; default = ""; }
        public string time_end { get; set; default = ""; }
        public bool weekdays_only { get; set; default = false; }
        public string location_name { get; set; default = ""; }
        public bool on_battery { get; set; default = false; }
        public bool on_ac_power { get; set; default = false; }
        
        public ProfileConditionConfig() {
            condition_type = ProfileCondition.MANUAL;
            ssid_list = {};
        }
        
        public void add_ssid(string ssid) {
            string[] new_list = ssid_list;
            new_list += ssid;
            ssid_list = new_list;
        }
        
        public void remove_ssid(string ssid) {
            string[] new_list = {};
            foreach (string s in ssid_list) {
                if (s != ssid) {
                    new_list += s;
                }
            }
            ssid_list = new_list;
        }
        
        public bool matches_current_conditions() {
            switch (condition_type) {
                case ProfileCondition.MANUAL:
                    return false; // Manual profiles never auto-activate
                    
                case ProfileCondition.TIME_BASED:
                    return matches_time_condition();
                    
                case ProfileCondition.LOCATION_BASED:
                    return matches_location_condition();
                    
                case ProfileCondition.POWER_BASED:
                    return matches_power_condition();
                    
                default:
                    return false;
            }
        }
        
        private bool matches_time_condition() {
            if (time_start.length == 0 || time_end.length == 0) return false;
            
            var now = new DateTime.now_local();
            var current_time = now.format("%H:%M");
            
            if (weekdays_only) {
                int day_of_week = now.get_day_of_week();
                if (day_of_week == 6 || day_of_week == 7) { // Saturday or Sunday
                    return false;
                }
            }
            
            return current_time >= time_start && current_time <= time_end;
        }
        
        private bool matches_location_condition() {
            // This would need integration with location services
            // For now, just return false
            return false;
        }
        
        private bool matches_power_condition() {
            // This would need integration with power management
            // For now, just return false
            return false;
        }
    }

    /**
     * Network profile containing all configuration settings
     */
    public class NetworkProfile : GLib.Object {
        public string id { get; set; }
        public string name { get; set; }
        public string description { get; set; default = ""; }
        public ProfilePriority priority { get; set; default = ProfilePriority.NORMAL; }
        public bool enabled { get; set; default = true; }
        public bool is_active { get; set; default = false; }
        public DateTime created_date { get; set; }
        public DateTime modified_date { get; set; }
        public DateTime? last_activated { get; set; }
        
        // Configuration components
        public ProxyConfiguration proxy_config { get; set; }
        public DNSConfiguration dns_config { get; set; }
        public EnterpriseAuthConfiguration enterprise_auth { get; set; }
        public ProfileConditionConfig activation_conditions { get; set; }
        
        // Network connection preferences
        public string[] preferred_wifi_networks { get; set; }
        public string[] preferred_vpn_profiles { get; set; }
        public bool prefer_ethernet { get; set; default = true; }
        public bool allow_mobile_data { get; set; default = false; }
        public bool allow_hotspot { get; set; default = false; }
        
        /**
         * Signal emitted when profile is activated
         */
        public signal void activated();
        
        /**
         * Signal emitted when profile is deactivated
         */
        public signal void deactivated();
        
        /**
         * Signal emitted when profile configuration changes
         */
        public signal void configuration_changed();
        
        public NetworkProfile() {
            id = Uuid.string_random();
            created_date = new DateTime.now_local();
            modified_date = created_date;
            
            proxy_config = new ProxyConfiguration();
            dns_config = new DNSConfiguration();
            enterprise_auth = new EnterpriseAuthConfiguration();
            activation_conditions = new ProfileConditionConfig();
            
            preferred_wifi_networks = {};
            preferred_vpn_profiles = {};
        }
        
        public NetworkProfile.with_name(string name) {
            this();
            this.name = name;
        }
        
        /**
         * Validate the profile configuration
         */
        public bool is_valid() {
            if (name.length == 0) return false;
            
            return proxy_config.is_valid() && 
                   dns_config.is_valid() && 
                   enterprise_auth.is_valid();
        }
        
        /**
         * Check if this profile should be activated based on current conditions
         */
        public bool should_activate() {
            if (!enabled) return false;
            
            return activation_conditions.matches_current_conditions();
        }
        
        /**
         * Activate this profile
         */
        public void activate() {
            if (is_active) return;
            
            is_active = true;
            last_activated = new DateTime.now_local();
            activated();
        }
        
        /**
         * Deactivate this profile
         */
        public void deactivate() {
            if (!is_active) return;
            
            is_active = false;
            deactivated();
        }
        
        /**
         * Update the modified timestamp
         */
        public void mark_modified() {
            modified_date = new DateTime.now_local();
            configuration_changed();
        }
        
        /**
         * Add a preferred WiFi network
         */
        public void add_preferred_wifi(string ssid) {
            string[] new_list = preferred_wifi_networks;
            new_list += ssid;
            preferred_wifi_networks = new_list;
            mark_modified();
        }
        
        /**
         * Remove a preferred WiFi network
         */
        public void remove_preferred_wifi(string ssid) {
            string[] new_list = {};
            foreach (string s in preferred_wifi_networks) {
                if (s != ssid) {
                    new_list += s;
                }
            }
            preferred_wifi_networks = new_list;
            mark_modified();
        }
        
        /**
         * Add a preferred VPN profile
         */
        public void add_preferred_vpn(string vpn_id) {
            string[] new_list = preferred_vpn_profiles;
            new_list += vpn_id;
            preferred_vpn_profiles = new_list;
            mark_modified();
        }
        
        /**
         * Remove a preferred VPN profile
         */
        public void remove_preferred_vpn(string vpn_id) {
            string[] new_list = {};
            foreach (string s in preferred_vpn_profiles) {
                if (s != vpn_id) {
                    new_list += s;
                }
            }
            preferred_vpn_profiles = new_list;
            mark_modified();
        }
        
        /**
         * Create a copy of this profile
         */
        public NetworkProfile copy() {
            var copy = new NetworkProfile();
            copy.id = Uuid.string_random(); // New ID for copy
            copy.name = (name ?? "Profile") + " (Copy)";
            copy.description = description;
            copy.priority = priority;
            copy.enabled = enabled;
            copy.prefer_ethernet = prefer_ethernet;
            copy.allow_mobile_data = allow_mobile_data;
            copy.allow_hotspot = allow_hotspot;
            
            // Deep copy configurations
            copy.proxy_config = copy_proxy_config();
            copy.dns_config = copy_dns_config();
            copy.enterprise_auth = copy_enterprise_auth();
            copy.activation_conditions = copy_activation_conditions();
            
            // Copy arrays
            copy.preferred_wifi_networks = preferred_wifi_networks;
            copy.preferred_vpn_profiles = preferred_vpn_profiles;
            
            return copy;
        }
        
        private ProxyConfiguration copy_proxy_config() {
            var copy = new ProxyConfiguration();
            copy.enabled = proxy_config.enabled;
            copy.http_proxy = proxy_config.http_proxy;
            copy.https_proxy = proxy_config.https_proxy;
            copy.socks_proxy = proxy_config.socks_proxy;
            copy.no_proxy = proxy_config.no_proxy;
            copy.auto_config = proxy_config.auto_config;
            copy.auto_config_url = proxy_config.auto_config_url;
            return copy;
        }
        
        private DNSConfiguration copy_dns_config() {
            var copy = new DNSConfiguration();
            copy.custom_dns = dns_config.custom_dns;
            copy.dns_servers = dns_config.dns_servers;
            copy.dns_over_https = dns_config.dns_over_https;
            copy.doh_server = dns_config.doh_server;
            copy.dns_over_tls = dns_config.dns_over_tls;
            copy.dot_server = dns_config.dot_server;
            return copy;
        }
        
        private EnterpriseAuthConfiguration copy_enterprise_auth() {
            var copy = new EnterpriseAuthConfiguration();
            copy.enabled = enterprise_auth.enabled;
            copy.eap_method = enterprise_auth.eap_method;
            copy.identity = enterprise_auth.identity;
            copy.anonymous_identity = enterprise_auth.anonymous_identity;
            copy.password = enterprise_auth.password;
            copy.ca_certificate_path = enterprise_auth.ca_certificate_path;
            copy.client_certificate_path = enterprise_auth.client_certificate_path;
            copy.private_key_path = enterprise_auth.private_key_path;
            copy.private_key_password = enterprise_auth.private_key_password;
            copy.validate_server_certificate = enterprise_auth.validate_server_certificate;
            return copy;
        }
        
        private ProfileConditionConfig copy_activation_conditions() {
            var copy = new ProfileConditionConfig();
            copy.condition_type = activation_conditions.condition_type;
            copy.ssid_list = activation_conditions.ssid_list;
            copy.time_start = activation_conditions.time_start;
            copy.time_end = activation_conditions.time_end;
            copy.weekdays_only = activation_conditions.weekdays_only;
            copy.location_name = activation_conditions.location_name;
            copy.on_battery = activation_conditions.on_battery;
            copy.on_ac_power = activation_conditions.on_ac_power;
            return copy;
        }
    }
}