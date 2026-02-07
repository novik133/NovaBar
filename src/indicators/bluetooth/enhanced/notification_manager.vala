/**
 * Enhanced Bluetooth Indicator - Notification Manager
 * 
 * This file provides notification management for Bluetooth events,
 * respecting user preferences and providing appropriate notifications
 * for device connections, pairing, and file transfers.
 */

using GLib;

namespace EnhancedBluetooth {

    /**
     * Notification Manager
     * 
     * This class manages notifications for Bluetooth events, including
     * device connections, pairing completion, and file transfers.
     * It respects user notification preferences from ConfigManager.
     */
    public class NotificationManager : Object {
        private BluetoothController controller;
        private ConfigManager config_manager;
        private bool notifications_enabled;
        
        // Notification settings
        private bool notify_on_connect;
        private bool notify_on_disconnect;
        private bool notify_on_pairing;
        private bool notify_on_transfer;
        
        /**
         * Signal emitted when a notification should be displayed
         */
        public signal void notification_requested(string message, NotificationType type);
        
        /**
         * Constructor
         */
        public NotificationManager(BluetoothController controller, ConfigManager config_manager) {
            this.controller = controller;
            this.config_manager = config_manager;
            
            // Load notification preferences
            load_notification_preferences();
            
            // Connect to controller events
            connect_controller_signals();
            
            debug("NotificationManager: Initialized");
        }
        
        /**
         * Load notification preferences from configuration
         */
        private void load_notification_preferences() {
            // Get UI preferences from config
            var ui_prefs = config_manager.get_ui_preferences();
            
            // Default to enabled if not specified
            notifications_enabled = ui_prefs.notifications_enabled;
            notify_on_connect = ui_prefs.notify_on_connect;
            notify_on_disconnect = ui_prefs.notify_on_disconnect;
            notify_on_pairing = ui_prefs.notify_on_pairing;
            notify_on_transfer = ui_prefs.notify_on_transfer;
            
            debug("NotificationManager: Preferences loaded - enabled: %s", 
                  notifications_enabled.to_string());
        }
        
        /**
         * Connect to controller signals for event notifications
         */
        private void connect_controller_signals() {
            controller.device_connected.connect(on_device_connected);
            controller.device_disconnected.connect(on_device_disconnected);
            controller.pairing_completed.connect(on_pairing_completed);
            controller.transfer_completed.connect(on_transfer_completed);
            controller.error_occurred.connect(on_error_occurred);
            
            debug("NotificationManager: Controller signals connected");
        }
        
        /**
         * Handle device connected events
         */
        private void on_device_connected(BluetoothDevice device) {
            if (!notifications_enabled || !notify_on_connect) {
                return;
            }
            
            var message = @"Connected to $(device.get_display_name())";
            notify(message, NotificationType.SUCCESS);
            
            debug("NotificationManager: Device connected notification: %s", message);
        }
        
        /**
         * Handle device disconnected events
         */
        private void on_device_disconnected(BluetoothDevice device) {
            if (!notifications_enabled || !notify_on_disconnect) {
                return;
            }
            
            var message = @"Disconnected from $(device.get_display_name())";
            notify(message, NotificationType.INFO);
            
            debug("NotificationManager: Device disconnected notification: %s", message);
        }
        
        /**
         * Handle pairing completed events
         */
        private void on_pairing_completed(string device_path, bool success) {
            if (!notifications_enabled || !notify_on_pairing) {
                return;
            }
            
            // Get device name
            var devices = controller.get_devices();
            string device_name = "Device";
            
            foreach (var device in devices) {
                if (device.object_path == device_path) {
                    device_name = device.get_display_name();
                    break;
                }
            }
            
            string message;
            NotificationType type;
            
            if (success) {
                message = @"Successfully paired with $device_name";
                type = NotificationType.SUCCESS;
            } else {
                message = @"Failed to pair with $device_name";
                type = NotificationType.ERROR;
            }
            
            notify(message, type);
            
            debug("NotificationManager: Pairing completed notification: %s", message);
        }
        
        /**
         * Handle transfer completed events
         */
        private void on_transfer_completed(FileTransfer transfer) {
            if (!notifications_enabled || !notify_on_transfer) {
                return;
            }
            
            string message;
            NotificationType type;
            
            if (transfer.status == TransferStatus.COMPLETE) {
                if (transfer.direction == TransferDirection.SENDING) {
                    message = @"File sent: $(transfer.filename)";
                } else {
                    message = @"File received: $(transfer.filename)";
                }
                type = NotificationType.SUCCESS;
            } else {
                if (transfer.direction == TransferDirection.SENDING) {
                    message = @"Failed to send: $(transfer.filename)";
                } else {
                    message = @"Failed to receive: $(transfer.filename)";
                }
                type = NotificationType.ERROR;
            }
            
            notify(message, type);
            
            debug("NotificationManager: Transfer completed notification: %s", message);
        }
        
