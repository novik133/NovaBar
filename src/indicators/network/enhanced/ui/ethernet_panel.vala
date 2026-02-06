/**
 * Enhanced Network Indicator - Ethernet Panel
 * 
 * This file implements the EthernetPanel component that provides comprehensive
 * ethernet connection management including status display, static IP configuration,
 * and connection diagnostics.
 */

using GLib;
using Gtk;

namespace EnhancedNetwork {

    /**
     * Static IP configuration dialog
     */
    private class StaticIPDialog : Gtk.Dialog {
        private EthernetConfiguration config;
        private Gtk.Entry ip_entry;
        private Gtk.Entry subnet_entry;
        private Gtk.Entry gateway_entry;
        private Gtk.Entry dns1_entry;
        private Gtk.Entry dns2_entry;
        private Gtk.Entry mtu_entry;
        private Gtk.Switch dhcp_switch;
        private Gtk.Grid config_grid;
        
        public StaticIPDialog(EthernetConfiguration current_config, Gtk.Widget parent) {
            Object(title: "Ethernet Configuration", 
                   transient_for: parent.get_toplevel() as Gtk.Window,
                   modal: true);
            
            this.config = new EthernetConfiguration();
            copy_configuration(current_config, this.config);
            
            setup_ui();
            load_configuration();
        }
        
        private void setup_ui() {
            var content_area = get_content_area();
            content_area.margin = 12;
            content_area.spacing = 12;
            
            // DHCP/Static switch
            var dhcp_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var dhcp_label = new Gtk.Label("Use DHCP:");
            dhcp_label.halign = Gtk.Align.START;
            dhcp_switch = new Gtk.Switch();
            dhcp_switch.notify["active"].connect(on_dhcp_toggled);
            dhcp_box.pack_start(dhcp_label, false, false, 0);
            dhcp_box.pack_end(dhcp_switch, false, false, 0);
            content_area.pack_start(dhcp_box, false, false, 0);
            
            // Static IP configuration grid
            config_grid = new Gtk.Grid();
            config_grid.column_spacing = 12;
            config_grid.row_spacing = 8;
            config_grid.margin_top = 8;
            content_area.pack_start(config_grid, false, false, 0);
            
            int row = 0;
            
            // IP Address
            config_grid.attach(new Gtk.Label("IP Address:"), 0, row, 1, 1);
            ip_entry = new Gtk.Entry();
            ip_entry.placeholder_text = "192.168.1.100";
            config_grid.attach(ip_entry, 1, row++, 1, 1);
            
            // Subnet Mask
            config_grid.attach(new Gtk.Label("Subnet Mask:"), 0, row, 1, 1);
            subnet_entry = new Gtk.Entry();
            subnet_entry.placeholder_text = "255.255.255.0";
            config_grid.attach(subnet_entry, 1, row++, 1, 1);
            
            // Gateway
            config_grid.attach(new Gtk.Label("Gateway:"), 0, row, 1, 1);
            gateway_entry = new Gtk.Entry();
            gateway_entry.placeholder_text = "192.168.1.1";
            config_grid.attach(gateway_entry, 1, row++, 1, 1);
            
            // Primary DNS
            config_grid.attach(new Gtk.Label("Primary DNS:"), 0, row, 1, 1);
            dns1_entry = new Gtk.Entry();
            dns1_entry.placeholder_text = "8.8.8.8";
            config_grid.attach(dns1_entry, 1, row++, 1, 1);
            
            // Secondary DNS
            config_grid.attach(new Gtk.Label("Secondary DNS:"), 0, row, 1, 1);
            dns2_entry = new Gtk.Entry();
            dns2_entry.placeholder_text = "8.8.4.4";
            config_grid.attach(dns2_entry, 1, row++, 1, 1);
            
            // MTU
            config_grid.attach(new Gtk.Label("MTU:"), 0, row, 1, 1);
            mtu_entry = new Gtk.Entry();
            mtu_entry.placeholder_text = "1500";
            config_grid.attach(mtu_entry, 1, row++, 1, 1);
            
            // Buttons
            add_button("Cancel", Gtk.ResponseType.CANCEL);
            add_button("Apply", Gtk.ResponseType.OK);
            
            set_default_response(Gtk.ResponseType.OK);
            show_all();
        }
        
