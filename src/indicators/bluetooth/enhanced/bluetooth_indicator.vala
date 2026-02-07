/**
 * Enhanced Bluetooth Indicator - Main Indicator Component
 * 
 * This file provides the main Bluetooth indicator component that displays
 * Bluetooth status and manages the popover interface for Bluetooth management.
 */

using GLib;
using Gtk;

namespace EnhancedBluetooth {

    /**
     * Main Bluetooth indicator component
     * 
     * This class provides the main indicator button with status display,
     * click/hover event handling, popover management, and notification system.
     */
    public class BluetoothIndicator : Gtk.Button {
        private Gtk.Image indicator_icon;
        private BluetoothPopover? popover;
        private BluetoothController? controller;
        private NotificationManager? notification_manager;
        private BluetoothState current_state;
        private bool hover_enabled;
        
        // Notification overlay
        private Gtk.Overlay overlay;
        private Gtk.Label notification_label;
        private bool notification_visible;
        private uint notification_timeout_id;
        
        /**
         * Signal emitted when Bluetooth state changes
         */
        public signal void bluetooth_state_changed(BluetoothState state);
        
        /**
         * Signal emitted when device connection status changes
         */
        public signal void device_status_changed(string device_path, bool connected);
        
        public BluetoothState indicator_state { 
            get { return current_state; } 
        }
        
        public BluetoothIndicator() {
            GLib.Object();
            
            // Setup button properties
            get_style_context().add_class("flat");
            get_style_context().add_class("indicator");
            get_style_context().add_class("bluetooth-indicator");
            
            current_state = BluetoothState.OFF;
            hover_enabled = true;
            notification_visible = false;
            notification_timeout_id = 0;
            
            setup_ui();
            setup_event_handlers();
            setup_accessibility();
            
            debug("BluetoothIndicator: Main component initialized");
        }
        
        /**
         * Setup accessibility features
         */
        private void setup_accessibility() {
            // Set accessible name and description
            AccessibilityHelper.set_accessible_name(this, "Bluetooth Indicator");
            AccessibilityHelper.set_accessible_description(this, "Click to open Bluetooth management");
            AccessibilityHelper.set_accessible_role(this, Atk.Role.PUSH_BUTTON);
            
            // Make indicator icon accessible
            AccessibilityHelper.set_accessible_name(indicator_icon, "Bluetooth status icon");
            
            debug("BluetoothIndicator: Accessibility setup complete");
        }
        
        /**
         * Setup the user interface components
         */
        private void setup_ui() {
            // Create overlay for notifications
            overlay = new Gtk.Overlay();
            
            // Create main indicator icon
            indicator_icon = new Gtk.Image.from_icon_name("bluetooth-disabled-symbolic", Gtk.IconSize.MENU);
            indicator_icon.set_tooltip_text("Bluetooth disabled");
            
            overlay.add(indicator_icon);
            
            // Create notification label (initially hidden)
            notification_label = new Gtk.Label("");
            notification_label.get_style_context().add_class("notification-label");
            notification_label.halign = Gtk.Align.END;
            notification_label.valign = Gtk.Align.START;
            notification_label.visible = false;
            notification_label.set_size_request(8, 8);
            
            overlay.add_overlay(notification_label);
            add(overlay);
            
            debug("BluetoothIndicator: UI components setup complete");
        }
        
        /**
         * Setup event handlers for user interactions
         */
        private void setup_event_handlers() {
            // Click event to show/hide popover
            clicked.connect(on_indicator_clicked);
            
            // Hover events for enhanced interaction
            enter_notify_event.connect(on_enter_notify);
            leave_notify_event.connect(on_leave_notify);
            
            // Key press events for accessibility
            key_press_event.connect(on_key_press);
            
            debug("BluetoothIndicator: Event handlers setup complete");
        }
        
