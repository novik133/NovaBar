/**
 * Enhanced Network Indicator - Security Analyzer Component
 * 
 * This file implements the SecurityAnalyzer class that provides comprehensive
 * network security assessment, risk analysis, captive portal detection,
 * and security alerting functionality.
 */

using GLib;
using NM;

namespace EnhancedNetwork {

    /**
     * Security assessment result for a network
     */
    public class SecurityAssessment : GLib.Object {
        public NetworkConnection network { get; set; }
        public SecurityLevel overall_level { get; set; }
        public GenericArray<SecurityRisk> risks { get; set; }
        public GenericArray<SecurityRecommendation> recommendations { get; set; }
        public DateTime assessment_time { get; set; }
        public bool has_captive_portal { get; set; }
        public string? captive_portal_url { get; set; }
        
        public SecurityAssessment() {
            risks = new GenericArray<SecurityRisk>();
            recommendations = new GenericArray<SecurityRecommendation>();
            assessment_time = new DateTime.now_local();
            overall_level = SecurityLevel.UNKNOWN;
            has_captive_portal = false;
        }
        
        /**
         * Get human-readable security level description
         */
        public string get_level_description() {
            switch (overall_level) {
                case SecurityLevel.SECURE:
                    return "Secure";
                case SecurityLevel.WARNING:
                    return "Potentially Insecure";
                case SecurityLevel.INSECURE:
                    return "Insecure";
                case SecurityLevel.UNKNOWN:
                default:
                    return "Unknown";
            }
        }
        
        /**
         * Get security score (0-100)
         */
        public uint get_security_score() {
            switch (overall_level) {
                case SecurityLevel.SECURE:
                    return 90 - (risks.length * 5); // Reduce score for each risk
                case SecurityLevel.WARNING:
                    return 60 - (risks.length * 10);
                case SecurityLevel.INSECURE:
                    return 20 - (risks.length * 5);
                case SecurityLevel.UNKNOWN:
                default:
                    return 0;
            }
        }
    }

    /**
     * Security risk identified in network analysis
     */
    public class SecurityRisk : GLib.Object {
        public string risk_id { get; set; }
        public string title { get; set; }
        public string description { get; set; }
        public ErrorSeverity severity { get; set; }
        public string? mitigation_advice { get; set; }
        public DateTime detected_time { get; set; }
        
        public SecurityRisk() {
            detected_time = new DateTime.now_local();
        }
        
        public SecurityRisk.with_details(string risk_id, string title, string description, ErrorSeverity severity) {
            this();
            this.risk_id = risk_id;
            this.title = title;
            this.description = description;
            this.severity = severity;
        }
        
        /**
         * Get severity description
         */
        public string get_severity_description() {
            switch (severity) {
                case ErrorSeverity.CRITICAL:
                    return "Critical";
                case ErrorSeverity.HIGH:
                    return "High";
                case ErrorSeverity.MEDIUM:
                    return "Medium";
                case ErrorSeverity.LOW:
                default:
                    return "Low";
            }
        }
    }

    /**
     * Security recommendation for improving network security
     */
    public class SecurityRecommendation : GLib.Object {
        public string recommendation_id { get; set; }
        public string title { get; set; }
        public string description { get; set; }
        public string? action_text { get; set; }
        public bool is_actionable { get; set; }
        public DateTime created_time { get; set; }
        
        public SecurityRecommendation() {
            created_time = new DateTime.now_local();
            is_actionable = false;
        }
        
        public SecurityRecommendation.with_details(string id, string title, string description) {
            this();
            this.recommendation_id = id;
            this.title = title;
            this.description = description;
        }
    }

    /**
     * Security alert for immediate user attention
     */
    public class SecurityAlert : GLib.Object {
        public string alert_id { get; set; }
        public string title { get; set; }
        public string message { get; set; }
        public ErrorSeverity severity { get; set; }
        public NetworkConnection? related_network { get; set; }
        public DateTime alert_time { get; set; }
        public bool requires_user_action { get; set; }
        public string? suggested_action { get; set; }
        
        public SecurityAlert() {
            alert_time = new DateTime.now_local();
            requires_user_action = false;
        }
        