        private void load_configuration() {
            dhcp_switch.active = config.use_dhcp;
            
            if (config.ip_address != null) {
                ip_entry.text = config.ip_address;
            }
            if (config.subnet_mask != null) {
                subnet_entry.text = config.subnet_mask;
            }
            if (config.gateway != null) {
                gateway_entry.text = config.gateway;
            }
            if (config.dns_primary != null) {
                dns1_entry.text = config.dns_primary;
            }
            if (config.dns_secondary != null) {
                dns2_entry.text = config.dns_secondary;
            }
            mtu_entry.text = config.mtu.to_string();
            
            on_dhcp_toggled();
        }
        
        private void on_dhcp_toggled() {
            config_grid.sensitive = !dhcp_switch.active;
        }
        
        private void copy_configuration(EthernetConfiguration from, EthernetConfiguration to) {
            to.use_dhcp = from.use_dhcp;
            to.ip_address = from.ip_address;
            to.subnet_mask = from.subnet_mask;
            to.gateway = from.gateway;
            to.dns_primary = from.dns_primary;
            to.dns_secondary = from.dns_secondary;
            to.mtu = from.mtu;
        }
        
        public EthernetConfiguration? get_configuration() {
            config.use_dhcp = dhcp_switch.active;
            
            if (!config.use_dhcp) {
                config.ip_address = ip_entry.text.length > 0 ? ip_entry.text : null;
                config.subnet_mask = subnet_entry.text.length > 0 ? subnet_entry.text : null;
                config.gateway = gateway_entry.text.length > 0 ? gateway_entry.text : null;
                config.dns_primary = dns1_entry.text.length > 0 ? dns1_entry.text : null;
                config.dns_secondary = dns2_entry.text.length > 0 ? dns2_entry.text : null;
                
                var mtu_text = mtu_entry.text;
                if (mtu_text.length > 0) {
                    config.mtu = (uint16)int.parse(mtu_text);
                }
                
                if (!config.validate()) {
                    return null;
                }
            }
            
            return config;
        }
    }

    /**
     * Ethernet connection row widget
     */
    private class EthernetConnectionRow : Gtk.ListBoxRow {
        private EthernetConnection connection;
        private Gtk.Box main_box;
        private Gtk.Label name_label;
        private Gtk.Label status_label;
        private Gtk.Label details_label;
        private Gtk.Image status_icon;
        private Gtk.Image cable_icon;
        private Gtk.Spinner connecting_spinner;
        private Gtk.Button connect_button;
        private Gtk.Button configure_button;
        
        public EthernetConnectionRow(EthernetConnection connection) {
            this.connection = connection;
            setup_ui();
            update_display();
            
            // Connect to connection state changes
            connection.state_changed.connect(on_connection_state_changed);
            connection.cable_status_changed.connect(on_cable_status_changed);
            connection.link_speed_changed.connect(on_link_speed_changed);
            connection.info_updated.connect(on_connection_info_updated);
        }
        
