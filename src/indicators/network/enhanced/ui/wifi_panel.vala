/**
 * Enhanced Network Indicator - WiFi Panel
 * 
 * This file implements the WiFiPanel component that provides comprehensive
 * WiFi network management including network list display, connection dialogs,
 * and context menus for network operations.
 */

using GLib;
using Gtk;

namespace EnhancedNetwork {

    /**
     * WiFi network list row widget
     */
    private class WiFiNetworkRow : Gtk.ListBoxRow {
        private WiFiNetwork network;
        private Gtk.Box main_box;
        private Gtk.Label name_label;
        private Gtk.Label security_label;
        private Gtk.Image signal_icon;
        private Gtk.Image security_icon;
        private Gtk.Spinner connecting_spinner;
        private Gtk.Button connect_button;
        
        public WiFiNetworkRow(WiFiNetwork network) {
            this.network = network;
            setup_ui();
            update_display();
            
            // Connect to network state changes
            network.state_changed.connect(on_network_state_changed);
            network.signal_strength_changed.connect(on_signal_strength_changed);
        }
        
        private void setup_ui() {
            main_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            main_box.margin = 8;
            add(main_box);
            
            // Signal strength icon
            signal_icon = new Gtk.Image();
            signal_icon.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            main_box.pack_start(signal_icon, false, false, 0);
            
            // Network info box
            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            main_box.pack_start(info_box, true, true, 0);
            
            // Network name
            name_label = new Gtk.Label(network.ssid);
            name_label.halign = Gtk.Align.START;
            name_label.get_style_context().add_class("network-name");
            info_box.pack_start(name_label, false, false, 0);
            
            // Security info
            security_label = new Gtk.Label("");
            security_label.halign = Gtk.Align.START;
            security_label.get_style_context().add_class("dim-label");
            security_label.get_style_context().add_class("caption");
            info_box.pack_start(security_label, false, false, 0);
            
            // Security icon
            security_icon = new Gtk.Image();
            security_icon.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            main_box.pack_start(security_icon, false, false, 0);
            
            // Connecting spinner
            connecting_spinner = new Gtk.Spinner();
            connecting_spinner.no_show_all = true;
            main_box.pack_start(connecting_spinner, false, false, 0);
            
            // Connect button (for disconnected networks)
            connect_button = new Gtk.Button.with_label("Connect");
            connect_button.get_style_context().add_class("suggested-action");
            connect_button.no_show_all = true;
            connect_button.clicked.connect(on_connect_clicked);
            main_box.pack_start(connect_button, false, false, 0);
            
            // Setup accessibility
            setup_row_accessibility();
            
            show_all();
        }
        
        /**
         * Setup accessibility for network row
         */
        private void setup_row_accessibility() {
            // Set accessible name and description
            var accessible_text = AccessibleErrorFormatter.format_network_status(network);
            AccessibilityHelper.set_accessible_name(this, accessible_text);
            AccessibilityHelper.mark_as_list_item(this, accessible_text);
            
            // Make row activatable
            can_focus = true;
            activatable = true;
            
            // Add focus indicator
            new FocusIndicator(this);
        }
        
        private void update_display() {
            // Update network name
            name_label.set_text(network.ssid);
            
            // Update signal strength icon
            signal_icon.set_from_icon_name(network.get_signal_icon_name(), Gtk.IconSize.SMALL_TOOLBAR);
            
            // Update security info
            var security_text = network.get_security_description();
            if (network.signal_strength > 0) {
                security_text += " • " + network.get_signal_strength_description();
            }
            security_label.set_text(security_text);
            
            // Update security icon
            string security_icon_name = "network-wireless-no-route-symbolic";
            switch (network.security_level) {
                case SecurityLevel.SECURE:
                    security_icon_name = "security-high-symbolic";
                    break;
                case SecurityLevel.WARNING:
                    security_icon_name = "security-medium-symbolic";
                    break;
                case SecurityLevel.INSECURE:
                    security_icon_name = "security-low-symbolic";
                    break;
            }
            security_icon.set_from_icon_name(security_icon_name, Gtk.IconSize.SMALL_TOOLBAR);
            
            // Update state-dependent UI
            update_state_ui();
            
            // Update accessible description
            var accessible_text = AccessibleErrorFormatter.format_network_status(network);
            AccessibilityHelper.set_accessible_name(this, accessible_text);
        }
        
