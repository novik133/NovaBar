/**
 * Enhanced Bluetooth Indicator - Transfer Manager
 * 
 * Manages file transfers via OBEX protocol for Bluetooth devices.
 */

using GLib;

namespace EnhancedBluetooth {

    /**
     * Transfer Manager for Bluetooth file transfer operations
     * 
     * This class handles file sending and receiving operations via OBEX,
     * transfer progress monitoring, and transfer control (pause, resume, cancel).
     */
    public class TransferManager : Object {
        // D-Bus constants
        private const string OBEX_SERVICE = "org.bluez.obex";
        private const string OBEX_CLIENT_INTERFACE = "org.bluez.obex.Client1";
        private const string OBEX_SESSION_INTERFACE = "org.bluez.obex.Session1";
        private const string OBEX_TRANSFER_INTERFACE = "org.bluez.obex.Transfer1";
        private const string OBEX_OBJECT_PUSH_INTERFACE = "org.bluez.obex.ObjectPush1";
        
        // BlueZ client reference
        private BlueZClient client;
        
        // Active transfers storage: transfer_path -> FileTransfer
        private HashTable<string, FileTransfer> active_transfers;
        
        // Initialization state
        private bool is_initialized;
        
        /**
         * Signal emitted when a transfer starts
         */
        public signal void transfer_started(FileTransfer transfer);
        
        /**
         * Signal emitted when transfer progress updates
         */
        public signal void transfer_progress(FileTransfer transfer, uint64 bytes_transferred);
        
        /**
         * Signal emitted when a transfer completes successfully
         */
        public signal void transfer_completed(FileTransfer transfer);
        
        /**
         * Signal emitted when a transfer fails
         */
        public signal void transfer_failed(FileTransfer transfer, Error error);
        
        /**
         * Constructor
         */
        public TransferManager() {
            active_transfers = new HashTable<string, FileTransfer>(str_hash, str_equal);
            is_initialized = false;
        }
        
        /**
         * Initialize the transfer manager with a BlueZ client
         * 
         * @param client The BlueZ D-Bus client
         */
        public async void initialize(BlueZClient client) throws Error {
            if (is_initialized) {
                warning("TransferManager: Already initialized");
                return;
            }
            
            debug("TransferManager: Initializing...");
            
            this.client = client;
            
            // Subscribe to BlueZ object events for transfer monitoring
            client.object_added.connect(on_object_added);
            client.object_removed.connect(on_object_removed);
            client.properties_changed.connect(on_properties_changed);
            
            is_initialized = true;
            debug("TransferManager: Initialization complete");
        }
        
        /**
         * Shutdown the transfer manager
         */
        public void shutdown() {
            debug("TransferManager: Shutting down...");
            
            // Clear active transfers
            active_transfers.remove_all();
            
            is_initialized = false;
            debug("TransferManager: Shutdown complete");
        }
        
        /**
         * Get a specific transfer by object path
         * 
         * @param transfer_path The D-Bus object path of the transfer
         * @return The FileTransfer object, or null if not found
         */
        public FileTransfer? get_transfer(string transfer_path) {
            return active_transfers.lookup(transfer_path);
        }
        
        /**
         * Get all active transfers
         * 
         * @return List of active FileTransfer objects
         */
        public GenericArray<FileTransfer> get_active_transfers() {
            var transfers = new GenericArray<FileTransfer>();
            
            active_transfers.foreach((path, transfer) => {
                transfers.add(transfer);
            });
            
            return transfers;
        }
        
        /**
         * Handle object added event
         */
        private void on_object_added(string object_path, string interface_name) {
            // Monitor for new transfer objects
            if (interface_name == OBEX_TRANSFER_INTERFACE) {
                debug("TransferManager: New transfer detected: %s", object_path);
                // Transfer will be tracked when properties are received
            }
        }
        
        /**
         * Handle object removed event
         */
        private void on_object_removed(string object_path, string interface_name) {
            // Handle transfer removal
            if (interface_name == OBEX_TRANSFER_INTERFACE) {
                debug("TransferManager: Transfer removed: %s", object_path);
                
                var transfer = active_transfers.lookup(object_path);
                if (transfer != null) {
                    // Mark as complete or failed based on status
                    if (transfer.status == TransferStatus.ACTIVE || 
                        transfer.status == TransferStatus.QUEUED) {
                        transfer.status = TransferStatus.ERROR;
                        var error = new IOError.FAILED("Transfer was removed unexpectedly");
                        transfer_failed(transfer, error);
                    }
                    
                    active_transfers.remove(object_path);
                }
            }
        }
        