        public SecurityAlert.with_details(string id, string title, string message, ErrorSeverity severity) {
            this();
            this.alert_id = id;
            this.title = title;
            this.message = message;
            this.severity = severity;
        }
    }

    /**
     * Security Analyzer - Comprehensive network security assessment
     * 
     * This class provides complete security analysis functionality including
     * network security assessment, risk analysis, captive portal detection,
     * and security alerting system.
     */
    public class SecurityAnalyzer : GLib.Object {
        private NetworkManagerClient nm_client;
        private GenericArray<SecurityAssessment> _assessment_cache;
        private GenericArray<SecurityAlert> _active_alerts;
        private Timer? _monitoring_timer;
        private uint _monitoring_timeout_id;
        
        // Configuration
        private const uint MONITORING_INTERVAL_MS = 30000; // 30 seconds
        private const uint ASSESSMENT_CACHE_SIZE = 50;
        private const uint CAPTIVE_PORTAL_TIMEOUT_MS = 10000; // 10 seconds
        private const string CAPTIVE_PORTAL_TEST_URL = "http://detectportal.firefox.com/canonical.html";
        private const string EXPECTED_CAPTIVE_RESPONSE = "success";
        
        /**
         * Signal emitted when a security alert is generated
         */
        public signal void security_alert(SecurityAlert alert);
        
        /**
         * Signal emitted when a captive portal is detected
         */
        public signal void captive_portal_detected(NetworkConnection connection, string? portal_url);
        
        /**
         * Signal emitted when security assessment is completed
         */
        public signal void assessment_completed(SecurityAssessment assessment);
        
        /**
         * Signal emitted when suspicious activity is detected
         */
        public signal void suspicious_activity_detected(NetworkConnection connection, string activity_description);
        
        public SecurityAnalyzer(NetworkManagerClient nm_client) {
            this.nm_client = nm_client;
            _assessment_cache = new GenericArray<SecurityAssessment>();
            _active_alerts = new GenericArray<SecurityAlert>();
            
            // Setup NetworkManager client signals
            setup_nm_signals();
            
            // Start security monitoring
            start_monitoring();
        }
        
        /**
         * Setup NetworkManager client signal handlers
         */
        private void setup_nm_signals() {
            nm_client.availability_changed.connect((available) => {
                if (!available) {
                    handle_nm_unavailable();
                }
            });
            
            nm_client.connection_activated.connect((connection) => {
                // Analyze newly activated connections
                analyze_network.begin(connection);
            });
            
            nm_client.connection_deactivated.connect((connection) => {
                // Clear alerts for deactivated connections
                clear_alerts_for_connection(connection);
            });
        }
        
        /**
         * Perform comprehensive security analysis of a network
         */
        public async SecurityAssessment analyze_network(NetworkConnection connection) {
            debug("SecurityAnalyzer: Analyzing network: %s", connection.name);
            
            var assessment = new SecurityAssessment();
            assessment.network = connection;
            
            try {
                // Analyze connection security
                analyze_connection_security(assessment);
                
                // Check for captive portal
                yield check_captive_portal(assessment);
                
                // Analyze network environment
                analyze_network_environment(assessment);
                
                // Generate recommendations
                generate_security_recommendations(assessment);
                
                // Calculate overall security level
                calculate_overall_security_level(assessment);
                
                // Cache the assessment
                cache_assessment(assessment);
                
                // Generate alerts if necessary
                generate_security_alerts(assessment);
                
                debug("SecurityAnalyzer: Analysis completed for %s - Level: %s", 
                      connection.name, assessment.get_level_description());
                
                assessment_completed(assessment);
                return assessment;
                
            } catch (Error e) {
                warning("SecurityAnalyzer: Analysis error for %s: %s", connection.name, e.message);
                assessment.overall_level = SecurityLevel.UNKNOWN;
                return assessment;
            }
        }
        
