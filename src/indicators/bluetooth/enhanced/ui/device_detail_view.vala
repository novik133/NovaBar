/**
 * Enhanced Bluetooth Indicator - Device Detail View
 * 
 * This file provides detailed device information view with properties,
 * audio profile management, file transfer UI, and device settings.
 */

using GLib;
using Gtk;

namespace EnhancedBluetooth {

    /**
     * Device detail view showing comprehensive device information
     */
    public class DeviceDetailView : Gtk.Box {
        private BluetoothController controller;
        private BluetoothDevice device;
        
        // UI components
        private Gtk.Box header_box;
        private Gtk.Image device_icon;
        private Gtk.Label device_name_label;
        private Gtk.Label device_address_label;
        
        private Gtk.Grid properties_grid;
        private Gtk.Label device_type_value;
        private Gtk.Label connection_state_value;
        private Gtk.Label signal_strength_value;
        private Gtk.Label battery_level_value;
        private Gtk.Label paired_status_value;
        private Gtk.Label trusted_status_value;
        
        private Gtk.Box audio_profile_box;
        private Gtk.ComboBoxText audio_profile_selector;
        private Gtk.Label audio_codec_label;
        
        private Gtk.Box file_transfer_box;
        private Gtk.Button send_file_button;
        private Gtk.Box transfer_progress_box;
        private Gtk.ProgressBar transfer_progress_bar;
        private Gtk.Label transfer_status_label;
        private Gtk.Button cancel_transfer_button;
        
        private Gtk.Box settings_box;
        private Gtk.Switch trust_switch;
        private Gtk.Switch block_switch;
        private Gtk.Button forget_button;
        
        // State
        private string? active_transfer_path;
        
        /**
         * Signal emitted when back button is clicked
         */
        public signal void back_requested();
        
        public DeviceDetailView(BluetoothController controller, BluetoothDevice device) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 12);
            
            this.controller = controller;
            this.device = device;
            this.active_transfer_path = null;
            
            margin = 12;
            get_style_context().add_class("device-detail-view");
            
