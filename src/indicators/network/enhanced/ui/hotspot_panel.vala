/**
 * Enhanced Network Indicator - Hotspot Panel
 * 
 * This file implements the HotspotPanel component that provides comprehensive
 * hotspot management including configuration, control interface, connected
 * device monitoring, and data usage display.
 */

using GLib;
using Gtk;

namespace EnhancedNetwork {

    /**
     * Hotspot configuration dialog
     */
    private class HotspotConfigDialog : Gtk.Dialog {
        private HotspotConfiguration config;
        private Gtk.Entry ssid_entry;
        private Gtk.Entry password_entry;
        private Gtk.Button generate_password_button;
        private Gtk.ComboBoxText security_combo;
        private Gtk.ComboBoxText channel_combo;
        private Gtk.SpinButton max_clients_spin;
        private Gtk.Switch hidden_switch;
        private Gtk.ComboBoxText interface_combo;
        private Gtk.ComboBoxText shared_connection_combo;
        
        public HotspotConfigDialog(HotspotConfiguration? existing_config, Gtk.Widget parent) {
            Object(title: "Hotspot Configuration", 
                   transient_for: parent.get_toplevel() as Gtk.Window,
                   modal: true);
            
            this.config = existing_config ?? new HotspotConfiguration();
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
            
            // Network Name (SSID)
            grid.attach(new Gtk.Label("Network Name:"), 0, row, 1, 1);
            ssid_entry = new Gtk.Entry();
            ssid_entry.placeholder_text = "My Hotspot";
            ssid_entry.max_length = 32;
            grid.attach(ssid_entry, 1, row++, 1, 1);
            
            // Security
            grid.attach(new Gtk.Label("Security:"), 0, row, 1, 1);
            security_combo = new Gtk.ComboBoxText();
            security_combo.append("none", "Open (No Password)");
            security_combo.append("wpa2", "WPA2 Personal");
            security_combo.append("wpa3", "WPA3 Personal");
            security_combo.active_id = "wpa2";
            security_combo.changed.connect(on_security_changed);
            grid.attach(security_combo, 1, row++, 1, 1);
            
            // Password
            grid.attach(new Gtk.Label("Password:"), 0, row, 1, 1);
            var password_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            password_entry = new Gtk.Entry();
            password_entry.visibility = false;
            password_entry.placeholder_text = "At least 8 characters";
            password_entry.max_length = 63;
            generate_password_button = new Gtk.Button.with_label("Generate");
            generate_password_button.clicked.connect(on_generate_password);
            password_box.pack_start(password_entry, true, true, 0);
            password_box.pack_start(generate_password_button, false, false, 0);
            grid.attach(password_box, 1, row++, 1, 1);
            
            // Channel
            grid.attach(new Gtk.Label("Channel:"), 0, row, 1, 1);
            channel_combo = new Gtk.ComboBoxText();
            channel_combo.append("auto", "Auto");
            for (int i = 1; i <= 11; i++) {
                channel_combo.append(i.to_string(), @"Channel $(i)");
            }
            channel_combo.active_id = "6";
            grid.attach(channel_combo, 1, row++, 1, 1);
            
            // Max Clients
            grid.attach(new Gtk.Label("Max Clients:"), 0, row, 1, 1);
            max_clients_spin = new Gtk.SpinButton.with_range(1, 50, 1);
            max_clients_spin.value = 10;
            grid.attach(max_clients_spin, 1, row++, 1, 1);
            
            // Hidden Network
            var hidden_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var hidden_label = new Gtk.Label("Hidden Network:");
            hidden_label.halign = Gtk.Align.START;
            hidden_switch = new Gtk.Switch();
            hidden_box.pack_start(hidden_label, false, false, 0);
            hidden_box.pack_end(hidden_switch, false, false, 0);
            grid.attach(hidden_box, 0, row++, 2, 1);
            
            // Interface
            grid.attach(new Gtk.Label("WiFi Interface:"), 0, row, 1, 1);
            interface_combo = new Gtk.ComboBoxText();
            interface_combo.append("wlan0", "wlan0");
            interface_combo.append("wlan1", "wlan1");
            interface_combo.active_id = "wlan0";
            grid.attach(interface_combo, 1, row++, 1, 1);
            
            // Shared Connection
            grid.attach(new Gtk.Label("Share Connection:"), 0, row, 1, 1);
            shared_connection_combo = new Gtk.ComboBoxText();
            shared_connection_combo.append("ethernet", "Ethernet");
            shared_connection_combo.append("mobile", "Mobile Data");
            shared_connection_combo.append("vpn", "VPN Connection");
            shared_connection_combo.active_id = "ethernet";
            grid.attach(shared_connection_combo, 1, row++, 1, 1);
            
            // Buttons
            add_button("Cancel", Gtk.ResponseType.CANCEL);
            add_button("Save", Gtk.ResponseType.OK);
            
            set_default_response(Gtk.ResponseType.OK);
            
            // Initial state
            on_security_changed();
            
            show_all();
        }
        