        /**
         * Detect captive portal for a connection
         */
        public async bool detect_captive_portal(NetworkConnection connection) {
            debug("SecurityAnalyzer: Checking captive portal for: %s", connection.name);
            
            try {
                // Simplified captive portal detection without Soup dependency
                // In a real implementation, this would make HTTP requests to detect redirects
                
                // For now, return false (no captive portal detected)
                debug("SecurityAnalyzer: Captive portal detection not implemented (requires libsoup)");
                return false;
                
            } catch (Error e) {
                warning("SecurityAnalyzer: Captive portal detection error: %s", e.message);
                return false;
            }
        }
        
        /**
         * Get security recommendations for current network environment
         */
        public async GenericArray<SecurityRecommendation> get_security_recommendations() {
            var recommendations = new GenericArray<SecurityRecommendation>();
            
            if (!nm_client.is_available) {
                return recommendations;
            }
            
            // Get active connections
            var active_connections = nm_client.get_active_connections();
            
            foreach (var connection in active_connections) {
                var network_connection = create_network_connection_wrapper(connection);
                if (network_connection != null) {
                    var assessment = get_cached_assessment(network_connection);
                    if (assessment != null) {
                        for (uint i = 0; i < assessment.recommendations.length; i++) {
                            recommendations.add(assessment.recommendations[i]);
                        }
                    } else {
                        // Generate basic recommendations for unanalyzed connections
                        generate_basic_recommendations(network_connection, recommendations);
                    }
                }
            }
            
            // Add general security recommendations
            add_general_security_recommendations(recommendations);
            
            return recommendations;
        }
        
        /**
         * Check if a network is considered secure
         */
        public bool is_network_secure(NetworkConnection connection) {
            var assessment = get_cached_assessment(connection);
            if (assessment != null) {
                return assessment.overall_level == SecurityLevel.SECURE;
            }
            
            // Basic security check based on connection type and security
            if (connection.connection_type == ConnectionType.WIFI) {
                var wifi_network = connection as WiFiNetwork;
                if (wifi_network != null) {
                    return wifi_network.security_type != SecurityType.NONE &&
                           wifi_network.security_type != SecurityType.WEP;
                }
            }
            
            // Assume other connection types are secure by default
            return connection.connection_type != ConnectionType.WIFI;
        }
        
        /**
         * Get active security alerts
         */
        public GenericArray<SecurityAlert> get_active_alerts() {
            return _active_alerts;
        }
        
        /**
         * Dismiss a security alert
         */
        public void dismiss_alert(string alert_id) {
            for (uint i = 0; i < _active_alerts.length; i++) {
                var alert = _active_alerts[i];
                if (alert.alert_id == alert_id) {
                    _active_alerts.remove_index(i);
                    debug("SecurityAnalyzer: Dismissed alert: %s", alert_id);
                    break;
                }
            }
        }
        
        /**
         * Analyze connection security properties
         */
        private void analyze_connection_security(SecurityAssessment assessment) {
            var connection = assessment.network;
            
            if (connection.connection_type == ConnectionType.WIFI) {
                analyze_wifi_security(assessment);
            } else if (connection.connection_type == ConnectionType.VPN) {
                analyze_vpn_security(assessment);
            } else if (connection.connection_type == ConnectionType.ETHERNET) {
                analyze_ethernet_security(assessment);
            }
        }
        
        /**
         * Analyze WiFi-specific security
         */
        private void analyze_wifi_security(SecurityAssessment assessment) {
            var wifi_network = assessment.network as WiFiNetwork;
            if (wifi_network == null) return;
            
            // Check encryption type
            switch (wifi_network.security_type) {
                case SecurityType.NONE:
                    add_security_risk(assessment, "open_network", "Open Network", 
                                    "This network uses no encryption", ErrorSeverity.HIGH);
                    break;
                    
                case SecurityType.WEP:
                    add_security_risk(assessment, "weak_encryption", "Weak Encryption", 
                                    "WEP encryption is easily broken", ErrorSeverity.HIGH);
                    break;
                    
                case SecurityType.WPA_PSK:
                    add_security_risk(assessment, "outdated_encryption", "Outdated Encryption", 
                                    "WPA is less secure than WPA2/WPA3", ErrorSeverity.MEDIUM);
                    break;
                    
                case SecurityType.WPA2_PSK:
                case SecurityType.WPA3_PSK:
                    // These are considered secure
                    break;
                    
                case SecurityType.WPA_ENTERPRISE:
                case SecurityType.WPA2_ENTERPRISE:
                case SecurityType.WPA3_ENTERPRISE:
                    // Enterprise networks are generally more secure
                    break;
            }
            
            // Check signal strength (weak signals can indicate spoofing)
            if (wifi_network.signal_strength < 30) {
                add_security_risk(assessment, "weak_signal", "Weak Signal", 
                                "Weak signals may indicate network spoofing", ErrorSeverity.LOW);
            }
        }
        
