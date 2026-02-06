/**
 * Enhanced Network Indicator - Mobile Panel
 * 
 * This file implements the MobilePanel component that provides comprehensive
 * mobile broadband management including cellular network display, data usage
 * monitoring, and roaming controls.
 */

using GLib;
using Gtk;

namespace EnhancedNetwork {

    /**
     * APN configuration dialog
     */
    private class APNConfigDialog : Gtk.Dialog {
        private APNConfiguration config;
        private Gtk.Entry name_entry;
        private Gtk.Entry apn_entry;
        private Gtk.Entry username_entry;
        private Gtk.Entry password_entry;
        private Gtk.Entry proxy_entry;
        private Gtk.SpinButton proxy_port_spin;
        private Gtk.Switch default_switch;
        
        public APNConfigDialog(APNConfiguration? existing_config, Gtk.Widget parent) {
            Object(title: existing_config != null ? "Edit APN" : "Add APN", 
                   transient_for: parent.get_toplevel() as Gtk.Window,
                   modal: true);
            
            this.config = existing_config ?? new APNConfiguration();
            setup_ui();
            
            if (existing_config != null) {
                load_config_data();
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
            
            // Name
            grid.attach(new Gtk.Label("Name:"), 0, row, 1, 1);
            name_entry = new Gtk.Entry();
            name_entry.placeholder_text = "My Carrier";
            grid.attach(name_entry, 1, row++, 1, 1);
            
            // APN
            grid.attach(new Gtk.Label("APN:"), 0, row, 1, 1);
            apn_entry = new Gtk.Entry();
            apn_entry.placeholder_text = "internet.carrier.com";
            grid.attach(apn_entry, 1, row++, 1, 1);
            
            // Username
            grid.attach(new Gtk.Label("Username:"), 0, row, 1, 1);
            username_entry = new Gtk.Entry();
            username_entry.placeholder_text = "Optional";
            grid.attach(username_entry, 1, row++, 1, 1);
            
            // Password
            grid.attach(new Gtk.Label("Password:"), 0, row, 1, 1);
            password_entry = new Gtk.Entry();
            password_entry.visibility = false;
            password_entry.placeholder_text = "Optional";
            grid.attach(password_entry, 1, row++, 1, 1);
            
            // Proxy
            grid.attach(new Gtk.Label("Proxy:"), 0, row, 1, 1);
            proxy_entry = new Gtk.Entry();
            proxy_entry.placeholder_text = "Optional";
            grid.attach(proxy_entry, 1, row++, 1, 1);
            
            // Proxy Port
            grid.attach(new Gtk.Label("Proxy Port:"), 0, row, 1, 1);
            proxy_port_spin = new Gtk.SpinButton.with_range(0, 65535, 1);
            grid.attach(proxy_port_spin, 1, row++, 1, 1);
            
            // Default APN
            var default_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var default_label = new Gtk.Label("Set as default:");
            default_label.halign = Gtk.Align.START;
            default_switch = new Gtk.Switch();
            default_box.pack_start(default_label, false, false, 0);
            default_box.pack_end(default_switch, false, false, 0);
            grid.attach(default_box, 0, row++, 2, 1);
            
            // Buttons
            add_button("Cancel", Gtk.ResponseType.CANCEL);
            add_button("Save", Gtk.ResponseType.OK);
            
            set_default_response(Gtk.ResponseType.OK);
            show_all();
        }
        
        private void load_config_data() {
            name_entry.text = config.name ?? "";
            apn_entry.text = config.apn ?? "";
            username_entry.text = config.username ?? "";
            password_entry.text = config.password ?? "";
            proxy_entry.text = config.proxy ?? "";
            proxy_port_spin.value = config.proxy_port;
            default_switch.active = config.is_default;
        }
        
        public APNConfiguration? get_configuration() {
            var name = name_entry.text.strip();
            var apn = apn_entry.text.strip();
            
            if (name.length == 0 || apn.length == 0) {
                return null;
            }
            
            config.name = name;
            config.apn = apn;
            config.username = username_entry.text.strip();
            config.password = password_entry.text.strip();
            config.proxy = proxy_entry.text.strip();
            config.proxy_port = (uint16)proxy_port_spin.value;
            config.is_default = default_switch.active;
            
            return config;
        }
    }

