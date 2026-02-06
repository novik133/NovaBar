/**
 * Enhanced Network Indicator - VPN Panel
 * 
 * This file implements the VPNPanel component that provides comprehensive
 * VPN connection management including profile list, connection controls,
 * and configuration dialogs.
 */

using GLib;
using Gtk;

namespace EnhancedNetwork {

    /**
     * VPN profile creation/edit dialog
     */
    private class VPNProfileDialog : Gtk.Dialog {
        private VPNProfile? profile;
        private Gtk.Entry name_entry;
        private Gtk.ComboBoxText type_combo;
        private Gtk.Entry server_entry;
        private Gtk.SpinButton port_spin;
        private Gtk.Entry username_entry;
        private Gtk.Entry password_entry;
        private Gtk.FileChooserButton config_file_button;
        private Gtk.Switch auto_connect_switch;
        private Gtk.Stack config_stack;
        private Gtk.Box manual_config_box;
        private Gtk.Box file_config_box;
        private Gtk.RadioButton manual_radio;
        private Gtk.RadioButton file_radio;
        
        public VPNProfileDialog(VPNProfile? existing_profile, Gtk.Widget parent) {
            Object(title: existing_profile != null ? "Edit VPN Profile" : "Create VPN Profile", 
                   transient_for: parent.get_toplevel() as Gtk.Window,
                   modal: true);
            
            this.profile = existing_profile;
            setup_ui();
            
            if (existing_profile != null) {
                load_profile_data();
            }
        }
        
        private void setup_ui() {
            var content_area = get_content_area();
            content_area.margin = 12;
            content_area.spacing = 12;
            
            var grid = new Gtk.Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 8;
            content_area.pack_start(grid, true, true, 0);
            
            int row = 0;
            
            // Profile name
            grid.attach(new Gtk.Label("Name:"), 0, row, 1, 1);
            name_entry = new Gtk.Entry();
            name_entry.placeholder_text = "My VPN Connection";
            grid.attach(name_entry, 1, row++, 1, 1);
            
            // VPN type
            grid.attach(new Gtk.Label("Type:"), 0, row, 1, 1);
            type_combo = new Gtk.ComboBoxText();
            type_combo.append("openvpn", "OpenVPN");
            type_combo.append("wireguard", "WireGuard");
            type_combo.append("pptp", "PPTP");
            type_combo.append("l2tp", "L2TP");
            type_combo.active_id = "openvpn";
            grid.attach(type_combo, 1, row++, 1, 1);
            
            // Configuration method
            var config_method_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            manual_radio = new Gtk.RadioButton.with_label(null, "Manual Configuration");
            file_radio = new Gtk.RadioButton.with_label_from_widget(manual_radio, "Import Configuration File");
            manual_radio.toggled.connect(on_config_method_changed);
            config_method_box.pack_start(manual_radio, false, false, 0);
            config_method_box.pack_start(file_radio, false, false, 0);
            grid.attach(config_method_box, 0, row++, 2, 1);
            
            // Configuration stack
            config_stack = new Gtk.Stack();
            grid.attach(config_stack, 0, row++, 2, 1);
            
            // Manual configuration
            manual_config_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            var manual_grid = new Gtk.Grid();
            manual_grid.column_spacing = 12;
            manual_grid.row_spacing = 8;
            manual_config_box.pack_start(manual_grid, false, false, 0);
            
            int manual_row = 0;
            
            // Server address
            manual_grid.attach(new Gtk.Label("Server:"), 0, manual_row, 1, 1);
            server_entry = new Gtk.Entry();
            server_entry.placeholder_text = "vpn.example.com";
            manual_grid.attach(server_entry, 1, manual_row++, 1, 1);
            
            // Port
            manual_grid.attach(new Gtk.Label("Port:"), 0, manual_row, 1, 1);
            port_spin = new Gtk.SpinButton.with_range(1, 65535, 1);
            port_spin.value = 1194; // Default OpenVPN port
            manual_grid.attach(port_spin, 1, manual_row++, 1, 1);
            
            // Username
            manual_grid.attach(new Gtk.Label("Username:"), 0, manual_row, 1, 1);
            username_entry = new Gtk.Entry();
            username_entry.placeholder_text = "Optional";
            manual_grid.attach(username_entry, 1, manual_row++, 1, 1);
            
            // Password
            manual_grid.attach(new Gtk.Label("Password:"), 0, manual_row, 1, 1);
            password_entry = new Gtk.Entry();
            password_entry.visibility = false;
            password_entry.placeholder_text = "Optional";
            manual_grid.attach(password_entry, 1, manual_row++, 1, 1);
            
            config_stack.add_named(manual_config_box, "manual");
            
            // File configuration
            file_config_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            var file_label = new Gtk.Label("Select configuration file:");
            file_label.halign = Gtk.Align.START;
            file_config_box.pack_start(file_label, false, false, 0);
            
            config_file_button = new Gtk.FileChooserButton("Select Configuration File", Gtk.FileChooserAction.OPEN);
            var filter = new Gtk.FileFilter();
            filter.set_name("VPN Configuration Files");
            filter.add_pattern("*.ovpn");
            filter.add_pattern("*.conf");
            config_file_button.add_filter(filter);
            file_config_box.pack_start(config_file_button, false, false, 0);
            
            config_stack.add_named(file_config_box, "file");
            
            // Auto-connect
            var auto_connect_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var auto_connect_label = new Gtk.Label("Auto-connect:");
            auto_connect_label.halign = Gtk.Align.START;
            auto_connect_switch = new Gtk.Switch();
            auto_connect_box.pack_start(auto_connect_label, false, false, 0);
            auto_connect_box.pack_end(auto_connect_switch, false, false, 0);
            grid.attach(auto_connect_box, 0, row++, 2, 1);
            
            // Buttons
            add_button("Cancel", Gtk.ResponseType.CANCEL);
            add_button(profile != null ? "Update" : "Create", Gtk.ResponseType.OK);
            
            set_default_response(Gtk.ResponseType.OK);
            
            // Set initial state
            config_stack.visible_child = manual_config_box;
            
            show_all();
        }
        