        /**
         * Initialize the Bluetooth controller and connect signals
         */
        public async bool initialize_controller() {
            try {
                debug("BluetoothIndicator: Initializing Bluetooth controller...");
                
                controller = new BluetoothController();
                
                // Connect controller signals
                controller.adapter_state_changed.connect(on_adapter_state_changed);
                controller.device_found.connect(on_device_found);
                controller.device_connected.connect(on_device_connected);
                controller.device_disconnected.connect(on_device_disconnected);
                controller.pairing_completed.connect(on_pairing_completed);
                controller.transfer_completed.connect(on_transfer_completed);
                controller.error_occurred.connect(on_error_occurred);
                
                // Initialize the controller
                var success = yield controller.initialize();
                if (!success) {
                    warning("BluetoothIndicator: Failed to initialize Bluetooth controller");
                    update_indicator_state(BluetoothState.UNAVAILABLE);
                    return false;
                }
                
                // Initialize notification manager
                var config_manager = controller.get_config_manager();
                notification_manager = new NotificationManager(controller, config_manager);
                notification_manager.notification_requested.connect((message, type) => {
                    show_notification(message, type);
                });
                
                // Get initial Bluetooth state
                update_state_from_controller();
                
                debug("BluetoothIndicator: Bluetooth controller initialized successfully");
                return true;
                
            } catch (Error e) {
                warning("BluetoothIndicator: Failed to initialize controller: %s", e.message);
                update_indicator_state(BluetoothState.UNAVAILABLE);
                return false;
            }
        }
        
        /**
         * Handle indicator click events
         */
        private void on_indicator_clicked() {
            debug("BluetoothIndicator: Indicator clicked");
            
            if (popover != null && popover.visible) {
                popover.hide();
                return;
            }
            
            show_popover();
        }
        
        /**
         * Handle mouse enter events
         */
        private bool on_enter_notify(Gdk.EventCrossing event) {
            if (hover_enabled) {
                get_style_context().add_class("hover");
                
                // Update tooltip with current connection info
                update_tooltip();
            }
            return false;
        }
        
        /**
         * Handle mouse leave events
         */
        private bool on_leave_notify(Gdk.EventCrossing event) {
            if (hover_enabled) {
                get_style_context().remove_class("hover");
            }
            return false;
        }
        
        /**
         * Handle key press events for accessibility
         */
        private bool on_key_press(Gdk.EventKey event) {
            // Check for activation keys
            if (KeyboardShortcuts.is_activation_key(event)) {
                on_indicator_clicked();
                return true;
            }
            
            // Handle specific shortcuts
            switch (event.keyval) {
                case Gdk.Key.Escape:
                    if (popover != null && popover.visible) {
                        popover.hide();
                        return true;
                    }
                    break;
                    
                case Gdk.Key.F10:
                case Gdk.Key.Menu:
                    // Show context menu (if implemented)
                    show_indicator_context_menu();
                    return true;
                    
                case Gdk.Key.F5:
                    // Quick refresh
                    if (popover != null && popover.visible) {
                        popover.refresh();
                        return true;
                    }
                    break;
            }
            
            return false;
        }
        
        /**
         * Show context menu for indicator
         */
        private void show_indicator_context_menu() {
            var menu = new Gtk.Menu();
            
            var refresh_item = new Gtk.MenuItem.with_label("Refresh Devices");
            refresh_item.activate.connect(() => {
                if (popover != null) {
                    popover.refresh();
                }
            });
            menu.append(refresh_item);
            
            var settings_item = new Gtk.MenuItem.with_label("Bluetooth Settings");
            settings_item.activate.connect(() => {
                show_popover();
            });
            menu.append(settings_item);
            
            menu.show_all();
            menu.popup_at_widget(this, Gdk.Gravity.SOUTH, Gdk.Gravity.NORTH, null);
        }
        
        /**
         * Show the Bluetooth popover
         */
        private void show_popover() {
            if (controller == null) {
                show_notification("Bluetooth controller not available", NotificationType.ERROR);
                return;
            }
            
            // Create popover if it doesn't exist
            if (popover == null) {
                popover = new BluetoothPopover(controller);
                
                // Connect popover signals
                popover.closed.connect(() => {
                    debug("BluetoothIndicator: Popover closed");
                });
            }
            
            // Calculate position below the indicator button
            int x, y;
            Gtk.Allocation alloc;
            get_allocation(out alloc);
            get_window().get_origin(out x, out y);
            x += alloc.x + alloc.width / 2;
            y += alloc.y + alloc.height + 4;
            
            // Refresh popover content and show
            popover.refresh();
            popover.show_at(x, y);
            
            debug("BluetoothIndicator: Popover shown");
        }
        
