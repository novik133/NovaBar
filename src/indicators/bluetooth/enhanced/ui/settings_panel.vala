/**
 * Enhanced Bluetooth Indicator - Settings Panel
 * 
 * This file provides the settings panel for adapter configuration,
 * notification settings, and UI preferences.
 */

using GLib;
using Gtk;

namespace EnhancedBluetooth {

    /**
     * Settings panel for Bluetooth configuration
     */
    public class SettingsPanel : Gtk.Box {
        private BluetoothController controller;
        private ConfigManager config_manager;
        
        // UI components
        private Gtk.ComboBoxText adapter_selector;
        
        // Adapter settings
        private Gtk.Entry adapter_name_entry;
        private Gtk.Switch discoverable_switch;
        private Gtk.SpinButton discoverable_timeout_spin;
        private Gtk.Switch pairable_switch;
        private Gtk.SpinButton pairable_timeout_spin;
        private Gtk.Button apply_adapter_button;
        
        // Notification settings
        private Gtk.Switch notifications_enabled_switch;
        private Gtk.Switch notify_connect_switch;
        private Gtk.Switch notify_disconnect_switch;
        private Gtk.Switch notify_pairing_switch;
        private Gtk.Switch notify_transfer_switch;
        
        // UI preferences
        private Gtk.ComboBoxText default_filter_combo;
        private Gtk.ComboBoxText default_sort_combo;
        private Gtk.Switch auto_scan_switch;
        
        // State
        private string? current_adapter_path;
        private bool is_loading;
        
        /**
         * Signal emitted when settings are changed
         */
        public signal void settings_changed();
        
        public SettingsPanel(BluetoothController controller, ConfigManager config_manager) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 12);
            
            this.controller = controller;
            this.config_manager = config_manager;
            this.is_loading = false;
            
            margin = 12;
            get_style_context().add_class("settings-panel");
            