    /**
     * Data usage limit dialog
     */
    private class DataLimitDialog : Gtk.Dialog {
        private Gtk.Switch limit_switch;
        private Gtk.SpinButton limit_spin;
        private Gtk.ComboBoxText unit_combo;
        private Gtk.SpinButton reset_day_spin;
        private Gtk.Switch warning_switch;
        private Gtk.SpinButton warning_spin;
        
        private uint64 current_limit;
        private bool limit_enabled;
        private uint8 reset_day;
        
        public DataLimitDialog(uint64 current_limit, bool enabled, uint8 reset_day, Gtk.Widget parent) {
            Object(title: "Data Usage Limit", 
                   transient_for: parent.get_toplevel() as Gtk.Window,
                   modal: true);
            
            this.current_limit = current_limit;
            this.limit_enabled = enabled;
            this.reset_day = reset_day;
            
            setup_ui();
            load_current_settings();
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
            
            // Enable limit
            var limit_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var limit_label = new Gtk.Label("Enable data limit:");
            limit_label.halign = Gtk.Align.START;
            limit_switch = new Gtk.Switch();
            limit_switch.notify["active"].connect(on_limit_toggled);
            limit_box.pack_start(limit_label, false, false, 0);
            limit_box.pack_end(limit_switch, false, false, 0);
            grid.attach(limit_box, 0, row++, 2, 1);
            
            // Data limit amount
            grid.attach(new Gtk.Label("Data limit:"), 0, row, 1, 1);
            var limit_amount_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            limit_spin = new Gtk.SpinButton.with_range(0.1, 999.9, 0.1);
            limit_spin.digits = 1;
            unit_combo = new Gtk.ComboBoxText();
            unit_combo.append("mb", "MB");
            unit_combo.append("gb", "GB");
            unit_combo.active_id = "gb";
            limit_amount_box.pack_start(limit_spin, false, false, 0);
            limit_amount_box.pack_start(unit_combo, false, false, 0);
            grid.attach(limit_amount_box, 1, row++, 1, 1);
            
            // Reset day
            grid.attach(new Gtk.Label("Reset on day:"), 0, row, 1, 1);
            reset_day_spin = new Gtk.SpinButton.with_range(1, 31, 1);
            grid.attach(reset_day_spin, 1, row++, 1, 1);
            
            // Warning threshold
            var warning_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var warning_label = new Gtk.Label("Warn at:");
            warning_switch = new Gtk.Switch();
            warning_spin = new Gtk.SpinButton.with_range(50, 95, 5);
            warning_spin.value = 80;
            var percent_label = new Gtk.Label("%");
            warning_box.pack_start(warning_label, false, false, 0);
            warning_box.pack_start(warning_switch, false, false, 0);
            warning_box.pack_start(warning_spin, false, false, 0);
            warning_box.pack_start(percent_label, false, false, 0);
            grid.attach(warning_box, 0, row++, 2, 1);
            
            // Buttons
            add_button("Cancel", Gtk.ResponseType.CANCEL);
            add_button("Apply", Gtk.ResponseType.OK);
            
            set_default_response(Gtk.ResponseType.OK);
            show_all();
        }
        
        private void load_current_settings() {
            limit_switch.active = limit_enabled;
            reset_day_spin.value = reset_day;
            
            if (current_limit > 0) {
                if (current_limit >= 1024 * 1024 * 1024) {
                    // GB
                    limit_spin.value = (double)current_limit / (1024.0 * 1024.0 * 1024.0);
                    unit_combo.active_id = "gb";
                } else {
                    // MB
                    limit_spin.value = (double)current_limit / (1024.0 * 1024.0);
                    unit_combo.active_id = "mb";
                }
            } else {
                limit_spin.value = 5.0;
                unit_combo.active_id = "gb";
            }
            
            on_limit_toggled();
        }
        
