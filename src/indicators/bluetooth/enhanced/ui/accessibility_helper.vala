/**
 * Enhanced Bluetooth Indicator - Accessibility Helper
 * 
 * This file provides accessibility utilities including screen reader support,
 * ARIA attributes, and accessible status announcements.
 */

using GLib;
using Gtk;
using Atk;

namespace EnhancedBluetooth {

    /**
     * Accessibility helper for screen reader support
     */
    public class AccessibilityHelper : GLib.Object {
        private static AccessibilityHelper? instance = null;
        private Gtk.Window? main_window;
        private Gtk.Label? announcement_label;
        
        /**
         * Get singleton instance
         */
        public static AccessibilityHelper get_instance() {
            if (instance == null) {
                instance = new AccessibilityHelper();
            }
            return instance;
        }
        
        private AccessibilityHelper() {
            setup_announcement_system();
        }
        
        /**
         * Setup announcement system for screen readers
         */
        private void setup_announcement_system() {
            // Create invisible label for announcements
            announcement_label = new Gtk.Label("");
            announcement_label.visible = false;
            announcement_label.no_show_all = true;
            
            // Set ATK role for announcements
            var atk_object = announcement_label.get_accessible();
            if (atk_object != null) {
                atk_object.set_role(Atk.Role.ALERT);
            }
            
            debug("AccessibilityHelper: Announcement system initialized");
        }
        
        /**
         * Announce message to screen readers
         */
        public void announce(string message, AnnouncementPriority priority = AnnouncementPriority.NORMAL) {
            if (announcement_label == null) return;
            
            debug("AccessibilityHelper: Announcing: %s (priority: %s)", message, priority.to_string());
            
            // Update label text to trigger screen reader announcement
            announcement_label.set_text(message);
            
            // Set appropriate ATK attributes based on priority
            var atk_object = announcement_label.get_accessible();
            if (atk_object != null) {
                switch (priority) {
                    case AnnouncementPriority.HIGH:
                        atk_object.set_role(Atk.Role.ALERT);
                        break;
                    case AnnouncementPriority.LOW:
                        atk_object.set_role(Atk.Role.LABEL);
                        break;
                    case AnnouncementPriority.NORMAL:
                    default:
                        atk_object.set_role(Atk.Role.LABEL);
                        break;
                }
            }
            
            // Clear announcement after delay to allow for new announcements
            Timeout.add(100, () => {
                if (announcement_label != null) {
                    announcement_label.set_text("");
                }
                return Source.REMOVE;
            });
        }
        
        /**
         * Set accessible name for widget
         */
        public static void set_accessible_name(Gtk.Widget widget, string name) {
            var atk_object = widget.get_accessible();
            if (atk_object != null) {
                atk_object.set_name(name);
            }
        }
        
        /**
         * Set accessible description for widget
         */
        public static void set_accessible_description(Gtk.Widget widget, string description) {
            var atk_object = widget.get_accessible();
            if (atk_object != null) {
                atk_object.set_description(description);
            }
        }
        
        /**
         * Set accessible role for widget
         */
        public static void set_accessible_role(Gtk.Widget widget, Atk.Role role) {
            var atk_object = widget.get_accessible();
            if (atk_object != null) {
                atk_object.set_role(role);
            }
        }
        
        /**
         * Mark widget as accessible button
         */
        public static void mark_as_button(Gtk.Widget widget, string label) {
            set_accessible_name(widget, label);
            set_accessible_role(widget, Atk.Role.PUSH_BUTTON);
        }
        
        /**
         * Mark widget as accessible toggle button
         */
        public static void mark_as_toggle(Gtk.Widget widget, string label, bool state) {
            set_accessible_name(widget, label);
            set_accessible_role(widget, Atk.Role.TOGGLE_BUTTON);
            
            var atk_object = widget.get_accessible();
            if (atk_object != null && atk_object is Atk.Action) {
                var action = atk_object as Atk.Action;
                action.set_description(0, state ? "Enabled" : "Disabled");
            }
        }
        
        /**
         * Mark widget as accessible list
         */
        public static void mark_as_list(Gtk.Widget widget, string label) {
            set_accessible_name(widget, label);
            set_accessible_role(widget, Atk.Role.LIST);
        }
        
        /**
         * Mark widget as accessible list item
         */
        public static void mark_as_list_item(Gtk.Widget widget, string label) {
            set_accessible_name(widget, label);
            set_accessible_role(widget, Atk.Role.LIST_ITEM);
        }
        
