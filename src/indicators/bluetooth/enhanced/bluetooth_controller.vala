/**
 * Enhanced Bluetooth Indicator - Bluetooth Controller
 * 
 * Central coordinator managing all Bluetooth subsystems including adapters,
 * devices, audio, transfers, and authentication.
 */

using GLib;

namespace EnhancedBluetooth {

    /**
     * Central Bluetooth Controller
     * 
     * This class coordinates all Bluetooth managers and provides a unified
     * interface for Bluetooth operations. It aggregates events from all managers
     * and routes operations to the appropriate subsystem.
     */
    public class BluetoothController : Object {
        // Manager components
        private AdapterManager adapter_manager;
        private DeviceManager device_manager;
        private AudioManager audio_manager;
        private TransferManager transfer_manager;
        private AgentManager agent_manager;
        
        // Support components
        private BlueZClient bluez_client;
        private ErrorHandler error_handler;
        private ConfigManager config_manager;
        private PolicyKitClient polkit_client;
        
        // Initialization state
        private bool is_initialized;
        
        /**
         * Signal emitted when adapter state changes
         */
        public signal void adapter_state_changed(BluetoothAdapter adapter);
        
        /**
         * Signal emitted when a device is found
         */
        public signal void device_found(BluetoothDevice device);
        
        /**
         * Signal emitted when a device connects
         */
        public signal void device_connected(BluetoothDevice device);
        
        /**
         * Signal emitted when a device disconnects
         */
        public signal void device_disconnected(BluetoothDevice device);
        
        /**
         * Signal emitted when a pairing request is received
         */
        public signal void pairing_request(PairingRequest request);
        
        /**
         * Signal emitted when pairing completes
         */
        public signal void pairing_completed(string device_path, bool success);
        
        /**
         * Signal emitted when transfer progress updates
         */
        public signal void transfer_progress(FileTransfer transfer);
        
        /**
         * Signal emitted when a transfer completes
         */
        public signal void transfer_completed(FileTransfer transfer);
        
        /**
         * Signal emitted when an error occurs
         */
        public signal void error_occurred(BluetoothError error);
        
        /**
         * Constructor
         */
        public BluetoothController() {
            is_initialized = false;
        }
        
        /**
         * Initialize the Bluetooth controller and all subsystems
         */
        public async bool initialize() throws Error {
            if (is_initialized) {
                warning("BluetoothController: Already initialized");
                return true;
            }
            
            debug("BluetoothController: Initializing...");
            
            try {
                // Initialize support components first
                error_handler = new ErrorHandler();
                config_manager = new ConfigManager();
                polkit_client = new PolicyKitClient();
                
                // Load configuration
                config_manager.load_configuration();
                
                // Initialize PolicyKit
                yield polkit_client.initialize();
                
                // Initialize BlueZ client
                bluez_client = new BlueZClient();
                yield bluez_client.initialize();
                
                // Initialize managers
                adapter_manager = new AdapterManager();
                yield adapter_manager.initialize(bluez_client);
                
                device_manager = new DeviceManager();
                
                audio_manager = new AudioManager();
                
                transfer_manager = new TransferManager();
                
                agent_manager = new AgentManager();
                
                // Connect signals BEFORE initialization so that device_found
                // signals emitted during scan are properly forwarded to the UI
                connect_manager_signals();
                
                // Now initialize managers (device_found signals will be received)
                yield device_manager.initialize(bluez_client);
                
                // Scan for devices on all adapters
                var adapters = adapter_manager.get_all_adapters();
                for (uint i = 0; i < adapters.length; i++) {
                    try {
                        yield device_manager.scan_devices(adapters[i].object_path);
                        debug("BluetoothController: Scanned devices for adapter %s", adapters[i].object_path);
                    } catch (Error e) {
                        warning("BluetoothController: Failed to scan devices for adapter %s: %s",
                               adapters[i].object_path, e.message);
                    }
                }
                
                yield audio_manager.initialize(bluez_client);
                
                yield transfer_manager.initialize(bluez_client);
                
                try {
                    yield agent_manager.initialize(bluez_client);
                } catch (Error agent_error) {
                    // Agent registration failure is non-fatal
                    // Another agent (blueman, gnome-bluetooth) may already be registered
                    warning("BluetoothController: Agent registration failed (non-fatal): %s", agent_error.message);
                    debug("BluetoothController: Continuing without agent - pairing may not work");
                }
                
                is_initialized = true;
                debug("BluetoothController: Initialization complete");
                
                // Auto-start discovery on powered adapters so nearby devices
                // appear without requiring the user to manually click Scan
                auto_start_discovery.begin();
                
                return true;
                
            } catch (Error e) {
                warning("BluetoothController: Initialization failed: %s", e.message);
                
                // Handle initialization error
                var bt_error = error_handler.handle_dbus_error(e, "Bluetooth initialization");
                error_occurred(bt_error);
                
                throw e;
            }
        }
        