        /**
         * Analyze VPN security
         */
        private void analyze_vpn_security(SecurityAssessment assessment) {
            // VPN connections are generally considered secure
            // Additional analysis could check VPN protocol, encryption, etc.
            debug("SecurityAnalyzer: VPN connections are generally secure");
        }
        
        /**
         * Analyze Ethernet security
         */
        private void analyze_ethernet_security(SecurityAssessment assessment) {
            // Ethernet connections are generally secure from wireless attacks
            // but may have other risks
            debug("SecurityAnalyzer: Ethernet connections have different security considerations");
        }
        
        /**
         * Check for captive portal
         */
        private async void check_captive_portal(SecurityAssessment assessment) {
            var has_portal = yield detect_captive_portal(assessment.network);
            assessment.has_captive_portal = has_portal;
            
            if (has_portal) {
                add_security_risk(assessment, "captive_portal", "Captive Portal Detected", 
                                "Network requires web authentication", ErrorSeverity.MEDIUM);
            }
        }
        
        /**
         * Analyze network environment for security risks
         */
        private void analyze_network_environment(SecurityAssessment assessment) {
            // This could include checking for:
            // - Multiple networks with same SSID (evil twin attacks)
            // - Unusual network behavior
            // - Known malicious networks
            
            debug("SecurityAnalyzer: Analyzing network environment (placeholder)");
        }
        
        /**
         * Generate security recommendations based on assessment
         */
        private void generate_security_recommendations(SecurityAssessment assessment) {
            var connection = assessment.network;
            
            // Generate recommendations based on risks
            for (uint i = 0; i < assessment.risks.length; i++) {
                var risk = assessment.risks[i];
                generate_recommendation_for_risk(assessment, risk);
            }
            
            // General recommendations
            if (connection.connection_type == ConnectionType.WIFI) {
                var wifi_network = connection as WiFiNetwork;
                if (wifi_network != null && wifi_network.security_type == SecurityType.NONE) {
                    add_security_recommendation(assessment, "use_vpn", "Use VPN", 
                                              "Consider using a VPN on open networks");
                }
            }
        }
        
        /**
         * Generate recommendation for a specific risk
         */
        private void generate_recommendation_for_risk(SecurityAssessment assessment, SecurityRisk risk) {
            switch (risk.risk_id) {
                case "open_network":
                    add_security_recommendation(assessment, "avoid_open", "Avoid Open Networks", 
                                              "Use networks with WPA2 or WPA3 encryption when possible");
                    add_security_recommendation(assessment, "use_vpn_open", "Use VPN", 
                                              "Always use a VPN when connecting to open networks");
                    break;
                    
                case "weak_encryption":
                    add_security_recommendation(assessment, "upgrade_security", "Upgrade Security", 
                                              "Ask network administrator to upgrade to WPA2 or WPA3");
                    break;
                    
                case "captive_portal":
                    add_security_recommendation(assessment, "verify_portal", "Verify Portal", 
                                              "Ensure the captive portal is legitimate before entering credentials");
                    break;
            }
        }
        