        private void load_profile_data() {
            if (profile == null) return;
            
            name_entry.text = profile.name;
            
            // Set VPN type
            switch (profile.vpn_type) {
                case VPNType.OPENVPN:
                    type_combo.active_id = "openvpn";
                    break;
                case VPNType.WIREGUARD:
                    type_combo.active_id = "wireguard";
                    break;
                case VPNType.PPTP:
                    type_combo.active_id = "pptp";
                    break;
                case VPNType.L2TP:
                    type_combo.active_id = "l2tp";
                    break;
            }
            
            var config = profile.get_configuration();
            if (config != null) {
                server_entry.text = config.server_address ?? "";
                port_spin.value = config.port;
                username_entry.text = config.username ?? "";
                
                if (config.config_file_path != null) {
                    file_radio.active = true;
                    config_file_button.set_filename(config.config_file_path);
                } else {
                    manual_radio.active = true;
                }
            }
            
            auto_connect_switch.active = profile.auto_connect;
        }
        
        private void on_config_method_changed() {
            if (manual_radio.active) {
                config_stack.visible_child = manual_config_box;
            } else {
                config_stack.visible_child = file_config_box;
            }
        }
        
        public VPNProfile? get_profile() {
            var name = name_entry.text.strip();
            if (name.length == 0) {
                return null;
            }
            
            VPNType vpn_type;
            switch (type_combo.active_id) {
                case "wireguard":
                    vpn_type = VPNType.WIREGUARD;
                    break;
                case "pptp":
                    vpn_type = VPNType.PPTP;
                    break;
                case "l2tp":
                    vpn_type = VPNType.L2TP;
                    break;
                default:
                    vpn_type = VPNType.OPENVPN;
                    break;
            }
            
            VPNProfile result_profile;
            if (profile != null) {
                result_profile = profile;
                result_profile.name = name;
                result_profile.vpn_type = vpn_type;
            } else {
                result_profile = new VPNProfile.with_name_and_type(name, vpn_type);
            }
            
            result_profile.auto_connect = auto_connect_switch.active;
            
            // Create configuration
            var config = new VPNConfiguration();
            
            if (file_radio.active) {
                // File-based configuration
                var filename = config_file_button.get_filename();
                if (filename != null) {
                    config.config_file_path = filename;
                    // Extract server info from filename if possible
                    config.server_address = "Imported from file";
                }
            } else {
                // Manual configuration
                config.server_address = server_entry.text.strip();
                config.port = (uint16)port_spin.value;
                config.username = username_entry.text.strip();
                config.password = password_entry.text.strip();
            }
            
            result_profile.set_configuration(config);
            
            return result_profile;
        }
    }