        private void load_config_data() {
            ssid_entry.text = config.ssid ?? "";
            password_entry.text = config.password ?? "";
            
            // Set security type
            switch (config.security_type) {
                case SecurityType.NONE:
                    security_combo.active_id = "none";
                    break;
                case SecurityType.WPA3_PSK:
                    security_combo.active_id = "wpa3";
                    break;
                default:
                    security_combo.active_id = "wpa2";
                    break;
            }
            
            channel_combo.active_id = config.channel.to_string();
            max_clients_spin.value = config.max_clients;
            hidden_switch.active = config.hidden;
            interface_combo.active_id = config.device_interface ?? "wlan0";
            
            on_security_changed();
        }
        
        private void on_security_changed() {
            var is_secured = security_combo.active_id != "none";
            password_entry.sensitive = is_secured;
            generate_password_button.sensitive = is_secured;
        }
        
        private void on_generate_password() {
            const string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            var sb = new StringBuilder();
            
            for (int i = 0; i < 12; i++) {
                sb.append_c(chars[Random.int_range(0, chars.length)]);
            }
            
            password_entry.text = sb.str;
        }
        
        public HotspotConfiguration? get_configuration() {
            var ssid = ssid_entry.text.strip();
            if (ssid.length == 0) {
                return null;
            }
            
            config.ssid = ssid;
            
            // Set security type and password
            switch (security_combo.active_id) {
                case "none":
                    config.security_type = SecurityType.NONE;
                    config.password = null;
                    break;
                case "wpa3":
                    config.security_type = SecurityType.WPA3_PSK;
                    config.password = password_entry.text.strip();
                    break;
                default:
                    config.security_type = SecurityType.WPA2_PSK;
                    config.password = password_entry.text.strip();
                    break;
            }
            
            // Validate password for secured networks
            if (config.security_type != SecurityType.NONE) {
                if (config.password == null || config.password.length < 8) {
                    return null;
                }
            }
            
            config.channel = (uint8)int.parse(channel_combo.active_id == "auto" ? "6" : channel_combo.active_id);
            config.max_clients = (uint32)max_clients_spin.value;
            config.hidden = hidden_switch.active;
            config.device_interface = interface_combo.active_id;
            config.shared_connection_id = shared_connection_combo.active_id;
            
            return config;
        }
    }

    /**
     * Connected device row widget
     */
    private class ConnectedDeviceRow : Gtk.ListBoxRow {
        private ConnectedDevice device;
        private Gtk.Box main_box;
        private Gtk.Label name_label;
        private Gtk.Label details_label;
        private Gtk.Label usage_label;
        private Gtk.Image device_icon;
        private Gtk.Button disconnect_button;
        
        public ConnectedDeviceRow(ConnectedDevice device) {
            this.device = device;
            setup_ui();
            update_display();
        }
        
