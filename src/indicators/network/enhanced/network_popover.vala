/**
 * Enhanced Network Indicator - Network Popover Container
 * 
 * This file provides the main popover container with stack-based panel navigation,
 * panel switching, state management, and common UI elements.
 */

using GLib;
using Gtk;
using NM;

namespace EnhancedNetwork {

    /**
     * Main network popover container
     * 
     * This class provides the main popover with stack-based panel navigation,
     * panel switching and state management, and common UI elements.
     */
    public class NetworkPopover : Gtk.Window {
        private NetworkController controller;
        private Gtk.Stack main_stack;
        private Gtk.StackSwitcher stack_switcher;
        private Gtk.HeaderBar header_bar;
        private Gtk.SearchEntry search_entry;
        private Gtk.Button refresh_button;
        private Gtk.Button settings_button;
        
        // Panel instances
        private OverviewPanel overview_panel;
        private WiFiPanel? wifi_panel;
        private EthernetPanel? ethernet_panel;
        private VPNPanel? vpn_panel;
        private MobilePanel? mobile_panel;
        private HotspotPanel? hotspot_panel;
        private MonitorPanel? monitor_panel;
        private SettingsPanel? settings_panel;
        
        // State management
        private PanelType current_panel;
        private bool is_refreshing;
        private string current_search_term;
        
        // Keyboard navigation
        private KeyboardNavigationHelper? keyboard_nav;
        
        /**
         * Signal emitted when a panel is switched
         */
        public signal void panel_switched(PanelType panel_type);
        
        /**
         * Signal emitted when refresh is requested
         */
        public signal void refresh_requested();
        
        /**
         * Signal emitted when search term changes
         */
        public signal void search_changed(string search_term);
        
        public PanelType active_panel { 
            get { return current_panel; } 
        }
        
        public bool refreshing { 
            get { return is_refreshing; } 
        }
        
        public signal void closed();
        
        public NetworkPopover(NetworkController controller) {
            GLib.Object(type: Gtk.WindowType.POPUP);
            Backend.setup_popup(this, 28);
            
            this.controller = controller;
            this.current_panel = PanelType.OVERVIEW;
            this.is_refreshing = false;
            this.current_search_term = "";
            this.keyboard_nav = null;
            
            setup_popover_properties();
            setup_ui();
            setup_panels();
            setup_event_handlers();
            setup_keyboard_navigation();
            
            debug("NetworkPopover: Container initialized");
        }
        
        /**
         * Setup popover properties and styling
         */
        private void setup_popover_properties() {
            set_size_request(400, 500);
            set_keep_above(true);
            set_app_paintable(true);
            
            var screen = get_screen();
            var visual = screen.get_rgba_visual();
            if (visual != null) set_visual(visual);
            
            draw.connect((cr) => {
                int w = get_allocated_width();
                int h = get_allocated_height();
                double r = 12;
                cr.new_sub_path();
                cr.arc(w - r, r, r, -Math.PI/2, 0);
                cr.arc(w - r, h - r, r, 0, Math.PI/2);
                cr.arc(r, h - r, r, Math.PI/2, Math.PI);
                cr.arc(r, r, r, Math.PI, 3*Math.PI/2);
                cr.close_path();
                cr.set_source_rgba(0.24, 0.24, 0.24, 0.95);
                cr.fill_preserve();
                cr.set_source_rgba(1, 1, 1, 0.15);
                cr.set_line_width(1);
                cr.stroke();
                return false;
            });
            
            button_press_event.connect((e) => {
                int w, h;
                get_size(out w, out h);
                if (e.x < 0 || e.y < 0 || e.x > w || e.y > h) {
                    ungrab_input();
                    hide();
                    closed();
                }
                return false;
            });
            
            focus_out_event.connect(() => { ungrab_input(); hide(); closed(); return false; });
            
            get_style_context().add_class("network-popover");
            
            debug("NetworkPopover: Properties setup complete");
        }
        
        private void ungrab_input() {
            var seat = Gdk.Display.get_default().get_default_seat();
            if (seat != null) seat.ungrab();
        }
        
        public void show_at(int x, int y) {
            show_all();
            Backend.position_popup(this, x, y, 28);
            if (Backend.is_x11()) {
                var seat = Gdk.Display.get_default().get_default_seat();
                if (seat != null && get_window() != null) {
                    seat.grab(get_window(), Gdk.SeatCapabilities.ALL, true, null, null, null);
                }
            }
            present();
        }
        