    /**
     * VPN profile row widget
     */
    private class VPNProfileRow : Gtk.ListBoxRow {
        private VPNProfile profile;
        private Gtk.Box main_box;
        private Gtk.Label name_label;
        private Gtk.Label details_label;
        private Gtk.Label status_label;
        private Gtk.Image type_icon;
        private Gtk.Image status_icon;
        private Gtk.Spinner connecting_spinner;
        private Gtk.Button connect_button;
        private Gtk.Button disconnect_button;
        
        public VPNProfileRow(VPNProfile profile) {
            this.profile = profile;
            setup_ui();
            update_display();
            
            // Connect to profile state changes
            profile.vpn_state_changed.connect(on_vpn_state_changed);
            profile.stats_updated.connect(on_stats_updated);
        }
        
        private void setup_ui() {
            main_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            main_box.margin = 8;
            add(main_box);
            
            // Type icon
            type_icon = new Gtk.Image();
            type_icon.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            main_box.pack_start(type_icon, false, false, 0);
            
            // Profile info box
            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            main_box.pack_start(info_box, true, true, 0);
            
            // Profile name
            name_label = new Gtk.Label(profile.name);
            name_label.halign = Gtk.Align.START;
            name_label.get_style_context().add_class("network-name");
            info_box.pack_start(name_label, false, false, 0);
            
            // Details (server, type)
            details_label = new Gtk.Label("");
            details_label.halign = Gtk.Align.START;
            details_label.get_style_context().add_class("dim-label");
            details_label.get_style_context().add_class("caption");
            info_box.pack_start(details_label, false, false, 0);
            
            // Status
            status_label = new Gtk.Label("");
            status_label.halign = Gtk.Align.START;
            status_label.get_style_context().add_class("dim-label");
            status_label.get_style_context().add_class("caption");
            info_box.pack_start(status_label, false, false, 0);
            
            // Status icon
            status_icon = new Gtk.Image();
            status_icon.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            main_box.pack_start(status_icon, false, false, 0);
            
            // Connecting spinner
            connecting_spinner = new Gtk.Spinner();
            connecting_spinner.no_show_all = true;
            main_box.pack_start(connecting_spinner, false, false, 0);
            
            // Connect button
            connect_button = new Gtk.Button.with_label("Connect");
            connect_button.get_style_context().add_class("suggested-action");
            connect_button.clicked.connect(on_connect_clicked);
            main_box.pack_start(connect_button, false, false, 0);
            
            // Disconnect button
            disconnect_button = new Gtk.Button.with_label("Disconnect");
            disconnect_button.get_style_context().add_class("destructive-action");
            disconnect_button.no_show_all = true;
            disconnect_button.clicked.connect(on_disconnect_clicked);
            main_box.pack_start(disconnect_button, false, false, 0);
            
            show_all();
        }
        
        private void update_display() {
            // Update profile name
            name_label.set_text(profile.name);
            
            // Update type icon
            string type_icon_name = "network-vpn-symbolic";
            switch (profile.vpn_type) {
                case VPNType.OPENVPN:
                    type_icon_name = "network-vpn-symbolic";
                    break;
                case VPNType.WIREGUARD:
                    type_icon_name = "network-vpn-symbolic";
                    break;
                default:
                    type_icon_name = "network-vpn-symbolic";
                    break;
            }
            type_icon.set_from_icon_name(type_icon_name, Gtk.IconSize.SMALL_TOOLBAR);
            
            // Update details
            var config = profile.get_configuration();
            if (config != null) {
                details_label.set_text(@"$(profile.get_type_description()) • $(config.server_address)");
            } else {
                details_label.set_text(profile.get_type_description());
            }
            
            // Update status
            update_status_display();
            
            // Update state-dependent UI
            update_state_ui();
        }
        