        /**
         * Update the indicator state and icon
         */
        public void update_indicator_state(BluetoothState state) {
            if (current_state == state) return;
            
            debug("BluetoothIndicator: State changed: %s -> %s", 
                  current_state.to_string(), state.to_string());
            
            current_state = state;
            
            string icon_name;
            string tooltip_text;
            string accessible_description;
            
            switch (state) {
                case BluetoothState.ON:
                    icon_name = "bluetooth-active-symbolic";
                    tooltip_text = "Bluetooth enabled";
                    accessible_description = "Bluetooth is enabled";
                    break;
                    
                case BluetoothState.CONNECTED:
                    icon_name = "bluetooth-active-symbolic";
                    tooltip_text = "Bluetooth connected";
                    accessible_description = "Bluetooth device connected";
                    break;
                    
                case BluetoothState.DISCOVERING:
                    icon_name = "bluetooth-active-symbolic";
                    tooltip_text = "Scanning for devices...";
                    accessible_description = "Scanning for Bluetooth devices";
                    break;
                    
                case BluetoothState.UNAVAILABLE:
                    icon_name = "bluetooth-disabled-symbolic";
                    tooltip_text = "Bluetooth unavailable";
                    accessible_description = "Bluetooth service unavailable";
                    break;
                    
                case BluetoothState.OFF:
                default:
                    icon_name = "bluetooth-disabled-symbolic";
                    tooltip_text = "Bluetooth disabled";
                    accessible_description = "Bluetooth is disabled";
                    break;
            }
            
            indicator_icon.set_from_icon_name(icon_name, Gtk.IconSize.MENU);
            indicator_icon.set_tooltip_text(tooltip_text);
            
            // Update accessible description
            AccessibilityHelper.set_accessible_description(this, accessible_description);
            AccessibilityHelper.set_accessible_name(indicator_icon, tooltip_text);
            
            // Add visual feedback for state changes
            get_style_context().remove_class("discovering");
            get_style_context().remove_class("connected");
            get_style_context().remove_class("unavailable");
            
            switch (state) {
                case BluetoothState.DISCOVERING:
                    get_style_context().add_class("discovering");
                    AccessibilityHelper.set_busy(this, true);
                    break;
                case BluetoothState.CONNECTED:
                    get_style_context().add_class("connected");
                    AccessibilityHelper.set_busy(this, false);
                    break;
                case BluetoothState.UNAVAILABLE:
                    get_style_context().add_class("unavailable");
                    AccessibilityHelper.set_busy(this, false);
                    break;
                default:
                    AccessibilityHelper.set_busy(this, false);
                    break;
            }
            
            bluetooth_state_changed(state);
        }
        
        /**
         * Show a notification with the specified message and type
         */
        public void show_notification(string message, NotificationType type) {
            debug("BluetoothIndicator: Showing notification: %s (%s)", message, type.to_string());
            
            // Clear any existing notification timeout
            if (notification_timeout_id > 0) {
                Source.remove(notification_timeout_id);
                notification_timeout_id = 0;
            }
            
            // Update notification appearance based on type
            notification_label.get_style_context().remove_class("info");
            notification_label.get_style_context().remove_class("warning");
            notification_label.get_style_context().remove_class("error");
            notification_label.get_style_context().remove_class("success");
            
            string css_class;
            switch (type) {
                case NotificationType.WARNING:
                    css_class = "warning";
                    break;
                case NotificationType.ERROR:
                    css_class = "error";
                    break;
                case NotificationType.SUCCESS:
                    css_class = "success";
                    break;
                case NotificationType.INFO:
                default:
                    css_class = "info";
                    break;
            }
            
            notification_label.get_style_context().add_class(css_class);
            notification_label.set_text("●"); // Simple dot indicator
            notification_label.set_tooltip_text(message);
            notification_label.visible = true;
            notification_visible = true;
            
            // Auto-hide notification after 5 seconds
            notification_timeout_id = Timeout.add_seconds(5, () => {
                hide_notification();
                notification_timeout_id = 0;
                return Source.REMOVE;
            });
        }
        
        /**
         * Hide the current notification
         */
        public void hide_notification() {
            if (notification_visible) {
                notification_label.visible = false;
                notification_visible = false;
                
                if (notification_timeout_id > 0) {
                    Source.remove(notification_timeout_id);
                    notification_timeout_id = 0;
                }
                
                debug("BluetoothIndicator: Notification hidden");
            }
        }
        