        private void setup_ui() {
            main_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            main_box.margin = 8;
            add(main_box);
            
            // Status icon
            status_icon = new Gtk.Image();
            status_icon.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            main_box.pack_start(status_icon, false, false, 0);
            
            // Connection info box
            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            main_box.pack_start(info_box, true, true, 0);
            
            // Connection name
            name_label = new Gtk.Label(connection.name);
            name_label.halign = Gtk.Align.START;
            name_label.get_style_context().add_class("network-name");
            info_box.pack_start(name_label, false, false, 0);
            
            // Status info
            status_label = new Gtk.Label("");
            status_label.halign = Gtk.Align.START;
            status_label.get_style_context().add_class("dim-label");
            status_label.get_style_context().add_class("caption");
            info_box.pack_start(status_label, false, false, 0);
            
            // Details info
            details_label = new Gtk.Label("");
            details_label.halign = Gtk.Align.START;
            details_label.get_style_context().add_class("dim-label");
            details_label.get_style_context().add_class("caption");
            info_box.pack_start(details_label, false, false, 0);
            
            // Cable icon
            cable_icon = new Gtk.Image();
            cable_icon.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            main_box.pack_start(cable_icon, false, false, 0);
            
            // Connecting spinner
            connecting_spinner = new Gtk.Spinner();
            connecting_spinner.no_show_all = true;
            main_box.pack_start(connecting_spinner, false, false, 0);
            
            // Configure button
            configure_button = new Gtk.Button.with_label("Configure");
            configure_button.clicked.connect(on_configure_clicked);
            main_box.pack_start(configure_button, false, false, 0);
            
            // Connect button
            connect_button = new Gtk.Button.with_label("Connect");
            connect_button.get_style_context().add_class("suggested-action");
            connect_button.no_show_all = true;
            connect_button.clicked.connect(on_connect_clicked);
            main_box.pack_start(connect_button, false, false, 0);
            
            show_all();
        }
        
