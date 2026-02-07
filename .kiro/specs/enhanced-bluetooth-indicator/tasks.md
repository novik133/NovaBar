# Implementation Plan: Enhanced Bluetooth Indicator

## Overview

This implementation plan breaks down the Enhanced Bluetooth Indicator into discrete, incremental coding tasks. The approach follows a bottom-up strategy: build core infrastructure first (D-Bus client, models), then managers, then UI components, and finally integration. Each task builds on previous work, with testing integrated throughout to catch errors early.

## Tasks

- [x] 1. Set up project structure and core models
  - Create directory structure: `src/indicators/bluetooth/enhanced/`
  - Create subdirectories: `models/`, `managers/`, `ui/`, `utils/`
  - Define core enums in `models/enums.vala` (BluetoothState, DeviceType, ConnectionState, SignalStrength, AudioProfileType, TransferStatus, TransferDirection, PairingMethod, ErrorCategory)
  - Create data model classes: `BluetoothAdapter`, `BluetoothDevice`, `AudioProfile`, `FileTransfer`, `PairingRequest`, `BluetoothError`
  - Set up meson build configuration for the enhanced Bluetooth indicator
  - _Requirements: 1.3, 2.3, 5.1-5.5, 7.4, 8.3-8.4_

- [ ]* 1.1 Write property tests for model completeness
  - **Property 3: Adapter Model Completeness**
  - **Property 7: Device Model Completeness**
  - **Validates: Requirements 1.3, 2.3, 5.1-5.5**

- [x] 2. Implement BlueZ D-Bus client
  - [x] 2.1 Create `BlueZClient` class with D-Bus connection management
    - Implement connection initialization and shutdown
    - Implement object manager setup for org.bluez
    - Implement proxy management for BlueZ objects
    - Add signal subscription and routing
    - Implement reconnection with exponential backoff
    - _Requirements: 15.1, 15.2, 15.3, 15.7_
  
  - [x] 2.2 Implement D-Bus method call wrappers
    - Implement async method call with error handling
    - Implement property get/set operations
    - Implement get_all_properties for bulk property retrieval
    - Add timeout handling for D-Bus operations
    - _Requirements: 15.1, 11.2_
  
  - [x] 2.3 Implement signal handling and routing
    - Subscribe to ObjectManager signals (InterfacesAdded, InterfacesRemoved)
    - Subscribe to PropertiesChanged signals
    - Route signals to appropriate handlers
    - Implement signal filtering to minimize processing
    - _Requirements: 15.2, 15.3, 15.6_

- [ ]* 2.4 Write property tests for D-Bus integration
  - **Property 39: Adapter Change Detection**
  - **Property 40: Device Change Detection**
  - **Validates: Requirements 15.2, 15.3**

- [x] 3. Implement ErrorHandler component
  - Create `ErrorHandler` class with error categorization
  - Implement error creation with category, code, message, details
  - Implement D-Bus error categorization (map D-Bus error names to ErrorCategory)
  - Implement BlueZ error categorization (map BlueZ error names to ErrorCategory)
  - Implement recovery suggestion generation for each error category
  - Implement error logging with timestamps and context
  - Implement user notification for errors
  - _Requirements: 1.7, 2.7, 3.6, 4.5, 8.7, 11.2-11.5_

- [ ]* 3.1 Write property tests for error handling
  - **Property 29: Error Categorization**
  - **Property 30: Error Recovery Suggestions**
  - **Property 31: Timeout Error Specificity**
  - **Property 32: Service Unavailable Error**
  - **Validates: Requirements 1.7, 11.2-11.5**

- [x] 4. Implement AdapterManager
  - [x] 4.1 Create `AdapterManager` class with adapter discovery
    - Implement initialization with BlueZClient
    - Implement scan_adapters() to discover all adapters via D-Bus
    - Maintain adapter map (object_path -> BluetoothAdapter)
    - Implement get_adapter(), get_default_adapter(), get_all_adapters()
    - _Requirements: 1.3, 10.1, 10.2_
  
  - [x] 4.2 Implement adapter power and discovery control
    - Implement set_powered() for adapter power control
    - Implement start_discovery() and stop_discovery()
    - Implement set_discoverable() with timeout support
    - Implement set_pairable() with timeout support
    - Handle D-Bus method call errors appropriately
    - _Requirements: 1.1, 1.4, 2.1_
  
  - [x] 4.3 Implement adapter configuration
    - Implement set_alias() for adapter name changes
    - Implement adapter property validation
    - Emit signals for adapter state changes
    - _Requirements: 1.5, 9.1, 9.2, 9.4, 9.7_
  
  - [x] 4.4 Implement adapter property monitoring
    - Subscribe to PropertiesChanged signals for adapters
    - Update BluetoothAdapter models when properties change
    - Emit adapter_property_changed signals
    - Handle adapter addition and removal
    - _Requirements: 1.2, 10.5, 10.6_