        /**
         * Handle error events
         */
        private void on_error_occurred(BluetoothError error) {
            if (!notifications_enabled) {
                return;
            }
            
            // Only notify for user-facing errors
            if (error.category == ErrorCategory.DBUS_ERROR ||
                error.category == ErrorCategory.UNKNOWN_ERROR) {
                // Don't notify for internal errors
                return;
            }
            
            var message = error.get_user_message();
            notify(message, NotificationType.ERROR);
            
            debug("NotificationManager: Error notification: %s", message);
        }
        
        /**
         * Send a notification
         */
        public void notify(string message, NotificationType type) {
            if (!notifications_enabled) {
                return;
            }
            
            // Emit signal for indicator to display notification
            notification_requested(message, type);
            
            // Also send system notification if available
            send_system_notification(message, type);
        }
        
        /**
         * Send a system notification using GLib.Notification
         */
        private void send_system_notification(string message, NotificationType type) {
            try {
                var notification = new GLib.Notification("Bluetooth");
                notification.set_body(message);
                
                // Set icon based on notification type
                string icon_name;
                switch (type) {
                    case NotificationType.SUCCESS:
                        icon_name = "bluetooth-active-symbolic";
                        break;
                    case NotificationType.ERROR:
                        icon_name = "dialog-error-symbolic";
                        break;
                    case NotificationType.WARNING:
                        icon_name = "dialog-warning-symbolic";
                        break;
                    case NotificationType.INFO:
                    default:
                        icon_name = "bluetooth-active-symbolic";
                        break;
                }
                
                var icon = new ThemedIcon(icon_name);
                notification.set_icon(icon);
                
                // Send notification
                // Note: This requires an Application instance
                // In NovaBar context, we may need to use a different notification system
                debug("NotificationManager: System notification sent: %s", message);
                
            } catch (Error e) {
                warning("NotificationManager: Failed to send system notification: %s", e.message);
            }
        }
        
        /**
         * Enable or disable notifications
         */
        public void set_notifications_enabled(bool enabled) {
            notifications_enabled = enabled;
            
            // Save preference
            var ui_prefs = config_manager.get_ui_preferences();
            ui_prefs.notifications_enabled = enabled;
            config_manager.set_ui_preferences(ui_prefs);
            config_manager.save_configuration();
            
            debug("NotificationManager: Notifications %s", enabled ? "enabled" : "disabled");
        }
        
        /**
         * Set notification preference for device connections
         */
        public void set_notify_on_connect(bool enabled) {
            notify_on_connect = enabled;
            
            var ui_prefs = config_manager.get_ui_preferences();
            ui_prefs.notify_on_connect = enabled;
            config_manager.set_ui_preferences(ui_prefs);
            config_manager.save_configuration();
        }
        
        /**
         * Set notification preference for device disconnections
         */
        public void set_notify_on_disconnect(bool enabled) {
            notify_on_disconnect = enabled;
            
            var ui_prefs = config_manager.get_ui_preferences();
            ui_prefs.notify_on_disconnect = enabled;
            config_manager.set_ui_preferences(ui_prefs);
            config_manager.save_configuration();
        }
        
        /**
         * Set notification preference for pairing events
         */
        public void set_notify_on_pairing(bool enabled) {
            notify_on_pairing = enabled;
            
            var ui_prefs = config_manager.get_ui_preferences();
            ui_prefs.notify_on_pairing = enabled;
            config_manager.set_ui_preferences(ui_prefs);
            config_manager.save_configuration();
        }
        
        /**
         * Set notification preference for file transfers
         */
        public void set_notify_on_transfer(bool enabled) {
            notify_on_transfer = enabled;
            
            var ui_prefs = config_manager.get_ui_preferences();
            ui_prefs.notify_on_transfer = enabled;
            config_manager.set_ui_preferences(ui_prefs);
            config_manager.save_configuration();
        }
        
        /**
         * Get current notification enabled state
         */
        public bool get_notifications_enabled() {
            return notifications_enabled;
        }
        
        /**
         * Get notification preference for device connections
         */
        public bool get_notify_on_connect() {
            return notify_on_connect;
        }
        
        /**
         * Get notification preference for device disconnections
         */
        public bool get_notify_on_disconnect() {
            return notify_on_disconnect;
        }
        
        /**
         * Get notification preference for pairing events
         */
        public bool get_notify_on_pairing() {
            return notify_on_pairing;
        }
        
        /**
         * Get notification preference for file transfers
         */
        public bool get_notify_on_transfer() {
            return notify_on_transfer;
        }
    }
}