        public void popup() {
            // No-op for compatibility; use show_at() instead
        }
        
        /**
         * Setup the main UI structure
         */
        private void setup_ui() {
            var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            
            // Create header bar with common controls
            setup_header_bar();
            main_box.pack_start(header_bar, false, false, 0);
            
            // Create main stack for panels
            main_stack = new Gtk.Stack();
            main_stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            main_stack.set_transition_duration(200);
            main_stack.set_homogeneous(false);
            
            // Create stack switcher for navigation
            stack_switcher = new Gtk.StackSwitcher();
            stack_switcher.set_stack(main_stack);
            stack_switcher.get_style_context().add_class("panel-switcher");
            
            var switcher_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            switcher_box.set_center_widget(stack_switcher);
            switcher_box.get_style_context().add_class("switcher-container");
            
            main_box.pack_start(switcher_box, false, false, 0);
            main_box.pack_start(main_stack, true, true, 0);
            
            add(main_box);
            
            debug("NetworkPopover: UI structure setup complete");
        }
        
        /**
         * Setup the header bar with common controls
         */
        private void setup_header_bar() {
            header_bar = new Gtk.HeaderBar();
            header_bar.set_show_close_button(false);
            header_bar.set_title("Network");
            header_bar.get_style_context().add_class("popover-header");
            
            // Search entry
            search_entry = new Gtk.SearchEntry();
            search_entry.set_placeholder_text("Search networks...");
            search_entry.set_size_request(200, -1);
            search_entry.get_style_context().add_class("network-search");
            AccessibilityHelper.set_accessible_name(search_entry, "Search all networks");
            AccessibilityHelper.set_accessible_description(search_entry, "Type to filter networks across all panels");
            
            // Refresh button
            refresh_button = new Gtk.Button.from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON);
            refresh_button.set_tooltip_text("Refresh network list");
            refresh_button.get_style_context().add_class("flat");
            AccessibilityHelper.mark_as_button(refresh_button, "Refresh all network lists");
            
            // Settings button
            settings_button = new Gtk.Button.from_icon_name("preferences-system-symbolic", Gtk.IconSize.BUTTON);
            settings_button.set_tooltip_text("Network settings");
            settings_button.get_style_context().add_class("flat");
            AccessibilityHelper.mark_as_button(settings_button, "Open network settings");
            
            // Pack header elements
            header_bar.pack_start(search_entry);
            header_bar.pack_end(settings_button);
            header_bar.pack_end(refresh_button);
            
            debug("NetworkPopover: Header bar setup complete");
        }
        
        /**
         * Setup all panel instances
         */
        private void setup_panels() {
            // Create overview panel (always present)
            overview_panel = new OverviewPanel(controller);
            main_stack.add_titled(overview_panel, "overview", "Overview");
            
            // Create other panels based on available hardware/features
            setup_conditional_panels();
            
            // Set initial panel
            main_stack.set_visible_child(overview_panel);
            current_panel = PanelType.OVERVIEW;
            
            debug("NetworkPopover: Panels setup complete");
        }
        
        /**
         * Setup panels based on available hardware and features
         */
        private void setup_conditional_panels() {
            if (controller.nm_client.is_available) {
                var nm_client = controller.nm_client.nm_client;
                
                // WiFi panel - if WiFi hardware is available
                if (nm_client.wireless_hardware_enabled) {
                    wifi_panel = new WiFiPanel(controller);
                    main_stack.add_titled(wifi_panel, "wifi", "WiFi");
                }
                
                // Ethernet panel - if ethernet devices are available
                var ethernet_devices = controller.nm_client.get_devices_by_type(NM.DeviceType.ETHERNET);
                if (ethernet_devices.length > 0) {
                    ethernet_panel = new EthernetPanel(controller);
                    main_stack.add_titled(ethernet_panel, "ethernet", "Ethernet");
                }
                
                // VPN panel - always available for configuration
                vpn_panel = new VPNPanel(controller);
                main_stack.add_titled(vpn_panel, "vpn", "VPN");
                
                // Mobile panel - if mobile broadband hardware is available
                if (nm_client.wwan_hardware_enabled) {
                    mobile_panel = new MobilePanel(controller);
                    main_stack.add_titled(mobile_panel, "mobile", "Mobile");
                }
                
                // Hotspot panel - if WiFi hardware supports AP mode
                if (nm_client.wireless_hardware_enabled) {
                    hotspot_panel = new HotspotPanel(controller);
                    main_stack.add_titled(hotspot_panel, "hotspot", "Hotspot");
                }
                
                // Monitor panel - always available
                monitor_panel = new MonitorPanel(controller);
                main_stack.add_titled(monitor_panel, "monitor", "Monitor");
                
                // Settings panel - always available
                settings_panel = new SettingsPanel(controller);
                main_stack.add_titled(settings_panel, "settings", "Settings");
            }
        }
        