        /**
         * Mark widget as accessible menu
         */
        public static void mark_as_menu(Gtk.Widget widget, string label) {
            set_accessible_name(widget, label);
            set_accessible_role(widget, Atk.Role.MENU);
        }
        
        /**
         * Mark widget as accessible menu item
         */
        public static void mark_as_menu_item(Gtk.Widget widget, string label) {
            set_accessible_name(widget, label);
            set_accessible_role(widget, Atk.Role.MENU_ITEM);
        }
        
        /**
         * Mark widget as accessible dialog
         */
        public static void mark_as_dialog(Gtk.Widget widget, string label) {
            set_accessible_name(widget, label);
            set_accessible_role(widget, Atk.Role.DIALOG);
        }
        
        /**
         * Mark widget as accessible combo box
         */
        public static void mark_as_combo_box(Gtk.Widget widget, string label) {
            set_accessible_name(widget, label);
            set_accessible_role(widget, Atk.Role.COMBO_BOX);
        }
        
        /**
         * Set accessible state for widget
         */
        public static void set_accessible_state(Gtk.Widget widget, Atk.StateType state, bool enabled) {
            var atk_object = widget.get_accessible();
            if (atk_object != null && atk_object is Atk.Object) {
                var atk_obj = atk_object as Atk.Object;
                var state_set = atk_obj.ref_state_set();
                if (state_set != null) {
                    if (enabled) {
                        state_set.add_state(state);
                    } else {
                        state_set.remove_state(state);
                    }
                }
            }
        }
        
        /**
         * Mark widget as busy (for loading states)
         */
        public static void set_busy(Gtk.Widget widget, bool busy) {
            set_accessible_state(widget, Atk.StateType.BUSY, busy);
        }
        
        /**
         * Mark widget as expanded/collapsed
         */
        public static void set_expanded(Gtk.Widget widget, bool expanded) {
            set_accessible_state(widget, Atk.StateType.EXPANDED, expanded);
        }
        
        /**
         * Mark widget as selected
         */
        public static void set_selected(Gtk.Widget widget, bool selected) {
            set_accessible_state(widget, Atk.StateType.SELECTED, selected);
        }
        
        /**
         * Mark widget as checked (for checkboxes/toggles)
         */
        public static void set_checked(Gtk.Widget widget, bool checked) {
            set_accessible_state(widget, Atk.StateType.CHECKED, checked);
        }
        
        /**
         * Add accessible relation between widgets
         */
        public static void add_relation(Gtk.Widget widget, Gtk.Widget target, Atk.RelationType relation) {
            var atk_object = widget.get_accessible();
            var target_atk = target.get_accessible();
            
            if (atk_object != null && target_atk != null) {
                var relation_set = atk_object.ref_relation_set();
                if (relation_set != null) {
                    var targets = new Atk.Object[1];
                    targets[0] = target_atk;
                    var atk_relation = new Atk.Relation(targets, relation);
                    relation_set.add(atk_relation);
                }
            }
        }
        
        /**
         * Label widget with another widget (for form fields)
         */
        public static void label_widget(Gtk.Widget label, Gtk.Widget widget) {
            add_relation(widget, label, Atk.RelationType.LABELLED_BY);
            add_relation(label, widget, Atk.RelationType.LABEL_FOR);
        }
        
        /**
         * Get announcement label for adding to UI
         */
        public Gtk.Label? get_announcement_label() {
            return announcement_label;
        }
    }

    /**
     * Announcement priority levels
     */
    public enum AnnouncementPriority {
        LOW,
        NORMAL,
        HIGH
    }

    /**
     * Bluetooth status announcer for accessible status updates
     */
    public class BluetoothStatusAnnouncer : GLib.Object {
        private AccessibilityHelper accessibility;
        private BluetoothController controller;
        private bool? last_adapter_powered;
        private string? last_connected_device;
        
        public BluetoothStatusAnnouncer(BluetoothController controller) {
            this.controller = controller;
            this.accessibility = AccessibilityHelper.get_instance();
            this.last_adapter_powered = null;
            this.last_connected_device = null;
            
            setup_state_monitoring();
        }
        
        /**
         * Setup Bluetooth state monitoring for announcements
         */
        private void setup_state_monitoring() {
            controller.adapter_state_changed.connect(on_adapter_state_changed);
            controller.device_found.connect(on_device_found);
            controller.device_connected.connect(on_device_connected);
            controller.device_disconnected.connect(on_device_disconnected);
            controller.pairing_request.connect(on_pairing_request);
            controller.transfer_progress.connect(on_transfer_progress);
            controller.error_occurred.connect(on_error_occurred);
        }
        
