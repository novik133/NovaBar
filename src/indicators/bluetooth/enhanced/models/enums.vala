/**
 * Enhanced Bluetooth Indicator - Core Enumerations
 * 
 * This file defines the core enumerations used throughout the enhanced
 * Bluetooth indicator system for type safety and consistency.
 */

namespace EnhancedBluetooth {

    /**
     * Overall Bluetooth system state
     */
    public enum BluetoothState {
        OFF,            // Adapter powered off
        ON,             // Adapter powered on, no devices connected
        CONNECTED,      // At least one device connected
        DISCOVERING,    // Discovery in progress
        UNAVAILABLE     // BlueZ daemon not available
    }

    /**
     * Types of Bluetooth devices
     */
    public enum DeviceType {
        AUDIO,          // Headphones, speakers, headsets
        INPUT,          // Keyboards, mice, game controllers
        PHONE,          // Mobile phones
        COMPUTER,       // Laptops, desktops
        PERIPHERAL,     // Printers, scanners
        WEARABLE,       // Smartwatches, fitness trackers
        UNKNOWN
    }

    /**
     * Connection state for devices
     */
    public enum ConnectionState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        DISCONNECTING
    }

    /**
     * Signal strength categories based on RSSI
     */
    public enum SignalStrength {
        EXCELLENT,      // RSSI > -50 dBm
        GOOD,           // RSSI > -60 dBm
        FAIR,           // RSSI > -70 dBm
        WEAK,           // RSSI > -80 dBm
        VERY_WEAK       // RSSI <= -80 dBm
    }

    /**
     * Audio profile types
     */
    public enum AudioProfileType {
        A2DP_SINK,      // Advanced Audio Distribution Profile (playback)
        A2DP_SOURCE,    // Advanced Audio Distribution Profile (recording)
        HFP,            // Hands-Free Profile
        HSP,            // Headset Profile
        AVRCP,          // Audio/Video Remote Control Profile
        UNKNOWN
    }

    /**
     * File transfer status
     */
    public enum TransferStatus {
        QUEUED,
        ACTIVE,
        SUSPENDED,
        COMPLETE,
        ERROR
    }

    /**
     * File transfer direction
     */
    public enum TransferDirection {
        SENDING,
        RECEIVING
    }

    /**
     * Pairing authentication methods
     */
    public enum PairingMethod {
        PIN_CODE,           // User enters PIN
        PASSKEY_ENTRY,      // User enters 6-digit passkey
        PASSKEY_DISPLAY,    // User confirms displayed passkey
        PASSKEY_CONFIRMATION, // User confirms passkey matches
        AUTHORIZATION,      // User authorizes connection
        SERVICE_AUTHORIZATION // User authorizes specific service
    }

    /**
     * Error categories for error handling
     */
    public enum ErrorCategory {
        ADAPTER_ERROR,      // Adapter power, configuration issues
        DEVICE_ERROR,       // Device not found, not available
        PAIRING_ERROR,      // Authentication, pairing failures
        CONNECTION_ERROR,   // Connection establishment failures
        TRANSFER_ERROR,     // File transfer failures
        DBUS_ERROR,         // D-Bus communication issues
        PERMISSION_ERROR,   // PolicyKit authorization failures
        TIMEOUT_ERROR,      // Operation timeouts
        UNKNOWN_ERROR
    }
}