        /**
         * Setup event handlers for user interactions
         */
        private void setup_event_handlers() {
            // Stack switcher events
            main_stack.notify["visible-child"].connect(on_panel_switched);
            
            // Search entry events
            search_entry.search_changed.connect(on_search_changed);
            search_entry.activate.connect(on_search_activated);
            
            // Button events
            refresh_button.clicked.connect(on_refresh_clicked);
            settings_button.clicked.connect(on_settings_clicked);
            
            // Popover events
            closed.connect(on_popover_closed);
            
            // Controller events
            controller.state_changed.connect(on_controller_state_changed);
            
            // Key press events for navigation
            key_press_event.connect(on_key_press);
            
            debug("NetworkPopover: Event handlers setup complete");
        }
        
        /**
         * Show a specific panel
         */
        public void show_panel(PanelType panel_type) {
            string panel_name;
            
            switch (panel_type) {
                case PanelType.WIFI:
                    panel_name = "wifi";
                    break;
                case PanelType.ETHERNET:
                    panel_name = "ethernet";
                    break;
                case PanelType.VPN:
                    panel_name = "vpn";
                    break;
                case PanelType.MOBILE:
                    panel_name = "mobile";
                    break;
                case PanelType.HOTSPOT:
                    panel_name = "hotspot";
                    break;
                case PanelType.MONITOR:
                    panel_name = "monitor";
                    break;
                case PanelType.SETTINGS:
                    panel_name = "settings";
                    break;
                case PanelType.OVERVIEW:
                default:
                    panel_name = "overview";
                    break;
            }
            
            var child = main_stack.get_child_by_name(panel_name);
            if (child != null) {
                main_stack.set_visible_child(child);
                current_panel = panel_type;
                
                debug("NetworkPopover: Switched to panel: %s", panel_type.to_string());
            } else {
                warning("NetworkPopover: Panel not found: %s", panel_name);
            }
        }
        
        /**
         * Refresh content of all panels
         */
        public void refresh_content() {
            if (is_refreshing) {
                debug("NetworkPopover: Already refreshing, skipping");
                return;
            }
            
            debug("NetworkPopover: Refreshing content...");
            is_refreshing = true;
            
            // Update refresh button state
            refresh_button.sensitive = false;
            refresh_button.set_tooltip_text("Refreshing...");
            
            // Refresh overview panel
            overview_panel.refresh();
            
            // Refresh active panels
            if (wifi_panel != null) wifi_panel.refresh();
            if (ethernet_panel != null) ethernet_panel.refresh();
            if (vpn_panel != null) vpn_panel.refresh();
            if (mobile_panel != null) mobile_panel.refresh();
            if (hotspot_panel != null) hotspot_panel.refresh();
            if (monitor_panel != null) monitor_panel.refresh();
            if (settings_panel != null) settings_panel.refresh();
            
            // Reset refresh state after a delay
            Timeout.add(1000, () => {
                is_refreshing = false;
                refresh_button.sensitive = true;
                refresh_button.set_tooltip_text("Refresh network list");
                return Source.REMOVE;
            });
            
            refresh_requested();
        }
        
        /**
         * Update network list based on search term
         */
        public void update_network_list() {
            // Apply current search filter to all panels
            apply_search_filter(current_search_term);
            
            debug("NetworkPopover: Network list updated");
        }
        
        /**
         * Apply search filter to all panels
         */
        private void apply_search_filter(string search_term) {
            if (wifi_panel != null) wifi_panel.apply_search_filter(search_term);
            if (ethernet_panel != null) ethernet_panel.apply_search_filter(search_term);
            if (vpn_panel != null) vpn_panel.apply_search_filter(search_term);
            if (mobile_panel != null) mobile_panel.apply_search_filter(search_term);
            if (hotspot_panel != null) hotspot_panel.apply_search_filter(search_term);
        }
        