        private void update_state_ui() {
            // Hide all state-dependent widgets first
            connecting_spinner.hide();
            connect_button.hide();
            
            // Show appropriate widgets based on state
            switch (network.state) {
                case ConnectionState.CONNECTED:
                    name_label.get_style_context().add_class("connected-network");
                    break;
                    
                case ConnectionState.CONNECTING:
                    connecting_spinner.show();
                    connecting_spinner.start();
                    break;
                    
                case ConnectionState.DISCONNECTED:
                case ConnectionState.FAILED:
                    name_label.get_style_context().remove_class("connected-network");
                    if (can_show_connect_button()) {
                        connect_button.show();
                    }
                    break;
                    
                case ConnectionState.DISCONNECTING:
                    connecting_spinner.show();
                    connecting_spinner.start();
                    break;
            }
        }
        
        private bool can_show_connect_button() {
            // Show connect button for known networks or open networks
            return !network.requires_authentication() || network.auto_connect;
        }
        
        private void on_network_state_changed(ConnectionState state) {
            update_state_ui();
        }
        
        private void on_signal_strength_changed(uint8 old_strength, uint8 new_strength) {
            update_display();
        }
        
        private void on_connect_clicked() {
            network_selected(network);
        }
        
        public WiFiNetwork get_network() {
            return network;
        }
        
        public signal void network_selected(WiFiNetwork network);
    }

    /**
     * WiFi management panel
     */
    public class WiFiPanel : NetworkPanel {
        private Gtk.ListBox network_list;
        private Gtk.SearchEntry search_entry;
        private Gtk.Button refresh_button;
        private Gtk.Button hidden_network_button;
        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Box header_box;
        private Gtk.Box empty_state_box;
        private Gtk.Label status_label;
        
        private GenericArray<WiFiNetwork> current_networks;
        private string current_search_term = "";
        
        // Keyboard navigation
        private ListNavigationHelper? list_nav;
        
        /**
         * Signal emitted when a network is selected for connection
         */
        public signal void network_selected(WiFiNetwork network);
        
        /**
         * Signal emitted when hidden network connection is requested
         */
        public signal void hidden_network_requested();
        
        public WiFiPanel(NetworkController controller) {
            base(controller, "wifi");
            current_networks = new GenericArray<WiFiNetwork>();
            list_nav = null;
            
            setup_ui();
            setup_controller_signals();
            setup_keyboard_navigation();
            
            // Initial refresh
            refresh();
        }
        
        private void setup_keyboard_navigation() {
            // Setup list navigation helper
            list_nav = new ListNavigationHelper(network_list);
            
            // Add focus indicators to controls
            new FocusIndicator(search_entry);
            new FocusIndicator(refresh_button);
            new FocusIndicator(hidden_network_button);
            
            // Make list focusable
            network_list.can_focus = true;
            network_list.focus_on_click = true;
            
            debug("WiFiPanel: Keyboard navigation setup complete");
        }
        
        private void setup_ui() {
            // Header with search and controls
            header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            header_box.margin_bottom = 8;
            pack_start(header_box, false, false, 0);
            
            // Search entry
            search_entry = new Gtk.SearchEntry();
            search_entry.placeholder_text = "Search networks...";
            search_entry.search_changed.connect(on_search_changed);
            AccessibilityHelper.set_accessible_name(search_entry, "Search WiFi networks");
            AccessibilityHelper.set_accessible_description(search_entry, "Type to filter network list");
            header_box.pack_start(search_entry, true, true, 0);
            
            // Refresh button
            refresh_button = new Gtk.Button.from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON);
            refresh_button.tooltip_text = "Refresh networks";
            refresh_button.clicked.connect(on_refresh_clicked);
            AccessibilityHelper.mark_as_button(refresh_button, "Refresh network list");
            header_box.pack_start(refresh_button, false, false, 0);
            