        /**
         * Handle adapter state changes
         */
        private void on_adapter_state_changed(BluetoothAdapter adapter) {
            // Announce power state changes
            if (last_adapter_powered == null) {
                announce_initial_adapter_state(adapter);
            } else if (last_adapter_powered != adapter.powered) {
                accessibility.announce(
                    adapter.powered ? "Bluetooth enabled" : "Bluetooth disabled",
                    AnnouncementPriority.NORMAL
                );
            }
            
            last_adapter_powered = adapter.powered;
            
            // Announce discovery state changes
            if (adapter.discovering) {
                accessibility.announce("Scanning for Bluetooth devices", AnnouncementPriority.LOW);
            }
        }
        
        /**
         * Announce initial adapter state
         */
        private void announce_initial_adapter_state(BluetoothAdapter adapter) {
            if (!adapter.powered) {
                accessibility.announce("Bluetooth is disabled", AnnouncementPriority.NORMAL);
            } else {
                var connected_count = adapter.connected_device_count;
                if (connected_count > 0) {
                    accessibility.announce(
                        @"Bluetooth enabled, $(connected_count) device$(connected_count > 1 ? "s" : "") connected",
                        AnnouncementPriority.NORMAL
                    );
                } else {
                    accessibility.announce("Bluetooth enabled, no devices connected", AnnouncementPriority.NORMAL);
                }
            }
        }
        
        /**
         * Handle device found
         */
        private void on_device_found(BluetoothDevice device) {
            // Only announce if device has a name (avoid announcing unnamed devices)
            if (device.name != null && device.name.length > 0) {
                accessibility.announce(
                    @"Found device: $(device.get_display_name())",
                    AnnouncementPriority.LOW
                );
            }
        }
        
        /**
         * Handle device connected
         */
        private void on_device_connected(BluetoothDevice device) {
            var device_name = device.get_display_name();
            last_connected_device = device_name;
            
            var message = @"Connected to $(device_name)";
            
            // Add device type information
            switch (device.device_type) {
                case DeviceType.AUDIO:
                    message += ", audio device";
                    break;
                case DeviceType.INPUT:
                    message += ", input device";
                    break;
                case DeviceType.PHONE:
                    message += ", phone";
                    break;
                case DeviceType.COMPUTER:
                    message += ", computer";
                    break;
            }
            
            accessibility.announce(message, AnnouncementPriority.NORMAL);
        }
        
        /**
         * Handle device disconnected
         */
        private void on_device_disconnected(BluetoothDevice device) {
            accessibility.announce(
                @"Disconnected from $(device.get_display_name())",
                AnnouncementPriority.NORMAL
            );
        }
        
        /**
         * Handle pairing request
         */
        private void on_pairing_request(PairingRequest request) {
            var message = @"Pairing request from $(request.device_name)";
            
            switch (request.method) {
                case PairingMethod.PIN_CODE:
                    message += ", enter PIN code";
                    break;
                case PairingMethod.PASSKEY_ENTRY:
                    message += ", enter passkey";
                    break;
                case PairingMethod.PASSKEY_DISPLAY:
                    message += @", passkey is $(request.passkey)";
                    break;
                case PairingMethod.PASSKEY_CONFIRMATION:
                    message += @", confirm passkey $(request.passkey)";
                    break;
                case PairingMethod.AUTHORIZATION:
                    message += ", authorize connection";
                    break;
            }
            
            accessibility.announce(message, AnnouncementPriority.HIGH);
        }
        
        /**
         * Handle transfer progress
         */
        private void on_transfer_progress(FileTransfer transfer) {
            // Only announce at significant milestones to avoid spam
            var progress = transfer.progress_percentage;
            
            if (progress >= 100.0) {
                accessibility.announce(
                    @"File transfer complete: $(transfer.filename)",
                    AnnouncementPriority.NORMAL
                );
            } else if (transfer.status == TransferStatus.ACTIVE && (int)progress % 25 == 0) {
                // Announce at 25%, 50%, 75%
                accessibility.announce(
                    @"File transfer $(((int)progress).to_string()) percent complete",
                    AnnouncementPriority.LOW
                );
            }
        }
        
        /**
         * Handle error occurred
         */
        private void on_error_occurred(BluetoothError error) {
            var priority = AnnouncementPriority.NORMAL;
            
            // High priority for critical errors
            if (error.category == ErrorCategory.PERMISSION_ERROR ||
                error.category == ErrorCategory.DBUS_ERROR) {
                priority = AnnouncementPriority.HIGH;
            }
            
            accessibility.announce(
                @"Error: $(error.get_user_message())",
                priority
            );
        }
        
