/**
 * Enhanced Bluetooth Indicator - Agent Manager
 * 
 * This file implements the BlueZ Agent1 interface for handling pairing
 * authentication requests from Bluetooth devices.
 * 
 * Note: This is a simplified implementation that provides the core functionality
 * for pairing authentication. The full D-Bus Agent1 interface implementation
 * will be added in a future iteration.
 */

using GLib;

namespace EnhancedBluetooth {

    /**
     * Agent Manager for handling Bluetooth pairing authentication
     * 
     * This class provides methods for handling various pairing methods including
     * PIN codes, passkeys, and authorization requests. It creates PairingRequest
     * objects and emits signals for UI interaction.
     */
    public class AgentManager : Object {
        // D-Bus constants
        private const string AGENT_INTERFACE = "org.bluez.Agent1";
        private const string AGENT_MANAGER_INTERFACE = "org.bluez.AgentManager1";
        private const string AGENT_MANAGER_PATH = "/org/bluez";
        private const string AGENT_CAPABILITY = "KeyboardDisplay";
        
        // BlueZ client reference
        private BlueZClient _client;
        
        // Agent registration
        private string _agent_path;
        private bool _is_registered;
        
        // Current pairing request
        private PairingRequest? _current_request;
        private MainLoop? _pending_loop;
        private bool _pending_response;
        private bool _pending_accepted;
        private string? _pending_value;
        
        /**
         * Signal emitted when a pairing request is received
         */
        public signal void pairing_request(PairingRequest request);
        
        /**
         * Signal emitted when pairing completes
         */
        public signal void pairing_completed(string device_path, bool success);
        
        /**
         * Whether the agent is registered
         */
        public bool is_registered {
            get { return _is_registered; }
        }
        
        /**
         * Constructor
         */
        public AgentManager() {
            _agent_path = "/org/novabar/bluetooth/agent";
            _is_registered = false;
            _current_request = null;
        }
        
        /**
         * Initialize the agent manager with BlueZ client
         * 
         * @param client The BlueZ D-Bus client
         */
        public async void initialize(BlueZClient client) throws Error {
            debug("AgentManager: Initializing...");
            
            _client = client;
            
            // Register the agent
            yield register_agent();
            
            debug("AgentManager: Initialization complete");
        }
        
        /**
         * Register the agent with BlueZ AgentManager
         * 
         * Handles conflicts with other Bluetooth managers (blueman, gnome-bluetooth)
         * by attempting multiple registration strategies:
         * 1. Try normal registration + request default
         * 2. If AlreadyExists, unregister first then retry
         * 3. If RequestDefaultAgent fails, still mark as registered (non-default)
         */
        public async void register_agent() throws Error {
            if (_is_registered) {
                debug("AgentManager: Agent already registered");
                return;
            }
            
            if (_client == null || !_client.is_connected) {
                throw new IOError.NOT_CONNECTED("BlueZ client not connected");
            }
            
            debug("AgentManager: Registering agent at %s with capability %s",
                  _agent_path, AGENT_CAPABILITY);
            
            // Strategy 1: Try normal registration
            bool registered = false;
            try {
                yield _client.call_method(
                    AGENT_MANAGER_PATH,
                    AGENT_MANAGER_INTERFACE,
                    "RegisterAgent",
                    new Variant("(os)", _agent_path, AGENT_CAPABILITY)
                );
                registered = true;
            } catch (Error e) {
                // If AlreadyExists, try to unregister first then retry
                if (e.message != null && e.message.contains("AlreadyExists")) {
                    debug("AgentManager: Agent path already exists, unregistering first...");
                    try {
                        yield _client.call_method(
                            AGENT_MANAGER_PATH,
                            AGENT_MANAGER_INTERFACE,
                            "UnregisterAgent",
                            new Variant("(o)", _agent_path)
                        );
                        // Retry registration
                        yield _client.call_method(
                            AGENT_MANAGER_PATH,
                            AGENT_MANAGER_INTERFACE,
                            "RegisterAgent",
                            new Variant("(os)", _agent_path, AGENT_CAPABILITY)
                        );
                        registered = true;
                    } catch (Error retry_error) {
                        warning("AgentManager: Retry registration failed: %s", retry_error.message);
                    }
                } else {
                    warning("AgentManager: Registration failed: %s", e.message);
                }
            }
            
            if (!registered) {
                // Non-fatal: another agent is handling pairing
                debug("AgentManager: Could not register agent, another Bluetooth manager is handling pairing");
                return;
            }
            
            // Strategy 2: Try to become default agent (non-fatal if it fails)
            try {
                yield _client.call_method(
                    AGENT_MANAGER_PATH,
                    AGENT_MANAGER_INTERFACE,
                    "RequestDefaultAgent",
                    new Variant("(o)", _agent_path)
                );
                debug("AgentManager: Registered as default agent");
            } catch (Error default_error) {
                // Another agent is the default — that's OK, we're still registered
                debug("AgentManager: Could not become default agent (another manager is default): %s",
                      default_error.message);
            }
            
            _is_registered = true;
            debug("AgentManager: Agent registered successfully");
        }
        