- [ ]* 4.5 Write property tests for AdapterManager
  - **Property 1: Adapter Power State Consistency**
  - **Property 2: Adapter State Propagation**
  - **Property 4: Multi-Adapter Independence**
  - **Property 5: Default Adapter Selection**
  - **Property 28: Configuration Validation**
  - **Validates: Requirements 1.1, 1.2, 1.4, 1.6, 9.7, 10.2, 10.4**

- [x] 5. Checkpoint - Verify adapter management
  - Ensure all adapter tests pass
  - Manually test adapter power control with real hardware
  - Verify adapter discovery with multiple adapters
  - Ask the user if questions arise

- [x] 6. Implement DeviceManager
  - [x] 6.1 Create `DeviceManager` class with device discovery
    - Implement initialization with BlueZClient
    - Implement scan_devices() to discover devices for an adapter
    - Maintain device map (object_path -> BluetoothDevice)
    - Implement device queries (get_device, get_devices_for_adapter, get_connected_devices, get_paired_devices)
    - _Requirements: 2.1, 2.2, 2.3_
  
  - [x] 6.2 Implement device pairing operations
    - Implement pair() to initiate pairing with a device
    - Implement unpair() to remove pairing
    - Handle pairing state transitions
    - Emit device_connected and device_disconnected signals
    - _Requirements: 3.1, 3.5, 3.7, 3.8_
  
  - [x] 6.3 Implement device connection operations
    - Implement connect() to establish device connection
    - Implement disconnect() to terminate connection
    - Track connection state transitions
    - Handle connection errors and timeouts
    - _Requirements: 4.1, 4.2, 4.3, 4.6_
  
  - [x] 6.4 Implement trust and block management
    - Implement set_trusted() to mark devices as trusted
    - Implement set_blocked() to block devices
    - Implement is_trusted() and is_blocked() queries
    - Maintain trusted and blocked device sets
    - _Requirements: 6.1, 6.2, 6.4, 6.6, 6.7_
  
  - [x] 6.5 Implement device property monitoring
    - Subscribe to PropertiesChanged signals for devices
    - Update BluetoothDevice models when properties change
    - Implement RSSI monitoring for connected devices
    - Emit device_property_changed signals
    - Handle device addition and removal
    - _Requirements: 2.2, 5.6, 15.3_

- [ ]* 6.6 Write property tests for DeviceManager
  - **Property 6: Discovery State Consistency**
  - **Property 8: Device Type Filtering**
  - **Property 9: Device Search Accuracy**
  - **Property 10: Device Sorting Correctness**
  - **Property 11: Pairing State Transition**
  - **Property 12: Unpairing Cleanup**
  - **Property 14: Connection State Consistency**
  - **Property 15: Connection State Exposure**
  - **Property 18: Trust and Block Status Exposure**
  - **Validates: Requirements 2.1, 2.4, 3.5, 3.7, 3.8, 4.1-4.3, 4.6, 6.1, 6.7, 18.3, 18.4**

- [x] 7. Implement AgentManager for pairing authentication
  - [x] 7.1 Create `AgentManager` class implementing org.bluez.Agent1
    - Implement initialization with BlueZClient
    - Implement register_agent() to register with AgentManager1
    - Implement unregister_agent() for cleanup
    - Define agent D-Bus object path
    - _Requirements: 3.1, 15.4, 15.5_
  
  - [x] 7.2 Implement Agent1 interface methods
    - Implement RequestPinCode() for PIN entry
    - Implement RequestPasskey() for passkey entry
    - Implement DisplayPasskey() for passkey display
    - Implement DisplayPinCode() for PIN display
    - Implement RequestConfirmation() for passkey confirmation
    - Implement RequestAuthorization() for authorization
    - Implement AuthorizeService() for service authorization
    - Implement Cancel() for pairing cancellation
    - _Requirements: 3.2, 3.3, 3.4_
  
  - [x] 7.3 Implement pairing request handling
    - Create PairingRequest objects for each pairing method
    - Emit pairing_request signal with request details
    - Implement response handling (provide_pin_code, provide_passkey, confirm_pairing, authorize)
    - Handle pairing completion and failure
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 3.6_