        /**
         * Update tooltip with current connection information
         */
        private void update_tooltip() {
            if (controller == null) return;
            
            var tooltip_text = new StringBuilder();
            
            // Add Bluetooth status
            switch (current_state) {
                case BluetoothState.OFF:
                    tooltip_text.append("Bluetooth disabled");
                    break;
                case BluetoothState.ON:
                    tooltip_text.append("Bluetooth enabled");
                    break;
                case BluetoothState.CONNECTED:
                    tooltip_text.append("Bluetooth connected");
                    // Add connected device count
                    var connected_devices = controller.get_connected_devices();
                    if (connected_devices.length > 0) {
                        tooltip_text.append_printf("\n%d device%s connected", 
                            connected_devices.length, 
                            connected_devices.length == 1 ? "" : "s");
                    }
                    break;
                case BluetoothState.DISCOVERING:
                    tooltip_text.append("Scanning for devices...");
                    break;
                case BluetoothState.UNAVAILABLE:
                    tooltip_text.append("Bluetooth unavailable");
                    break;
            }
            
            indicator_icon.set_tooltip_text(tooltip_text.str);
        }
        
        /**
         * Update state from controller
         */
        private void update_state_from_controller() {
            if (controller == null) return;
            
            // Get default adapter
            var adapters = controller.get_adapters();
            if (adapters.length == 0) {
                update_indicator_state(BluetoothState.UNAVAILABLE);
                return;
            }
            
            var default_adapter = adapters[0];
            
            // Determine state based on adapter
            if (!default_adapter.powered) {
                update_indicator_state(BluetoothState.OFF);
            } else if (default_adapter.discovering) {
                update_indicator_state(BluetoothState.DISCOVERING);
            } else {
                // Check if any devices are connected
                var connected_devices = controller.get_connected_devices();
                if (connected_devices.length > 0) {
                    update_indicator_state(BluetoothState.CONNECTED);
                } else {
                    update_indicator_state(BluetoothState.ON);
                }
            }
        }
        
        /**
         * Handle adapter state changes from controller
         */
        private void on_adapter_state_changed(BluetoothAdapter adapter) {
            debug("BluetoothIndicator: Adapter state changed");
            update_state_from_controller();
        }
        
        /**
         * Handle device found events
         */
        private void on_device_found(BluetoothDevice device) {
            debug("BluetoothIndicator: Device found: %s", device.get_display_name());
        }
        
        /**
         * Handle device connected events
         */
        private void on_device_connected(BluetoothDevice device) {
            debug("BluetoothIndicator: Device connected: %s", device.get_display_name());
            update_state_from_controller();
            device_status_changed(device.object_path, true);
        }
        
        /**
         * Handle device disconnected events
         */
        private void on_device_disconnected(BluetoothDevice device) {
            debug("BluetoothIndicator: Device disconnected: %s", device.get_display_name());
            update_state_from_controller();
            device_status_changed(device.object_path, false);
        }
        
        /**
         * Handle pairing completed events
         */
        private void on_pairing_completed(string device_path, bool success) {
            debug("BluetoothIndicator: Pairing completed for %s: %s", 
                  device_path, success ? "success" : "failed");
        }
        
        /**
         * Handle transfer completed events
         */
        private void on_transfer_completed(FileTransfer transfer) {
            debug("BluetoothIndicator: Transfer completed: %s", transfer.filename);
        }
        
        /**
         * Handle errors from controller
         */
        private void on_error_occurred(BluetoothError error) {
            warning("BluetoothIndicator: Error occurred: %s", error.message);
        }
        
        /**
         * Enable or disable hover effects
         */
        public void set_hover_enabled(bool enabled) {
            hover_enabled = enabled;
            
            if (!enabled) {
                get_style_context().remove_class("hover");
            }
        }
        
        /**
         * Get the current popover instance
         */
        public BluetoothPopover? get_popover() {
            return popover;
        }
        
        /**
         * Force refresh of the indicator state
         */
        public async void refresh_state() {
            if (controller != null) {
                update_state_from_controller();
            }
        }
        
        /**
         * Cleanup resources when indicator is destroyed
         */
        public override void destroy() {
            debug("BluetoothIndicator: Cleaning up resources...");
            
            if (notification_timeout_id > 0) {
                Source.remove(notification_timeout_id);
                notification_timeout_id = 0;
            }
            
            if (popover != null) {
                popover.destroy();
                popover = null;
            }
            
            if (controller != null) {
                controller.shutdown();
                controller = null;
            }
            
            base.destroy();
        }
    }
    
    /**
     * Notification type enum
     */
    public enum NotificationType {
        INFO,
        SUCCESS,
        WARNING,
        ERROR
    }
}