        /**
         * Shutdown the Bluetooth controller and cleanup resources
         */
        public void shutdown() {
            if (!is_initialized) {
                return;
            }
            
            debug("BluetoothController: Shutting down...");
            
            // Save configuration
            if (config_manager != null) {
                config_manager.save_configuration();
            }
            
            // Shutdown managers
            if (agent_manager != null) {
                agent_manager.shutdown();
            }
            
            if (transfer_manager != null) {
                transfer_manager.shutdown();
            }
            
            if (audio_manager != null) {
                audio_manager.shutdown();
            }
            
            if (device_manager != null) {
                device_manager.shutdown();
            }
            
            // Shutdown BlueZ client
            if (bluez_client != null) {
                bluez_client.shutdown();
            }
            
            // Shutdown PolicyKit client
            if (polkit_client != null) {
                polkit_client.shutdown();
            }
            
            is_initialized = false;
            debug("BluetoothController: Shutdown complete");
        }
        
        /**
         * Connect signals from all managers for event aggregation
         */
        private void connect_manager_signals() {
            // Adapter manager signals
            adapter_manager.adapter_state_changed.connect((adapter) => {
                adapter_state_changed(adapter);
            });
            
            // Device manager signals
            device_manager.device_found.connect((device) => {
                device_found(device);
            });
            
            device_manager.device_connected.connect((device) => {
                device_connected(device);
            });
            
            device_manager.device_disconnected.connect((device) => {
                device_disconnected(device);
            });
            
            // Agent manager signals
            agent_manager.pairing_request.connect((request) => {
                pairing_request(request);
            });
            
            agent_manager.pairing_completed.connect((device_path, success) => {
                pairing_completed(device_path, success);
            });
            
            // Transfer manager signals
            transfer_manager.transfer_progress.connect((transfer, bytes_transferred) => {
                transfer_progress(transfer);
            });
            
            transfer_manager.transfer_completed.connect((transfer) => {
                transfer_completed(transfer);
            });
            
            // Error handler signals
            error_handler.error_occurred.connect((error) => {
                error_occurred(error);
            });
        }
        
        /**
         * Auto-start discovery on all powered adapters for a brief period
         * so nearby devices appear without requiring manual scan.
         */
        private async void auto_start_discovery() {
            if (!is_initialized || adapter_manager == null) {
                return;
            }
            
            var adapters = adapter_manager.get_all_adapters();
            var started_paths = new GenericArray<string>();
            
            for (uint i = 0; i < adapters.length; i++) {
                var adapter = adapters[i];
                if (adapter.powered && !adapter.discovering) {
                    try {
                        yield adapter_manager.start_discovery(adapter.object_path);
                        started_paths.add(adapter.object_path);
                        debug("BluetoothController: Auto-started discovery on %s", adapter.object_path);
                    } catch (Error e) {
                        debug("BluetoothController: Could not auto-start discovery on %s: %s",
                              adapter.object_path, e.message);
                    }
                }
            }
            
            if (started_paths.length == 0) {
                return;
            }
            
            // Stop discovery after 15 seconds to save power
            Timeout.add_seconds(15, () => {
                for (uint i = 0; i < started_paths.length; i++) {
                    adapter_manager.stop_discovery.begin(started_paths[i], (obj, res) => {
                        try {
                            adapter_manager.stop_discovery.end(res);
                        } catch (Error e) {
                            // Ignore — adapter may have been removed or discovery already stopped
                        }
                    });
                }
                return Source.REMOVE;
            });
        }
        