        /**
         * Show connection dialog for a specific network
         */
        public void show_connection_dialog(NetworkConnection connection) {
            debug("NetworkPopover: Showing connection dialog for: %s", connection.name);
            
            var dialog = new ConnectionDialog(connection, this);
            dialog.set_transient_for(this);
            dialog.set_modal(true);
            
            dialog.response.connect((response_id) => {
                if (response_id == Gtk.ResponseType.OK) {
                    // Handle connection attempt
                    handle_connection_request(connection, dialog.get_credentials());
                }
                dialog.destroy();
            });
            
            dialog.show_all();
        }
        
        /**
         * Handle connection request from dialog
         */
        private async void handle_connection_request(NetworkConnection connection, Credentials? credentials) {
            try {
                debug("NetworkPopover: Attempting to connect to: %s", connection.name);
                
                var success = yield controller.connect_to_network(connection.id, credentials);
                if (success) {
                    debug("NetworkPopover: Connection successful");
                } else {
                    warning("NetworkPopover: Connection failed");
                }
                
            } catch (Error e) {
                warning("NetworkPopover: Connection error: %s", e.message);
            }
        }
        
        /**
         * Handle panel switching events
         */
        private void on_panel_switched() {
            var visible_child = main_stack.get_visible_child();
            if (visible_child == null) return;
            
            var child_name = main_stack.get_visible_child_name();
            
            PanelType new_panel;
            switch (child_name) {
                case "wifi":
                    new_panel = PanelType.WIFI;
                    break;
                case "ethernet":
                    new_panel = PanelType.ETHERNET;
                    break;
                case "vpn":
                    new_panel = PanelType.VPN;
                    break;
                case "mobile":
                    new_panel = PanelType.MOBILE;
                    break;
                case "hotspot":
                    new_panel = PanelType.HOTSPOT;
                    break;
                case "monitor":
                    new_panel = PanelType.MONITOR;
                    break;
                case "settings":
                    new_panel = PanelType.SETTINGS;
                    break;
                case "overview":
                default:
                    new_panel = PanelType.OVERVIEW;
                    break;
            }
            
            if (current_panel != new_panel) {
                current_panel = new_panel;
                panel_switched(new_panel);
                
                debug("NetworkPopover: Panel switched to: %s", new_panel.to_string());
            }
        }
        
        /**
         * Handle search term changes
         */
        private void on_search_changed() {
            current_search_term = search_entry.get_text();
            apply_search_filter(current_search_term);
            search_changed(current_search_term);
            
            debug("NetworkPopover: Search term changed: '%s'", current_search_term);
        }
        
        /**
         * Handle search activation (Enter key)
         */
        private void on_search_activated() {
            // Focus first matching result if available
            var visible_child = main_stack.get_visible_child();
            if (visible_child is NetworkPanel) {
                var panel = visible_child as NetworkPanel;
                panel.focus_first_result();
            }
        }
        
        /**
         * Handle refresh button clicks
         */
        private void on_refresh_clicked() {
            refresh_content();
        }
        
        /**
         * Handle settings button clicks
         */
        private void on_settings_clicked() {
            show_panel(PanelType.SETTINGS);
        }
        
        /**
         * Handle popover closed events
         */
        private void on_popover_closed() {
            // Clear search when popover is closed
            search_entry.set_text("");
            current_search_term = "";
            ungrab_input();
            hide();
            
            debug("NetworkPopover: Popover closed");
        }
        
        /**
         * Handle controller state changes
         */
        private void on_controller_state_changed(NetworkState state) {
            // Update panels based on new state
            Idle.add(() => {
                update_network_list();
                return Source.REMOVE;
            });
        }
        
        /**
         * Setup keyboard navigation
         */
        private void setup_keyboard_navigation() {
            // Initialize keyboard navigation helper
            keyboard_nav = new KeyboardNavigationHelper(this);
            
            // Setup focus indicators for all focusable widgets
            setup_focus_indicators();
            
            // Rebuild focus chain when popover is shown
            show.connect(() => {
                if (keyboard_nav != null) {
                    keyboard_nav.build_focus_chain();
                }
            });
            
            debug("NetworkPopover: Keyboard navigation setup complete");
        }
        
