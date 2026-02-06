/**
 * Enhanced Network Indicator - Overview Panel
 * 
 * This file provides the overview panel showing current network status
 * and quick access to common network operations.
 */

using GLib;
using Gtk;

namespace EnhancedNetwork {

    /**
     * Overview panel showing network status and quick actions
     */
    public class OverviewPanel : NetworkPanel {
        private Gtk.Label status_label;
        private Gtk.Label connection_label;
        private Gtk.Box quick_actions_box;
        private Gtk.Button wifi_toggle_button;
        private Gtk.Button ethernet_button;
        private Gtk.Button vpn_button;
        
        public OverviewPanel(NetworkController controller) {
            base(controller, "overview");
            
            setup_ui();
            setup_event_handlers();
            refresh();
        }
        
        /**
         * Setup the overview panel UI
         */
        private void setup_ui() {
            // Status section
            var status_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            status_box.get_style_context().add_class("status-section");
            
            status_label = new Gtk.Label("Checking network status...");
            status_label.get_style_context().add_class("status-label");
            status_label.halign = Gtk.Align.START;
            
            connection_label = new Gtk.Label("");
            connection_label.get_style_context().add_class("connection-label");
            connection_label.halign = Gtk.Align.START;
            connection_label.wrap = true;
            
            status_box.pack_start(status_label, false, false, 0);
            status_box.pack_start(connection_label, false, false, 0);
            
            pack_start(status_box, false, false, 0);
            
            // Separator
            pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 8);
            
            // Quick actions section
            var actions_label = new Gtk.Label("Quick Actions");
            actions_label.get_style_context().add_class("section-title");
            actions_label.halign = Gtk.Align.START;
            pack_start(actions_label, false, false, 0);
            
            quick_actions_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            quick_actions_box.get_style_context().add_class("quick-actions");
            
            // WiFi toggle
            wifi_toggle_button = new Gtk.Button();
            wifi_toggle_button.get_style_context().add_class("flat");
            wifi_toggle_button.get_style_context().add_class("action-button");
            
            // Ethernet status
            ethernet_button = new Gtk.Button();
            ethernet_button.get_style_context().add_class("flat");
            ethernet_button.get_style_context().add_class("action-button");
            
            // VPN status
            vpn_button = new Gtk.Button();
            vpn_button.get_style_context().add_class("flat");
            vpn_button.get_style_context().add_class("action-button");
            
            quick_actions_box.pack_start(wifi_toggle_button, false, false, 0);
            quick_actions_box.pack_start(ethernet_button, false, false, 0);
            quick_actions_box.pack_start(vpn_button, false, false, 0);
            
            pack_start(quick_actions_box, false, false, 0);
        }
        
        /**
         * Setup event handlers
         */
        private void setup_event_handlers() {
            controller.state_changed.connect(on_network_state_changed);
            
            wifi_toggle_button.clicked.connect(on_wifi_toggle_clicked);
            ethernet_button.clicked.connect(on_ethernet_clicked);
            vpn_button.clicked.connect(on_vpn_clicked);
        }
        
        /**
         * Refresh panel content
         */
        public override void refresh() {
            set_refreshing(true);
            
            update_status_display();
            update_quick_actions();
            
            Timeout.add(500, () => {
                set_refreshing(false);
                return Source.REMOVE;
            });
        }
        
        /**
         * Apply search filter (not applicable for overview)
         */
        public override void apply_search_filter(string search_term) {
            // Overview panel doesn't have searchable content
        }
        
        /**
         * Focus first result (not applicable for overview)
         */
        public override void focus_first_result() {
            // Focus first action button
            wifi_toggle_button.grab_focus();
        }
        
        /**
         * Update status display
         */
        private void update_status_display() {
            if (!controller.nm_client.is_available) {
                status_label.set_text("NetworkManager not available");
                connection_label.set_text("Network management is not available");
                return;
            }
            
            var state = controller.current_state;
            if (state == null) {
                status_label.set_text("Unknown network status");
                connection_label.set_text("");
                return;
            }
            
            // Update main status
            status_label.set_text(controller.nm_client.get_connectivity_description());
            
            // Update connection details
            if (state.primary_connection_id != null) {
                connection_label.set_text(@"Connected to: $(state.primary_connection_id)");
            } else if (!state.networking_enabled) {
                connection_label.set_text("Networking is disabled");
            } else {
                connection_label.set_text("No active connections");
            }
        }
        
        /**
         * Update quick actions buttons
         */
        private void update_quick_actions() {
            if (!controller.nm_client.is_available) {
                wifi_toggle_button.sensitive = false;
                ethernet_button.sensitive = false;
                vpn_button.sensitive = false;
                return;
            }
            
            var state = controller.current_state;
            if (state == null) return;
            
            // Update WiFi button
            update_wifi_button(state);
            update_ethernet_button(state);
            update_vpn_button(state);
        }
        