        private void on_limit_toggled() {
            var enabled = limit_switch.active;
            limit_spin.sensitive = enabled;
            unit_combo.sensitive = enabled;
            reset_day_spin.sensitive = enabled;
            warning_switch.sensitive = enabled;
            warning_spin.sensitive = enabled && warning_switch.active;
        }
        
        public uint64 get_limit_bytes() {
            if (!limit_switch.active) {
                return 0;
            }
            
            var amount = limit_spin.value;
            if (unit_combo.active_id == "gb") {
                return (uint64)(amount * 1024.0 * 1024.0 * 1024.0);
            } else {
                return (uint64)(amount * 1024.0 * 1024.0);
            }
        }
        
        public bool get_limit_enabled() {
            return limit_switch.active;
        }
        
        public uint8 get_reset_day() {
            return (uint8)reset_day_spin.value;
        }
    }

    /**
     * Mobile connection row widget
     */
    private class MobileConnectionRow : Gtk.ListBoxRow {
        private MobileConnection connection;
        private Gtk.Box main_box;
        private Gtk.Label name_label;
        private Gtk.Label operator_label;
        private Gtk.Label status_label;
        private Gtk.Label usage_label;
        private Gtk.Image signal_icon;
        private Gtk.Image network_type_icon;
        private Gtk.Image roaming_icon;
        private Gtk.Spinner connecting_spinner;
        private Gtk.Button connect_button;
        private Gtk.Button disconnect_button;
        private Gtk.ProgressBar usage_progress;
        
        public MobileConnectionRow(MobileConnection connection) {
            this.connection = connection;
            setup_ui();
            update_display();
            
            // Connect to connection state changes
            connection.state_changed.connect(on_connection_state_changed);
            connection.operator_changed.connect(on_operator_changed);
            connection.data_usage_updated.connect(on_data_usage_updated);
            connection.roaming_status_changed.connect(on_roaming_status_changed);
            connection.signal_strength_changed.connect(on_signal_strength_changed);
        }
        
        private void setup_ui() {
            main_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            main_box.margin = 8;
            add(main_box);
            
            // Signal strength icon
            signal_icon = new Gtk.Image();
            signal_icon.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            main_box.pack_start(signal_icon, false, false, 0);
            
            // Connection info box
            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            main_box.pack_start(info_box, true, true, 0);
            
            // Connection name
            name_label = new Gtk.Label(connection.name ?? "Mobile Broadband");
            name_label.halign = Gtk.Align.START;
            name_label.get_style_context().add_class("network-name");
            info_box.pack_start(name_label, false, false, 0);
            
            // Operator info
            operator_label = new Gtk.Label("");
            operator_label.halign = Gtk.Align.START;
            operator_label.get_style_context().add_class("dim-label");
            operator_label.get_style_context().add_class("caption");
            info_box.pack_start(operator_label, false, false, 0);
            
            // Status
            status_label = new Gtk.Label("");
            status_label.halign = Gtk.Align.START;
            status_label.get_style_context().add_class("dim-label");
            status_label.get_style_context().add_class("caption");
            info_box.pack_start(status_label, false, false, 0);
            
            // Usage info and progress
            usage_label = new Gtk.Label("");
            usage_label.halign = Gtk.Align.START;
            usage_label.get_style_context().add_class("dim-label");
            usage_label.get_style_context().add_class("caption");
            info_box.pack_start(usage_label, false, false, 0);
            
            usage_progress = new Gtk.ProgressBar();
            usage_progress.show_text = false;
            usage_progress.no_show_all = true;
            info_box.pack_start(usage_progress, false, false, 0);
            
            // Network type icon
            network_type_icon = new Gtk.Image();
            network_type_icon.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            main_box.pack_start(network_type_icon, false, false, 0);
            
            // Roaming icon
            roaming_icon = new Gtk.Image();
            roaming_icon.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
            roaming_icon.no_show_all = true;
            main_box.pack_start(roaming_icon, false, false, 0);
            
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
            // Update connection name
            name_label.set_text(connection.name ?? "Mobile Broadband");
            
            // Update operator info
            update_operator_display();
            
            // Update status
            update_status_display();
            
            // Update usage display
            update_usage_display();
            
            // Update signal strength
            update_signal_display();
            
            // Update state-dependent UI
            update_state_ui();
        }
        