        private void setup_ui() {
            main_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            main_box.margin = 8;
            add(main_box);
            
            // Device icon
            device_icon = new Gtk.Image.from_icon_name("computer-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            main_box.pack_start(device_icon, false, false, 0);
            
            // Device info box
            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            main_box.pack_start(info_box, true, true, 0);
            
            // Device name
            name_label = new Gtk.Label(device.get_display_name());
            name_label.halign = Gtk.Align.START;
            name_label.get_style_context().add_class("device-name");
            info_box.pack_start(name_label, false, false, 0);
            
            // Device details
            details_label = new Gtk.Label("");
            details_label.halign = Gtk.Align.START;
            details_label.get_style_context().add_class("dim-label");
            details_label.get_style_context().add_class("caption");
            info_box.pack_start(details_label, false, false, 0);
            
            // Usage info
            usage_label = new Gtk.Label("");
            usage_label.halign = Gtk.Align.START;
            usage_label.get_style_context().add_class("dim-label");
            usage_label.get_style_context().add_class("caption");
            info_box.pack_start(usage_label, false, false, 0);
            
            // Disconnect button
            disconnect_button = new Gtk.Button.with_label("Disconnect");
            disconnect_button.get_style_context().add_class("destructive-action");
            disconnect_button.clicked.connect(on_disconnect_clicked);
            main_box.pack_start(disconnect_button, false, false, 0);
            
            show_all();
        }
        
        private void update_display() {
            // Update device name
            name_label.set_text(device.get_display_name());
            
            // Update details
            var duration = device.get_connection_duration() / 1000000; // microseconds to seconds
            var duration_text = format_duration(duration);
            details_label.set_text(@"$(device.ip_address) • Connected $(duration_text)");
            
            // Update usage
            var total_usage = device.get_total_usage();
            usage_label.set_text(@"Data: $(format_bytes(total_usage))");
        }
        
        private string format_duration(int64 seconds) {
            if (seconds < 60) {
                return @"$(seconds)s";
            } else if (seconds < 3600) {
                return @"$(seconds / 60)m";
            } else {
                return @"$(seconds / 3600)h $(seconds % 3600 / 60)m";
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
        
        private void on_disconnect_clicked() {
            disconnect_requested(device);
        }
        
        public ConnectedDevice get_device() {
            return device;
        }
        
        public signal void disconnect_requested(ConnectedDevice device);
    }

    /**
     * Hotspot management panel
     */
    public class HotspotPanel : NetworkPanel {
        private Gtk.Box control_box;
        private Gtk.Button start_button;
        private Gtk.Button stop_button;
        private Gtk.Button configure_button;
        private Gtk.Label status_label;
        private Gtk.Label config_summary_label;
        
        private Gtk.Box active_hotspot_box;
        private Gtk.Label hotspot_info_label;
        private Gtk.Label connected_devices_count_label;
        private Gtk.Label data_usage_label;
        private Gtk.ProgressBar usage_progress;
        
        private Gtk.Box devices_box;
        private Gtk.Label devices_title_label;
        private Gtk.ListBox devices_list;
        private Gtk.ScrolledWindow devices_scrolled;
        private Gtk.Box no_devices_box;
        
        private HotspotConfiguration? current_config;
        
        /**
         * Signal emitted when hotspot start is requested
         */
        public signal void start_requested(HotspotConfiguration config);
        
        /**
         * Signal emitted when hotspot stop is requested
         */
        public signal void stop_requested();
        
        /**
         * Signal emitted when device disconnect is requested
         */
        public signal void device_disconnect_requested(ConnectedDevice device);
        
        public HotspotPanel(NetworkController controller) {
            base(controller, "hotspot");
            
            setup_ui();
            setup_controller_signals();
            
            // Initial refresh
            refresh();
        }
        
        private void setup_ui() {
            // Control section
            control_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            control_box.margin_bottom = 12;
            pack_start(control_box, false, false, 0);
            
            // Title and buttons
            var header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var title_label = new Gtk.Label("WiFi Hotspot");
            title_label.get_style_context().add_class("heading");
            title_label.halign = Gtk.Align.START;
            header_box.pack_start(title_label, true, true, 0);
            
            configure_button = new Gtk.Button.from_icon_name("preferences-system-symbolic", Gtk.IconSize.BUTTON);
            configure_button.tooltip_text = "Configure hotspot";
            configure_button.clicked.connect(on_configure_clicked);
            header_box.pack_start(configure_button, false, false, 0);
            
            control_box.pack_start(header_box, false, false, 0);
            
            // Status
            status_label = new Gtk.Label("Hotspot is inactive");
            status_label.get_style_context().add_class("dim-label");
            status_label.halign = Gtk.Align.START;
            control_box.pack_start(status_label, false, false, 0);
            
            // Configuration summary
            config_summary_label = new Gtk.Label("");
            config_summary_label.get_style_context().add_class("dim-label");
            config_summary_label.get_style_context().add_class("caption");
            config_summary_label.halign = Gtk.Align.START;
            config_summary_label.wrap = true;
            control_box.pack_start(config_summary_label, false, false, 0);
            
            // Control buttons
            var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            button_box.margin_top = 8;
            
            start_button = new Gtk.Button.with_label("Start Hotspot");
            start_button.get_style_context().add_class("suggested-action");
            start_button.clicked.connect(on_start_clicked);
            button_box.pack_start(start_button, false, false, 0);
            
            stop_button = new Gtk.Button.with_label("Stop Hotspot");
            stop_button.get_style_context().add_class("destructive-action");
            stop_button.no_show_all = true;
            stop_button.clicked.connect(on_stop_clicked);
            button_box.pack_start(stop_button, false, false, 0);
            
            control_box.pack_start(button_box, false, false, 0);
            
            // Active hotspot info
            active_hotspot_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            active_hotspot_box.margin_top = 12;
            active_hotspot_box.get_style_context().add_class("hotspot-info");
            active_hotspot_box.no_show_all = true;
            
            var info_title = new Gtk.Label("Hotspot Information");
            info_title.get_style_context().add_class("heading");
            info_title.halign = Gtk.Align.START;
            active_hotspot_box.pack_start(info_title, false, false, 0);
            
            hotspot_info_label = new Gtk.Label("");
            hotspot_info_label.get_style_context().add_class("dim-label");
            hotspot_info_label.halign = Gtk.Align.START;
            hotspot_info_label.wrap = true;
            active_hotspot_box.pack_start(hotspot_info_label, false, false, 0);
            
            connected_devices_count_label = new Gtk.Label("");
            connected_devices_count_label.get_style_context().add_class("dim-label");
            connected_devices_count_label.halign = Gtk.Align.START;
            active_hotspot_box.pack_start(connected_devices_count_label, false, false, 0);
            
            data_usage_label = new Gtk.Label("");
            data_usage_label.get_style_context().add_class("dim-label");
            data_usage_label.halign = Gtk.Align.START;
            active_hotspot_box.pack_start(data_usage_label, false, false, 0);
            
            usage_progress = new Gtk.ProgressBar();
            usage_progress.show_text = false;
            usage_progress.no_show_all = true;
            active_hotspot_box.pack_start(usage_progress, false, false, 0);
            
            pack_start(active_hotspot_box, false, false, 0);
            
            // Connected devices section
            devices_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            devices_box.margin_top = 12;
            devices_box.no_show_all = true;
            
            devices_title_label = new Gtk.Label("Connected Devices");
            devices_title_label.get_style_context().add_class("heading");
            devices_title_label.halign = Gtk.Align.START;
            devices_box.pack_start(devices_title_label, false, false, 0);
            
            // Devices list
            devices_scrolled = new Gtk.ScrolledWindow(null, null);
            devices_scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            devices_scrolled.set_min_content_height(150);
            
            devices_list = new Gtk.ListBox();
            devices_list.selection_mode = Gtk.SelectionMode.NONE;
            devices_scrolled.add(devices_list);
            devices_box.pack_start(devices_scrolled, true, true, 0);
            
            // No devices state
            no_devices_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            no_devices_box.valign = Gtk.Align.CENTER;
            no_devices_box.margin = 24;
            
            var no_devices_icon = new Gtk.Image.from_icon_name("computer-symbolic", Gtk.IconSize.DIALOG);
            no_devices_icon.get_style_context().add_class("dim-label");
            no_devices_box.pack_start(no_devices_icon, false, false, 0);
            
            var no_devices_label = new Gtk.Label("No devices connected");
            no_devices_label.get_style_context().add_class("dim-label");
            no_devices_box.pack_start(no_devices_label, false, false, 0);
            
            no_devices_box.show_all();
            devices_box.pack_start(no_devices_box, true, true, 0);
            
            pack_start(devices_box, true, true, 0);
            
            show_all();
            update_ui_state();
        }
        
        private void setup_controller_signals() {
            // Connect to hotspot manager signals through controller
            controller.hotspot_manager.hotspot_state_changed.connect(on_hotspot_state_changed);
            controller.hotspot_manager.device_connected.connect(on_device_connected);
            controller.hotspot_manager.device_disconnected.connect(on_device_disconnected);
            controller.hotspot_manager.usage_updated.connect(on_usage_updated);
            controller.hotspot_manager.usage_threshold_reached.connect(on_usage_threshold_reached);
            controller.hotspot_manager.hotspot_failed.connect(on_hotspot_failed);
        }
        
        public override void refresh() {
            set_refreshing(true);
            
            // Get current hotspot state
            current_config = controller.hotspot_manager.active_hotspot;
            update_ui_state();
            
            set_refreshing(false);
        }
        
        public override void apply_search_filter(string search_term) {
            // Hotspot panel doesn't need search filtering
        }
        
        public override void focus_first_result() {
            if (start_button.visible) {
                start_button.grab_focus();
            } else if (stop_button.visible) {
                stop_button.grab_focus();
            }
        }
        
        private void update_ui_state() {
            if (current_config != null && current_config.is_active()) {
                // Hotspot is active
                status_label.set_text(@"Hotspot is active: $(current_config.ssid)");
                
                // Show configuration summary
                var summary = new StringBuilder();
                summary.append(@"Network: $(current_config.ssid)\n");
                summary.append(@"Security: $(current_config.get_security_description())\n");
                summary.append(@"Channel: $(current_config.channel)\n");
                summary.append(@"Max Clients: $(current_config.max_clients)");
                config_summary_label.set_text(summary.str);
                
                // Show stop button, hide start button
                start_button.hide();
                stop_button.show();
                
                // Show active hotspot info
                active_hotspot_box.show();
                update_hotspot_info();
                
                // Show devices section
                devices_box.show();
                update_devices_list();
                
            } else {
                // Hotspot is inactive
                status_label.set_text("Hotspot is inactive");
                
                if (current_config != null) {
                    // Show last configuration
                    var summary = @"Last configuration: $(current_config.ssid) ($(current_config.get_security_description()))";
                    config_summary_label.set_text(summary);
                } else {
                    config_summary_label.set_text("No configuration set");
                }
                
                // Show start button, hide stop button
                start_button.show();
                stop_button.hide();
                
                // Hide active sections
                active_hotspot_box.hide();
                devices_box.hide();
            }
        }
        
        private void update_hotspot_info() {
            if (current_config == null || !current_config.is_active()) {
                return;
            }
            
            var info = new StringBuilder();
            info.append(@"SSID: $(current_config.ssid)\n");
            info.append(@"Password: $(current_config.password ?? "None")\n");
            info.append(@"Security: $(current_config.get_security_description())\n");
            info.append(@"Channel: $(current_config.channel)\n");
            info.append(@"Interface: $(current_config.device_interface)");
            
            hotspot_info_label.set_text(info.str);
            
            // Update device count
            var device_count = current_config.get_connected_device_count();
            connected_devices_count_label.set_text(@"Connected Devices: $(device_count) / $(current_config.max_clients)");
            
            // Update data usage
            var usage = current_config.get_data_usage();
            var usage_text = @"Data Usage: $(format_bytes(usage.get_total_usage()))";
            
            if (usage.limit_enabled) {
                usage_text += @" / $(format_bytes(usage.usage_limit))";
                var percentage = usage.get_usage_percentage();
                usage_progress.fraction = percentage / 100.0;
                usage_progress.show();
                
                if (usage.is_limit_exceeded()) {
                    usage_progress.get_style_context().add_class("over-limit");
                } else if (percentage >= 80.0) {
                    usage_progress.get_style_context().add_class("approaching-limit");
                } else {
                    usage_progress.get_style_context().remove_class("over-limit");
                    usage_progress.get_style_context().remove_class("approaching-limit");
                }
            } else {
                usage_progress.hide();
            }
            
            data_usage_label.set_text(usage_text);
        }
        
        private void update_devices_list() {
            // Clear existing rows
            devices_list.foreach((widget) => {
                devices_list.remove(widget);
            });
            
            if (current_config == null || !current_config.is_active()) {
                no_devices_box.show();
                devices_scrolled.hide();
                return;
            }
            
            var connected_devices = current_config.get_connected_devices();
            
            if (connected_devices.length() == 0) {
                no_devices_box.show();
                devices_scrolled.hide();
            } else {
                no_devices_box.hide();
                devices_scrolled.show();
                
                foreach (var device in connected_devices) {
                    var row = new ConnectedDeviceRow(device);
                    row.disconnect_requested.connect(on_device_disconnect_requested);
                    devices_list.add(row);
                }
                
                devices_list.show_all();
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
        
        // Signal handlers
        private void on_start_clicked() {
            if (current_config == null) {
                // No configuration, show config dialog first
                show_config_dialog();
            } else {
                // Use existing configuration
                start_requested(current_config);
            }
        }
        
        private void on_stop_clicked() {
            stop_requested();
        }
        
        private void on_configure_clicked() {
            show_config_dialog();
        }
        
        private void show_config_dialog() {
            var dialog = new HotspotConfigDialog(current_config, this);
            var response = dialog.run();
            
            if (response == Gtk.ResponseType.OK) {
                var config = dialog.get_configuration();
                if (config != null) {
                    current_config = config;
                    update_ui_state();
                    
                    // If user wants to start immediately
                    if (!config.is_active()) {
                        start_requested(config);
                    }
                } else {
                    show_error_dialog("Invalid Configuration", "Please check your hotspot settings and try again.");
                }
            }
            
            dialog.destroy();
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
        
        private void on_device_disconnect_requested(ConnectedDevice device) {
            var dialog = new Gtk.MessageDialog(
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.YES_NO,
                @"Disconnect $(device.get_display_name())?"
            );
            dialog.secondary_text = "This will disconnect the device from the hotspot.";
            
            var response = dialog.run();
            dialog.destroy();
            
            if (response == Gtk.ResponseType.YES) {
                device_disconnect_requested(device);
            }
        }
        
        private void on_hotspot_state_changed(HotspotState state) {
            switch (state) {
                case HotspotState.STARTING:
                    status_label.set_text("Starting hotspot...");
                    start_button.sensitive = false;
                    break;
                case HotspotState.ACTIVE:
                    status_label.set_text("Hotspot is active");
                    start_button.sensitive = true;
                    break;
                case HotspotState.STOPPING:
                    status_label.set_text("Stopping hotspot...");
                    stop_button.sensitive = false;
                    break;
                case HotspotState.INACTIVE:
                    status_label.set_text("Hotspot stopped");
                    stop_button.sensitive = true;
                    break;
                case HotspotState.FAILED:
                    status_label.set_text("Hotspot failed to start");
                    start_button.sensitive = true;
                    break;
            }
            
            update_ui_state();
        }
        
        private void on_device_connected(ConnectedDevice device) {
            status_label.set_text(@"Device connected: $(device.get_display_name())");
            update_devices_list();
            update_hotspot_info();
        }
        
        private void on_device_disconnected(ConnectedDevice device) {
            status_label.set_text(@"Device disconnected: $(device.get_display_name())");
            update_devices_list();
            update_hotspot_info();
        }
        
        private void on_usage_updated(DataUsage usage) {
            update_hotspot_info();
        }
        
        private void on_usage_threshold_reached(double percentage) {
            status_label.set_text(@"Data usage warning: $((int)percentage)% of limit reached");
        }
        
        private void on_hotspot_failed(string error_message) {
            show_error_dialog("Hotspot Failed", error_message);
        }
    }
}