            setup_ui();
            setup_event_handlers();
            update_display();
        }
        
        /**
         * Setup the detail view UI
         */
        private void setup_ui() {
            // Header with device icon and name
            setup_header();
            pack_start(header_box, false, false, 0);
            
            pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 0);
            
            // Device properties
            setup_properties();
            pack_start(properties_grid, false, false, 0);
            
            pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 0);
            
            // Audio profile section (for audio devices)
            setup_audio_profile_section();
            pack_start(audio_profile_box, false, false, 0);
            
            // File transfer section
            setup_file_transfer_section();
            pack_start(file_transfer_box, false, false, 0);
            
            pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 0);
            
            // Device settings
            setup_settings_section();
            pack_start(settings_box, false, false, 0);
        }
        
        /**
         * Setup header section
         */
        private void setup_header() {
            header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            header_box.get_style_context().add_class("device-header");
            
            // Back button
            var back_button = new Gtk.Button.from_icon_name("go-previous-symbolic", Gtk.IconSize.BUTTON);
            back_button.get_style_context().add_class("flat");
            back_button.set_tooltip_text("Back to device list");
            back_button.clicked.connect(() => back_requested());
            
            // Device icon
            device_icon = new Gtk.Image();
            device_icon.set_pixel_size(48);
            
            // Device info
            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            info_box.hexpand = true;
            info_box.halign = Gtk.Align.START;
            
            device_name_label = new Gtk.Label("");
            device_name_label.halign = Gtk.Align.START;
            device_name_label.get_style_context().add_class("device-name-large");
            
            device_address_label = new Gtk.Label("");
            device_address_label.halign = Gtk.Align.START;
            device_address_label.get_style_context().add_class("dim-label");
            
            info_box.pack_start(device_name_label, false, false, 0);
            info_box.pack_start(device_address_label, false, false, 0);
            
            header_box.pack_start(back_button, false, false, 0);
            header_box.pack_start(device_icon, false, false, 0);
            header_box.pack_start(info_box, true, true, 0);
        }
        
        /**
         * Setup properties grid
         */
        private void setup_properties() {
            properties_grid = new Gtk.Grid();
            properties_grid.row_spacing = 8;
            properties_grid.column_spacing = 12;
            properties_grid.get_style_context().add_class("properties-grid");
            
            int row = 0;
            
            // Device type
            add_property_row(ref row, "Type:", out device_type_value);
            
            // Connection state
            add_property_row(ref row, "Status:", out connection_state_value);
            
            // Signal strength
            add_property_row(ref row, "Signal:", out signal_strength_value);
            
            // Battery level
            add_property_row(ref row, "Battery:", out battery_level_value);
            
            // Paired status
            add_property_row(ref row, "Paired:", out paired_status_value);
            
            // Trusted status
            add_property_row(ref row, "Trusted:", out trusted_status_value);
        }
        
        /**
         * Add a property row to the grid
         */
        private void add_property_row(ref int row, string label_text, out Gtk.Label value_label) {
            var label = new Gtk.Label(label_text);
            label.halign = Gtk.Align.END;
            label.get_style_context().add_class("property-label");
            
            value_label = new Gtk.Label("");
            value_label.halign = Gtk.Align.START;
            value_label.hexpand = true;
            value_label.get_style_context().add_class("property-value");
            
            properties_grid.attach(label, 0, row, 1, 1);
            properties_grid.attach(value_label, 1, row, 1, 1);
            
            row++;
        }
        
        /**
         * Setup audio profile section
         */
        private void setup_audio_profile_section() {
            audio_profile_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            audio_profile_box.get_style_context().add_class("audio-profile-section");
            audio_profile_box.no_show_all = true;
            
            var title_label = new Gtk.Label("Audio Profiles");
            title_label.halign = Gtk.Align.START;
            title_label.get_style_context().add_class("section-title");
            
            var profile_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            var profile_label = new Gtk.Label("Active Profile:");
            profile_label.halign = Gtk.Align.START;
            
            audio_profile_selector = new Gtk.ComboBoxText();
            audio_profile_selector.hexpand = true;
            audio_profile_selector.set_tooltip_text("Select audio profile");
            
            profile_box.pack_start(profile_label, false, false, 0);
            profile_box.pack_start(audio_profile_selector, true, true, 0);
            
            audio_codec_label = new Gtk.Label("");
            audio_codec_label.halign = Gtk.Align.START;
            audio_codec_label.get_style_context().add_class("dim-label");
            
            audio_profile_box.pack_start(title_label, false, false, 0);
            audio_profile_box.pack_start(profile_box, false, false, 0);
            audio_profile_box.pack_start(audio_codec_label, false, false, 0);
        }
        
        /**
         * Setup file transfer section
         */
        private void setup_file_transfer_section() {
            file_transfer_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            file_transfer_box.get_style_context().add_class("file-transfer-section");
            
            var title_label = new Gtk.Label("File Transfer");
            title_label.halign = Gtk.Align.START;
            title_label.get_style_context().add_class("section-title");
            
            send_file_button = new Gtk.Button.with_label("Send File...");
            send_file_button.halign = Gtk.Align.START;
            send_file_button.get_style_context().add_class("suggested-action");
            
            // Transfer progress (hidden by default)
            transfer_progress_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            transfer_progress_box.no_show_all = true;
            
            transfer_progress_bar = new Gtk.ProgressBar();
            transfer_progress_bar.set_show_text(true);
            
            var progress_controls = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            transfer_status_label = new Gtk.Label("");
            transfer_status_label.halign = Gtk.Align.START;
            transfer_status_label.hexpand = true;
            transfer_status_label.get_style_context().add_class("dim-label");
            
            cancel_transfer_button = new Gtk.Button.with_label("Cancel");
            cancel_transfer_button.get_style_context().add_class("destructive-action");
            
            progress_controls.pack_start(transfer_status_label, true, true, 0);
            progress_controls.pack_end(cancel_transfer_button, false, false, 0);
            
            transfer_progress_box.pack_start(transfer_progress_bar, false, false, 0);
            transfer_progress_box.pack_start(progress_controls, false, false, 0);
            
            file_transfer_box.pack_start(title_label, false, false, 0);
            file_transfer_box.pack_start(send_file_button, false, false, 0);
            file_transfer_box.pack_start(transfer_progress_box, false, false, 0);
        }
        
        /**
         * Setup settings section
         */
        private void setup_settings_section() {
            settings_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            settings_box.get_style_context().add_class("settings-section");
            
            var title_label = new Gtk.Label("Device Settings");
            title_label.halign = Gtk.Align.START;
            title_label.get_style_context().add_class("section-title");
            
            // Trust switch
            var trust_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var trust_label = new Gtk.Label("Trust this device");
            trust_label.halign = Gtk.Align.START;
            trust_label.hexpand = true;
            trust_label.set_tooltip_text("Allow automatic connections from this device");
            
            trust_switch = new Gtk.Switch();
            trust_switch.halign = Gtk.Align.END;
            
            trust_box.pack_start(trust_label, true, true, 0);
            trust_box.pack_end(trust_switch, false, false, 0);
            
            // Block switch
            var block_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            var block_label = new Gtk.Label("Block this device");
            block_label.halign = Gtk.Align.START;
            block_label.hexpand = true;
            block_label.set_tooltip_text("Prevent connections from this device");
            
            block_switch = new Gtk.Switch();
            block_switch.halign = Gtk.Align.END;
            
            block_box.pack_start(block_label, true, true, 0);
            block_box.pack_end(block_switch, false, false, 0);
            
            // Forget button
            forget_button = new Gtk.Button.with_label("Forget Device");
            forget_button.halign = Gtk.Align.START;
            forget_button.get_style_context().add_class("destructive-action");
            forget_button.set_tooltip_text("Remove pairing information for this device");
            
            settings_box.pack_start(title_label, false, false, 0);
            settings_box.pack_start(trust_box, false, false, 0);
            settings_box.pack_start(block_box, false, false, 0);
            settings_box.pack_start(forget_button, false, false, 0);
        }
        
        /**
         * Setup event handlers
         */
        private void setup_event_handlers() {
            // Audio profile selector
            audio_profile_selector.changed.connect(on_audio_profile_changed);
            
            // File transfer
            send_file_button.clicked.connect(on_send_file_clicked);
            cancel_transfer_button.clicked.connect(on_cancel_transfer_clicked);
            
            // Settings
            trust_switch.notify["active"].connect(on_trust_toggled);
            block_switch.notify["active"].connect(on_block_toggled);
            forget_button.clicked.connect(on_forget_clicked);
            
            // Controller events
            controller.device_connected.connect(on_device_state_changed);
            controller.device_disconnected.connect(on_device_state_changed);
            controller.transfer_progress.connect(on_transfer_progress);
        }
        
        /**
         * Update display with current device information
         */
        public void update_display() {
            // Update header
            device_icon.set_from_icon_name(device.get_device_type_icon(), Gtk.IconSize.DIALOG);
            device_name_label.label = device.get_display_name();
            device_address_label.label = device.address;
            
            // Update properties
            device_type_value.label = get_device_type_string(device.device_type);
            connection_state_value.label = get_connection_state_string(device.connection_state);
            
            if (device.connected && device.rssi != 0) {
                signal_strength_value.label = @"$(device.rssi) dBm ($(get_signal_strength_string(device.signal_strength)))";
            } else {
                signal_strength_value.label = "N/A";
            }
            
            if (device.battery_percentage != null) {
                battery_level_value.label = @"$(device.battery_percentage)%";
            } else {
                battery_level_value.label = "N/A";
            }
            
            paired_status_value.label = device.paired ? "Yes" : "No";
            trusted_status_value.label = device.trusted ? "Yes" : "No";
            
            // Update audio profile section
            update_audio_profiles();
            
            // Update settings
            trust_switch.active = device.trusted;
            block_switch.active = device.blocked;
            
            // Enable/disable controls based on device state
            send_file_button.sensitive = device.connected && device.supports_file_transfer();
            forget_button.sensitive = device.paired;
        }
        
        /**
         * Update audio profiles
         */
        private void update_audio_profiles() {
            if (!device.has_audio_profile()) {
                audio_profile_box.visible = false;
                return;
            }
            
            audio_profile_box.visible = true;
            audio_profile_selector.remove_all();
            
            var profiles = controller.get_audio_profiles(device.object_path);
            if (profiles.length == 0) {
                audio_profile_selector.append("none", "No profiles available");
                audio_profile_selector.set_active_id("none");
                audio_profile_selector.sensitive = false;
                return;
            }
            
            audio_profile_selector.sensitive = true;
            
            foreach (var profile in profiles) {
                audio_profile_selector.append(profile.uuid, profile.get_display_name());
                
                if (profile.connected) {
                    audio_profile_selector.set_active_id(profile.uuid);
                    
                    if (profile.codec != null) {
                        audio_codec_label.label = @"Codec: $(profile.codec)";
                        audio_codec_label.visible = true;
                    } else {
                        audio_codec_label.visible = false;
                    }
                }
            }
        }
        
        /**
         * Get device type string
         */
        private string get_device_type_string(DeviceType type) {
            switch (type) {
                case DeviceType.AUDIO:
                    return "Audio Device";
                case DeviceType.INPUT:
                    return "Input Device";
                case DeviceType.PHONE:
                    return "Phone";
                case DeviceType.COMPUTER:
                    return "Computer";
                case DeviceType.PERIPHERAL:
                    return "Peripheral";
                case DeviceType.WEARABLE:
                    return "Wearable";
                default:
                    return "Unknown";
            }
        }
        
        /**
         * Get connection state string
         */
        private string get_connection_state_string(ConnectionState state) {
            switch (state) {
                case ConnectionState.CONNECTED:
                    return "Connected";
                case ConnectionState.CONNECTING:
                    return "Connecting...";
                case ConnectionState.DISCONNECTING:
                    return "Disconnecting...";
                case ConnectionState.DISCONNECTED:
                default:
                    return "Disconnected";
            }
        }
        
        /**
         * Get signal strength string
         */
        private string get_signal_strength_string(SignalStrength strength) {
            switch (strength) {
                case SignalStrength.EXCELLENT:
                    return "Excellent";
                case SignalStrength.GOOD:
                    return "Good";
                case SignalStrength.FAIR:
                    return "Fair";
                case SignalStrength.WEAK:
                    return "Weak";
                case SignalStrength.VERY_WEAK:
                    return "Very Weak";
                default:
                    return "Unknown";
            }
        }
        
        /**
         * Handle audio profile change
         */
        private void on_audio_profile_changed() {
            var profile_uuid = audio_profile_selector.get_active_id();
            if (profile_uuid == null || profile_uuid == "none") {
                return;
            }
            
            controller.set_audio_profile.begin(device.object_path, profile_uuid);
        }
        
        /**
         * Handle send file button click
         */
        private void on_send_file_clicked() {
            var file_chooser = new Gtk.FileChooserDialog(
                "Select file to send",
                get_toplevel() as Gtk.Window,
                Gtk.FileChooserAction.OPEN,
                "_Cancel", Gtk.ResponseType.CANCEL,
                "_Send", Gtk.ResponseType.ACCEPT
            );
            
            if (file_chooser.run() == Gtk.ResponseType.ACCEPT) {
                var file_path = file_chooser.get_filename();
                send_file.begin(file_path);
            }
            
            file_chooser.destroy();
        }
        
        /**
         * Send file to device
         */
        private async void send_file(string file_path) {
            try {
                active_transfer_path = yield controller.send_file(device.object_path, file_path);
                
                // Show transfer progress UI
                send_file_button.visible = false;
                transfer_progress_box.visible = true;
                transfer_status_label.label = "Sending...";
                
            } catch (Error e) {
                warning("Failed to send file: %s", e.message);
                
                var dialog = new Gtk.MessageDialog(
                    get_toplevel() as Gtk.Window,
                    Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.ERROR,
                    Gtk.ButtonsType.OK,
                    "Failed to send file: %s",
                    e.message
                );
                dialog.run();
                dialog.destroy();
            }
        }
        
        /**
         * Handle cancel transfer button click
         */
        private void on_cancel_transfer_clicked() {
            if (active_transfer_path != null) {
                controller.cancel_transfer.begin(active_transfer_path);
                
                // Hide transfer progress UI
                transfer_progress_box.visible = false;
                send_file_button.visible = true;
                active_transfer_path = null;
            }
        }
        
        /**
         * Handle transfer progress updates
         */
        private void on_transfer_progress(FileTransfer transfer) {
            if (transfer.object_path != active_transfer_path) {
                return;
            }
            
            Idle.add(() => {
                transfer_progress_bar.fraction = transfer.progress_percentage / 100.0;
                transfer_progress_bar.text = @"$(transfer.progress_percentage)%";
                
                transfer_status_label.label = transfer.get_progress_text();
                
                // Check if transfer completed
                if (transfer.status == TransferStatus.COMPLETE) {
                    transfer_progress_box.visible = false;
                    send_file_button.visible = true;
                    active_transfer_path = null;
                    
                    var dialog = new Gtk.MessageDialog(
                        get_toplevel() as Gtk.Window,
                        Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.INFO,
                        Gtk.ButtonsType.OK,
                        "File transfer completed successfully"
                    );
                    dialog.run();
                    dialog.destroy();
                    
                } else if (transfer.status == TransferStatus.ERROR) {
                    transfer_progress_box.visible = false;
                    send_file_button.visible = true;
                    active_transfer_path = null;
                    
                    var dialog = new Gtk.MessageDialog(
                        get_toplevel() as Gtk.Window,
                        Gtk.DialogFlags.MODAL,
                        Gtk.MessageType.ERROR,
                        Gtk.ButtonsType.OK,
                        "File transfer failed"
                    );
                    dialog.run();
                    dialog.destroy();
                }
                
                return Source.REMOVE;
            });
        }
        
        /**
         * Handle trust switch toggle
         */
        private void on_trust_toggled() {
            controller.trust_device.begin(device.object_path, trust_switch.active);
        }
        
        /**
         * Handle block switch toggle
         */
        private void on_block_toggled() {
            // Note: Block functionality would need to be added to controller
            // For now, just update the UI
        }
        
        /**
         * Handle forget button click
         */
        private void on_forget_clicked() {
            var dialog = new Gtk.MessageDialog(
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.YES_NO,
                "Are you sure you want to forget this device?\n\nThis will remove all pairing information."
            );
            
            if (dialog.run() == Gtk.ResponseType.YES) {
                controller.unpair_device.begin(device.object_path);
                back_requested();
            }
            
            dialog.destroy();
        }
        
        /**
         * Handle device state changes
         */
        private void on_device_state_changed(BluetoothDevice updated_device) {
            if (updated_device.object_path == device.object_path) {
                Idle.add(() => {
                    device = updated_device;
                    update_display();
                    return Source.REMOVE;
                });
            }
        }
    }
}