            // Hidden network button
            hidden_network_button = new Gtk.Button.with_label("Hidden Network");
            hidden_network_button.tooltip_text = "Connect to hidden network";
            hidden_network_button.clicked.connect(on_hidden_network_clicked);
            AccessibilityHelper.mark_as_button(hidden_network_button, "Connect to hidden network");
            header_box.pack_start(hidden_network_button, false, false, 0);
            
            // Status label
            status_label = new Gtk.Label("");
            status_label.get_style_context().add_class("dim-label");
            status_label.halign = Gtk.Align.START;
            AccessibilityHelper.set_accessible_role(status_label, Atk.Role.LABEL);
            pack_start(status_label, false, false, 0);
            
            // Scrolled window for network list
            scrolled_window = new Gtk.ScrolledWindow(null, null);
            scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_min_content_height(200);
            pack_start(scrolled_window, true, true, 0);
            
            // Network list
            network_list = new Gtk.ListBox();
            network_list.selection_mode = Gtk.SelectionMode.NONE;
            network_list.activate_on_single_click = true;
            network_list.row_activated.connect(on_network_row_activated);
            network_list.button_press_event.connect(on_network_list_button_press);
            AccessibilityHelper.mark_as_list(network_list, "Available WiFi networks");
            scrolled_window.add(network_list);
            
            // Empty state
            empty_state_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            empty_state_box.valign = Gtk.Align.CENTER;
            empty_state_box.margin = 24;
            
            var empty_icon = new Gtk.Image.from_icon_name("network-wireless-symbolic", Gtk.IconSize.DIALOG);
            empty_icon.get_style_context().add_class("dim-label");
            empty_state_box.pack_start(empty_icon, false, false, 0);
            
            var empty_label = new Gtk.Label("No WiFi networks found");
            empty_label.get_style_context().add_class("dim-label");
            empty_state_box.pack_start(empty_label, false, false, 0);
            
            var empty_sublabel = new Gtk.Label("Try refreshing or check if WiFi is enabled");
            empty_sublabel.get_style_context().add_class("dim-label");
            empty_sublabel.get_style_context().add_class("caption");
            empty_state_box.pack_start(empty_sublabel, false, false, 0);
            
            empty_state_box.show_all();
            empty_state_box.no_show_all = true;
            pack_start(empty_state_box, true, true, 0);
            
            show_all();
        }
        
        private void setup_controller_signals() {
            // Connect to WiFi manager signals through controller
            controller.wifi_manager.networks_updated.connect(on_networks_updated);
            controller.wifi_manager.scan_started.connect(on_scan_started);
            controller.wifi_manager.scan_completed.connect(on_scan_completed);
            controller.wifi_manager.connection_state_changed.connect(on_connection_state_changed);
        }
        
        public override void refresh() {
            set_refreshing(true);
            refresh_button.sensitive = false;
            status_label.set_text("Scanning for networks...");
            
            controller.wifi_manager.start_scan.begin((obj, res) => {
                try {
                    var result = controller.wifi_manager.start_scan.end(res);
                    if (!result.scan_successful && result.error_message != null) {
                        status_label.set_text("Scan failed: " + result.error_message);
                    }
                } catch (Error e) {
                    status_label.set_text("Scan error: " + e.message);
                }
            });
        }
        
        public override void apply_search_filter(string search_term) {
            current_search_term = search_term.down();
            update_network_list_filter();
        }
        