- [ ]* 7.4 Write property tests for AgentManager
  - **Property 13: Pairing Method Detection**
  - **Property 41: Agent Registration**
  - **Validates: Requirements 3.2, 3.3, 3.4, 15.5**

- [x] 8. Checkpoint - Verify device and pairing management
  - Ensure all device and agent tests pass
  - Manually test device discovery
  - Manually test pairing with real devices (keyboard, headphones)
  - Verify pairing authentication flows
  - Ask the user if questions arise

- [x] 9. Implement AudioManager
  - [x] 9.1 Create `AudioManager` class with profile detection
    - Implement initialization with BlueZClient
    - Implement detect_profiles() to identify audio UUIDs
    - Map UUIDs to AudioProfile objects (A2DP, HFP, HSP, AVRCP)
    - Maintain device_profiles map
    - _Requirements: 7.1, 7.4_
  
  - [x] 9.2 Implement audio profile management
    - Implement connect_profile() for specific profile connection
    - Implement disconnect_profile() for profile disconnection
    - Implement set_active_profile() to switch profiles
    - Emit profile_changed signals
    - _Requirements: 7.2, 7.3_
  
  - [x] 9.3 Implement audio device monitoring
    - Subscribe to device connection events
    - Automatically detect profiles on audio device connection
    - Emit audio_device_connected and audio_device_disconnected signals
    - Track multiple simultaneous audio connections
    - _Requirements: 7.2, 7.7_

- [ ]* 9.4 Write property tests for AudioManager
  - **Property 19: Audio Device Detection**
  - **Property 20: Audio Profile Activation**
  - **Property 21: Multiple Audio Device Support**
  - **Validates: Requirements 7.1, 7.2, 7.4, 7.7**

- [x] 10. Implement TransferManager for file transfers
  - [x] 10.1 Create `TransferManager` class with OBEX support
    - Implement initialization with BlueZClient
    - Maintain active_transfers map
    - Implement get_transfer() and get_active_transfers() queries
    - _Requirements: 8.1, 8.2_
  
  - [x] 10.2 Implement file sending operations
    - Implement send_file() to initiate file transfer via OBEX
    - Implement send_files() for multiple file transfers
    - Create FileTransfer objects for tracking
    - Emit transfer_started signals
    - _Requirements: 8.1_
  
  - [x] 10.3 Implement file receiving operations
    - Implement accept_transfer() to accept incoming transfers
    - Implement reject_transfer() to decline transfers
    - Handle incoming transfer requests
    - _Requirements: 8.2_
  
  - [x] 10.4 Implement transfer control and monitoring
    - Implement cancel_transfer() to abort transfers
    - Implement pause_transfer() and resume_transfer()
    - Subscribe to transfer PropertiesChanged signals
    - Update transfer progress (bytes_transferred, progress_percentage, bytes_per_second)
    - Emit transfer_progress, transfer_completed, transfer_failed signals
    - _Requirements: 8.3, 8.4, 8.5, 8.6, 8.7_

- [ ]* 10.5 Write property tests for TransferManager
  - **Property 22: Transfer Progress Monotonicity**
  - **Property 23: Transfer Metrics Calculation**
  - **Property 24: Transfer Cancellation**
  - **Validates: Requirements 8.3, 8.4, 8.5**

- [x] 11. Implement ConfigManager for persistence
  - Create `ConfigManager` class for configuration persistence
  - Implement save_configuration() to write config to file (JSON format)
  - Implement load_configuration() to read config from file
  - Implement configuration schema: adapter settings, trusted devices, blocked devices, UI preferences
  - Handle corrupted configuration files (use safe defaults, log error)
  - Implement configuration validation before saving
  - _Requirements: 9.3, 17.1-17.7_

- [ ]* 11.1 Write property tests for ConfigManager
  - **Property 16: Trust Persistence Round-Trip**
  - **Property 17: Block Status Round-Trip**
  - **Property 25: Adapter Configuration Round-Trip**
  - **Property 26: UI Preferences Persistence**
  - **Property 27: Configuration Corruption Resilience**
  - **Validates: Requirements 6.2, 6.6, 9.3, 17.2-17.7**

- [x] 12. Implement PolicyKitClient for authorization
  - Create `PolicyKitClient` class for PolicyKit integration
  - Implement check_authorization() for synchronous auth checks
  - Implement request_authorization() for interactive auth dialogs
  - Define PolicyKit actions: org.novabar.bluetooth.power, org.novabar.bluetooth.pair, org.novabar.bluetooth.configure
  - Handle authorization denial gracefully
  - Handle dialog cancellation without crashing
  - Cache authorizations according to PolicyKit rules
  - _Requirements: 14.1, 14.3, 14.4, 14.5_