        /**
         * Handle properties changed event
         */
        private void on_properties_changed(
            string object_path,
            string interface_name,
            HashTable<string, Variant> changed_properties
        ) {
            // Monitor transfer property changes
            if (interface_name == OBEX_TRANSFER_INTERFACE) {
                update_transfer_from_properties.begin(object_path, changed_properties);
            }
        }
        
        /**
         * Update transfer object from D-Bus properties
         */
        private async void update_transfer_from_properties(
            string transfer_path,
            HashTable<string, Variant> properties
        ) {
            var transfer = active_transfers.lookup(transfer_path);
            
            // Create transfer if it doesn't exist
            if (transfer == null) {
                transfer = new FileTransfer();
                transfer.object_path = transfer_path;
                active_transfers[transfer_path] = transfer;
            }
            
            // Update properties
            bool progress_updated = false;
            bool status_changed = false;
            
            Variant? value = null;
            
            value = properties.lookup("Transferred");
            if (value != null) {
                uint64 new_transferred = value.get_uint64();
                if (new_transferred != transfer.transferred) {
                    transfer.update_progress(new_transferred);
                    progress_updated = true;
                }
            }
            
            value = properties.lookup("Size");
            if (value != null) {
                transfer.size = value.get_uint64();
            }
            
            value = properties.lookup("Filename");
            if (value != null) {
                transfer.filename = value.get_string();
            }
            
            value = properties.lookup("Name");
            if (value != null && transfer.filename == "") {
                transfer.filename = value.get_string();
            }
            
            value = properties.lookup("Status");
            if (value != null) {
                string status_str = value.get_string();
                var old_status = transfer.status;
                transfer.status = parse_transfer_status(status_str);
                
                if (old_status != transfer.status) {
                    status_changed = true;
                }
            }
            
            // Emit appropriate signals
            if (status_changed) {
                if (transfer.status == TransferStatus.ACTIVE && 
                    active_transfers.size() == 1) {
                    // First time seeing this transfer as active
                    transfer_started(transfer);
                } else if (transfer.status == TransferStatus.COMPLETE) {
                    transfer_completed(transfer);
                } else if (transfer.status == TransferStatus.ERROR) {
                    var error = new IOError.FAILED("Transfer failed");
                    transfer_failed(transfer, error);
                }
            }
            
            if (progress_updated && transfer.status == TransferStatus.ACTIVE) {
                transfer_progress(transfer, transfer.transferred);
            }
        }
        
        /**
         * Parse transfer status string from D-Bus
         */
        private TransferStatus parse_transfer_status(string status_str) {
            switch (status_str.down()) {
                case "queued":
                    return TransferStatus.QUEUED;
                case "active":
                    return TransferStatus.ACTIVE;
                case "suspended":
                    return TransferStatus.SUSPENDED;
                case "complete":
                    return TransferStatus.COMPLETE;
                case "error":
                    return TransferStatus.ERROR;
                default:
                    warning("TransferManager: Unknown transfer status: %s", status_str);
                    return TransferStatus.QUEUED;
            }
        }
        
        /**
         * Send a file to a device via OBEX
         * 
         * @param device_path The D-Bus object path of the target device
         * @param file_path The local file path to send
         * @return The transfer object path
         */
        public async string send_file(string device_path, string file_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("TransferManager not initialized");
            }
            
            debug("TransferManager: Sending file %s to device %s", file_path, device_path);
            
            // Verify file exists
            var file = File.new_for_path(file_path);
            if (!file.query_exists()) {
                throw new IOError.NOT_FOUND("File not found: %s", file_path);
            }
            
            // Get device address from device path
            string device_address;
            try {
                var address_variant = yield client.get_property(
                    device_path,
                    "org.bluez.Device1",
                    "Address"
                );
                device_address = address_variant.get_string();
            } catch (Error e) {
                throw new IOError.FAILED("Failed to get device address: %s", e.message);
            }
            
            // Create OBEX session
            string session_path;
            try {
                session_path = yield create_obex_session(device_address);
            } catch (Error e) {
                throw new IOError.FAILED("Failed to create OBEX session: %s", e.message);
            }
            
            // Send file via ObjectPush
            string transfer_path;
            try {
                transfer_path = yield send_file_via_session(session_path, file_path);
            } catch (Error e) {
                // Clean up session on failure
                yield remove_obex_session(session_path);
                throw new IOError.FAILED("Failed to send file: %s", e.message);
            }
            