        private void update_status_display() {
            var status_text = profile.get_state_description();
            
            if (profile.is_connected()) {
                var stats = profile.get_stats();
                if (stats != null && stats.virtual_ip != null) {
                    status_text += @" • $(stats.virtual_ip)";
                }
                name_label.get_style_context().add_class("connected-network");
            } else {
                name_label.get_style_context().remove_class("connected-network");
            }
            
            status_label.set_text(status_text);
            
            // Update status icon
            string status_icon_name = "network-vpn-disconnected-symbolic";
            switch (profile.state) {
                case ConnectionState.CONNECTED:
                    status_icon_name = "network-vpn-symbolic";
                    break;
                case ConnectionState.CONNECTING:
                    status_icon_name = "network-vpn-acquiring-symbolic";
                    break;
                case ConnectionState.DISCONNECTED:
                case ConnectionState.FAILED:
                    status_icon_name = "network-vpn-disconnected-symbolic";
                    break;
            }
            status_icon.set_from_icon_name(status_icon_name, Gtk.IconSize.SMALL_TOOLBAR);
        }
        
        private void update_state_ui() {
            // Hide all state-dependent widgets first
            connecting_spinner.hide();
            connect_button.hide();
            disconnect_button.hide();
            
            // Show appropriate widgets based on state
            switch (profile.state) {
                case ConnectionState.CONNECTED:
                    disconnect_button.show();
                    break;
                    
                case ConnectionState.CONNECTING:
                case ConnectionState.DISCONNECTING:
                    connecting_spinner.show();
                    connecting_spinner.start();
                    break;
                    
                case ConnectionState.DISCONNECTED:
                case ConnectionState.FAILED:
                    connect_button.show();
                    break;
            }
        }
        
        private void on_vpn_state_changed(ConnectionState old_state, ConnectionState new_state) {
            update_display();
        }
        
        private void on_stats_updated(VPNStats stats) {
            update_status_display();
        }
        
        private void on_connect_clicked() {
            profile_connect_requested(profile);
        }
        
        private void on_disconnect_clicked() {
            profile_disconnect_requested(profile);
        }
        
        public VPNProfile get_profile() {
            return profile;
        }
        
        public signal void profile_connect_requested(VPNProfile profile);
        public signal void profile_disconnect_requested(VPNProfile profile);
        public signal void profile_edit_requested(VPNProfile profile);
    }

    /**
     * VPN management panel
     */
    public class VPNPanel : NetworkPanel {
        private Gtk.ListBox profile_list;
        private Gtk.Button refresh_button;
        private Gtk.Button add_button;
        private Gtk.Button import_button;
        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Box header_box;
        private Gtk.Box empty_state_box;
        private Gtk.Label status_label;
        private Gtk.Box connection_info_box;
        private Gtk.Label connection_info_label;
        
        private GenericArray<VPNProfile> current_profiles;
        private string current_search_term = "";
        
        /**
         * Signal emitted when a profile connection is requested
         */
        public signal void profile_connect_requested(VPNProfile profile);
        
        /**
         * Signal emitted when a profile disconnection is requested
         */
        public signal void profile_disconnect_requested(VPNProfile profile);
        
        public VPNPanel(NetworkController controller) {
            base(controller, "vpn");
            current_profiles = new GenericArray<VPNProfile>();
            
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
            var title_label = new Gtk.Label("VPN Connections");
            title_label.get_style_context().add_class("heading");
            title_label.halign = Gtk.Align.START;
            header_box.pack_start(title_label, true, true, 0);
            
            // Add profile button
            add_button = new Gtk.Button.from_icon_name("list-add-symbolic", Gtk.IconSize.BUTTON);
            add_button.tooltip_text = "Create new VPN profile";
            add_button.clicked.connect(on_add_profile_clicked);
            header_box.pack_start(add_button, false, false, 0);
            
            // Import profile button
            import_button = new Gtk.Button.from_icon_name("document-open-symbolic", Gtk.IconSize.BUTTON);
            import_button.tooltip_text = "Import VPN configuration";
            import_button.clicked.connect(on_import_profile_clicked);
            header_box.pack_start(import_button, false, false, 0);
            
            // Refresh button
            refresh_button = new Gtk.Button.from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON);
            refresh_button.tooltip_text = "Refresh profiles";
            refresh_button.clicked.connect(on_refresh_clicked);
            header_box.pack_start(refresh_button, false, false, 0);
            