        /**
         * Setup focus indicators for visual feedback
         */
        private void setup_focus_indicators() {
            // Add focus indicators to header controls
            new FocusIndicator(search_entry);
            new FocusIndicator(refresh_button);
            new FocusIndicator(settings_button);
            
            // Stack switcher buttons will get focus indicators automatically
            stack_switcher.foreach((widget) => {
                if (widget.can_focus) {
                    new FocusIndicator(widget);
                }
            });
        }
        
        /**
         * Handle key press events for navigation
         */
        private bool on_key_press(Gdk.EventKey event) {
            // Handle Escape key
            if (event.keyval == KeyboardShortcuts.KEY_ESCAPE) {
                if (search_entry.has_focus && search_entry.get_text().length > 0) {
                    search_entry.set_text("");
                    return true;
                } else {
                    ungrab_input();
                    hide();
                    closed();
                    return true;
                }
            }
            
            // Handle F5 for refresh
            if (event.keyval == KeyboardShortcuts.KEY_REFRESH) {
                refresh_content();
                return true;
            }
            
            // Handle Ctrl+F for search focus
            if (KeyboardShortcuts.matches_shortcut(event, KeyboardShortcuts.KEY_SEARCH, Gdk.ModifierType.CONTROL_MASK)) {
                search_entry.grab_focus();
                return true;
            }
            
            // Handle Ctrl+Tab for panel cycling
            if (event.keyval == KeyboardShortcuts.KEY_TAB && 
                (event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                cycle_panels((event.state & Gdk.ModifierType.SHIFT_MASK) != 0);
                return true;
            }
            
            // Handle Alt+1-9 for direct panel access
            if ((event.state & Gdk.ModifierType.MOD1_MASK) != 0) {
                if (event.keyval >= Gdk.Key.@1 && event.keyval <= Gdk.Key.@9) {
                    int panel_index = (int)(event.keyval - Gdk.Key.@1);
                    return switch_to_panel_by_index(panel_index);
                }
            }
            
            // Handle Home/End for focus navigation
            if (event.keyval == KeyboardShortcuts.KEY_HOME) {
                if (keyboard_nav != null) {
                    keyboard_nav.focus_first();
                    return true;
                }
            } else if (event.keyval == KeyboardShortcuts.KEY_END) {
                if (keyboard_nav != null) {
                    keyboard_nav.focus_last();
                    return true;
                }
            }
            
            return false;
        }
        
        /**
         * Switch to panel by index (for Alt+number shortcuts)
         */
        private bool switch_to_panel_by_index(int index) {
            var children = main_stack.get_children();
            if (index >= 0 && index < children.length()) {
                var child = children.nth_data(index);
                if (child != null) {
                    main_stack.set_visible_child(child);
                    return true;
                }
            }
            return false;
        }
        
        /**
         * Cycle through available panels
         */
        private void cycle_panels(bool reverse) {
            var children = main_stack.get_children();
            if (children.length() <= 1) return;
            
            var current_child = main_stack.get_visible_child();
            var current_index = children.index(current_child);
            
            int next_index;
            if (reverse) {
                next_index = (current_index - 1 + (int)children.length()) % (int)children.length();
            } else {
                next_index = (current_index + 1) % (int)children.length();
            }
            
            var next_child = children.nth_data(next_index);
            main_stack.set_visible_child(next_child);
        }
        
        /**
         * Get the currently active panel widget
         */
        public Gtk.Widget? get_active_panel_widget() {
            return main_stack.get_visible_child();
        }
        
        /**
         * Check if a specific panel type is available
         */
        public bool is_panel_available(PanelType panel_type) {
            switch (panel_type) {
                case PanelType.OVERVIEW:
                    return overview_panel != null;
                case PanelType.WIFI:
                    return wifi_panel != null;
                case PanelType.ETHERNET:
                    return ethernet_panel != null;
                case PanelType.VPN:
                    return vpn_panel != null;
                case PanelType.MOBILE:
                    return mobile_panel != null;
                case PanelType.HOTSPOT:
                    return hotspot_panel != null;
                case PanelType.MONITOR:
                    return monitor_panel != null;
                case PanelType.SETTINGS:
                    return settings_panel != null;
                default:
                    return false;
            }
        }
        
        /**
         * Set the search entry visibility
         */
        public void set_search_visible(bool visible) {
            search_entry.visible = visible;
        }
        
        /**
         * Get current search term
         */
        public string get_search_term() {
            return current_search_term;
        }
        
        /**
         * Clear the search term
         */
        public void clear_search() {
            search_entry.set_text("");
            current_search_term = "";
        }
    }
}