- [ ]* 12.1 Write property tests for PolicyKitClient
  - **Property 42: Privileged Operation Authorization**
  - **Property 43: Authorization Cancellation Handling**
  - **Validates: Requirements 14.1, 14.3, 14.5**

- [x] 13. Implement BluetoothController coordinator
  - [x] 13.1 Create `BluetoothController` class
    - Implement initialization of all managers (Adapter, Device, Audio, Transfer, Agent)
    - Initialize BlueZClient and pass to all managers
    - Initialize ErrorHandler, ConfigManager, PolicyKitClient
    - Implement shutdown() for cleanup
    - _Requirements: All_
  
  - [x] 13.2 Implement adapter operation wrappers
    - Implement set_adapter_powered() with PolicyKit check
    - Implement set_adapter_discoverable() with PolicyKit check
    - Implement start_discovery() and stop_discovery()
    - Implement get_adapters() query
    - Route operations to AdapterManager
    - _Requirements: 1.1, 1.4, 2.1, 14.1_
  
  - [x] 13.3 Implement device operation wrappers
    - Implement pair_device() with PolicyKit check
    - Implement unpair_device()
    - Implement connect_device() and disconnect_device()
    - Implement trust_device() and block_device()
    - Implement get_devices() query
    - Route operations to DeviceManager
    - _Requirements: 3.1, 3.7, 4.1, 4.3, 6.2, 6.4, 14.1_
  
  - [x] 13.4 Implement audio and transfer operation wrappers
    - Implement set_audio_profile() routing to AudioManager
    - Implement get_audio_profiles() query
    - Implement send_file() routing to TransferManager
    - Implement cancel_transfer() routing to TransferManager
    - _Requirements: 7.3, 8.1, 8.5_
  
  - [x] 13.5 Implement event aggregation and routing
    - Subscribe to all manager signals
    - Re-emit aggregated signals (adapter_state_changed, device_found, device_connected, etc.)
    - Route pairing requests from AgentManager
    - Route errors from ErrorHandler
    - _Requirements: All_

- [x] 14. Checkpoint - Verify core functionality
  - Ensure all manager and controller tests pass
  - Test adapter power control end-to-end
  - Test device discovery, pairing, and connection
  - Test audio device profile management
  - Test file transfer operations
  - Verify configuration persistence
  - Ask the user if questions arise

- [x] 15. Implement UI components
  - [x] 15.1 Create `BluetoothPanel` main UI
    - Create GTK widget for main panel
    - Implement device list view with filtering and sorting
    - Implement adapter selector for multi-adapter support
    - Implement scan button and discovery progress indicator
    - Implement device action buttons (connect, disconnect, pair, unpair, trust, block)
    - _Requirements: 2.1, 10.7, 18.2, 18.4, 18.6_
  
  - [x] 15.2 Create device detail views
    - Implement device property display (name, address, type, RSSI, battery)
    - Implement audio profile selector for audio devices
    - Implement file transfer UI (send file button, transfer progress)
    - Implement device settings (trust, block, forget)
    - _Requirements: 5.1-5.5, 7.3, 8.3_
  
  - [x] 15.3 Create pairing dialog
    - Implement PIN entry dialog
    - Implement passkey entry dialog
    - Implement passkey confirmation dialog
    - Implement authorization dialog
    - Connect dialogs to AgentManager responses
    - _Requirements: 3.2, 3.3, 3.4_
  
  - [x] 15.4 Create settings panel
    - Implement adapter configuration UI (name, discoverable timeout, pairable timeout)
    - Implement notification settings (enable/disable)
    - Implement UI preferences (filter, sort, view mode)
    - Connect to ConfigManager for persistence
    - _Requirements: 9.1, 9.2, 19.6_

