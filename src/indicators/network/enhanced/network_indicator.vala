/**
 * Enhanced Network Indicator - Main UI Component
 * 
 * This file provides the main network indicator component that displays
 * network status and manages the popover interface for network management.
 */

using GLib;
using Gtk;
using NM;

namespace EnhancedNetwork {

    /**
     * Network state for indicator display
     */
    public enum IndicatorState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED_WIFI,
        CONNECTED_ETHERNET,
        CONNECTED_VPN,
        CONNECTED_MOBILE,
        ERROR,
        DISABLED
    }

    /**
     * Main network indicator component
     * 
     * This class provides the main indicator icon with status display,
     * click/hover event handling, popover management, and notification system.
     */
    public class NetworkIndicator : Gtk.Button {
        private Gtk.Image indicator_icon;
        private NetworkPopover? popover;
        private NetworkController? controller;
        private IndicatorState current_state;
        private bool hover_enabled;
        private uint notification_timeout_id;
        
        // Notification overlay
        private Gtk.Overlay overlay;
        private Gtk.Label notification_label;
        private bool notification_visible;
        
        // Accessibility
        private NetworkStatusAnnouncer? status_announcer;
        
        /**
         * Signal emitted when network state changes
         */
        public signal void network_changed(NetworkState state);
        
        /**
         * Signal emitted when connection status changes
         */
        public signal void connection_status_changed(string connection_id, ConnectionStatus status);
        
        public IndicatorState indicator_state { 
            get { return current_state; } 
        }
        
        public NetworkIndicator() {
            GLib.Object();
            
            // Setup button properties
            get_style_context().add_class("flat");
            get_style_context().add_class("indicator");
            get_style_context().add_class("network-indicator");
            
            current_state = IndicatorState.DISCONNECTED;
            hover_enabled = true;
            notification_visible = false;
            status_announcer = null;
            
            setup_ui();
            setup_event_handlers();
            setup_accessibility();
            
            debug("NetworkIndicator: Main component initialized");
        }
        
        /**
         * Setup accessibility features
         */
        private void setup_accessibility() {
            // Set accessible name and description
            AccessibilityHelper.set_accessible_name(this, "Network Indicator");
            AccessibilityHelper.set_accessible_description(this, "Click to open network management");
            AccessibilityHelper.set_accessible_role(this, Atk.Role.PUSH_BUTTON);
            
            // Make indicator icon accessible
            AccessibilityHelper.set_accessible_name(indicator_icon, "Network status icon");
            
            debug("NetworkIndicator: Accessibility setup complete");
        }
        
        /**
         * Setup the user interface components
         */
        private void setup_ui() {
            // Create overlay for notifications
            overlay = new Gtk.Overlay();
            
            // Create main indicator icon
            indicator_icon = new Gtk.Image.from_icon_name("network-offline-symbolic", Gtk.IconSize.MENU);
            indicator_icon.set_tooltip_text("Network disconnected");
            
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
            
            debug("NetworkIndicator: UI components setup complete");
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
            
            debug("NetworkIndicator: Event handlers setup complete");
        }
        
        /**
         * Initialize the network controller and connect signals
         */
        public async bool initialize_controller() {
            try {
                debug("NetworkIndicator: Initializing network controller...");
                
                controller = new NetworkController();
                
                // Connect controller signals
                controller.state_changed.connect(on_network_state_changed);
                controller.connection_added.connect(on_connection_added);
                controller.connection_removed.connect(on_connection_removed);
                controller.security_alert.connect(on_security_alert);
                
                // Initialize the controller
                var success = yield controller.initialize();
                if (!success) {
                    warning("NetworkIndicator: Failed to initialize network controller");
                    update_indicator_state(IndicatorState.ERROR);
                    return false;
                }
                
                // Setup accessibility announcer
                status_announcer = new NetworkStatusAnnouncer(controller);
                
                // Get initial network state
                var initial_state = controller.current_state;
                if (initial_state != null) {
                    on_network_state_changed(initial_state);
                }
                
                debug("NetworkIndicator: Network controller initialized successfully");
                return true;
                
            } catch (Error e) {
                warning("NetworkIndicator: Failed to initialize controller: %s", e.message);
                update_indicator_state(IndicatorState.ERROR);
                return false;
            }
        }
        
        /**
         * Handle indicator click events
         */
        private void on_indicator_clicked() {
            debug("NetworkIndicator: Indicator clicked");
            
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
                        popover.refresh_content();
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
            
            var refresh_item = new Gtk.MenuItem.with_label("Refresh Networks");
            refresh_item.activate.connect(() => {
                if (popover != null) {
                    popover.refresh_content();
                }
            });
            menu.append(refresh_item);
            
            var settings_item = new Gtk.MenuItem.with_label("Network Settings");
            settings_item.activate.connect(() => {
                show_popover();
                if (popover != null) {
                    popover.show_panel(PanelType.SETTINGS);
                }
            });
            menu.append(settings_item);
            
            menu.show_all();
            menu.popup_at_widget(this, Gdk.Gravity.SOUTH, Gdk.Gravity.NORTH, null);
        }
        
        /**
         * Show the network popover
         */
        private void show_popover() {
            if (controller == null) {
                show_notification("Network controller not available", NotificationType.ERROR);
                return;
            }
            
            // Create popover if it doesn't exist
            if (popover == null) {
                popover = new NetworkPopover(controller);
                
                // Connect popover signals
                popover.closed.connect(() => {
                    debug("NetworkIndicator: Popover closed");
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
            popover.refresh_content();
            popover.show_at(x, y);
            
            debug("NetworkIndicator: Popover shown");
        }
        
        /**
         * Update the indicator state and icon
         */
        public void update_indicator_state(IndicatorState state) {
            if (current_state == state) return;
            
            debug("NetworkIndicator: State changed: %s -> %s", 
                  current_state.to_string(), state.to_string());
            
            current_state = state;
            
            string icon_name;
            string tooltip_text;
            string accessible_description;
            
            switch (state) {
                case IndicatorState.CONNECTED_WIFI:
                    icon_name = "network-wireless-signal-excellent-symbolic";
                    tooltip_text = "Connected to WiFi";
                    accessible_description = "Connected to WiFi network";
                    break;
                    
                case IndicatorState.CONNECTED_ETHERNET:
                    icon_name = "network-wired-symbolic";
                    tooltip_text = "Connected via Ethernet";
                    accessible_description = "Connected via Ethernet cable";
                    break;
                    
                case IndicatorState.CONNECTED_VPN:
                    icon_name = "network-vpn-symbolic";
                    tooltip_text = "Connected via VPN";
                    accessible_description = "Connected via VPN connection";
                    break;
                    
                case IndicatorState.CONNECTED_MOBILE:
                    icon_name = "network-cellular-signal-excellent-symbolic";
                    tooltip_text = "Connected via Mobile Data";
                    accessible_description = "Connected via mobile data network";
                    break;
                    
                case IndicatorState.CONNECTING:
                    icon_name = "network-wireless-acquiring-symbolic";
                    tooltip_text = "Connecting to network...";
                    accessible_description = "Connecting to network, please wait";
                    break;
                    
                case IndicatorState.ERROR:
                    icon_name = "network-error-symbolic";
                    tooltip_text = "Network error";
                    accessible_description = "Network error occurred";
                    break;
                    
                case IndicatorState.DISABLED:
                    icon_name = "network-wireless-disabled-symbolic";
                    tooltip_text = "Networking disabled";
                    accessible_description = "Networking is disabled";
                    break;
                    
                case IndicatorState.DISCONNECTED:
                default:
                    icon_name = "network-offline-symbolic";
                    tooltip_text = "Network disconnected";
                    accessible_description = "Not connected to any network";
                    break;
            }
            
            indicator_icon.set_from_icon_name(icon_name, Gtk.IconSize.MENU);
            indicator_icon.set_tooltip_text(tooltip_text);
            
            // Update accessible description
            AccessibilityHelper.set_accessible_description(this, accessible_description);
            AccessibilityHelper.set_accessible_name(indicator_icon, tooltip_text);
            
            // Add visual feedback for state changes
            get_style_context().remove_class("connecting");
            get_style_context().remove_class("connected");
            get_style_context().remove_class("error");
            
            switch (state) {
                case IndicatorState.CONNECTING:
                    get_style_context().add_class("connecting");
                    AccessibilityHelper.set_busy(this, true);
                    break;
                case IndicatorState.CONNECTED_WIFI:
                case IndicatorState.CONNECTED_ETHERNET:
                case IndicatorState.CONNECTED_VPN:
                case IndicatorState.CONNECTED_MOBILE:
                    get_style_context().add_class("connected");
                    AccessibilityHelper.set_busy(this, false);
                    break;
                case IndicatorState.ERROR:
                    get_style_context().add_class("error");
                    AccessibilityHelper.set_busy(this, false);
                    break;
                default:
                    AccessibilityHelper.set_busy(this, false);
                    break;
            }
        }
        
        /**
         * Show a notification with the specified message and type
         */
        public void show_notification(string message, NotificationType type) {
            debug("NetworkIndicator: Showing notification: %s (%s)", message, type.to_string());
            
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
                
                debug("NetworkIndicator: Notification hidden");
            }
        }
        
        /**
         * Update tooltip with current connection information
         */
        private void update_tooltip() {
            if (controller == null) return;
            
            var state = controller.current_state;
            if (state == null) return;
            
            var tooltip_text = new StringBuilder();
            
            // Add connectivity status
            tooltip_text.append(controller.nm_client.get_connectivity_description());
            
            // Add primary connection info
            if (state.primary_connection_id != null) {
                tooltip_text.append_printf("\nActive: %s", state.primary_connection_id);
            }
            
            // Add additional status info
            if (!state.networking_enabled) {
                tooltip_text.append("\nNetworking disabled");
            } else if (!state.wireless_enabled && !state.wireless_hardware_enabled) {
                tooltip_text.append("\nWiFi disabled");
            }
            
            indicator_icon.set_tooltip_text(tooltip_text.str);
        }
        
        /**
         * Handle network state changes from controller
         */
        private void on_network_state_changed(NetworkState state) {
            debug("NetworkIndicator: Network state changed");
            
            // Determine indicator state based on network state
            IndicatorState new_indicator_state;
            
            if (!state.networking_enabled) {
                new_indicator_state = IndicatorState.DISABLED;
            } else if (state.connectivity == NM.ConnectivityState.FULL || 
                      state.connectivity == NM.ConnectivityState.LIMITED) {
                
                // Determine connection type based on primary connection
                if (state.primary_connection_type != null) {
                    switch (state.primary_connection_type) {
                        case "802-11-wireless":
                            new_indicator_state = IndicatorState.CONNECTED_WIFI;
                            break;
                        case "802-3-ethernet":
                            new_indicator_state = IndicatorState.CONNECTED_ETHERNET;
                            break;
                        case "vpn":
                            new_indicator_state = IndicatorState.CONNECTED_VPN;
                            break;
                        case "gsm":
                        case "cdma":
                            new_indicator_state = IndicatorState.CONNECTED_MOBILE;
                            break;
                        default:
                            new_indicator_state = IndicatorState.CONNECTED_WIFI; // Default fallback
                            break;
                    }
                } else {
                    new_indicator_state = IndicatorState.CONNECTED_WIFI; // Default when connected
                }
            } else if (state.connectivity == NM.ConnectivityState.PORTAL) {
                new_indicator_state = IndicatorState.CONNECTED_WIFI;
                show_notification("Captive portal detected", NotificationType.WARNING);
            } else {
                new_indicator_state = IndicatorState.DISCONNECTED;
            }
            
            update_indicator_state(new_indicator_state);
            network_changed(state);
        }
        
        /**
         * Handle connection added events
         */
        private void on_connection_added(NetworkConnection connection) {
            debug("NetworkIndicator: Connection added: %s", connection.name);
            show_notification(@"Network '$(connection.name)' added", NotificationType.INFO);
        }
        
        /**
         * Handle connection removed events
         */
        private void on_connection_removed(string connection_id) {
            debug("NetworkIndicator: Connection removed: %s", connection_id);
            show_notification("Network connection removed", NotificationType.INFO);
        }
        
        /**
         * Handle security alerts from controller
         */
        private void on_security_alert(SecurityAlert alert) {
            debug("NetworkIndicator: Security alert: %s", alert.message);
            
            var notification_type = NotificationType.WARNING;
            if (alert.severity == ErrorSeverity.HIGH) {
                notification_type = NotificationType.ERROR;
            }
            
            show_notification(alert.message, notification_type);
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
        public NetworkPopover? get_popover() {
            return popover;
        }
        
        /**
         * Force refresh of the indicator state
         */
        public async void refresh_state() {
            if (controller != null) {
                try {
                    var current_state = controller.current_state;
                    if (current_state != null) {
                        on_network_state_changed(current_state);
                    }
                } catch (Error e) {
                    warning("NetworkIndicator: Failed to refresh state: %s", e.message);
                    update_indicator_state(IndicatorState.ERROR);
                }
            }
        }
        
        /**
         * Cleanup resources when indicator is destroyed
         */
        public override void destroy() {
            debug("NetworkIndicator: Cleaning up resources...");
            
            if (notification_timeout_id > 0) {
                Source.remove(notification_timeout_id);
                notification_timeout_id = 0;
            }
            
            if (popover != null) {
                popover.destroy();
                popover = null;
            }
            
            controller = null;
            
            base.destroy();
        }
    }
}