        public override void focus_first_result() {
            var first_row = network_list.get_row_at_index(0);
            if (first_row != null) {
                first_row.grab_focus();
            }
        }
        
        /**
         * Update network list with current networks
         */
        public void update_network_list(GenericArray<WiFiNetwork> networks) {
            current_networks = networks;
            rebuild_network_list();
        }
        
        private void rebuild_network_list() {
            // Clear existing rows
            network_list.foreach((widget) => {
                network_list.remove(widget);
            });
            
            // Sort networks by signal strength and connection status
            var sorted_networks = new GenericArray<WiFiNetwork>();
            
            // Add connected networks first
            for (uint i = 0; i < current_networks.length; i++) {
                var network = current_networks[i];
                if (network.state == ConnectionState.CONNECTED) {
                    sorted_networks.add(network);
                }
            }
            
            // Add other networks sorted by signal strength
            var other_networks = new GenericArray<WiFiNetwork>();
            for (uint i = 0; i < current_networks.length; i++) {
                var network = current_networks[i];
                if (network.state != ConnectionState.CONNECTED) {
                    other_networks.add(network);
                }
            }
            
            // Simple bubble sort by signal strength (descending)
            for (uint i = 0; i < other_networks.length; i++) {
                for (uint j = 0; j < other_networks.length - 1 - i; j++) {
                    if (other_networks[j].signal_strength < other_networks[j + 1].signal_strength) {
                        var temp = other_networks[j];
                        other_networks[j] = other_networks[j + 1];
                        other_networks[j + 1] = temp;
                    }
                }
            }
            
            // Add sorted other networks
            for (uint i = 0; i < other_networks.length; i++) {
                sorted_networks.add(other_networks[i]);
            }
            
            // Create rows for filtered networks
            uint visible_count = 0;
            for (uint i = 0; i < sorted_networks.length; i++) {
                var network = sorted_networks[i];
                if (matches_search_filter(network)) {
                    var row = new WiFiNetworkRow(network);
                    row.network_selected.connect(on_network_selected);
                    network_list.add(row);
                    visible_count++;
                }
            }
            
            // Show/hide empty state
            if (visible_count == 0) {
                scrolled_window.hide();
                empty_state_box.show();
                if (current_search_term.length > 0) {
                    status_label.set_text(@"No networks match \"$(current_search_term ?? "")\"");
                } else {
                    status_label.set_text("No networks found");
                }
            } else {
                empty_state_box.hide();
                scrolled_window.show();
                status_label.set_text(@"Found $(visible_count) network$(visible_count == 1 ? "" : "s")");
            }
            
            network_list.show_all();
            
            // Update list navigation helper
            if (list_nav != null) {
                list_nav.update_visible_rows();
            }
        }
        
        private bool matches_search_filter(WiFiNetwork network) {
            if (current_search_term.length == 0) {
                return true;
            }
            
            return (network.ssid != null && network.ssid.down().contains(current_search_term)) ||
                   network.get_security_description().down().contains(current_search_term);
        }
        
        private void update_network_list_filter() {
            rebuild_network_list();
        }
        
        /**
         * Show password dialog for network connection
         */
        public void show_password_dialog(WiFiNetwork network) {
            var dialog = new ConnectionDialog(network, this);
            var response = dialog.run();
            
            if (response == Gtk.ResponseType.OK) {
                var credentials = dialog.get_credentials();
                if (credentials != null && credentials.password.length > 0) {
                    connect_to_network_with_password(network, credentials.password);
                }
            }
            
            dialog.destroy();
        }
        
        /**
         * Show connection progress for a network
         */
        public void show_connection_progress(WiFiNetwork network) {
            // The network row will automatically show spinner when state changes
            status_label.set_text(@"Connecting to $(network.ssid ?? "network")...");
        }
        