        /**
         * Announce pairing started
         */
        public void announce_pairing_started(string device_name) {
            accessibility.announce(
                @"Pairing with $(device_name)",
                AnnouncementPriority.NORMAL
            );
        }
        
        /**
         * Announce pairing completed
         */
        public void announce_pairing_completed(string device_name, bool success) {
            if (success) {
                accessibility.announce(
                    @"Successfully paired with $(device_name)",
                    AnnouncementPriority.NORMAL
                );
            } else {
                accessibility.announce(
                    @"Failed to pair with $(device_name)",
                    AnnouncementPriority.HIGH
                );
            }
        }
        
        /**
         * Announce connection started
         */
        public void announce_connection_started(string device_name) {
            accessibility.announce(
                @"Connecting to $(device_name)",
                AnnouncementPriority.LOW
            );
        }
    }

    /**
     * Error message formatter for accessible error messages
     */
    public class AccessibleErrorFormatter : GLib.Object {
        /**
         * Format error message for screen readers
         */
        public static string format_error(BluetoothError error) {
            var message = new StringBuilder();
            
            // Add severity prefix
            switch (error.category) {
                case ErrorCategory.PERMISSION_ERROR:
                case ErrorCategory.DBUS_ERROR:
                    message.append("Critical error: ");
                    break;
                case ErrorCategory.TIMEOUT_ERROR:
                case ErrorCategory.CONNECTION_ERROR:
                    message.append("Error: ");
                    break;
                default:
                    message.append("Warning: ");
                    break;
            }
            
            // Add error message
            message.append(error.message);
            
            // Add recovery suggestion if available
            if (error.recovery_suggestion != null && error.recovery_suggestion.length > 0) {
                message.append(". ");
                message.append(error.recovery_suggestion);
            }
            
            return message.str;
        }
        
        /**
         * Format device status for screen readers
         */
        public static string format_device_status(BluetoothDevice device) {
            var parts = new GenericArray<string>();
            
            parts.add(device.get_display_name());
            
            // Add device type
            switch (device.device_type) {
                case DeviceType.AUDIO:
                    parts.add("Audio device");
                    break;
                case DeviceType.INPUT:
                    parts.add("Input device");
                    break;
                case DeviceType.PHONE:
                    parts.add("Phone");
                    break;
                case DeviceType.COMPUTER:
                    parts.add("Computer");
                    break;
                case DeviceType.PERIPHERAL:
                    parts.add("Peripheral");
                    break;
                case DeviceType.WEARABLE:
                    parts.add("Wearable");
                    break;
            }
            
            // Add connection state
            if (device.connected) {
                parts.add("Connected");
            } else if (device.paired) {
                parts.add("Paired");
            } else {
                parts.add("Not paired");
            }
            
            // Add signal strength if connected
            if (device.connected && device.rssi != 0) {
                var strength = get_signal_strength_text(device.signal_strength);
                parts.add(@"Signal strength $(strength)");
            }
            
            // Add battery level if available
            if (device.battery_percentage != null) {
                parts.add(@"Battery $(device.battery_percentage) percent");
            }
            
            // Join parts
            var result = new StringBuilder();
            for (uint i = 0; i < parts.length; i++) {
                if (i > 0) result.append(", ");
                result.append(parts[i]);
            }
            
            return result.str;
        }
        
        /**
         * Get signal strength text
         */
        private static string get_signal_strength_text(SignalStrength strength) {
            switch (strength) {
                case SignalStrength.EXCELLENT:
                    return "excellent";
                case SignalStrength.GOOD:
                    return "good";
                case SignalStrength.FAIR:
                    return "fair";
                case SignalStrength.WEAK:
                    return "weak";
                case SignalStrength.VERY_WEAK:
                    return "very weak";
                default:
                    return "unknown";
            }
        }
        
        /**
         * Format adapter status for screen readers
         */
        public static string format_adapter_status(BluetoothAdapter adapter) {
            var parts = new GenericArray<string>();
            
            parts.add(adapter.get_display_name());
            
            if (adapter.powered) {
                parts.add("Enabled");
            } else {
                parts.add("Disabled");
            }
            
            if (adapter.discovering) {
                parts.add("Scanning for devices");
            }
            
            if (adapter.connected_device_count > 0) {
                parts.add(@"$(adapter.connected_device_count) device$(adapter.connected_device_count > 1 ? "s" : "") connected");
            }
            
            // Join parts
            var result = new StringBuilder();
            for (uint i = 0; i < parts.length; i++) {
                if (i > 0) result.append(", ");
                result.append(parts[i]);
            }
            
            return result.str;
        }
    }
}