        /**
         * Update WiFi toggle button
         */
        private void update_wifi_button(NetworkState state) {
            var wifi_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            var wifi_icon = new Gtk.Image();
            var wifi_label = new Gtk.Label("");
            var wifi_switch = new Gtk.Switch();
            
            if (state.wireless_hardware_enabled) {
                wifi_icon.set_from_icon_name("network-wireless-symbolic", Gtk.IconSize.MENU);
                wifi_switch.active = state.wireless_enabled;
                wifi_switch.sensitive = true;
                
                if (state.wireless_enabled) {
                    wifi_label.set_text("WiFi Enabled");
                } else {
                    wifi_label.set_text("WiFi Disabled");
                }
            } else {
                wifi_icon.set_from_icon_name("network-wireless-disabled-symbolic", Gtk.IconSize.MENU);
                wifi_label.set_text("WiFi Hardware Unavailable");
                wifi_switch.active = false;
                wifi_switch.sensitive = false;
            }
            
            wifi_label.halign = Gtk.Align.START;
            wifi_label.hexpand = true;
            
            wifi_box.pack_start(wifi_icon, false, false, 0);
            wifi_box.pack_start(wifi_label, true, true, 0);
            wifi_box.pack_end(wifi_switch, false, false, 0);
            
            // Clear and update button content
            var child = wifi_toggle_button.get_child();
            if (child != null) {
                wifi_toggle_button.remove(child);
            }
            wifi_toggle_button.add(wifi_box);
            wifi_toggle_button.show_all();
            
            // Connect switch signal
            wifi_switch.notify["active"].connect(() => {
                controller.nm_client.set_wireless_enabled(wifi_switch.active);
            });
        }
        
        /**
         * Update ethernet button
         */
        private void update_ethernet_button(NetworkState state) {
            var ethernet_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            var ethernet_icon = new Gtk.Image();
            var ethernet_label = new Gtk.Label("");
            
            // Check for ethernet devices
            var ethernet_devices = controller.nm_client.get_devices_by_type(NM.DeviceType.ETHERNET);
            
            if (ethernet_devices.length > 0) {
                var device = ethernet_devices[0];
                var device_state = device.get_state();
                
                if (device_state == NM.DeviceState.ACTIVATED) {
                    ethernet_icon.set_from_icon_name("network-wired-symbolic", Gtk.IconSize.MENU);
                    ethernet_label.set_text("Ethernet Connected");
                } else if (device_state == NM.DeviceState.UNAVAILABLE) {
                    ethernet_icon.set_from_icon_name("network-wired-disconnected-symbolic", Gtk.IconSize.MENU);
                    ethernet_label.set_text("Ethernet Cable Unplugged");
                } else {
                    ethernet_icon.set_from_icon_name("network-wired-symbolic", Gtk.IconSize.MENU);
                    ethernet_label.set_text("Ethernet Available");
                }
            } else {
                ethernet_icon.set_from_icon_name("network-wired-unavailable-symbolic", Gtk.IconSize.MENU);
                ethernet_label.set_text("No Ethernet Device");
            }
            
            ethernet_label.halign = Gtk.Align.START;
            ethernet_label.hexpand = true;
            
            ethernet_box.pack_start(ethernet_icon, false, false, 0);
            ethernet_box.pack_start(ethernet_label, true, true, 0);
            
            // Clear and update button content
            var child = ethernet_button.get_child();
            if (child != null) {
                ethernet_button.remove(child);
            }
            ethernet_button.add(ethernet_box);
            ethernet_button.show_all();
        }
        
        /**
         * Update VPN button
         */
        private void update_vpn_button(NetworkState state) {
            var vpn_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            var vpn_icon = new Gtk.Image();
            var vpn_label = new Gtk.Label("");
            
            // Check for active VPN connections
            var active_connections = controller.nm_client.get_active_connections();
            bool vpn_active = false;
            
            for (uint i = 0; i < active_connections.length; i++) {
                var connection = active_connections[i];
                if (connection.get_connection_type() == "vpn") {
                    vpn_active = true;
                    break;
                }
            }
            
            if (vpn_active) {
                vpn_icon.set_from_icon_name("network-vpn-symbolic", Gtk.IconSize.MENU);
                vpn_label.set_text("VPN Connected");
            } else {
                vpn_icon.set_from_icon_name("network-vpn-disconnected-symbolic", Gtk.IconSize.MENU);
                vpn_label.set_text("VPN Disconnected");
            }
            
            vpn_label.halign = Gtk.Align.START;
            vpn_label.hexpand = true;
            
            vpn_box.pack_start(vpn_icon, false, false, 0);
            vpn_box.pack_start(vpn_label, true, true, 0);
            
            // Clear and update button content
            var child = vpn_button.get_child();
            if (child != null) {
                vpn_button.remove(child);
            }
            vpn_button.add(vpn_box);
            vpn_button.show_all();
        }
        
        /**
         * Handle network state changes
         */
        private void on_network_state_changed(NetworkState state) {
            Idle.add(() => {
                update_status_display();
                update_quick_actions();
                return Source.REMOVE;
            });
        }
        
        /**
         * Handle WiFi toggle button clicks
         */
        private void on_wifi_toggle_clicked() {
            // WiFi toggle is handled by the switch widget
        }
        
        /**
         * Handle ethernet button clicks
         */
        private void on_ethernet_clicked() {
            // Switch to ethernet panel or show ethernet settings
            var popover = get_ancestor(typeof(NetworkPopover)) as NetworkPopover;
            if (popover != null && popover.is_panel_available(PanelType.ETHERNET)) {
                popover.show_panel(PanelType.ETHERNET);
            }
        }
        
        /**
         * Handle VPN button clicks
         */
        private void on_vpn_clicked() {
            // Switch to VPN panel
            var popover = get_ancestor(typeof(NetworkPopover)) as NetworkPopover;
            if (popover != null && popover.is_panel_available(PanelType.VPN)) {
                popover.show_panel(PanelType.VPN);
            }
        }
    }
}