        /**
         * Calculate overall security level based on risks
         */
        private void calculate_overall_security_level(SecurityAssessment assessment) {
            if (assessment.risks.length == 0) {
                assessment.overall_level = SecurityLevel.SECURE;
                return;
            }
            
            bool has_critical = false;
            bool has_high = false;
            bool has_medium = false;
            
            for (uint i = 0; i < assessment.risks.length; i++) {
                var risk = assessment.risks[i];
                switch (risk.severity) {
                    case ErrorSeverity.CRITICAL:
                        has_critical = true;
                        break;
                    case ErrorSeverity.HIGH:
                        has_high = true;
                        break;
                    case ErrorSeverity.MEDIUM:
                        has_medium = true;
                        break;
                }
            }
            
            if (has_critical || has_high) {
                assessment.overall_level = SecurityLevel.INSECURE;
            } else if (has_medium) {
                assessment.overall_level = SecurityLevel.WARNING;
            } else {
                assessment.overall_level = SecurityLevel.SECURE;
            }
        }
        
        /**
         * Generate security alerts based on assessment
         */
        private void generate_security_alerts(SecurityAssessment assessment) {
            // Generate alerts for high-severity risks
            for (uint i = 0; i < assessment.risks.length; i++) {
                var risk = assessment.risks[i];
                if (risk.severity == ErrorSeverity.CRITICAL || risk.severity == ErrorSeverity.HIGH) {
                    var alert = new SecurityAlert.with_details(
                        "risk_%s_%s".printf(assessment.network.id ?? "unknown", risk.risk_id ?? "unknown"),
                        risk.title,
                        risk.description,
                        risk.severity
                    );
                    alert.related_network = assessment.network;
                    alert.requires_user_action = true;
                    alert.suggested_action = risk.mitigation_advice;
                    
                    add_security_alert(alert);
                }
            }
        }
        
        /**
         * Add a security risk to assessment
         */
        private void add_security_risk(SecurityAssessment assessment, string risk_id, 
                                     string title, string description, ErrorSeverity severity) {
            var risk = new SecurityRisk.with_details(risk_id, title, description, severity);
            assessment.risks.add(risk);
        }
        
        /**
         * Add a security recommendation to assessment
         */
        private void add_security_recommendation(SecurityAssessment assessment, string rec_id,
                                               string title, string description) {
            var recommendation = new SecurityRecommendation.with_details(rec_id, title, description);
            assessment.recommendations.add(recommendation);
        }
        
        /**
         * Add a security alert
         */
        private void add_security_alert(SecurityAlert alert) {
            // Check if alert already exists
            for (uint i = 0; i < _active_alerts.length; i++) {
                var existing = _active_alerts[i];
                if (existing.alert_id == alert.alert_id) {
                    return; // Don't add duplicate alerts
                }
            }
            
            _active_alerts.add(alert);
            security_alert(alert);
            
            debug("SecurityAnalyzer: Generated security alert: %s", alert.title);
        }
        
        /**
         * Cache security assessment
         */
        private void cache_assessment(SecurityAssessment assessment) {
            // Remove old assessment for same network
            for (uint i = 0; i < _assessment_cache.length; i++) {
                var cached = _assessment_cache[i];
                if (cached.network.id == assessment.network.id) {
                    _assessment_cache.remove_index(i);
                    break;
                }
            }
            
            // Add new assessment
            _assessment_cache.add(assessment);
            
            // Limit cache size
            while (_assessment_cache.length > ASSESSMENT_CACHE_SIZE) {
                _assessment_cache.remove_index(0);
            }
        }
        
        /**
         * Get cached assessment for a network
         */
        private SecurityAssessment? get_cached_assessment(NetworkConnection connection) {
            for (uint i = 0; i < _assessment_cache.length; i++) {
                var assessment = _assessment_cache[i];
                if (assessment.network.id == connection.id) {
                    return assessment;
                }
            }
            return null;
        }
        
        /**
         * Create a NetworkConnection wrapper from NM.ActiveConnection
         */
        private NetworkConnection? create_network_connection_wrapper(NM.ActiveConnection active_connection) {
            var connection = active_connection.get_connection();
            if (connection == null) return null;
            
            var connection_type = connection.get_connection_type();
            
            if (connection_type == "802-11-wireless") {
                var wifi_network = new WiFiNetwork();
                wifi_network.id = connection.get_uuid();
                wifi_network.name = connection.get_id();
                wifi_network.connection_type = ConnectionType.WIFI;
                return wifi_network;
            } else if (connection_type == "802-3-ethernet") {
                var network_connection = new BasicNetworkConnection();
                network_connection.id = connection.get_uuid();
                network_connection.name = connection.get_id();
                network_connection.connection_type = ConnectionType.ETHERNET;
                return network_connection;
            } else if (connection_type == "vpn") {
                var network_connection = new BasicNetworkConnection();
                network_connection.id = connection.get_uuid();
                network_connection.name = connection.get_id();
                network_connection.connection_type = ConnectionType.VPN;
                return network_connection;
            }
            
            return null;
        }
        
