/**
 * Enhanced Network Indicator - Accessibility Helper
 * 
 * This file provides accessibility utilities including screen reader support,
 * ARIA attributes, and accessible status announcements.
 */

using GLib;
using Gtk;
using Atk;

namespace EnhancedNetwork {

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
     * Network status announcer for accessible status updates
     */
    public class NetworkStatusAnnouncer : GLib.Object {
        private AccessibilityHelper accessibility;
        private NetworkController controller;
        private NetworkState? last_state;
        
        public NetworkStatusAnnouncer(NetworkController controller) {
            this.controller = controller;
            this.accessibility = AccessibilityHelper.get_instance();
            this.last_state = null;
            
            setup_state_monitoring();
        }
        
        /**
         * Setup network state monitoring for announcements
         */
        private void setup_state_monitoring() {
            controller.state_changed.connect(on_network_state_changed);
            controller.connection_added.connect(on_connection_added);
            controller.connection_removed.connect(on_connection_removed);
            controller.security_alert.connect(on_security_alert);
        }
        
        /**
         * Handle network state changes
         */
        private void on_network_state_changed(NetworkState state) {
            // Announce significant state changes
            if (last_state == null) {
                announce_initial_state(state);
            } else {
                announce_state_change(last_state, state);
            }
            
            last_state = state;
        }
        
        /**
         * Announce initial network state
         */
        private void announce_initial_state(NetworkState state) {
            if (!state.networking_enabled) {
                accessibility.announce("Networking is disabled", AnnouncementPriority.NORMAL);
            } else if (state.connectivity == NM.ConnectivityState.FULL) {
                var message = "Connected to network";
                if (state.primary_connection_id != null) {
                    message += ": " + state.primary_connection_id;
                }
                accessibility.announce(message, AnnouncementPriority.NORMAL);
            } else {
                accessibility.announce("Not connected to network", AnnouncementPriority.NORMAL);
            }
        }
        
        /**
         * Announce network state change
         */
        private void announce_state_change(NetworkState old_state, NetworkState new_state) {
            // Announce connectivity changes
            if (old_state.connectivity != new_state.connectivity) {
                announce_connectivity_change(new_state.connectivity);
            }
            
            // Announce primary connection changes
            if (old_state.primary_connection_id != new_state.primary_connection_id) {
                if (new_state.primary_connection_id != null) {
                    accessibility.announce(
                        @"Connected to $(new_state.primary_connection_id)",
                        AnnouncementPriority.NORMAL
                    );
                } else {
                    accessibility.announce("Disconnected from network", AnnouncementPriority.NORMAL);
                }
            }
            
            // Announce wireless state changes
            if (old_state.wireless_enabled != new_state.wireless_enabled) {
                accessibility.announce(
                    new_state.wireless_enabled ? "WiFi enabled" : "WiFi disabled",
                    AnnouncementPriority.NORMAL
                );
            }
        }
        
        /**
         * Announce connectivity change
         */
        private void announce_connectivity_change(NM.ConnectivityState connectivity) {
            string message;
            var priority = AnnouncementPriority.NORMAL;
            
            switch (connectivity) {
                case NM.ConnectivityState.FULL:
                    message = "Full network connectivity";
                    break;
                case NM.ConnectivityState.LIMITED:
                    message = "Limited network connectivity";
                    priority = AnnouncementPriority.HIGH;
                    break;
                case NM.ConnectivityState.PORTAL:
                    message = "Captive portal detected";
                    priority = AnnouncementPriority.HIGH;
                    break;
                case NM.ConnectivityState.NONE:
                    message = "No network connectivity";
                    priority = AnnouncementPriority.HIGH;
                    break;
                case NM.ConnectivityState.UNKNOWN:
                default:
                    message = "Network connectivity unknown";
                    break;
            }
            
            accessibility.announce(message, priority);
        }
        
        /**
         * Handle connection added
         */
        private void on_connection_added(NetworkConnection connection) {
            accessibility.announce(
                @"Network added: $(connection.name ?? "Unknown")",
                AnnouncementPriority.LOW
            );
        }
        
        /**
         * Handle connection removed
         */
        private void on_connection_removed(string connection_id) {
            accessibility.announce(
                @"Network removed: $(connection_id ?? "Unknown")",
                AnnouncementPriority.LOW
            );
        }
        
        /**
         * Handle security alert
         */
        private void on_security_alert(SecurityAlert alert) {
            var priority = AnnouncementPriority.NORMAL;
            if (alert.severity == ErrorSeverity.HIGH) {
                priority = AnnouncementPriority.HIGH;
            }
            
            accessibility.announce(
                @"Security alert: $(alert.message ?? "Unknown alert")",
                priority
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
        public static string format_error(string error_message, ErrorSeverity severity) {
            string prefix;
            
            switch (severity) {
                case ErrorSeverity.HIGH:
                    prefix = "Critical error";
                    break;
                case ErrorSeverity.MEDIUM:
                    prefix = "Error";
                    break;
                case ErrorSeverity.LOW:
                    prefix = "Warning";
                    break;
                default:
                    prefix = "Notice";
                    break;
            }
            
            return @"$(prefix): $(error_message ?? "Unknown error")";
        }
        
        /**
         * Format connection error for screen readers
         */
        public static string format_connection_error(string network_name, string error_reason) {
            return @"Failed to connect to $(network_name ?? "network"). $(error_reason ?? "Unknown reason")";
        }
        
        /**
         * Format network status for screen readers
         */
        public static string format_network_status(WiFiNetwork network) {
            var parts = new GenericArray<string>();
            
            parts.add(network.ssid);
            
            // Add connection state
            switch (network.state) {
                case ConnectionState.CONNECTED:
                    parts.add("Connected");
                    break;
                case ConnectionState.CONNECTING:
                    parts.add("Connecting");
                    break;
                case ConnectionState.DISCONNECTED:
                    parts.add("Not connected");
                    break;
                case ConnectionState.FAILED:
                    parts.add("Connection failed");
                    break;
            }
            
            // Add signal strength
            parts.add(@"Signal strength $(network.signal_strength) percent");
            
            // Add security info
            parts.add(network.get_security_description());
            
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