        /**
         * Unregister the agent from BlueZ
         */
        public async void unregister_agent() throws Error {
            if (!_is_registered) {
                debug("AgentManager: Agent not registered");
                return;
            }
            
            try {
                debug("AgentManager: Unregistering agent...");
                
                // Unregister from BlueZ AgentManager
                if (_client != null && _client.is_connected) {
                    yield _client.call_method(
                        AGENT_MANAGER_PATH,
                        AGENT_MANAGER_INTERFACE,
                        "UnregisterAgent",
                        new Variant("(o)", _agent_path)
                    );
                }
                
                _is_registered = false;
                debug("AgentManager: Agent unregistered successfully");
                
            } catch (Error e) {
                warning("AgentManager: Failed to unregister agent: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Shutdown the agent manager
         */
        public void shutdown() {
            debug("AgentManager: Shutting down...");
            
            if (_is_registered) {
                unregister_agent.begin((obj, res) => {
                    try {
                        unregister_agent.end(res);
                    } catch (Error e) {
                        warning("AgentManager: Error during shutdown: %s", e.message);
                    }
                });
            }
            
            _current_request = null;
            _client = null;
        }
        
        /**
         * Request PIN code from device (called by DeviceManager during pairing)
         */
        public async string? request_pin_code(string device_path) throws Error {
            debug("AgentManager: RequestPinCode for device %s", device_path);
            
            // Create pairing request
            var request = yield create_pairing_request(
                device_path,
                PairingMethod.PIN_CODE
            );
            
            // Emit signal and wait for response
            var response = yield wait_for_user_response(request);
            
            if (response.accepted && response.value != null) {
                pairing_completed(device_path, true);
                return response.value;
            } else {
                pairing_completed(device_path, false);
                throw new IOError.CANCELLED("User rejected pairing");
            }
        }
        
        /**
         * Display PIN code to user
         */
        public async void display_pin_code(string device_path, string pin_code) throws Error {
            debug("AgentManager: DisplayPinCode for device %s: %s", device_path, pin_code);
            
            // Create pairing request
            var request = yield create_pairing_request(
                device_path,
                PairingMethod.PASSKEY_DISPLAY
            );
            request.pin_code = pin_code;
            
            // Emit signal and wait for response
            var response = yield wait_for_user_response(request);
            
            if (response.accepted) {
                pairing_completed(device_path, true);
            } else {
                pairing_completed(device_path, false);
                throw new IOError.CANCELLED("User rejected pairing");
            }
        }
        
        /**
         * Request passkey from user
         */
        public async uint32 request_passkey(string device_path) throws Error {
            debug("AgentManager: RequestPasskey for device %s", device_path);
            
            // Create pairing request
            var request = yield create_pairing_request(
                device_path,
                PairingMethod.PASSKEY_ENTRY
            );
            
            // Emit signal and wait for response
            var response = yield wait_for_user_response(request);
            
            if (response.accepted && response.value != null) {
                uint32 passkey = (uint32) uint64.parse(response.value);
                pairing_completed(device_path, true);
                return passkey;
            } else {
                pairing_completed(device_path, false);
                throw new IOError.CANCELLED("User rejected pairing");
            }
        }
        
        /**
         * Display passkey to user
         */
        public async void display_passkey(string device_path, uint32 passkey, uint16 entered) throws Error {
            debug("AgentManager: DisplayPasskey for device %s: %06u (entered: %u)",
                  device_path, passkey, entered);
            
            // Create pairing request
            var request = yield create_pairing_request(
                device_path,
                PairingMethod.PASSKEY_DISPLAY
            );
            request.passkey = passkey;
            
            // Emit signal (no response needed for display)
            pairing_request(request);
        }
        
        /**
         * Request user to confirm passkey
         */
        public async void request_confirmation(string device_path, uint32 passkey) throws Error {
            debug("AgentManager: RequestConfirmation for device %s: %06u",
                  device_path, passkey);
            
            // Create pairing request
            var request = yield create_pairing_request(
                device_path,
                PairingMethod.PASSKEY_CONFIRMATION
            );
            request.passkey = passkey;
            
            // Emit signal and wait for response
            var response = yield wait_for_user_response(request);
            
            if (response.accepted) {
                pairing_completed(device_path, true);
            } else {
                pairing_completed(device_path, false);
                throw new IOError.CANCELLED("User rejected pairing");
            }
        }
        
        /**
         * Request user authorization
         */
        public async void request_authorization(string device_path) throws Error {
            debug("AgentManager: RequestAuthorization for device %s", device_path);
            
            // Create pairing request
            var request = yield create_pairing_request(
                device_path,
                PairingMethod.AUTHORIZATION
            );
            
            // Emit signal and wait for response
            var response = yield wait_for_user_response(request);
            
            if (response.accepted) {
                pairing_completed(device_path, true);
            } else {
                pairing_completed(device_path, false);
                throw new IOError.CANCELLED("User rejected authorization");
            }
        }
        
        /**
         * Request service authorization
         */
        public async void authorize_service(string device_path, string uuid) throws Error {
            debug("AgentManager: AuthorizeService for device %s, UUID: %s",
                  device_path, uuid);
            
            // Create pairing request
            var request = yield create_pairing_request(
                device_path,
                PairingMethod.SERVICE_AUTHORIZATION
            );
            
            // Emit signal and wait for response
            var response = yield wait_for_user_response(request);
            
            if (response.accepted) {
                pairing_completed(device_path, true);
            } else {
                pairing_completed(device_path, false);
                throw new IOError.CANCELLED("User rejected service authorization");
            }
        }
        
        /**
         * Cancel current pairing operation
         */
        public void cancel() {
            debug("AgentManager: Cancel called");
            
            if (_current_request != null) {
                var device_path = _current_request.device_path;
                _current_request = null;
                
                // Cancel pending response
                if (_pending_loop != null) {
                    _pending_response = true;
                    _pending_accepted = false;
                    _pending_value = null;
                    _pending_loop.quit();
                }
                
                pairing_completed(device_path, false);
            }
        }
        
        /**
         * Create a pairing request for a device
         */
        private async PairingRequest create_pairing_request(
            string device_path,
            PairingMethod method
        ) throws Error {
            var request = new PairingRequest();
            request.device_path = device_path;
            request.method = method;
            
            // Get device name from BlueZ
            try {
                var name_variant = yield _client.get_property(
                    device_path,
                    "org.bluez.Device1",
                    "Alias"
                );
                request.device_name = name_variant.get_string();
            } catch (Error e) {
                warning("AgentManager: Failed to get device name: %s", e.message);
                request.device_name = "Unknown Device";
            }
            
            _current_request = request;
            return request;
        }
        
        /**
         * Wait for user response to pairing request
         */
        private async UserResponse wait_for_user_response(PairingRequest request) {
            // Emit the pairing request signal
            pairing_request(request);
            
            // Create a main loop to wait for response
            _pending_loop = new MainLoop();
            _pending_response = false;
            _pending_accepted = false;
            _pending_value = null;
            
            // Set up timeout (30 seconds)
            var timeout_id = Timeout.add_seconds(30, () => {
                if (!_pending_response) {
                    _pending_response = true;
                    _pending_accepted = false;
                    _pending_loop.quit();
                }
                return Source.REMOVE;
            });
            
            // Wait for response
            _pending_loop.run();
            
            // Clean up timeout
            if (timeout_id > 0) {
                Source.remove(timeout_id);
            }
            
            var response = UserResponse() {
                accepted = _pending_accepted,
                value = _pending_value
            };
            
            _pending_loop = null;
            _current_request = null;
            
            return response;
        }
        
        /**
         * Provide PIN code response
         */
        public void provide_pin_code(string pin_code) {
            if (_pending_loop != null && !_pending_response) {
                _pending_response = true;
                _pending_accepted = true;
                _pending_value = pin_code;
                _pending_loop.quit();
            }
        }
        
        /**
         * Provide passkey response
         */
        public void provide_passkey(uint32 passkey) {
            if (_pending_loop != null && !_pending_response) {
                _pending_response = true;
                _pending_accepted = true;
                _pending_value = passkey.to_string();
                _pending_loop.quit();
            }
        }
        
        /**
         * Confirm pairing
         */
        public void confirm_pairing(bool confirmed) {
            if (_pending_loop != null && !_pending_response) {
                _pending_response = true;
                _pending_accepted = confirmed;
                _pending_value = null;
                _pending_loop.quit();
            }
        }
        
        /**
         * Authorize pairing or service
         */
        public void authorize(bool authorized) {
            if (_pending_loop != null && !_pending_response) {
                _pending_response = true;
                _pending_accepted = authorized;
                _pending_value = null;
                _pending_loop.quit();
            }
        }
    }
    
    /**
     * User response structure
     */
    private struct UserResponse {
        bool accepted;
        string? value;
    }
}