        private void update_operator_display() {
            if (connection.operator_info != null) {
                var operator = connection.operator_info;
                var text = @"$(operator.get_display_name()) • $(operator.get_network_type_description())";
                operator_label.set_text(text);
                
                // Update network type icon
                string network_icon = "network-cellular-symbolic";
                if (operator.network_type != null) {
                    switch (operator.network_type.up()) {
                        case "LTE":
                            network_icon = "network-cellular-4g-symbolic";
                            break;
                        case "5GNR":
                            network_icon = "network-cellular-5g-symbolic";
                            break;
                        case "UMTS":
                        case "HSPA":
                            network_icon = "network-cellular-3g-symbolic";
                            break;
                        default:
                            network_icon = "network-cellular-symbolic";
                            break;
                    }
                }
                network_type_icon.set_from_icon_name(network_icon, Gtk.IconSize.SMALL_TOOLBAR);
                
                // Update roaming icon
                if (operator.is_roaming) {
                    roaming_icon.set_from_icon_name("network-cellular-roaming-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
                    roaming_icon.tooltip_text = "Roaming";
                    roaming_icon.show();
                } else {
                    roaming_icon.hide();
                }
            } else {
                operator_label.set_text("No operator information");
                network_type_icon.set_from_icon_name("network-cellular-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
                roaming_icon.hide();
            }
        }
        
        private void update_status_display() {
            var status_text = connection.get_mobile_state_description();
            
            if (connection.state == ConnectionState.CONNECTED) {
                name_label.get_style_context().add_class("connected-network");
                if (connection.is_roaming() && !connection.data_roaming_allowed) {
                    status_text += " (Roaming disabled)";
                }
            } else {
                name_label.get_style_context().remove_class("connected-network");
            }
            
            status_label.set_text(status_text);
        }
        
        private void update_usage_display() {
            var usage = connection.data_usage;
            var usage_text = @"Data: $(usage.format_usage())";
            
            if (usage.limit_enabled) {
                usage_text += @" / $(usage.format_limit())";
                var percentage = usage.get_usage_percentage();
                usage_progress.fraction = percentage / 100.0;
                usage_progress.show();
                
                if (usage.is_over_limit()) {
                    usage_progress.get_style_context().add_class("over-limit");
                } else if (usage.is_approaching_limit()) {
                    usage_progress.get_style_context().add_class("approaching-limit");
                } else {
                    usage_progress.get_style_context().remove_class("over-limit");
                    usage_progress.get_style_context().remove_class("approaching-limit");
                }
            } else {
                usage_progress.hide();
            }
            
            usage_label.set_text(usage_text);
        }
        
        private void update_signal_display() {
            if (connection.operator_info != null) {
                var strength = connection.operator_info.signal_strength;
                string signal_icon_name = "network-cellular-signal-none-symbolic";
                
                if (strength >= 80) {
                    signal_icon_name = "network-cellular-signal-excellent-symbolic";
                } else if (strength >= 60) {
                    signal_icon_name = "network-cellular-signal-good-symbolic";
                } else if (strength >= 40) {
                    signal_icon_name = "network-cellular-signal-ok-symbolic";
                } else if (strength >= 20) {
                    signal_icon_name = "network-cellular-signal-weak-symbolic";
                } else {
                    signal_icon_name = "network-cellular-signal-none-symbolic";
                }
                
                signal_icon.set_from_icon_name(signal_icon_name, Gtk.IconSize.SMALL_TOOLBAR);
                signal_icon.tooltip_text = @"Signal: $(strength)% ($(connection.operator_info.get_signal_strength_description()))";
            } else {
                signal_icon.set_from_icon_name("network-cellular-signal-none-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
                signal_icon.tooltip_text = "No signal information";
            }
        }
        
        private void update_state_ui() {
            // Hide all state-dependent widgets first
            connecting_spinner.hide();
            connect_button.hide();
            disconnect_button.hide();
            
            // Show appropriate widgets based on state
            switch (connection.mobile_state) {
                case MobileConnectionState.CONNECTED:
                    disconnect_button.show();
                    break;
                    
                case MobileConnectionState.CONNECTING:
                case MobileConnectionState.SEARCHING:
                case MobileConnectionState.REGISTERING:
                case MobileConnectionState.DISCONNECTING:
                    connecting_spinner.show();
                    connecting_spinner.start();
                    break;
                    
                case MobileConnectionState.DISCONNECTED:
                case MobileConnectionState.FAILED:
                    if (connection.can_connect()) {
                        connect_button.show();
                    } else {
                        connect_button.show();
                        connect_button.sensitive = false;
                        connect_button.tooltip_text = "Data roaming is disabled";
                    }
                    break;
            }
        }
        
        private void on_connection_state_changed(ConnectionState old_state, ConnectionState new_state) {
            update_display();
        }
        
        private void on_operator_changed(MobileOperator? operator) {
            update_display();
        }
        
        private void on_data_usage_updated(MobileDataUsage usage) {
            update_usage_display();
        }
        
        private void on_roaming_status_changed(bool is_roaming) {
            update_display();
        }
        
        private void on_signal_strength_changed(uint8 strength) {
            update_signal_display();
        }
        
        private void on_connect_clicked() {
            connection_selected(connection);
        }
        
        private void on_disconnect_clicked() {
            disconnect_requested(connection);
        }
        
        public MobileConnection get_connection() {
            return connection;
        }
        
        public signal void connection_selected(MobileConnection connection);
        public signal void disconnect_requested(MobileConnection connection);
        public signal void configure_requested(MobileConnection connection);
    }

    /**
     * Mobile broadband management panel
     */
    public class MobilePanel : NetworkPanel {
        private Gtk.ListBox connection_list;
        private Gtk.Button refresh_button;
        private Gtk.Button settings_button;
        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Box header_box;
        private Gtk.Box empty_state_box;
        private Gtk.Label status_label;
        private Gtk.Box usage_summary_box;
        private Gtk.Label usage_summary_label;
        private Gtk.ProgressBar usage_summary_progress;
        private Gtk.Button usage_settings_button;
        
        private GenericArray<MobileConnection> current_connections;
        private string current_search_term = "";
        
        /**
         * Signal emitted when a connection is selected
         */
        public signal void connection_selected(MobileConnection connection);
        
        /**
         * Signal emitted when disconnect is requested
         */
        public signal void disconnect_requested(MobileConnection connection);
        
        public MobilePanel(NetworkController controller) {
            base(controller, "mobile");
            current_connections = new GenericArray<MobileConnection>();
            
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
            var title_label = new Gtk.Label("Mobile Broadband");
            title_label.get_style_context().add_class("heading");
            title_label.halign = Gtk.Align.START;
            header_box.pack_start(title_label, true, true, 0);
            
            // Settings button
            settings_button = new Gtk.Button.from_icon_name("preferences-system-symbolic", Gtk.IconSize.BUTTON);
            settings_button.tooltip_text = "Mobile settings";
            settings_button.clicked.connect(on_settings_clicked);
            header_box.pack_start(settings_button, false, false, 0);
            
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
            
            // Usage summary box
            usage_summary_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            usage_summary_box.margin_top = 8;
            usage_summary_box.get_style_context().add_class("usage-summary");
            
            var usage_header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var usage_title = new Gtk.Label("Data Usage This Month");
            usage_title.get_style_context().add_class("heading");
            usage_title.halign = Gtk.Align.START;
            usage_settings_button = new Gtk.Button.with_label("Set Limit");
            usage_settings_button.get_style_context().add_class("flat");
            usage_settings_button.clicked.connect(on_usage_settings_clicked);
            usage_header_box.pack_start(usage_title, true, true, 0);
            usage_header_box.pack_start(usage_settings_button, false, false, 0);
            usage_summary_box.pack_start(usage_header_box, false, false, 0);
            
            usage_summary_label = new Gtk.Label("");
            usage_summary_label.get_style_context().add_class("dim-label");
            usage_summary_label.halign = Gtk.Align.START;
            usage_summary_box.pack_start(usage_summary_label, false, false, 0);
            
            usage_summary_progress = new Gtk.ProgressBar();
            usage_summary_progress.show_text = false;
            usage_summary_progress.no_show_all = true;
            usage_summary_box.pack_start(usage_summary_progress, false, false, 0);
            
            usage_summary_box.show_all();
            usage_summary_box.no_show_all = true;
            pack_start(usage_summary_box, false, false, 0);
            
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
            
            var empty_icon = new Gtk.Image.from_icon_name("network-cellular-symbolic", Gtk.IconSize.DIALOG);
            empty_icon.get_style_context().add_class("dim-label");
            empty_state_box.pack_start(empty_icon, false, false, 0);
            
            var empty_label = new Gtk.Label("No mobile broadband devices found");
            empty_label.get_style_context().add_class("dim-label");
            empty_state_box.pack_start(empty_label, false, false, 0);
            
            var empty_sublabel = new Gtk.Label("Insert a SIM card or connect a mobile modem");
            empty_sublabel.get_style_context().add_class("dim-label");
            empty_sublabel.get_style_context().add_class("caption");
            empty_state_box.pack_start(empty_sublabel, false, false, 0);
            
            empty_state_box.show_all();
            empty_state_box.no_show_all = true;
            pack_start(empty_state_box, true, true, 0);
            
            show_all();
        }
        
        private void setup_controller_signals() {
            // Connect to mobile manager signals through controller
            controller.mobile_manager.connections_updated.connect(on_connections_updated);
            controller.mobile_manager.connection_state_changed.connect(on_connection_state_changed);
            controller.mobile_manager.data_usage_updated.connect(on_data_usage_updated);
            controller.mobile_manager.data_limit_warning.connect(on_data_limit_warning);
            controller.mobile_manager.data_limit_exceeded.connect(on_data_limit_exceeded);
            controller.mobile_manager.roaming_status_changed.connect(on_roaming_status_changed);
        }
        
        public override void refresh() {
            set_refreshing(true);
            refresh_button.sensitive = false;
            status_label.set_text("Searching for mobile devices...");
            
            // Get current connections from mobile manager
            var connections = controller.mobile_manager.mobile_connections;
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
        public void update_connection_list(GenericArray<MobileConnection> connections) {
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
                    var row = new MobileConnectionRow(connection);
                    row.connection_selected.connect(on_connection_selected);
                    row.disconnect_requested.connect(on_disconnect_requested);
                    row.configure_requested.connect(on_configure_requested);
                    connection_list.add(row);
                    visible_count++;
                }
            }
            
            // Show/hide empty state
            if (visible_count == 0) {
                scrolled_window.hide();
                empty_state_box.show();
                usage_summary_box.hide();
                if (current_search_term.length > 0) {
                    status_label.set_text(@"No connections match \"$(current_search_term)\"");
                } else {
                    status_label.set_text("No mobile broadband devices found");
                }
            } else {
                empty_state_box.hide();
                scrolled_window.show();
                status_label.set_text(@"$(visible_count) mobile connection$(visible_count == 1 ? "" : "s")");
                
                // Show usage summary for active connection
                update_usage_summary_display();
            }
            
            connection_list.show_all();
        }
        
        private bool matches_search_filter(MobileConnection connection) {
            if (current_search_term.length == 0) {
                return true;
            }
            
            var name = connection.name ?? "";
            if (name.down().contains(current_search_term)) {
                return true;
            }
            
            if (connection.operator_info != null) {
                var operator_name = connection.operator_info.get_display_name();
                if (operator_name != null && operator_name.down().contains(current_search_term)) {
                    return true;
                }
            }
            
            return false;
        }
        
        private void update_connection_list_filter() {
            rebuild_connection_list();
        }
        
        private void update_usage_summary_display() {
            var active_connection = controller.mobile_manager.active_connection;
            if (active_connection != null) {
                usage_summary_box.show();
                
                var usage = active_connection.data_usage;
                var usage_text = @"Used: $(usage.format_usage())";
                
                if (usage.limit_enabled) {
                    usage_text += @" of $(usage.format_limit())";
                    var percentage = usage.get_usage_percentage();
                    usage_summary_progress.fraction = percentage / 100.0;
                    usage_summary_progress.show();
                    
                    if (usage.is_over_limit()) {
                        usage_summary_progress.get_style_context().add_class("over-limit");
                        usage_text += " (Over limit!)";
                    } else if (usage.is_approaching_limit()) {
                        usage_summary_progress.get_style_context().add_class("approaching-limit");
                        usage_text += @" ($((int)percentage)%)";
                    } else {
                        usage_summary_progress.get_style_context().remove_class("over-limit");
                        usage_summary_progress.get_style_context().remove_class("approaching-limit");
                    }
                } else {
                    usage_summary_progress.hide();
                    usage_text += " (No limit set)";
                }
                
                usage_summary_label.set_text(usage_text);
            } else {
                usage_summary_box.hide();
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
        
        private void show_connection_context_menu(MobileConnection connection, Gdk.EventButton event) {
            var menu = new Gtk.Menu();
            
            if (connection.state == ConnectionState.CONNECTED) {
                var disconnect_item = new Gtk.MenuItem.with_label("Disconnect");
                disconnect_item.activate.connect(() => {
                    on_disconnect_requested(connection);
                });
                menu.append(disconnect_item);
            } else {
                var connect_item = new Gtk.MenuItem.with_label("Connect");
                connect_item.activate.connect(() => {
                    on_connection_selected(connection);
                });
                menu.append(connect_item);
            }
            
            var apn_item = new Gtk.MenuItem.with_label("APN Settings");
            apn_item.activate.connect(() => {
                show_apn_dialog(connection);
            });
            menu.append(apn_item);
            
            var roaming_item = new Gtk.MenuItem.with_label(connection.data_roaming_allowed ? "Disable Roaming" : "Enable Roaming");
            roaming_item.activate.connect(() => {
                toggle_roaming(connection);
            });
            menu.append(roaming_item);
            
            var usage_item = new Gtk.MenuItem.with_label("Reset Usage");
            usage_item.activate.connect(() => {
                reset_usage(connection);
            });
            menu.append(usage_item);
            
            menu.show_all();
            menu.popup_at_pointer(event);
        }
        
        private void show_apn_dialog(MobileConnection connection) {
            var dialog = new APNConfigDialog(connection.apn_config, this);
            var response = dialog.run();
            
            if (response == Gtk.ResponseType.OK) {
                var config = dialog.get_configuration();
                if (config != null) {
                    connection.set_apn_configuration(config);
                    status_label.set_text("APN configuration updated");
                }
            }
            
            dialog.destroy();
        }
        
        private void toggle_roaming(MobileConnection connection) {
            connection.data_roaming_allowed = !connection.data_roaming_allowed;
            status_label.set_text(connection.data_roaming_allowed ? "Data roaming enabled" : "Data roaming disabled");
            rebuild_connection_list();
        }
        
        private void reset_usage(MobileConnection connection) {
            var dialog = new Gtk.MessageDialog(
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.YES_NO,
                "Reset data usage statistics?"
            );
            dialog.secondary_text = "This will reset the data usage counter to zero.";
            
            var response = dialog.run();
            dialog.destroy();
            
            if (response == Gtk.ResponseType.YES) {
                connection.reset_data_usage();
                status_label.set_text("Data usage statistics reset");
                update_usage_summary_display();
            }
        }
        
        // Signal handlers
        private void on_refresh_clicked() {
            refresh();
        }
        
        private void on_settings_clicked() {
            // Show mobile settings dialog
            status_label.set_text("Mobile settings not yet implemented");
        }
        
        private void on_usage_settings_clicked() {
            var active_connection = controller.mobile_manager.active_connection;
            if (active_connection != null) {
                var usage = active_connection.data_usage;
                var dialog = new DataLimitDialog(usage.monthly_limit, usage.limit_enabled, 1, this);
                var response = dialog.run();
                
                if (response == Gtk.ResponseType.OK) {
                    var limit = dialog.get_limit_bytes();
                    var enabled = dialog.get_limit_enabled();
                    active_connection.set_data_limit(limit, enabled);
                    status_label.set_text("Data limit updated");
                    update_usage_summary_display();
                }
                
                dialog.destroy();
            }
        }
        
        private void on_connection_row_activated(Gtk.ListBoxRow row) {
            var mobile_row = row as MobileConnectionRow;
            if (mobile_row != null) {
                var connection = mobile_row.get_connection();
                if (connection.state == ConnectionState.CONNECTED) {
                    on_disconnect_requested(connection);
                } else {
                    on_connection_selected(connection);
                }
            }
        }
        
        private bool on_connection_list_button_press(Gdk.EventButton event) {
            if (event.button == 3) { // Right click
                var row = connection_list.get_row_at_y((int)event.y);
                if (row != null) {
                    var mobile_row = row as MobileConnectionRow;
                    if (mobile_row != null) {
                        show_connection_context_menu(mobile_row.get_connection(), event);
                        return true;
                    }
                }
            }
            return false;
        }
        
        private void on_connection_selected(MobileConnection connection) {
            if (connection.can_connect()) {
                status_label.set_text(@"Connecting to mobile network...");
                
                controller.mobile_manager.connect_mobile.begin(connection, (obj, res) => {
                    try {
                        var success = controller.mobile_manager.connect_mobile.end(res);
                        if (success) {
                            status_label.set_text("Connected to mobile network");
                        } else {
                            status_label.set_text("Failed to connect to mobile network");
                        }
                    } catch (Error e) {
                        status_label.set_text(@"Connection error: $(e.message)");
                    }
                });
            } else {
                status_label.set_text("Cannot connect - data roaming is disabled");
            }
        }
        
        private void on_disconnect_requested(MobileConnection connection) {
            status_label.set_text("Disconnecting from mobile network...");
            
            controller.mobile_manager.disconnect_mobile.begin(connection, (obj, res) => {
                try {
                    var success = controller.mobile_manager.disconnect_mobile.end(res);
                    if (success) {
                        status_label.set_text("Disconnected from mobile network");
                    } else {
                        status_label.set_text("Failed to disconnect from mobile network");
                    }
                } catch (Error e) {
                    status_label.set_text(@"Disconnection error: $(e.message)");
                }
            });
        }
        
        private void on_configure_requested(MobileConnection connection) {
            show_apn_dialog(connection);
        }
        
        private void on_connections_updated(GenericArray<MobileConnection> connections) {
            update_connection_list(connections);
        }
        
        private void on_connection_state_changed(MobileConnection connection, MobileConnectionState state) {
            // Connection rows will update themselves, but we can update status and usage summary
            switch (state) {
                case MobileConnectionState.CONNECTING:
                case MobileConnectionState.SEARCHING:
                case MobileConnectionState.REGISTERING:
                    status_label.set_text("Connecting to mobile network...");
                    break;
                case MobileConnectionState.CONNECTED:
                    status_label.set_text("Connected to mobile network");
                    update_usage_summary_display();
                    break;
                case MobileConnectionState.DISCONNECTING:
                    status_label.set_text("Disconnecting from mobile network...");
                    break;
                case MobileConnectionState.DISCONNECTED:
                    status_label.set_text("Disconnected from mobile network");
                    update_usage_summary_display();
                    break;
                case MobileConnectionState.FAILED:
                    status_label.set_text("Mobile connection failed");
                    break;
            }
        }
        
        private void on_data_usage_updated(MobileConnection connection, MobileDataUsage usage) {
            update_usage_summary_display();
        }
        
        private void on_data_limit_warning(MobileConnection connection, double usage_percentage) {
            status_label.set_text(@"Data usage warning: $((int)usage_percentage)% of limit reached");
        }
        
        private void on_data_limit_exceeded(MobileConnection connection) {
            status_label.set_text("Data limit exceeded!");
        }
        
        private void on_roaming_status_changed(MobileConnection connection, bool is_roaming) {
            if (is_roaming) {
                status_label.set_text("Now roaming");
            } else {
                status_label.set_text("No longer roaming");
            }
            rebuild_connection_list();
        }
    }
}