        private void connect_to_network_with_password(WiFiNetwork network, string password) {
            show_connection_progress(network);
            
            controller.wifi_manager.connect_to_network.begin(network, password, (obj, res) => {
                try {
                    var success = controller.wifi_manager.connect_to_network.end(res);
                    if (success) {
                        status_label.set_text(@"Connected to $(network.ssid ?? "network")");
                    } else {
                        status_label.set_text(@"Failed to connect to $(network.ssid ?? "network")");
                    }
                } catch (Error e) {
                    status_label.set_text(@"Connection error: $(e.message ?? "Unknown error")");
                }
            });
        }
        
        private void show_network_context_menu(WiFiNetwork network, Gdk.EventButton event) {
            var menu = new Gtk.Menu();
            
            if (network.state == ConnectionState.CONNECTED) {
                var disconnect_item = new Gtk.MenuItem.with_label("Disconnect");
                disconnect_item.activate.connect(() => {
                    disconnect_from_network(network);
                });
                menu.append(disconnect_item);
            } else {
                var connect_item = new Gtk.MenuItem.with_label("Connect");
                connect_item.activate.connect(() => {
                    on_network_selected(network);
                });
                menu.append(connect_item);
            }
            
            if (network.auto_connect) {
                var forget_item = new Gtk.MenuItem.with_label("Forget Network");
                forget_item.activate.connect(() => {
                    forget_network(network);
                });
                menu.append(forget_item);
            }
            
            var properties_item = new Gtk.MenuItem.with_label("Properties");
            properties_item.activate.connect(() => {
                show_network_properties(network);
            });
            menu.append(properties_item);
            
            menu.show_all();
            menu.popup_at_pointer(event);
        }
        
        private void disconnect_from_network(WiFiNetwork network) {
            status_label.set_text(@"Disconnecting from $(network.ssid ?? "network")...");
            
            controller.wifi_manager.disconnect_from_network.begin(network, (obj, res) => {
                try {
                    var success = controller.wifi_manager.disconnect_from_network.end(res);
                    if (success) {
                        status_label.set_text(@"Disconnected from $(network.ssid ?? "network")");
                    } else {
                        status_label.set_text(@"Failed to disconnect from $(network.ssid ?? "network")");
                    }
                } catch (Error e) {
                    status_label.set_text(@"Disconnection error: $(e.message ?? "Unknown error")");
                }
            });
        }
        
        private void forget_network(WiFiNetwork network) {
            var dialog = new Gtk.MessageDialog(
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.YES_NO,
                @"Forget network \"$(network.ssid ?? "Unknown")\"?"
            );
            dialog.secondary_text = "This will remove the saved password and settings for this network.";
            
            var response = dialog.run();
            dialog.destroy();
            
            if (response == Gtk.ResponseType.YES) {
                controller.wifi_manager.forget_network.begin(network, (obj, res) => {
                    try {
                        var success = controller.wifi_manager.forget_network.end(res);
                        if (success) {
                            status_label.set_text(@"Forgot network $(network.ssid)");
                        } else {
                            status_label.set_text(@"Failed to forget network $(network.ssid)");
                        }
                    } catch (Error e) {
                        status_label.set_text(@"Error forgetting network: $(e.message)");
                    }
                });
            }
        }
        