            // Create FileTransfer object
            var transfer = new FileTransfer();
            transfer.object_path = transfer_path;
            transfer.session_path = session_path;
            transfer.device_path = device_path;
            transfer.filename = file.get_basename();
            transfer.local_path = file_path;
            transfer.direction = TransferDirection.SENDING;
            transfer.status = TransferStatus.QUEUED;
            
            // Get file size
            try {
                var file_info = yield file.query_info_async(
                    FileAttribute.STANDARD_SIZE,
                    FileQueryInfoFlags.NONE
                );
                transfer.size = file_info.get_size();
            } catch (Error e) {
                warning("TransferManager: Failed to get file size: %s", e.message);
            }
            
            // Store transfer
            active_transfers[transfer_path] = transfer;
            
            // Emit signal
            transfer_started(transfer);
            
            debug("TransferManager: File transfer started: %s", transfer_path);
            return transfer_path;
        }
        
        /**
         * Send multiple files to a device via OBEX
         * 
         * @param device_path The D-Bus object path of the target device
         * @param file_paths Array of local file paths to send
         * @return Array of transfer object paths
         */
        public async string[] send_files(string device_path, string[] file_paths) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("TransferManager not initialized");
            }
            
            debug("TransferManager: Sending %d files to device %s", file_paths.length, device_path);
            
            string[] transfer_paths = {};
            
            // Send each file sequentially
            foreach (var file_path in file_paths) {
                try {
                    var transfer_path = yield send_file(device_path, file_path);
                    transfer_paths += transfer_path;
                } catch (Error e) {
                    warning("TransferManager: Failed to send file %s: %s", file_path, e.message);
                    // Continue with remaining files
                }
            }
            
            debug("TransferManager: Started %d/%d file transfers", 
                  transfer_paths.length, file_paths.length);
            
            return transfer_paths;
        }
        
        /**
         * Create an OBEX session with a device
         */
        private async string create_obex_session(string device_address) throws Error {
            debug("TransferManager: Creating OBEX session for device %s", device_address);
            
            // Call CreateSession on OBEX Client
            var parameters = new HashTable<string, Variant>(str_hash, str_equal);
            parameters["Target"] = new Variant.string("opp"); // Object Push Profile
            
            var result = yield client.call_method(
                "/org/bluez/obex",
                OBEX_CLIENT_INTERFACE,
                "CreateSession",
                new Variant("(sa{sv})", device_address, parameters)
            );
            
            string session_path;
            result.get("(o)", out session_path);
            
            debug("TransferManager: OBEX session created: %s", session_path);
            return session_path;
        }
        
        /**
         * Remove an OBEX session
         */
        private async void remove_obex_session(string session_path) {
            try {
                debug("TransferManager: Removing OBEX session: %s", session_path);
                
                yield client.call_method(
                    "/org/bluez/obex",
                    OBEX_CLIENT_INTERFACE,
                    "RemoveSession",
                    new Variant("(o)", session_path)
                );
                
                debug("TransferManager: OBEX session removed");
            } catch (Error e) {
                warning("TransferManager: Failed to remove OBEX session: %s", e.message);
            }
        }
        
        /**
         * Send a file via an existing OBEX session
         */
        private async string send_file_via_session(string session_path, string file_path) throws Error {
            debug("TransferManager: Sending file via session %s: %s", session_path, file_path);
            
            // Call SendFile on ObjectPush interface
            var result = yield client.call_method(
                session_path,
                OBEX_OBJECT_PUSH_INTERFACE,
                "SendFile",
                new Variant("(s)", file_path)
            );
            
            string transfer_path;
            Variant properties_variant;
            result.get("(o@a{sv})", out transfer_path, out properties_variant);
            
            debug("TransferManager: File send initiated: %s", transfer_path);
            return transfer_path;
        }
        
        /**
         * Accept an incoming file transfer
         * 
         * @param transfer_path The D-Bus object path of the transfer
         * @param save_path The local path where the file should be saved
         */
        public async void accept_transfer(string transfer_path, string save_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("TransferManager not initialized");
            }
            
            debug("TransferManager: Accepting transfer %s to %s", transfer_path, save_path);
            
            var transfer = active_transfers.lookup(transfer_path);
            if (transfer == null) {
                throw new IOError.NOT_FOUND("Transfer not found: %s", transfer_path);
            }
            
            // Verify save directory exists
            var save_file = File.new_for_path(save_path);
            var save_dir = save_file.get_parent();
            if (save_dir != null && !save_dir.query_exists()) {
                throw new IOError.NOT_FOUND("Save directory does not exist: %s", save_dir.get_path());
            }
            
            // Update transfer local path
            transfer.local_path = save_path;
            transfer.status = TransferStatus.ACTIVE;
            
            // Note: BlueZ OBEX automatically accepts transfers when they are created
            // The actual file saving is handled by BlueZ based on the session configuration
            // We just need to track the transfer and monitor its progress
            
            debug("TransferManager: Transfer accepted");
        }
        
        /**
         * Reject an incoming file transfer
         * 
         * @param transfer_path The D-Bus object path of the transfer
         */
        public async void reject_transfer(string transfer_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("TransferManager not initialized");
            }
            
            debug("TransferManager: Rejecting transfer %s", transfer_path);
            
            var transfer = active_transfers.lookup(transfer_path);
            if (transfer == null) {
                throw new IOError.NOT_FOUND("Transfer not found: %s", transfer_path);
            }
            
            // Cancel the transfer to reject it
            try {
                yield cancel_transfer(transfer_path);
                debug("TransferManager: Transfer rejected");
            } catch (Error e) {
                throw new IOError.FAILED("Failed to reject transfer: %s", e.message);
            }
        }
        
        /**
         * Cancel an active file transfer
         * 
         * @param transfer_path The D-Bus object path of the transfer
         */
        public async void cancel_transfer(string transfer_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("TransferManager not initialized");
            }
            
            debug("TransferManager: Cancelling transfer %s", transfer_path);
            
            var transfer = active_transfers.lookup(transfer_path);
            if (transfer == null) {
                throw new IOError.NOT_FOUND("Transfer not found: %s", transfer_path);
            }
            
            // Call Cancel method on transfer
            try {
                yield client.call_method(
                    transfer_path,
                    OBEX_TRANSFER_INTERFACE,
                    "Cancel",
                    null
                );
                
                // Update transfer status
                transfer.status = TransferStatus.ERROR;
                
                // Emit signal
                var error = new IOError.CANCELLED("Transfer cancelled by user");
                transfer_failed(transfer, error);
                
                // Remove from active transfers
                active_transfers.remove(transfer_path);
                
                // Clean up session if this was the last transfer
                if (transfer.session_path != null && transfer.session_path != "") {
                    yield remove_obex_session(transfer.session_path);
                }
                
                debug("TransferManager: Transfer cancelled");
            } catch (Error e) {
                throw new IOError.FAILED("Failed to cancel transfer: %s", e.message);
            }
        }
        
        /**
         * Pause an active file transfer
         * 
         * @param transfer_path The D-Bus object path of the transfer
         */
        public async void pause_transfer(string transfer_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("TransferManager not initialized");
            }
            
            debug("TransferManager: Pausing transfer %s", transfer_path);
            
            var transfer = active_transfers.lookup(transfer_path);
            if (transfer == null) {
                throw new IOError.NOT_FOUND("Transfer not found: %s", transfer_path);
            }
            
            if (transfer.status != TransferStatus.ACTIVE) {
                throw new IOError.INVALID_ARGUMENT("Transfer is not active");
            }
            
            // Call Suspend method on transfer
            try {
                yield client.call_method(
                    transfer_path,
                    OBEX_TRANSFER_INTERFACE,
                    "Suspend",
                    null
                );
                
                // Update transfer status
                transfer.status = TransferStatus.SUSPENDED;
                
                debug("TransferManager: Transfer paused");
            } catch (Error e) {
                throw new IOError.FAILED("Failed to pause transfer: %s", e.message);
            }
        }
        
        /**
         * Resume a paused file transfer
         * 
         * @param transfer_path The D-Bus object path of the transfer
         */
        public async void resume_transfer(string transfer_path) throws Error {
            if (!is_initialized) {
                throw new IOError.NOT_INITIALIZED("TransferManager not initialized");
            }
            
            debug("TransferManager: Resuming transfer %s", transfer_path);
            
            var transfer = active_transfers.lookup(transfer_path);
            if (transfer == null) {
                throw new IOError.NOT_FOUND("Transfer not found: %s", transfer_path);
            }
            
            if (transfer.status != TransferStatus.SUSPENDED) {
                throw new IOError.INVALID_ARGUMENT("Transfer is not suspended");
            }
            
            // Call Resume method on transfer
            try {
                yield client.call_method(
                    transfer_path,
                    OBEX_TRANSFER_INTERFACE,
                    "Resume",
                    null
                );
                
                // Update transfer status
                transfer.status = TransferStatus.ACTIVE;
                
                debug("TransferManager: Transfer resumed");
            } catch (Error e) {
                throw new IOError.FAILED("Failed to resume transfer: %s", e.message);
            }
        }
    }
}