            // Status label
            status_label = new Gtk.Label("");
            status_label.get_style_context().add_class("dim-label");
            status_label.halign = Gtk.Align.START;
            pack_start(status_label, false, false, 0);
            
            // Connection info box
            connection_info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            connection_info_box.margin_top = 8;
            connection_info_box.get_style_context().add_class("connection-info");
            
            var info_title = new Gtk.Label("Active VPN Connection");
            info_title.get_style_context().add_class("heading");
            info_title.halign = Gtk.Align.START;
            connection_info_box.pack_start(info_title, false, false, 0);
            
            connection_info_label = new Gtk.Label("");
            connection_info_label.get_style_context().add_class("dim-label");
            connection_info_label.halign = Gtk.Align.START;
            connection_info_label.wrap = true;
            connection_info_box.pack_start(connection_info_label, false, false, 0);
            
            connection_info_box.show_all();
            connection_info_box.no_show_all = true;
            pack_start(connection_info_box, false, false, 0);
            
            // Scrolled window for profile list
            scrolled_window = new Gtk.ScrolledWindow(null, null);
            scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_min_content_height(200);
            pack_start(scrolled_window, true, true, 0);
            
            // Profile list
            profile_list = new Gtk.ListBox();
            profile_list.selection_mode = Gtk.SelectionMode.NONE;
            profile_list.activate_on_single_click = true;
            profile_list.row_activated.connect(on_profile_row_activated);
            profile_list.button_press_event.connect(on_profile_list_button_press);
            scrolled_window.add(profile_list);
            
            // Empty state
            empty_state_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            empty_state_box.valign = Gtk.Align.CENTER;
            empty_state_box.margin = 24;
            
            var empty_icon = new Gtk.Image.from_icon_name("network-vpn-symbolic", Gtk.IconSize.DIALOG);
            empty_icon.get_style_context().add_class("dim-label");
            empty_state_box.pack_start(empty_icon, false, false, 0);
            
            var empty_label = new Gtk.Label("No VPN profiles configured");
            empty_label.get_style_context().add_class("dim-label");
            empty_state_box.pack_start(empty_label, false, false, 0);
            
            var empty_sublabel = new Gtk.Label("Create a new profile or import a configuration file");
            empty_sublabel.get_style_context().add_class("dim-label");
            empty_sublabel.get_style_context().add_class("caption");
            empty_state_box.pack_start(empty_sublabel, false, false, 0);
            
            empty_state_box.show_all();
            empty_state_box.no_show_all = true;
            pack_start(empty_state_box, true, true, 0);
            
            show_all();
        }
        
        private void setup_controller_signals() {
            // Connect to VPN manager signals through controller
            controller.vpn_manager.profiles_updated.connect(on_profiles_updated);
            controller.vpn_manager.vpn_state_changed.connect(on_vpn_state_changed);
            controller.vpn_manager.vpn_error.connect(on_vpn_error);
            controller.vpn_manager.vpn_stats_updated.connect(on_vpn_stats_updated);
        }
        
        public override void refresh() {
            set_refreshing(true);
            refresh_button.sensitive = false;
            status_label.set_text("Refreshing VPN profiles...");
            
            // Get current profiles from VPN manager
            var profiles_array = new GenericArray<VPNProfile>();
            for (uint i = 0; i < controller.vpn_manager.vpn_profiles.length; i++) {
                profiles_array.add(controller.vpn_manager.vpn_profiles[i]);
            }
            update_profile_list(profiles_array);
            
            set_refreshing(false);
            refresh_button.sensitive = true;
        }
        
        public override void apply_search_filter(string search_term) {
            current_search_term = search_term.down();
            update_profile_list_filter();
        }
        
        public override void focus_first_result() {
            var first_row = profile_list.get_row_at_index(0);
            if (first_row != null) {
                first_row.grab_focus();
            }
        }
        
        /**
         * Update profile list with current profiles
         */
        public void update_profile_list(GenericArray<VPNProfile> profiles) {
            current_profiles = profiles;
            rebuild_profile_list();
        }
        