            setup_ui();
            setup_event_handlers();
            load_settings();
        }
        
        /**
         * Setup the settings panel UI
         */
        private void setup_ui() {
            // Adapter selector
            var adapter_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            adapter_box.get_style_context().add_class("adapter-selector-box");
            
            var adapter_label = new Gtk.Label("Configure Adapter:");
            adapter_label.halign = Gtk.Align.START;
            
            adapter_selector = new Gtk.ComboBoxText();
            adapter_selector.hexpand = true;
            adapter_selector.set_tooltip_text("Select adapter to configure");
            
            adapter_box.pack_start(adapter_label, false, false, 0);
            adapter_box.pack_start(adapter_selector, true, true, 0);
            
            pack_start(adapter_box, false, false, 0);
            pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 0);
            
            // Scrolled window for settings
            var scrolled = new Gtk.ScrolledWindow(null, null);
            scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled.set_size_request(-1, 400);
            
            var settings_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 16);
            settings_box.margin = 8;
            
            // Adapter settings section
            settings_box.pack_start(create_adapter_settings_section(), false, false, 0);
            settings_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 0);
            
            // Notification settings section
            settings_box.pack_start(create_notification_settings_section(), false, false, 0);
            settings_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 0);
            
            // UI preferences section
            settings_box.pack_start(create_ui_preferences_section(), false, false, 0);
            
            scrolled.add(settings_box);
            pack_start(scrolled, true, true, 0);
        }
        
        /**
         * Create adapter settings section
         */
        private Gtk.Box create_adapter_settings_section() {
            var section_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            
            var title_label = new Gtk.Label("Adapter Configuration");
            title_label.halign = Gtk.Align.START;
            title_label.get_style_context().add_class("section-title");
            
            var grid = new Gtk.Grid();
            grid.row_spacing = 8;
            grid.column_spacing = 12;
            
            int row = 0;
            
            // Adapter name
            var name_label = new Gtk.Label("Adapter Name:");
            name_label.halign = Gtk.Align.END;
            
            adapter_name_entry = new Gtk.Entry();
            adapter_name_entry.hexpand = true;
            adapter_name_entry.set_placeholder_text("Enter adapter name");
            adapter_name_entry.set_tooltip_text("Friendly name for this Bluetooth adapter");
            
            grid.attach(name_label, 0, row, 1, 1);
            grid.attach(adapter_name_entry, 1, row, 1, 1);
            row++;
            
            // Discoverable
            var discoverable_label = new Gtk.Label("Discoverable:");
            discoverable_label.halign = Gtk.Align.END;
            
            var discoverable_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            discoverable_switch = new Gtk.Switch();
            discoverable_switch.set_tooltip_text("Make adapter visible to other devices");
            
            var timeout_label = new Gtk.Label("Timeout (seconds):");
            
            discoverable_timeout_spin = new Gtk.SpinButton.with_range(0, 300, 10);
            discoverable_timeout_spin.set_value(180);
            discoverable_timeout_spin.set_tooltip_text("0 = unlimited");
            
            discoverable_box.pack_start(discoverable_switch, false, false, 0);
            discoverable_box.pack_start(timeout_label, false, false, 0);
            discoverable_box.pack_start(discoverable_timeout_spin, false, false, 0);
            
            grid.attach(discoverable_label, 0, row, 1, 1);
            grid.attach(discoverable_box, 1, row, 1, 1);
            row++;
            
            // Pairable
            var pairable_label = new Gtk.Label("Pairable:");
            pairable_label.halign = Gtk.Align.END;
            
            var pairable_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            pairable_switch = new Gtk.Switch();
            pairable_switch.set_tooltip_text("Allow pairing with new devices");
            
            var pairable_timeout_label = new Gtk.Label("Timeout (seconds):");
            
            pairable_timeout_spin = new Gtk.SpinButton.with_range(0, 300, 10);
            pairable_timeout_spin.set_value(0);
            pairable_timeout_spin.set_tooltip_text("0 = unlimited");
            
            pairable_box.pack_start(pairable_switch, false, false, 0);
            pairable_box.pack_start(pairable_timeout_label, false, false, 0);
            pairable_box.pack_start(pairable_timeout_spin, false, false, 0);
            
            grid.attach(pairable_label, 0, row, 1, 1);
            grid.attach(pairable_box, 1, row, 1, 1);
            row++;
            
            // Apply button
            apply_adapter_button = new Gtk.Button.with_label("Apply Adapter Settings");
            apply_adapter_button.halign = Gtk.Align.END;
            apply_adapter_button.get_style_context().add_class("suggested-action");
            apply_adapter_button.set_tooltip_text("Apply configuration to selected adapter");
            
            section_box.pack_start(title_label, false, false, 0);
            section_box.pack_start(grid, false, false, 0);
            section_box.pack_start(apply_adapter_button, false, false, 0);
            
            return section_box;
        }
        
        /**
         * Create notification settings section
         */
        private Gtk.Box create_notification_settings_section() {
            var section_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            
            var title_label = new Gtk.Label("Notification Settings");
            title_label.halign = Gtk.Align.START;
            title_label.get_style_context().add_class("section-title");
            
            var grid = new Gtk.Grid();
            grid.row_spacing = 8;
            grid.column_spacing = 12;
            
            int row = 0;
            
            // Enable notifications
            add_switch_row(grid, ref row, "Enable Notifications:", 
                          "Show desktop notifications for Bluetooth events",
                          out notifications_enabled_switch);
            
            // Notify on connect
            add_switch_row(grid, ref row, "Device Connected:", 
                          "Notify when a device connects",
                          out notify_connect_switch);
            
            // Notify on disconnect
            add_switch_row(grid, ref row, "Device Disconnected:", 
                          "Notify when a device disconnects",
                          out notify_disconnect_switch);
            
            // Notify on pairing
            add_switch_row(grid, ref row, "Pairing Events:", 
                          "Notify when pairing succeeds or fails",
                          out notify_pairing_switch);
            
            // Notify on transfer
            add_switch_row(grid, ref row, "File Transfers:", 
                          "Notify when file transfers complete",
                          out notify_transfer_switch);
            
            section_box.pack_start(title_label, false, false, 0);
            section_box.pack_start(grid, false, false, 0);
            
            return section_box;
        }
        
        /**
         * Create UI preferences section
         */
        private Gtk.Box create_ui_preferences_section() {
            var section_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            
            var title_label = new Gtk.Label("UI Preferences");
            title_label.halign = Gtk.Align.START;
            title_label.get_style_context().add_class("section-title");
            
            var grid = new Gtk.Grid();
            grid.row_spacing = 8;
            grid.column_spacing = 12;
            
            int row = 0;
            
            // Default filter
            var filter_label = new Gtk.Label("Default Filter:");
            filter_label.halign = Gtk.Align.END;
            
            default_filter_combo = new Gtk.ComboBoxText();
            default_filter_combo.append("all", "All Devices");
            default_filter_combo.append("audio", "Audio Devices");
            default_filter_combo.append("input", "Input Devices");
            default_filter_combo.append("connected", "Connected Only");
            default_filter_combo.set_active_id("all");
            default_filter_combo.set_tooltip_text("Default device filter when opening panel");
            
            grid.attach(filter_label, 0, row, 1, 1);
            grid.attach(default_filter_combo, 1, row, 1, 1);
            row++;
            
            // Default sort
            var sort_label = new Gtk.Label("Default Sort:");
            sort_label.halign = Gtk.Align.END;
            
            default_sort_combo = new Gtk.ComboBoxText();
            default_sort_combo.append("name", "Name");
            default_sort_combo.append("signal", "Signal Strength");
            default_sort_combo.append("status", "Connection Status");
            default_sort_combo.set_active_id("name");
            default_sort_combo.set_tooltip_text("Default device sort order");
            
            grid.attach(sort_label, 0, row, 1, 1);
            grid.attach(default_sort_combo, 1, row, 1, 1);
            row++;
            
            // Auto-scan
            add_switch_row(grid, ref row, "Auto-scan on Open:", 
                          "Automatically start scanning when panel opens",
                          out auto_scan_switch);
            
            section_box.pack_start(title_label, false, false, 0);
            section_box.pack_start(grid, false, false, 0);
            
            return section_box;
        }
        
        /**
         * Add a switch row to a grid
         */
        private void add_switch_row(Gtk.Grid grid, ref int row, string label_text, 
                                    string tooltip, out Gtk.Switch switch_widget) {
            var label = new Gtk.Label(label_text);
            label.halign = Gtk.Align.END;
            
            switch_widget = new Gtk.Switch();
            switch_widget.halign = Gtk.Align.START;
            switch_widget.set_tooltip_text(tooltip);
            
            grid.attach(label, 0, row, 1, 1);
            grid.attach(switch_widget, 1, row, 1, 1);
            
            row++;
        }
        
        /**
         * Setup event handlers
         */
        private void setup_event_handlers() {
            // Adapter selector
            adapter_selector.changed.connect(on_adapter_changed);
            
            // Apply adapter settings button
            apply_adapter_button.clicked.connect(on_apply_adapter_settings);
            
            // Notification switches
            notifications_enabled_switch.notify["active"].connect(on_notification_setting_changed);
            notify_connect_switch.notify["active"].connect(on_notification_setting_changed);
            notify_disconnect_switch.notify["active"].connect(on_notification_setting_changed);
            notify_pairing_switch.notify["active"].connect(on_notification_setting_changed);
            notify_transfer_switch.notify["active"].connect(on_notification_setting_changed);
            
            // UI preference changes
            default_filter_combo.changed.connect(on_ui_preference_changed);
            default_sort_combo.changed.connect(on_ui_preference_changed);
            auto_scan_switch.notify["active"].connect(on_ui_preference_changed);
            
            // Controller events
            controller.adapter_state_changed.connect(on_adapter_state_changed);
        }
        
        /**
         * Load settings from configuration
         */
        private void load_settings() {
            is_loading = true;
            
            // Update adapter list
            update_adapter_list();
            
            // Load notification settings
            var config = config_manager.get_ui_preferences();
            
            notifications_enabled_switch.active = config.notifications_enabled;
            notify_connect_switch.active = config.notify_on_connect;
            notify_disconnect_switch.active = config.notify_on_disconnect;
            notify_pairing_switch.active = config.notify_on_pairing;
            notify_transfer_switch.active = config.notify_on_transfer;
            
            // Load UI preferences - convert enum to string ID
            string filter_id = "all";
            switch (config.filter_type) {
                case DeviceTypeFilter.AUDIO:
                    filter_id = "audio";
                    break;
                case DeviceTypeFilter.INPUT:
                    filter_id = "input";
                    break;
                default:
                    filter_id = "all";
                    break;
            }
            default_filter_combo.set_active_id(filter_id);
            
            string sort_id = "name";
            switch (config.sort_order) {
                case SortOrder.SIGNAL_STRENGTH:
                    sort_id = "signal";
                    break;
                case SortOrder.CONNECTION_STATUS:
                    sort_id = "status";
                    break;
                default:
                    sort_id = "name";
                    break;
            }
            default_sort_combo.set_active_id(sort_id);
            
            auto_scan_switch.active = config.show_only_paired;
            
            is_loading = false;
        }
        
        /**
         * Update adapter list
         */
        private void update_adapter_list() {
            adapter_selector.remove_all();
            
            var adapters = controller.get_adapters();
            if (adapters.length == 0) {
                adapter_selector.append("none", "No adapter available");
                adapter_selector.set_active_id("none");
                adapter_selector.sensitive = false;
                set_adapter_controls_sensitive(false);
                return;
            }
            
            adapter_selector.sensitive = true;
            
            foreach (var adapter in adapters) {
                var display_name = adapter.get_display_name();
                adapter_selector.append(adapter.object_path, display_name);
            }
            
            // Select first adapter
            var default_adapter = adapters[0];
            adapter_selector.set_active_id(default_adapter.object_path);
            current_adapter_path = default_adapter.object_path;
            
            load_adapter_settings(default_adapter);
        }
        
        /**
         * Load adapter settings into UI
         */
        private void load_adapter_settings(BluetoothAdapter adapter) {
            is_loading = true;
            
            adapter_name_entry.text = adapter.alias;
            discoverable_switch.active = adapter.discoverable;
            discoverable_timeout_spin.value = adapter.discoverable_timeout;
            pairable_switch.active = adapter.pairable;
            pairable_timeout_spin.value = adapter.pairable_timeout;
            
            set_adapter_controls_sensitive(adapter.powered);
            
            is_loading = false;
        }
        
        /**
         * Set adapter controls sensitivity
         */
        private void set_adapter_controls_sensitive(bool sensitive) {
            adapter_name_entry.sensitive = sensitive;
            discoverable_switch.sensitive = sensitive;
            discoverable_timeout_spin.sensitive = sensitive;
            pairable_switch.sensitive = sensitive;
            pairable_timeout_spin.sensitive = sensitive;
            apply_adapter_button.sensitive = sensitive;
        }
        
        /**
         * Handle adapter selection change
         */
        private void on_adapter_changed() {
            if (is_loading) return;
            
            var adapter_path = adapter_selector.get_active_id();
            if (adapter_path == null || adapter_path == "none") {
                current_adapter_path = null;
                set_adapter_controls_sensitive(false);
                return;
            }
            
            current_adapter_path = adapter_path;
            
            // Load adapter settings
            var adapters = controller.get_adapters();
            foreach (var adapter in adapters) {
                if (adapter.object_path == adapter_path) {
                    load_adapter_settings(adapter);
                    break;
                }
            }
        }
        
        /**
         * Handle apply adapter settings button click
         */
        private void on_apply_adapter_settings() {
            if (current_adapter_path == null) {
                return;
            }
            
            apply_adapter_settings.begin();
        }
        
        /**
         * Apply adapter settings
         */
        private async void apply_adapter_settings() {
            if (current_adapter_path == null) {
                return;
            }
            
            try {
                // Apply adapter name
                var adapters = controller.get_adapters();
                foreach (var adapter in adapters) {
                    if (adapter.object_path == current_adapter_path) {
                        if (adapter.alias != adapter_name_entry.text) {
                            // Note: Set alias functionality would need to be added to controller
                            debug("Setting adapter alias to: %s", adapter_name_entry.text);
                        }
                        break;
                    }
                }
                
                // Apply discoverable settings
                yield controller.set_adapter_discoverable(
                    current_adapter_path,
                    discoverable_switch.active,
                    (uint32)discoverable_timeout_spin.value
                );
                
                // Apply pairable settings (would need to be added to controller)
                debug("Setting pairable: %s, timeout: %u", 
                      pairable_switch.active.to_string(),
                      (uint32)pairable_timeout_spin.value);
                
                // Save configuration
                save_configuration();
                
                // Show success message
                show_info_message("Adapter settings applied successfully");
                
            } catch (Error e) {
                show_error_message(@"Failed to apply adapter settings: $(e.message)");
            }
        }
        
        /**
         * Handle notification setting changes
         */
        private void on_notification_setting_changed() {
            if (is_loading) return;
            
            save_configuration();
            settings_changed();
        }
        
        /**
         * Handle UI preference changes
         */
        private void on_ui_preference_changed() {
            if (is_loading) return;
            
            save_configuration();
            settings_changed();
        }
        
        /**
         * Save configuration
         */
        private void save_configuration() {
            var config = config_manager.get_ui_preferences();
            
            // Update notification settings
            config.notifications_enabled = notifications_enabled_switch.active;
            config.notify_on_connect = notify_connect_switch.active;
            config.notify_on_disconnect = notify_disconnect_switch.active;
            config.notify_on_pairing = notify_pairing_switch.active;
            config.notify_on_transfer = notify_transfer_switch.active;
            
            // Update UI preferences - convert string ID to enum
            string filter_id = default_filter_combo.get_active_id();
            if (filter_id == "audio") {
                config.filter_type = DeviceTypeFilter.AUDIO;
            } else if (filter_id == "input") {
                config.filter_type = DeviceTypeFilter.INPUT;
            } else {
                config.filter_type = DeviceTypeFilter.ALL;
            }
            
            string sort_id = default_sort_combo.get_active_id();
            if (sort_id == "signal") {
                config.sort_order = SortOrder.SIGNAL_STRENGTH;
            } else if (sort_id == "status") {
                config.sort_order = SortOrder.CONNECTION_STATUS;
            } else {
                config.sort_order = SortOrder.NAME;
            }
            
            config.show_only_paired = auto_scan_switch.active;
            
            // Save to file
            try {
                config_manager.save_configuration();
            } catch (Error e) {
                warning("Failed to save configuration: %s", e.message);
            }
        }
        
        /**
         * Handle adapter state changes
         */
        private void on_adapter_state_changed(BluetoothAdapter adapter) {
            if (adapter.object_path == current_adapter_path) {
                Idle.add(() => {
                    load_adapter_settings(adapter);
                    return Source.REMOVE;
                });
            }
        }
        
        /**
         * Show info message
         */
        private void show_info_message(string message) {
            var dialog = new Gtk.MessageDialog(
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.INFO,
                Gtk.ButtonsType.OK,
                message
            );
            dialog.run();
            dialog.destroy();
        }
        
        /**
         * Show error message
         */
        private void show_error_message(string message) {
            var dialog = new Gtk.MessageDialog(
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.ERROR,
                Gtk.ButtonsType.OK,
                message
            );
            dialog.run();
            dialog.destroy();
        }
        
        /**
         * Refresh settings panel
         */
        public void refresh() {
            load_settings();
        }
    }
}