- [x] 16. Implement accessibility features
  - [x] 16.1 Implement keyboard navigation
    - Create `KeyboardNavigationHelper` class
    - Implement Tab navigation through all interactive elements
    - Implement Arrow key navigation in device list
    - Implement Enter key activation for buttons
    - Implement Escape key for dialog dismissal
    - Add visible focus indicators to all elements
    - _Requirements: 12.1, 12.2_
  
  - [x] 16.2 Implement screen reader support
    - Create `AccessibilityHelper` class
    - Add ARIA labels to all interactive elements
    - Add ARIA roles (button, listitem, dialog, etc.)
    - Implement state change announcements (device connected, pairing started, etc.)
    - Add text alternatives for icons and visual indicators
    - _Requirements: 12.3, 12.4, 12.7_
  
  - [x] 16.3 Implement keyboard shortcuts
    - Implement Ctrl+B to toggle Bluetooth power
    - Implement Ctrl+S to start/stop scan
    - Implement Ctrl+L to connect to last device
    - Document shortcuts in UI
    - _Requirements: 12.5_

- [ ]* 16.4 Write UI accessibility tests
  - Test keyboard navigation completeness
  - Test ARIA attribute presence
  - Test focus indicators visibility
  - Verify screen reader announcements
  - **Validates: Requirements 12.1-12.5, 12.7**

- [x] 17. Implement BluetoothPopover
  - Create `BluetoothPopover` class extending Gtk.Popover
  - Embed BluetoothPanel as main content
  - Implement popover sizing and positioning
  - Handle popover show/hide events
  - Connect to BluetoothController for data
  - _Requirements: 13.4_

- [x] 18. Implement BluetoothIndicator
  - [x] 18.1 Create `BluetoothIndicator` class
    - Extend NovaBar's Indicator base class
    - Implement activate() and deactivate() lifecycle methods
    - Create indicator icon (Gtk.Image)
    - Create BluetoothPopover instance
    - Initialize BluetoothController
    - _Requirements: 13.1, 13.2_
  
  - [x] 18.2 Implement icon state management
    - Implement update_icon_state() based on BluetoothState enum
    - Map states to icon names (bluetooth-disabled, bluetooth-active, bluetooth-connected, bluetooth-acquiring)
    - Subscribe to adapter and device state changes
    - Update icon when state changes
    - _Requirements: 13.3_
  
  - [x] 18.3 Implement notification system
    - Create `NotificationManager` class
    - Implement notify() using NovaBar's notification system
    - Subscribe to controller events (device_connected, device_disconnected, pairing_completed, pairing_failed, transfer_completed)
    - Generate notifications with appropriate content
    - Respect notification settings from ConfigManager
    - _Requirements: 19.1-19.6, 13.7_

- [ ]* 18.4 Write property tests for indicator
  - **Property 36: Icon State Mapping**
  - **Property 34: Event Notification Completeness**
  - **Property 35: Notification Settings Respect**
  - **Validates: Requirements 13.3, 19.1-19.6**

- [x] 19. Implement integration wrapper
  - Create `enhanced_wrapper.vala` similar to network indicator
  - Implement factory function to create BluetoothIndicator
  - Handle feature flag for enhanced vs. basic indicator
  - Ensure backward compatibility with existing bluetooth.vala
  - _Requirements: 13.1_

- [ ] 20. Write integration tests
  - [ ] 20.1 Write D-Bus integration tests
    - Test BlueZClient connection and reconnection
    - Test adapter discovery via D-Bus
    - Test device discovery via D-Bus
    - Test pairing flow via D-Bus
    - Mock BlueZ daemon for testing
    - _Requirements: 15.1-15.7_
  
  - [ ] 20.2 Write PolicyKit integration tests
    - Test authorization requests
    - Test authorization denial handling
    - Test dialog cancellation
    - Mock PolicyKit for testing
    - _Requirements: 14.1-14.5_
  
  - [ ] 20.3 Write end-to-end tests
    - Test complete discovery-pair-connect flow
    - Test audio device connection and profile switching
    - Test file transfer flow
    - Test configuration persistence across restarts
    - Test error recovery scenarios
    - _Requirements: All_

- [ ] 21. Final checkpoint - Complete system verification
  - Run full test suite (unit, property, integration)
  - Verify code coverage meets 80% minimum
  - Test with real Bluetooth hardware (multiple adapters, various devices)
  - Test accessibility with keyboard and screen reader
  - Verify performance (memory usage, responsiveness)
  - Test error scenarios (BlueZ restart, adapter removal, device out of range)
  - Ask the user if questions arise

- [ ] 22. Documentation and polish
  - Write user documentation for Bluetooth indicator features
  - Write developer documentation for architecture and APIs
  - Add code comments for complex logic
  - Create troubleshooting guide for common issues
  - Update NovaBar documentation to include enhanced Bluetooth indicator
  - _Requirements: 20.7_

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Integration tests validate D-Bus and PolicyKit interactions
- Manual testing with real hardware is essential for Bluetooth functionality
