/**
 * Enhanced Network Indicator - Core Enumerations
 * 
 * This file defines the core enumerations used throughout the enhanced
 * network indicator system for type safety and consistency.
 */

namespace EnhancedNetwork {

    /**
     * Types of network connections supported by the system
     */
    public enum ConnectionType {
        WIFI,
        ETHERNET,
        VPN,
        MOBILE_BROADBAND,
        HOTSPOT
    }

    /**
     * Current state of a network connection
     */
    public enum ConnectionState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        DISCONNECTING,
        FAILED
    }

    /**
     * Security types for wireless networks
     */
    public enum SecurityType {
        NONE,
        WEP,
        WPA_PSK,
        WPA2_PSK,
        WPA3_PSK,
        WPA_ENTERPRISE,
        WPA2_ENTERPRISE,
        WPA3_ENTERPRISE
    }

    /**
     * VPN protocol types
     */
    public enum VPNType {
        OPENVPN,
        WIREGUARD,
        PPTP,
        L2TP,
        SSTP
    }

    /**
     * Security assessment levels for networks
     */
    public enum SecurityLevel {
        SECURE,
        WARNING,
        INSECURE,
        UNKNOWN
    }

    /**
     * WiFi operating modes
     */
    public enum WiFiMode {
        INFRASTRUCTURE,
        ADHOC,
        AP
    }

    /**
     * VPN connection states
     */
    public enum VPNState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        DISCONNECTING,
        FAILED,
        UNKNOWN
    }

    /**
     * Hotspot operational states
     */
    public enum HotspotState {
        INACTIVE,
        STARTING,
        ACTIVE,
        STOPPING,
        FAILED
    }

    /**
     * Network notification types
     */
    public enum NotificationType {
        INFO,
        WARNING,
        ERROR,
        SUCCESS
    }

    /**
     * Error severity levels
     */
    public enum ErrorSeverity {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }

    /**
     * Panel types for the network popover
     */
    public enum PanelType {
        OVERVIEW,
        WIFI,
        ETHERNET,
        VPN,
        MOBILE,
        HOTSPOT,
        MONITOR,
        SETTINGS
    }
}