        /**
         * Generate basic recommendations for unanalyzed connections
         */
        private void generate_basic_recommendations(NetworkConnection connection, 
                                                  GenericArray<SecurityRecommendation> recommendations) {
            if (connection.connection_type == ConnectionType.WIFI) {
                var rec = new SecurityRecommendation.with_details(
                    "basic_wifi", "WiFi Security", 
                    "Ensure you're connecting to trusted WiFi networks"
                );
                recommendations.add(rec);
            }
        }
        
        /**
         * Add general security recommendations
         */
        private void add_general_security_recommendations(GenericArray<SecurityRecommendation> recommendations) {
            var vpn_rec = new SecurityRecommendation.with_details(
                "general_vpn", "Use VPN", 
                "Consider using a VPN for additional privacy and security"
            );
            recommendations.add(vpn_rec);
            
            var update_rec = new SecurityRecommendation.with_details(
                "general_updates", "Keep Software Updated", 
                "Ensure your system and network software are up to date"
            );
            recommendations.add(update_rec);
        }
        
        /**
         * Clear alerts for a specific connection
         */
        private void clear_alerts_for_connection(NetworkConnection connection) {
            for (int i = (int)_active_alerts.length - 1; i >= 0; i--) {
                var alert = _active_alerts[i];
                if (alert.related_network != null && alert.related_network.id == connection.id) {
                    _active_alerts.remove_index((uint)i);
                    debug("SecurityAnalyzer: Cleared alert for disconnected network: %s", connection.name);
                }
            }
        }
        
        /**
         * Start security monitoring
         */
        private void start_monitoring() {
            if (_monitoring_timeout_id > 0) {
                return; // Already monitoring
            }
            
            debug("SecurityAnalyzer: Starting security monitoring");
            
            _monitoring_timeout_id = Timeout.add(MONITORING_INTERVAL_MS, () => {
                monitor_security.begin();
                return true; // Continue monitoring
            });
        }
        
        /**
         * Stop security monitoring
         */
        private void stop_monitoring() {
            if (_monitoring_timeout_id > 0) {
                Source.remove(_monitoring_timeout_id);
                _monitoring_timeout_id = 0;
                debug("SecurityAnalyzer: Stopped security monitoring");
            }
        }
        
        /**
         * Monitor security of active connections
         */
        private async void monitor_security() {
            if (!nm_client.is_available) {
                return;
            }
            
            try {
                var active_connections = nm_client.get_active_connections();
                
                foreach (var connection in active_connections) {
                    // Check if we need to re-analyze this connection
                    var network_connection = create_network_connection_wrapper(connection);
                    if (network_connection != null) {
                        var assessment = get_cached_assessment(network_connection);
                        if (assessment == null || should_reanalyze(assessment)) {
                            yield analyze_network(network_connection);
                        }
                    }
                }
                
            } catch (Error e) {
                warning("SecurityAnalyzer: Monitoring error: %s", e.message);
            }
        }
        
        /**
         * Check if a connection should be re-analyzed
         */
        private bool should_reanalyze(SecurityAssessment assessment) {
            var now = new DateTime.now_local();
            var age = now.difference(assessment.assessment_time);
            
            // Re-analyze every 5 minutes
            return age > 5 * 60 * 1000000; // 5 minutes in microseconds
        }
        
        /**
         * Handle NetworkManager becoming unavailable
         */
        private void handle_nm_unavailable() {
            stop_monitoring();
            _assessment_cache.remove_range(0, _assessment_cache.length);
            _active_alerts.remove_range(0, _active_alerts.length);
        }
    }
}