        private void show_network_properties(WiFiNetwork network) {
            var dialog = new Gtk.Dialog.with_buttons(
                @"Properties - $(network.ssid)",
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                "Close", Gtk.ResponseType.CLOSE
            );
            
            var content = dialog.get_content_area();
            content.margin = 12;
            content.spacing = 8;
            
            var grid = new Gtk.Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 6;
            content.pack_start(grid, true, true, 0);
            
            int row = 0;
            
            // Network name
            grid.attach(new Gtk.Label("Network:"), 0, row, 1, 1);
            var name_label = new Gtk.Label(network.ssid);
            name_label.halign = Gtk.Align.START;
            grid.attach(name_label, 1, row++, 1, 1);
            
            // Security
            grid.attach(new Gtk.Label("Security:"), 0, row, 1, 1);
            var security_label = new Gtk.Label(network.get_security_description());
            security_label.halign = Gtk.Align.START;
            grid.attach(security_label, 1, row++, 1, 1);
            
            // Signal strength
            grid.attach(new Gtk.Label("Signal:"), 0, row, 1, 1);
            var signal_label = new Gtk.Label(@"$(network.signal_strength)% ($(network.get_signal_strength_description()))");
            signal_label.halign = Gtk.Align.START;
            grid.attach(signal_label, 1, row++, 1, 1);
            
            // Frequency
            if (network.frequency > 0) {
                grid.attach(new Gtk.Label("Frequency:"), 0, row, 1, 1);
                var freq_label = new Gtk.Label(@"$(network.frequency) MHz");
                freq_label.halign = Gtk.Align.START;
                grid.attach(freq_label, 1, row++, 1, 1);
            }
            
            // BSSID
            if (network.bssid.length > 0) {
                grid.attach(new Gtk.Label("BSSID:"), 0, row, 1, 1);
                var bssid_label = new Gtk.Label(network.bssid);
                bssid_label.halign = Gtk.Align.START;
                bssid_label.selectable = true;
                grid.attach(bssid_label, 1, row++, 1, 1);
            }
            
            dialog.show_all();
            dialog.run();
            dialog.destroy();
        }
        
        // Signal handlers
        private void on_search_changed() {
            apply_search_filter(search_entry.get_text());
        }
        
        private void on_refresh_clicked() {
            refresh();
        }
        
        private void on_hidden_network_clicked() {
            hidden_network_requested();
        }
        
        private void on_network_row_activated(Gtk.ListBoxRow row) {
            var wifi_row = row as WiFiNetworkRow;
            if (wifi_row != null) {
                on_network_selected(wifi_row.get_network());
            }
        }
        
        private bool on_network_list_button_press(Gdk.EventButton event) {
            if (event.button == 3) { // Right click
                var row = network_list.get_row_at_y((int)event.y);
                if (row != null) {
                    var wifi_row = row as WiFiNetworkRow;
                    if (wifi_row != null) {
                        show_network_context_menu(wifi_row.get_network(), event);
                        return true;
                    }
                }
            }
            return false;
        }
        
        private void on_network_selected(WiFiNetwork network) {
            if (network.requires_authentication() && !network.auto_connect) {
                show_password_dialog(network);
            } else {
                connect_to_network_with_password(network, "");
            }
        }
        
        private void on_networks_updated(GenericArray<WiFiNetwork> networks) {
            update_network_list(networks);
        }
        
        private void on_scan_started() {
            set_refreshing(true);
            refresh_button.sensitive = false;
            status_label.set_text("Scanning...");
        }
        
        private void on_scan_completed(WiFiScanResult result) {
            set_refreshing(false);
            refresh_button.sensitive = true;
            
            if (result.scan_successful) {
                var count = result.networks.length;
                status_label.set_text(@"Found $(count) network$(count == 1 ? "" : "s")");
            } else {
                status_label.set_text("Scan failed: " + (result.error_message ?? "Unknown error"));
            }
        }
        
        private void on_connection_state_changed(WiFiNetwork network, ConnectionState state) {
            // Network rows will update themselves, but we can update status
            switch (state) {
                case ConnectionState.CONNECTING:
                    status_label.set_text(@"Connecting to $(network.ssid)...");
                    break;
                case ConnectionState.CONNECTED:
                    status_label.set_text(@"Connected to $(network.ssid)");
                    break;
                case ConnectionState.DISCONNECTING:
                    status_label.set_text(@"Disconnecting from $(network.ssid)...");
                    break;
                case ConnectionState.DISCONNECTED:
                    status_label.set_text(@"Disconnected from $(network.ssid)");
                    break;
                case ConnectionState.FAILED:
                    status_label.set_text(@"Failed to connect to $(network.ssid)");
                    break;
            }
        }
    }
}