        // ========== Adapter Operations ==========
        
        /**
         * Set adapter powered state with PolicyKit authorization
         * 
         * @param adapter_path The adapter object path
         * @param powered Whether to power on or off
         */
        public async void set_adapter_powered(string adapter_path, bool powered) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Setting adapter %s powered to %s", adapter_path, powered.to_string());
            
            // Check PolicyKit authorization
            var authorized = yield polkit_client.request_authorization(
                PolicyKitClient.ACTION_BLUETOOTH_POWER,
                "Authentication is required to control Bluetooth adapter power"
            );
            
            if (!authorized) {
                var error = error_handler.handle_permission_error(
                    "Set adapter powered",
                    PolicyKitClient.ACTION_BLUETOOTH_POWER
                );
                throw new IOError.PERMISSION_DENIED(error.message);
            }
            
            try {
                yield adapter_manager.set_powered(adapter_path, powered);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Set adapter powered");
                throw e;
            }
        }
        
        /**
         * Set adapter discoverable state with PolicyKit authorization
         * 
         * @param adapter_path The adapter object path
         * @param discoverable Whether the adapter should be discoverable
         * @param timeout Timeout in seconds (0 for unlimited)
         */
        public async void set_adapter_discoverable(
            string adapter_path,
            bool discoverable,
            uint32 timeout = 0
        ) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Setting adapter %s discoverable to %s (timeout: %u)",
                  adapter_path, discoverable.to_string(), timeout);
            
            // Check PolicyKit authorization
            var authorized = yield polkit_client.request_authorization(
                PolicyKitClient.ACTION_BLUETOOTH_CONFIGURE,
                "Authentication is required to configure Bluetooth adapter"
            );
            
            if (!authorized) {
                var error = error_handler.handle_permission_error(
                    "Set adapter discoverable",
                    PolicyKitClient.ACTION_BLUETOOTH_CONFIGURE
                );
                throw new IOError.PERMISSION_DENIED(error.message);
            }
            
            try {
                yield adapter_manager.set_discoverable(adapter_path, discoverable, timeout);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Set adapter discoverable");
                throw e;
            }
        }
        
        /**
         * Start device discovery on an adapter
         * 
         * @param adapter_path The adapter object path
         */
        public async void start_discovery(string adapter_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Starting discovery on adapter %s", adapter_path);
            
            try {
                yield adapter_manager.start_discovery(adapter_path);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Start discovery");
                throw e;
            }
        }
        
        /**
         * Stop device discovery on an adapter
         * 
         * @param adapter_path The adapter object path
         */
        public async void stop_discovery(string adapter_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Stopping discovery on adapter %s", adapter_path);
            
            try {
                yield adapter_manager.stop_discovery(adapter_path);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Stop discovery");
                throw e;
            }
        }
        
        /**
         * Get all available adapters
         * 
         * @return List of Bluetooth adapters
         */
        public GenericArray<BluetoothAdapter> get_adapters() {
            if (!is_initialized) {
                warning("BluetoothController: Not initialized, returning empty adapter list");
                return new GenericArray<BluetoothAdapter>();
            }
            
            return adapter_manager.get_all_adapters();
        }
        
        /**
         * Get the default adapter
         * 
         * @return The default adapter, or null if no adapters available
         */
        public BluetoothAdapter? get_default_adapter() {
            if (!is_initialized) {
                return null;
            }
            
            return adapter_manager.get_default_adapter();
        }

        
        // ========== Device Operations ==========
        
        /**
         * Pair with a device with PolicyKit authorization
         * 
         * @param device_path The device object path
         */
        public async void pair_device(string device_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Pairing with device %s", device_path);
            
            // Check PolicyKit authorization
            var authorized = yield polkit_client.request_authorization(
                PolicyKitClient.ACTION_BLUETOOTH_PAIR,
                "Authentication is required to pair with Bluetooth devices"
            );
            
            if (!authorized) {
                var error = error_handler.handle_permission_error(
                    "Pair device",
                    PolicyKitClient.ACTION_BLUETOOTH_PAIR
                );
                throw new IOError.PERMISSION_DENIED(error.message);
            }
            
            try {
                yield device_manager.pair(device_path);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Pair device");
                throw e;
            }
        }
        
        /**
         * Unpair (remove pairing) from a device
         * 
         * @param device_path The device object path
         */
        public async void unpair_device(string device_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Unpairing device %s", device_path);
            
            try {
                yield device_manager.unpair(device_path);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Unpair device");
                throw e;
            }
        }
        
        /**
         * Connect to a device
         * 
         * @param device_path The device object path
         */
        public async void connect_device(string device_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Connecting to device %s", device_path);
            
            try {
                yield device_manager.connect(device_path);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Connect device");
                throw e;
            }
        }
        
        /**
         * Disconnect from a device
         * 
         * @param device_path The device object path
         */
        public async void disconnect_device(string device_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Disconnecting from device %s", device_path);
            
            try {
                yield device_manager.disconnect(device_path);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Disconnect device");
                throw e;
            }
        }
        
        /**
         * Set trusted status for a device
         * 
         * @param device_path The device object path
         * @param trusted Whether the device should be trusted
         */
        public async void trust_device(string device_path, bool trusted) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Setting device %s trusted to %s", device_path, trusted.to_string());
            
            try {
                yield device_manager.set_trusted(device_path, trusted);
                
                // Update configuration
                var device = device_manager.get_device(device_path);
                if (device != null) {
                    if (trusted) {
                        config_manager.add_trusted_device(device.address);
                    } else {
                        config_manager.remove_trusted_device(device.address);
                    }
                }
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Set device trusted");
                throw e;
            }
        }
        
        /**
         * Set blocked status for a device
         * 
         * @param device_path The device object path
         * @param blocked Whether the device should be blocked
         */
        public async void block_device(string device_path, bool blocked) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Setting device %s blocked to %s", device_path, blocked.to_string());
            
            try {
                yield device_manager.set_blocked(device_path, blocked);
                
                // Update configuration
                var device = device_manager.get_device(device_path);
                if (device != null) {
                    if (blocked) {
                        config_manager.add_blocked_device(device.address);
                    } else {
                        config_manager.remove_blocked_device(device.address);
                    }
                }
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Set device blocked");
                throw e;
            }
        }
        
        /**
         * Get all devices
         * 
         * @param adapter_path Optional adapter path to filter devices
         * @return List of Bluetooth devices
         */
        public GenericArray<BluetoothDevice> get_devices(string? adapter_path = null) {
            if (!is_initialized) {
                warning("BluetoothController: Not initialized, returning empty device list");
                return new GenericArray<BluetoothDevice>();
            }
            
            if (adapter_path != null) {
                return device_manager.get_devices_for_adapter(adapter_path);
            } else {
                // Get devices from all adapters
                var all_devices = new GenericArray<BluetoothDevice>();
                var adapters = adapter_manager.get_all_adapters();
                
                for (uint i = 0; i < adapters.length; i++) {
                    var adapter_devices = device_manager.get_devices_for_adapter(adapters[i].object_path);
                    for (uint j = 0; j < adapter_devices.length; j++) {
                        all_devices.add(adapter_devices[j]);
                    }
                }
                
                return all_devices;
            }
        }
        
        /**
         * Get connected devices
         * 
         * @return List of connected devices
         */
        public GenericArray<BluetoothDevice> get_connected_devices() {
            if (!is_initialized) {
                return new GenericArray<BluetoothDevice>();
            }
            
            return device_manager.get_connected_devices();
        }
        
        /**
         * Get paired devices
         * 
         * @return List of paired devices
         */
        public GenericArray<BluetoothDevice> get_paired_devices() {
            if (!is_initialized) {
                return new GenericArray<BluetoothDevice>();
            }
            
            return device_manager.get_paired_devices();
        }

        
        // ========== Audio Operations ==========
        
        /**
         * Set active audio profile for a device
         * 
         * @param device_path The device object path
         * @param profile_uuid The UUID of the profile to activate
         */
        public async void set_audio_profile(string device_path, string profile_uuid) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Setting audio profile %s for device %s", profile_uuid, device_path);
            
            try {
                yield audio_manager.set_active_profile(device_path, profile_uuid);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Set audio profile");
                throw e;
            }
        }
        
        /**
         * Get audio profiles for a device
         * 
         * @param device_path The device object path
         * @return List of audio profiles
         */
        public GenericArray<AudioProfile> get_audio_profiles(string device_path) {
            if (!is_initialized) {
                return new GenericArray<AudioProfile>();
            }
            
            return audio_manager.get_profiles(device_path);
        }
        
        /**
         * Check if a device is an audio device
         * 
         * @param device_path The device object path
         * @return true if the device has audio profiles
         */
        public bool is_audio_device(string device_path) {
            if (!is_initialized) {
                return false;
            }
            
            var profiles = audio_manager.get_profiles(device_path);
            return profiles.length > 0;
        }
        
        // ========== Transfer Operations ==========
        
        /**
         * Send a file to a device
         * 
         * @param device_path The device object path
         * @param file_path The local file path to send
         * @return The transfer object path
         */
        public async string send_file(string device_path, string file_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Sending file %s to device %s", file_path, device_path);
            
            try {
                return yield transfer_manager.send_file(device_path, file_path);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Send file");
                throw e;
            }
        }
        
        /**
         * Send multiple files to a device
         * 
         * @param device_path The device object path
         * @param file_paths Array of local file paths to send
         * @return Array of transfer object paths
         */
        public async string[] send_files(string device_path, string[] file_paths) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Sending %d files to device %s", file_paths.length, device_path);
            
            try {
                return yield transfer_manager.send_files(device_path, file_paths);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Send files");
                throw e;
            }
        }
        
        /**
         * Cancel an active file transfer
         * 
         * @param transfer_path The transfer object path
         */
        public async void cancel_transfer(string transfer_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("BluetoothController not initialized");
            }
            
            debug("BluetoothController: Cancelling transfer %s", transfer_path);
            
            try {
                yield transfer_manager.cancel_transfer(transfer_path);
            } catch (Error e) {
                var bt_error = error_handler.handle_bluez_error(e, "Cancel transfer");
                throw e;
            }
        }
        
        /**
         * Get all active transfers
         * 
         * @return List of active file transfers
         */
        public GenericArray<FileTransfer> get_active_transfers() {
            if (!is_initialized) {
                return new GenericArray<FileTransfer>();
            }
            
            return transfer_manager.get_active_transfers();
        }
        
        // ========== Pairing Response Methods ==========
        
        /**
         * Provide PIN code response for pairing
         * 
         * @param pin_code The PIN code entered by the user
         */
        public void provide_pin_code(string pin_code) {
            if (!is_initialized) {
                warning("BluetoothController: Not initialized");
                return;
            }
            
            agent_manager.provide_pin_code(pin_code);
        }
        
        /**
         * Provide passkey response for pairing
         * 
         * @param passkey The passkey entered by the user
         */
        public void provide_passkey(uint32 passkey) {
            if (!is_initialized) {
                warning("BluetoothController: Not initialized");
                return;
            }
            
            agent_manager.provide_passkey(passkey);
        }
        
        /**
         * Confirm pairing request
         * 
         * @param confirmed Whether the user confirmed the pairing
         */
        public void confirm_pairing(bool confirmed) {
            if (!is_initialized) {
                warning("BluetoothController: Not initialized");
                return;
            }
            
            agent_manager.confirm_pairing(confirmed);
        }
        
        /**
         * Authorize pairing or service
         * 
         * @param authorized Whether the user authorized the operation
         */
        public void authorize(bool authorized) {
            if (!is_initialized) {
                warning("BluetoothController: Not initialized");
                return;
            }
            
            agent_manager.authorize(authorized);
        }
        
        // ========== Configuration Methods ==========
        
        /**
         * Get configuration manager
         * 
         * @return The configuration manager instance
         */
        public ConfigManager get_config_manager() {
            return config_manager;
        }
        
        /**
         * Get error handler
         * 
         * @return The error handler instance
         */
        public ErrorHandler get_error_handler() {
            return error_handler;
        }
        
        /**
         * Get PolicyKit client
         * 
         * @return The PolicyKit client instance
         */
        public PolicyKitClient get_polkit_client() {
            return polkit_client;
        }
    }
}