        private void rebuild_profile_list() {
            // Clear existing rows
            profile_list.foreach((widget) => {
                profile_list.remove(widget);
            });
            
            // Create rows for filtered profiles
            uint visible_count = 0;
            for (uint i = 0; i < current_profiles.length; i++) {
                var profile = current_profiles[i];
                if (matches_search_filter(profile)) {
                    var row = new VPNProfileRow(profile);
                    row.profile_connect_requested.connect(on_profile_connect_requested);
                    row.profile_disconnect_requested.connect(on_profile_disconnect_requested);
                    row.profile_edit_requested.connect(on_profile_edit_requested);
                    profile_list.add(row);
                    visible_count++;
                }
            }
            
            // Show/hide empty state
            if (visible_count == 0) {
                scrolled_window.hide();
                empty_state_box.show();
                connection_info_box.hide();
                if (current_search_term.length > 0) {
                    status_label.set_text(@"No profiles match \"$(current_search_term)\"");
                } else {
                    status_label.set_text("No VPN profiles configured");
                }
            } else {
                empty_state_box.hide();
                scrolled_window.show();
                status_label.set_text(@"$(visible_count) VPN profile$(visible_count == 1 ? "" : "s")");
                
                // Show connection info if any VPN is connected
                update_connection_info_display();
            }
            
            profile_list.show_all();
        }
        
        private bool matches_search_filter(VPNProfile profile) {
            if (current_search_term.length == 0) {
                return true;
            }
            
            return (profile.name != null && profile.name.down().contains(current_search_term)) ||
                   profile.get_type_description().down().contains(current_search_term) ||
                   (profile.server_address != null && profile.server_address.down().contains(current_search_term));
        }
        
        private void update_profile_list_filter() {
            rebuild_profile_list();
        }
        