        private void update_display() {
            // Update connection name
            name_label.set_text(connection.name);
            
            // Update status icon
            string status_icon_name = "network-wired-symbolic";
            switch (connection.state) {
                case ConnectionState.CONNECTED:
                    status_icon_name = "network-wired-symbolic";
                    name_label.get_style_context().add_class("connected-network");
                    break;
                case ConnectionState.CONNECTING:
                    status_icon_name = "network-wired-acquiring-symbolic";
                    break;
                case ConnectionState.DISCONNECTED:
                case ConnectionState.FAILED:
                    status_icon_name = "network-wired-disconnected-symbolic";
                    name_label.get_style_context().remove_class("connected-network");
                    break;
            }
            status_icon.set_from_icon_name(status_icon_name, Gtk.IconSize.SMALL_TOOLBAR);
            
            // Update cable icon
            if (connection.diagnostics.cable_connected) {
                cable_icon.set_from_icon_name("network-wired-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
                cable_icon.tooltip_text = "Cable connected";
            } else {
                cable_icon.set_from_icon_name("network-wired-disconnected-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
                cable_icon.tooltip_text = "No cable connected";
            }
            
            // Update status text
            update_status_text();
            
            // Update details text
            update_details_text();
            
            // Update state-dependent UI
            update_state_ui();
        }
        
        private void update_status_text() {
            string status_text = "";
            
            switch (connection.state) {
                case ConnectionState.CONNECTED:
                    if (connection.configuration.use_dhcp) {
                        status_text = "Connected (DHCP)";
                    } else {
                        status_text = "Connected (Static IP)";
                    }
                    break;
                case ConnectionState.CONNECTING:
                    status_text = "Connecting...";
                    break;
                case ConnectionState.DISCONNECTING:
                    status_text = "Disconnecting...";
                    break;
                case ConnectionState.DISCONNECTED:
                    if (connection.diagnostics.cable_connected) {
                        status_text = "Disconnected";
                    } else {
                        status_text = "No cable connected";
                    }
                    break;
                case ConnectionState.FAILED:
                    status_text = "Connection failed";
                    break;
            }
            
            status_label.set_text(status_text);
        }
        
        private void update_details_text() {
            string details_text = "";
            
            if (connection.state == ConnectionState.CONNECTED && connection.get_connection_info() != null) {
                var info = connection.get_connection_info();
                details_text = @"$(info.ip_address) • $(connection.diagnostics.get_speed_description())";
            } else if (connection.diagnostics.cable_connected) {
                details_text = connection.diagnostics.get_speed_description();
            } else {
                details_text = @"Interface: $(connection.interface_name)";
            }
            
            details_label.set_text(details_text);
        }
        
        private void update_state_ui() {
            // Hide all state-dependent widgets first
            connecting_spinner.hide();
            connect_button.hide();
            
            // Show appropriate widgets based on state
            switch (connection.state) {
                case ConnectionState.CONNECTED:
                    // No additional widgets needed
                    break;
                    
                case ConnectionState.CONNECTING:
                case ConnectionState.DISCONNECTING:
                    connecting_spinner.show();
                    connecting_spinner.start();
                    break;
                    
                case ConnectionState.DISCONNECTED:
                case ConnectionState.FAILED:
                    if (connection.diagnostics.cable_connected) {
                        connect_button.show();
                    }
                    break;
            }
        }
        
        private void on_connection_state_changed(ConnectionState old_state, ConnectionState new_state) {
            update_display();
        }
        
        private void on_cable_status_changed(bool connected) {
            update_display();
        }
        
        private void on_link_speed_changed(uint32 old_speed, uint32 new_speed) {
            update_display();
        }
        
        private void on_connection_info_updated(ConnectionInfo info) {
            update_display();
        }
        
        private void on_connect_clicked() {
            connection_selected(connection);
        }
        
        private void on_configure_clicked() {
            configure_requested(connection);
        }
        
        public EthernetConnection get_connection() {
            return connection;
        }
        
        public signal void connection_selected(EthernetConnection connection);
        public signal void configure_requested(EthernetConnection connection);
    }

    /**
     * Ethernet management panel
     */
    public class EthernetPanel : NetworkPanel {
        private Gtk.ListBox connection_list;
        private Gtk.Button refresh_button;
        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Box header_box;
        private Gtk.Box empty_state_box;
        private Gtk.Label status_label;
        private Gtk.Box diagnostics_box;
        private Gtk.Label diagnostics_label;
        
        private GenericArray<EthernetConnection> current_connections;
        private string current_search_term = "";
        
        /**
         * Signal emitted when a connection is selected
         */
        public signal void connection_selected(EthernetConnection connection);
        
        /**
         * Signal emitted when configuration is requested
         */
        public signal void configure_requested(EthernetConnection connection);
        
        public EthernetPanel(NetworkController controller) {
            base(controller, "ethernet");
            current_connections = new GenericArray<EthernetConnection>();
            
            setup_ui();
            setup_controller_signals();
            
            // Initial refresh
            refresh();
        }
        
        private void setup_ui() {
            // Header with controls
            header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            header_box.margin_bottom = 8;
            pack_start(header_box, false, false, 0);
            
            // Title
            var title_label = new Gtk.Label("Ethernet Connections");
            title_label.get_style_context().add_class("heading");
            title_label.halign = Gtk.Align.START;
            header_box.pack_start(title_label, true, true, 0);
            
            // Refresh button
            refresh_button = new Gtk.Button.from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON);
            refresh_button.tooltip_text = "Refresh connections";
            refresh_button.clicked.connect(on_refresh_clicked);
            header_box.pack_start(refresh_button, false, false, 0);
            
            // Status label
            status_label = new Gtk.Label("");
            status_label.get_style_context().add_class("dim-label");
            status_label.halign = Gtk.Align.START;
            pack_start(status_label, false, false, 0);
            
            // Scrolled window for connection list
            scrolled_window = new Gtk.ScrolledWindow(null, null);
            scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_min_content_height(200);
            pack_start(scrolled_window, true, true, 0);
            
            // Connection list
            connection_list = new Gtk.ListBox();
            connection_list.selection_mode = Gtk.SelectionMode.NONE;
            connection_list.activate_on_single_click = true;
            connection_list.row_activated.connect(on_connection_row_activated);
            connection_list.button_press_event.connect(on_connection_list_button_press);
            scrolled_window.add(connection_list);
            
            // Empty state
            empty_state_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            empty_state_box.valign = Gtk.Align.CENTER;
            empty_state_box.margin = 24;
            
            var empty_icon = new Gtk.Image.from_icon_name("network-wired-symbolic", Gtk.IconSize.DIALOG);
            empty_icon.get_style_context().add_class("dim-label");
            empty_state_box.pack_start(empty_icon, false, false, 0);
            
            var empty_label = new Gtk.Label("No ethernet connections found");
            empty_label.get_style_context().add_class("dim-label");
            empty_state_box.pack_start(empty_label, false, false, 0);
            
            var empty_sublabel = new Gtk.Label("Check if ethernet cable is connected");
            empty_sublabel.get_style_context().add_class("dim-label");
            empty_sublabel.get_style_context().add_class("caption");
            empty_state_box.pack_start(empty_sublabel, false, false, 0);
            
            empty_state_box.show_all();
            empty_state_box.no_show_all = true;
            pack_start(empty_state_box, true, true, 0);
            
            // Diagnostics section
            diagnostics_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            diagnostics_box.margin_top = 8;
            diagnostics_box.get_style_context().add_class("diagnostics-section");
            
            var diagnostics_title = new Gtk.Label("Connection Diagnostics");
            diagnostics_title.get_style_context().add_class("heading");
            diagnostics_title.halign = Gtk.Align.START;
            diagnostics_box.pack_start(diagnostics_title, false, false, 0);
            
            diagnostics_label = new Gtk.Label("");
            diagnostics_label.get_style_context().add_class("dim-label");
            diagnostics_label.halign = Gtk.Align.START;
            diagnostics_label.wrap = true;
            diagnostics_box.pack_start(diagnostics_label, false, false, 0);
            
            diagnostics_box.show_all();
            diagnostics_box.no_show_all = true;
            pack_start(diagnostics_box, false, false, 0);
            
            show_all();
        }
        
        private void setup_controller_signals() {
            // Connect to ethernet manager signals through controller
            controller.ethernet_manager.connections_updated.connect(on_connections_updated);
            controller.ethernet_manager.connection_state_changed.connect(on_connection_state_changed);
            controller.ethernet_manager.cable_status_changed.connect(on_cable_status_changed);
            controller.ethernet_manager.link_speed_changed.connect(on_link_speed_changed);
            controller.ethernet_manager.configuration_error.connect(on_configuration_error);
            controller.ethernet_manager.connection_failed.connect(on_connection_failed);
        }
        
        public override void refresh() {
            set_refreshing(true);
            refresh_button.sensitive = false;
            status_label.set_text("Refreshing ethernet connections...");
            
            // Get current connections from ethernet manager
            var connections = controller.ethernet_manager.get_ethernet_connections();
            update_connection_list(connections);
            
            set_refreshing(false);
            refresh_button.sensitive = true;
        }
        
        public override void apply_search_filter(string search_term) {
            current_search_term = search_term.down();
            update_connection_list_filter();
        }
        
        public override void focus_first_result() {
            var first_row = connection_list.get_row_at_index(0);
            if (first_row != null) {
                first_row.grab_focus();
            }
        }
        
        /**
         * Update connection list with current connections
         */
        public void update_connection_list(GenericArray<EthernetConnection> connections) {
            current_connections = connections;
            rebuild_connection_list();
        }
        
        private void rebuild_connection_list() {
            // Clear existing rows
            connection_list.foreach((widget) => {
                connection_list.remove(widget);
            });
            
            // Create rows for filtered connections
            uint visible_count = 0;
            for (uint i = 0; i < current_connections.length; i++) {
                var connection = current_connections[i];
                if (matches_search_filter(connection)) {
                    var row = new EthernetConnectionRow(connection);
                    row.connection_selected.connect(on_connection_selected);
                    row.configure_requested.connect(on_configure_requested);
                    connection_list.add(row);
                    visible_count++;
                }
            }
            
            // Show/hide empty state
            if (visible_count == 0) {
                scrolled_window.hide();
                empty_state_box.show();
                diagnostics_box.hide();
                if (current_search_term.length > 0) {
                    status_label.set_text(@"No connections match \"$(current_search_term)\"");
                } else {
                    status_label.set_text("No ethernet connections found");
                }
            } else {
                empty_state_box.hide();
                scrolled_window.show();
                status_label.set_text(@"Found $(visible_count) ethernet connection$(visible_count == 1 ? "" : "s")");
                
                // Show diagnostics for active connection
                update_diagnostics_display();
            }
            
            connection_list.show_all();
        }
        
        private bool matches_search_filter(EthernetConnection connection) {
            if (current_search_term.length == 0) {
                return true;
            }
            
            return (connection.name != null && connection.name.down().contains(current_search_term)) ||
                   (connection.interface_name != null && connection.interface_name.down().contains(current_search_term));
        }
        
        private void update_connection_list_filter() {
            rebuild_connection_list();
        }
        
        private void update_diagnostics_display() {
            var active_connection = controller.ethernet_manager.active_connection;
            if (active_connection != null) {
                diagnostics_box.show();
                var diagnostics = active_connection.diagnostics;
                
                var text = new StringBuilder();
                text.append(@"Interface: $(diagnostics.interface_name)\n");
                text.append(@"MAC Address: $(diagnostics.mac_address)\n");
                text.append(@"Link Speed: $(diagnostics.get_speed_description())\n");
                text.append(@"Bytes Sent: $(format_bytes(diagnostics.bytes_sent))\n");
                text.append(@"Bytes Received: $(format_bytes(diagnostics.bytes_received))\n");
                
                if (diagnostics.errors_sent > 0 || diagnostics.errors_received > 0) {
                    text.append(@"Errors: $(diagnostics.errors_sent) sent, $(diagnostics.errors_received) received\n");
                }
                
                diagnostics_label.set_text(text.str);
            } else {
                diagnostics_box.hide();
            }
        }
        
        private string format_bytes(uint64 bytes) {
            if (bytes < 1024) {
                return @"$(bytes) B";
            } else if (bytes < 1024 * 1024) {
                return @"$(bytes / 1024) KB";
            } else if (bytes < 1024 * 1024 * 1024) {
                return @"$(bytes / (1024 * 1024)) MB";
            } else {
                return @"$(bytes / (1024 * 1024 * 1024)) GB";
            }
        }
        
        /**
         * Show static IP configuration dialog
         */
        public void show_static_ip_dialog(EthernetConnection connection) {
            var dialog = new StaticIPDialog(connection.configuration, this);
            var response = dialog.run();
            
            if (response == Gtk.ResponseType.OK) {
                var config = dialog.get_configuration();
                if (config != null) {
                    configure_connection(connection, config);
                } else {
                    show_error_dialog("Invalid Configuration", "Please check your network settings and try again.");
                }
            }
            
            dialog.destroy();
        }
        
        private void configure_connection(EthernetConnection connection, EthernetConfiguration config) {
            status_label.set_text(@"Configuring $(connection.name)...");
            
            controller.ethernet_manager.configure_static_ip.begin(connection, config, (obj, res) => {
                try {
                    var success = controller.ethernet_manager.configure_static_ip.end(res);
                    if (success) {
                        status_label.set_text(@"Configuration applied to $(connection.name)");
                    } else {
                        status_label.set_text(@"Failed to configure $(connection.name)");
                    }
                } catch (Error e) {
                    status_label.set_text(@"Configuration error: $(e.message)");
                }
            });
        }
        
        private void show_error_dialog(string title, string message) {
            var dialog = new Gtk.MessageDialog(
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.ERROR,
                Gtk.ButtonsType.OK,
                title
            );
            dialog.secondary_text = message;
            dialog.run();
            dialog.destroy();
        }
        
        private void show_connection_context_menu(EthernetConnection connection, Gdk.EventButton event) {
            var menu = new Gtk.Menu();
            
            if (connection.state == ConnectionState.CONNECTED) {
                var disconnect_item = new Gtk.MenuItem.with_label("Disconnect");
                disconnect_item.activate.connect(() => {
                    disconnect_from_connection(connection);
                });
                menu.append(disconnect_item);
            } else if (connection.diagnostics.cable_connected) {
                var connect_item = new Gtk.MenuItem.with_label("Connect");
                connect_item.activate.connect(() => {
                    on_connection_selected(connection);
                });
                menu.append(connect_item);
            }
            
            var configure_item = new Gtk.MenuItem.with_label("Configure");
            configure_item.activate.connect(() => {
                show_static_ip_dialog(connection);
            });
            menu.append(configure_item);
            
            var diagnostics_item = new Gtk.MenuItem.with_label("Show Diagnostics");
            diagnostics_item.activate.connect(() => {
                show_diagnostics_dialog(connection);
            });
            menu.append(diagnostics_item);
            
            menu.show_all();
            menu.popup_at_pointer(event);
        }
        
        private void disconnect_from_connection(EthernetConnection connection) {
            status_label.set_text(@"Disconnecting $(connection.name)...");
            
            controller.ethernet_manager.disconnect_from_network.begin(connection, (obj, res) => {
                try {
                    var success = controller.ethernet_manager.disconnect_from_network.end(res);
                    if (success) {
                        status_label.set_text(@"Disconnected from $(connection.name)");
                    } else {
                        status_label.set_text(@"Failed to disconnect from $(connection.name)");
                    }
                } catch (Error e) {
                    status_label.set_text(@"Disconnection error: $(e.message)");
                }
            });
        }
        
        private void show_diagnostics_dialog(EthernetConnection connection) {
            var dialog = new Gtk.Dialog.with_buttons(
                @"Diagnostics - $(connection.name)",
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
            
            var diagnostics = connection.diagnostics;
            int row = 0;
            
            // Interface
            grid.attach(new Gtk.Label("Interface:"), 0, row, 1, 1);
            var interface_label = new Gtk.Label(diagnostics.interface_name ?? "Unknown");
            interface_label.halign = Gtk.Align.START;
            grid.attach(interface_label, 1, row++, 1, 1);
            
            // MAC Address
            grid.attach(new Gtk.Label("MAC Address:"), 0, row, 1, 1);
            var mac_label = new Gtk.Label(diagnostics.mac_address ?? "Unknown");
            mac_label.halign = Gtk.Align.START;
            mac_label.selectable = true;
            grid.attach(mac_label, 1, row++, 1, 1);
            
            // Cable Status
            grid.attach(new Gtk.Label("Cable:"), 0, row, 1, 1);
            var cable_label = new Gtk.Label(diagnostics.cable_connected ? "Connected" : "Disconnected");
            cable_label.halign = Gtk.Align.START;
            grid.attach(cable_label, 1, row++, 1, 1);
            
            // Link Speed
            grid.attach(new Gtk.Label("Link Speed:"), 0, row, 1, 1);
            var speed_label = new Gtk.Label(diagnostics.get_speed_description());
            speed_label.halign = Gtk.Align.START;
            grid.attach(speed_label, 1, row++, 1, 1);
            
            // Statistics
            grid.attach(new Gtk.Label("Bytes Sent:"), 0, row, 1, 1);
            var sent_label = new Gtk.Label(format_bytes(diagnostics.bytes_sent));
            sent_label.halign = Gtk.Align.START;
            grid.attach(sent_label, 1, row++, 1, 1);
            
            grid.attach(new Gtk.Label("Bytes Received:"), 0, row, 1, 1);
            var received_label = new Gtk.Label(format_bytes(diagnostics.bytes_received));
            received_label.halign = Gtk.Align.START;
            grid.attach(received_label, 1, row++, 1, 1);
            
            // Errors
            if (diagnostics.errors_sent > 0 || diagnostics.errors_received > 0) {
                grid.attach(new Gtk.Label("Errors Sent:"), 0, row, 1, 1);
                var errors_sent_label = new Gtk.Label(diagnostics.errors_sent.to_string());
                errors_sent_label.halign = Gtk.Align.START;
                grid.attach(errors_sent_label, 1, row++, 1, 1);
                
                grid.attach(new Gtk.Label("Errors Received:"), 0, row, 1, 1);
                var errors_received_label = new Gtk.Label(diagnostics.errors_received.to_string());
                errors_received_label.halign = Gtk.Align.START;
                grid.attach(errors_received_label, 1, row++, 1, 1);
            }
            
            dialog.show_all();
            dialog.run();
            dialog.destroy();
        }
        
        // Signal handlers
        private void on_refresh_clicked() {
            refresh();
        }
        
        private void on_connection_row_activated(Gtk.ListBoxRow row) {
            var ethernet_row = row as EthernetConnectionRow;
            if (ethernet_row != null) {
                on_connection_selected(ethernet_row.get_connection());
            }
        }
        
        private bool on_connection_list_button_press(Gdk.EventButton event) {
            if (event.button == 3) { // Right click
                var row = connection_list.get_row_at_y((int)event.y);
                if (row != null) {
                    var ethernet_row = row as EthernetConnectionRow;
                    if (ethernet_row != null) {
                        show_connection_context_menu(ethernet_row.get_connection(), event);
                        return true;
                    }
                }
            }
            return false;
        }
        
        private void on_connection_selected(EthernetConnection connection) {
            if (connection.diagnostics.cable_connected) {
                status_label.set_text(@"Connecting to $(connection.name)...");
                
                controller.ethernet_manager.connect_to_network.begin(connection, null, (obj, res) => {
                    try {
                        var success = controller.ethernet_manager.connect_to_network.end(res);
                        if (success) {
                            status_label.set_text(@"Connected to $(connection.name)");
                        } else {
                            status_label.set_text(@"Failed to connect to $(connection.name)");
                        }
                    } catch (Error e) {
                        status_label.set_text(@"Connection error: $(e.message)");
                    }
                });
            } else {
                status_label.set_text("Cannot connect - no cable detected");
            }
        }
        
        private void on_configure_requested(EthernetConnection connection) {
            show_static_ip_dialog(connection);
        }
        
        private void on_connections_updated(GenericArray<EthernetConnection> connections) {
            update_connection_list(connections);
        }
        
        private void on_connection_state_changed(EthernetConnection connection, ConnectionState state) {
            // Connection rows will update themselves, but we can update status and diagnostics
            switch (state) {
                case ConnectionState.CONNECTING:
                    status_label.set_text(@"Connecting to $(connection.name)...");
                    break;
                case ConnectionState.CONNECTED:
                    status_label.set_text(@"Connected to $(connection.name)");
                    update_diagnostics_display();
                    break;
                case ConnectionState.DISCONNECTING:
                    status_label.set_text(@"Disconnecting from $(connection.name)...");
                    break;
                case ConnectionState.DISCONNECTED:
                    status_label.set_text(@"Disconnected from $(connection.name)");
                    update_diagnostics_display();
                    break;
                case ConnectionState.FAILED:
                    status_label.set_text(@"Failed to connect to $(connection.name)");
                    break;
            }
        }
        
        private void on_cable_status_changed(EthernetConnection connection, bool connected) {
            if (connected) {
                status_label.set_text(@"Cable connected to $(connection.name)");
            } else {
                status_label.set_text(@"Cable disconnected from $(connection.name)");
            }
            update_diagnostics_display();
        }
        
        private void on_link_speed_changed(EthernetConnection connection, uint32 old_speed, uint32 new_speed) {
            status_label.set_text(@"Link speed changed on $(connection.name): $(new_speed) Mbps");
            update_diagnostics_display();
        }
        
        private void on_configuration_error(EthernetConnection connection, string error_message) {
            show_error_dialog("Configuration Error", error_message);
        }
        
        private void on_connection_failed(EthernetConnection connection, string error_message) {
            status_label.set_text(@"Connection failed: $(error_message)");
        }
    }
}