        private void update_connection_info_display() {
            var active_vpn = controller.vpn_manager.active_vpn;
            if (active_vpn != null && active_vpn.is_connected()) {
                connection_info_box.show();
                
                var text = new StringBuilder();
                text.append(@"Connected to: $(active_vpn.name)\n");
                text.append(@"Type: $(active_vpn.get_type_description())\n");
                text.append(@"Server: $(active_vpn.server_address)\n");
                
                var stats = active_vpn.get_stats();
                if (stats != null) {
                    if (stats.virtual_ip != null) {
                        text.append(@"Virtual IP: $(stats.virtual_ip)\n");
                    }
                    if (stats.connected_since != null) {
                        var duration = new DateTime.now_local().difference(stats.connected_since) / 1000000; // microseconds to seconds
                        text.append(@"Connected for: $(format_duration(duration)) seconds\n");
                    }
                    if (stats.bytes_sent > 0 || stats.bytes_received > 0) {
                        text.append(@"Data: ↑$(format_bytes(stats.bytes_sent)) ↓$(format_bytes(stats.bytes_received))");
                    }
                }
                
                connection_info_label.set_text(text.str);
            } else {
                connection_info_box.hide();
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
        
        private string format_duration(int64 seconds) {
            if (seconds < 60) {
                return @"$(seconds)";
            } else if (seconds < 3600) {
                return @"$(seconds / 60)m $(seconds % 60)s";
            } else {
                return @"$(seconds / 3600)h $(seconds % 3600 / 60)m";
            }
        }
        
        private void show_profile_context_menu(VPNProfile profile, Gdk.EventButton event) {
            var menu = new Gtk.Menu();
            
            if (profile.is_connected()) {
                var disconnect_item = new Gtk.MenuItem.with_label("Disconnect");
                disconnect_item.activate.connect(() => {
                    on_profile_disconnect_requested(profile);
                });
                menu.append(disconnect_item);
            } else {
                var connect_item = new Gtk.MenuItem.with_label("Connect");
                connect_item.activate.connect(() => {
                    on_profile_connect_requested(profile);
                });
                menu.append(connect_item);
            }
            
            var edit_item = new Gtk.MenuItem.with_label("Edit");
            edit_item.activate.connect(() => {
                on_profile_edit_requested(profile);
            });
            menu.append(edit_item);
            
            var delete_item = new Gtk.MenuItem.with_label("Delete");
            delete_item.activate.connect(() => {
                delete_profile(profile);
            });
            menu.append(delete_item);
            
            var export_item = new Gtk.MenuItem.with_label("Export");
            export_item.activate.connect(() => {
                export_profile(profile);
            });
            menu.append(export_item);
            
            menu.show_all();
            menu.popup_at_pointer(event);
        }
        
        private void delete_profile(VPNProfile profile) {
            var dialog = new Gtk.MessageDialog(
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.YES_NO,
                @"Delete VPN profile \"$(profile.name)\"?"
            );
            dialog.secondary_text = "This action cannot be undone.";
            
            var response = dialog.run();
            dialog.destroy();
            
            if (response == Gtk.ResponseType.YES) {
                controller.vpn_manager.delete_vpn_profile.begin(profile, (obj, res) => {
                    try {
                        var success = controller.vpn_manager.delete_vpn_profile.end(res);
                        if (success) {
                            status_label.set_text(@"Deleted profile $(profile.name)");
                        } else {
                            status_label.set_text(@"Failed to delete profile $(profile.name)");
                        }
                    } catch (Error e) {
                        status_label.set_text(@"Error deleting profile: $(e.message)");
                    }
                });
            }
        }
        
        private void export_profile(VPNProfile profile) {
            var dialog = new Gtk.FileChooserDialog(
                "Export VPN Profile",
                get_toplevel() as Gtk.Window,
                Gtk.FileChooserAction.SAVE,
                "Cancel", Gtk.ResponseType.CANCEL,
                "Export", Gtk.ResponseType.ACCEPT
            );
            
            dialog.set_current_name(@"$(profile.name).json");
            
            var response = dialog.run();
            if (response == Gtk.ResponseType.ACCEPT) {
                var filename = dialog.get_filename();
                if (filename != null) {
                    profile.export_to_file.begin(filename, (obj, res) => {
                        try {
                            var success = profile.export_to_file.end(res);
                            if (success) {
                                status_label.set_text(@"Exported profile to $(filename)");
                            } else {
                                status_label.set_text("Failed to export profile");
                            }
                        } catch (Error e) {
                            status_label.set_text(@"Export error: $(e.message)");
                        }
                    });
                }
            }
            
            dialog.destroy();
        }
        
        // Signal handlers
        private void on_refresh_clicked() {
            refresh();
        }
        
        private void on_add_profile_clicked() {
            var dialog = new VPNProfileDialog(null, this);
            var response = dialog.run();
            
            if (response == Gtk.ResponseType.OK) {
                var profile = dialog.get_profile();
                if (profile != null) {
                    var config = profile.get_configuration();
                    if (config != null) {
                        controller.vpn_manager.create_vpn_profile.begin(
                            profile.name, profile.vpn_type, config, (obj, res) => {
                            try {
                                var success = controller.vpn_manager.create_vpn_profile.end(res);
                                if (success) {
                                    status_label.set_text(@"Created profile $(profile.name)");
                                } else {
                                    status_label.set_text(@"Failed to create profile $(profile.name)");
                                }
                            } catch (Error e) {
                                status_label.set_text(@"Error creating profile: $(e.message)");
                            }
                        });
                    }
                }
            }
            
            dialog.destroy();
        }
        
        private void on_import_profile_clicked() {
            var dialog = new Gtk.FileChooserDialog(
                "Import VPN Configuration",
                get_toplevel() as Gtk.Window,
                Gtk.FileChooserAction.OPEN,
                "Cancel", Gtk.ResponseType.CANCEL,
                "Import", Gtk.ResponseType.ACCEPT
            );
            
            var filter = new Gtk.FileFilter();
            filter.set_name("VPN Configuration Files");
            filter.add_pattern("*.ovpn");
            filter.add_pattern("*.conf");
            dialog.add_filter(filter);
            
            var response = dialog.run();
            if (response == Gtk.ResponseType.ACCEPT) {
                var filename = dialog.get_filename();
                if (filename != null) {
                    status_label.set_text("Importing VPN configuration...");
                    controller.vpn_manager.import_vpn_profile.begin(filename, (obj, res) => {
                        try {
                            var success = controller.vpn_manager.import_vpn_profile.end(res);
                            if (success) {
                                status_label.set_text("VPN profile imported successfully");
                            } else {
                                status_label.set_text("Failed to import VPN profile");
                            }
                        } catch (Error e) {
                            status_label.set_text(@"Import error: $(e.message)");
                        }
                    });
                }
            }
            
            dialog.destroy();
        }
        
        private void on_profile_row_activated(Gtk.ListBoxRow row) {
            var vpn_row = row as VPNProfileRow;
            if (vpn_row != null) {
                var profile = vpn_row.get_profile();
                if (profile.is_connected()) {
                    on_profile_disconnect_requested(profile);
                } else {
                    on_profile_connect_requested(profile);
                }
            }
        }
        
        private bool on_profile_list_button_press(Gdk.EventButton event) {
            if (event.button == 3) { // Right click
                var row = profile_list.get_row_at_y((int)event.y);
                if (row != null) {
                    var vpn_row = row as VPNProfileRow;
                    if (vpn_row != null) {
                        show_profile_context_menu(vpn_row.get_profile(), event);
                        return true;
                    }
                }
            }
            return false;
        }
        
        private void on_profile_connect_requested(VPNProfile profile) {
            status_label.set_text(@"Connecting to $(profile.name)...");
            
            controller.vpn_manager.connect_vpn.begin(profile, (obj, res) => {
                try {
                    var success = controller.vpn_manager.connect_vpn.end(res);
                    if (success) {
                        status_label.set_text(@"Connected to $(profile.name)");
                    } else {
                        status_label.set_text(@"Failed to connect to $(profile.name)");
                    }
                } catch (Error e) {
                    status_label.set_text(@"Connection error: $(e.message)");
                }
            });
        }
        
        private void on_profile_disconnect_requested(VPNProfile profile) {
            status_label.set_text(@"Disconnecting from $(profile.name)...");
            
            controller.vpn_manager.disconnect_vpn.begin(profile, (obj, res) => {
                try {
                    var success = controller.vpn_manager.disconnect_vpn.end(res);
                    if (success) {
                        status_label.set_text(@"Disconnected from $(profile.name)");
                    } else {
                        status_label.set_text(@"Failed to disconnect from $(profile.name)");
                    }
                } catch (Error e) {
                    status_label.set_text(@"Disconnection error: $(e.message)");
                }
            });
        }
        
        private void on_profile_edit_requested(VPNProfile profile) {
            var dialog = new VPNProfileDialog(profile, this);
            var response = dialog.run();
            
            if (response == Gtk.ResponseType.OK) {
                var updated_profile = dialog.get_profile();
                if (updated_profile != null) {
                    var config = updated_profile.get_configuration();
                    if (config != null) {
                        controller.vpn_manager.update_vpn_profile.begin(profile, config, (obj, res) => {
                            try {
                                var success = controller.vpn_manager.update_vpn_profile.end(res);
                                if (success) {
                                    status_label.set_text(@"Updated profile $(profile.name)");
                                } else {
                                    status_label.set_text(@"Failed to update profile $(profile.name)");
                                }
                            } catch (Error e) {
                                status_label.set_text(@"Error updating profile: $(e.message)");
                            }
                        });
                    }
                }
            }
            
            dialog.destroy();
        }
        
        private void on_profiles_updated(GenericArray<VPNProfile> profiles) {
            update_profile_list(profiles);
        }
        
        private void on_vpn_state_changed(VPNProfile profile, ConnectionState state) {
            // Profile rows will update themselves, but we can update status and connection info
            switch (state) {
                case ConnectionState.CONNECTING:
                    status_label.set_text(@"Connecting to $(profile.name)...");
                    break;
                case ConnectionState.CONNECTED:
                    status_label.set_text(@"Connected to $(profile.name)");
                    update_connection_info_display();
                    break;
                case ConnectionState.DISCONNECTING:
                    status_label.set_text(@"Disconnecting from $(profile.name)...");
                    break;
                case ConnectionState.DISCONNECTED:
                    status_label.set_text(@"Disconnected from $(profile.name)");
                    update_connection_info_display();
                    break;
                case ConnectionState.FAILED:
                    status_label.set_text(@"Failed to connect to $(profile.name)");
                    break;
            }
        }
        
        private void on_vpn_error(VPNProfile profile, string error_message) {
            status_label.set_text(@"VPN error ($(profile.name)): $(error_message)");
        }
        
        private void on_vpn_stats_updated(VPNProfile profile, VPNStats stats) {
            update_connection_info_display();
        }
    }
}