/**
 * Enhanced Bluetooth Indicator - Pairing Dialog
 * 
 * This file provides pairing authentication dialogs for PIN entry,
 * passkey entry, passkey confirmation, and authorization.
 */

using GLib;
using Gtk;

namespace EnhancedBluetooth {

    /**
     * Pairing dialog for device authentication
     */
    public class PairingDialog : Gtk.Dialog {
        private PairingRequest request;
        private BluetoothController controller;
        
        // UI components
        private Gtk.Box content_box;
        private Gtk.Image device_icon;
        private Gtk.Label device_name_label;
        private Gtk.Label prompt_label;
        
        // Method-specific widgets
        private Gtk.Entry pin_entry;
        private Gtk.SpinButton passkey_entry;
        private Gtk.Label passkey_display_label;
        private Gtk.Label confirmation_label;
        
        public PairingDialog(PairingRequest request, BluetoothController controller, Gtk.Window? parent) {
            Object(
                title: "Bluetooth Pairing",
                transient_for: parent,
                modal: true,
                destroy_with_parent: true,
                window_position: Gtk.WindowPosition.CENTER_ON_PARENT
            );
            
            this.request = request;
            this.controller = controller;
            
            setup_ui();
            setup_buttons();
        }
        
        /**
         * Setup the dialog UI
         */
        private void setup_ui() {
            set_default_size(400, -1);
            set_resizable(false);
            
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            content_box.margin = 20;
            
            // Device header
            var header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            
            device_icon = new Gtk.Image.from_icon_name("bluetooth-symbolic", Gtk.IconSize.DIALOG);
            device_icon.set_pixel_size(48);
            
            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            info_box.hexpand = true;
            info_box.halign = Gtk.Align.START;
            
            device_name_label = new Gtk.Label(request.device_name);
            device_name_label.halign = Gtk.Align.START;
            device_name_label.get_style_context().add_class("device-name-large");
            
            var device_address_label = new Gtk.Label(request.device_path);
            device_address_label.halign = Gtk.Align.START;
            device_address_label.get_style_context().add_class("dim-label");
            
            info_box.pack_start(device_name_label, false, false, 0);
            info_box.pack_start(device_address_label, false, false, 0);
            
            header_box.pack_start(device_icon, false, false, 0);
            header_box.pack_start(info_box, true, true, 0);
            
            content_box.pack_start(header_box, false, false, 0);
            content_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 0);
            
            // Prompt label
            prompt_label = new Gtk.Label(request.get_prompt_text());
            prompt_label.wrap = true;
            prompt_label.max_width_chars = 50;
            prompt_label.halign = Gtk.Align.START;
            content_box.pack_start(prompt_label, false, false, 0);
            
            // Method-specific UI
            setup_method_specific_ui();
            
            get_content_area().add(content_box);
            show_all();
        }
        
        /**
         * Setup method-specific UI elements
         */
        private void setup_method_specific_ui() {
            switch (request.method) {
                case PairingMethod.PIN_CODE:
                    setup_pin_entry_ui();
                    break;
                
                case PairingMethod.PASSKEY_ENTRY:
                    setup_passkey_entry_ui();
                    break;
                
                case PairingMethod.PASSKEY_DISPLAY:
                    setup_passkey_display_ui();
                    break;
                
                case PairingMethod.PASSKEY_CONFIRMATION:
                    setup_passkey_confirmation_ui();
                    break;
                
                case PairingMethod.AUTHORIZATION:
                case PairingMethod.SERVICE_AUTHORIZATION:
                    setup_authorization_ui();
                    break;
            }
        }
        
        /**
         * Setup PIN entry UI
         */
        private void setup_pin_entry_ui() {
            var entry_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            var label = new Gtk.Label("PIN Code:");
            label.halign = Gtk.Align.END;
            
            pin_entry = new Gtk.Entry();
            pin_entry.hexpand = true;
            pin_entry.set_placeholder_text("Enter PIN code");
            pin_entry.set_max_length(16);
            pin_entry.set_visibility(true);
            pin_entry.set_input_purpose(Gtk.InputPurpose.DIGITS);
            pin_entry.activate.connect(() => response(Gtk.ResponseType.OK));
            
            entry_box.pack_start(label, false, false, 0);
            entry_box.pack_start(pin_entry, true, true, 0);
            
            content_box.pack_start(entry_box, false, false, 0);
            
            // Focus the entry
            pin_entry.grab_focus();
        }
        
        /**
         * Setup passkey entry UI
         */
        private void setup_passkey_entry_ui() {
            var entry_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            var label = new Gtk.Label("Passkey:");
            label.halign = Gtk.Align.END;
            
            passkey_entry = new Gtk.SpinButton.with_range(0, 999999, 1);
            passkey_entry.hexpand = true;
            passkey_entry.set_digits(0);
            passkey_entry.set_numeric(true);
            passkey_entry.set_value(0);
            passkey_entry.activate.connect(() => response(Gtk.ResponseType.OK));
            
            entry_box.pack_start(label, false, false, 0);
            entry_box.pack_start(passkey_entry, true, true, 0);
            
            content_box.pack_start(entry_box, false, false, 0);
            
            // Focus the entry
            passkey_entry.grab_focus();
        }
        
        /**
         * Setup passkey display UI
         */
        private void setup_passkey_display_ui() {
            var display_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            display_box.get_style_context().add_class("passkey-display");
            
            var instruction_label = new Gtk.Label("Enter this passkey on the device:");
            instruction_label.halign = Gtk.Align.START;
            instruction_label.get_style_context().add_class("dim-label");
            
            passkey_display_label = new Gtk.Label(@"$(request.passkey)");
            passkey_display_label.halign = Gtk.Align.CENTER;
            passkey_display_label.get_style_context().add_class("passkey-large");
            
            // Format passkey with spacing for readability
            var passkey_str = @"$(request.passkey)";
            while (passkey_str.length < 6) {
                passkey_str = "0" + passkey_str;
            }
            passkey_display_label.label = passkey_str;
            
            display_box.pack_start(instruction_label, false, false, 0);
            display_box.pack_start(passkey_display_label, false, false, 0);
            
            content_box.pack_start(display_box, false, false, 0);
        }
        
        /**
         * Setup passkey confirmation UI
         */
        private void setup_passkey_confirmation_ui() {
            var confirm_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            confirm_box.get_style_context().add_class("passkey-confirmation");
            
            var instruction_label = new Gtk.Label("Does this passkey match the one shown on the device?");
            instruction_label.wrap = true;
            instruction_label.max_width_chars = 50;
            instruction_label.halign = Gtk.Align.START;
            instruction_label.get_style_context().add_class("dim-label");
            
            confirmation_label = new Gtk.Label(@"$(request.passkey)");
            confirmation_label.halign = Gtk.Align.CENTER;
            confirmation_label.get_style_context().add_class("passkey-large");
            
            // Format passkey with spacing for readability
            var passkey_str = @"$(request.passkey)";
            while (passkey_str.length < 6) {
                passkey_str = "0" + passkey_str;
            }
            confirmation_label.label = passkey_str;
            
            confirm_box.pack_start(instruction_label, false, false, 0);
            confirm_box.pack_start(confirmation_label, false, false, 0);
            
            content_box.pack_start(confirm_box, false, false, 0);
        }
        
        /**
         * Setup authorization UI
         */
        private void setup_authorization_ui() {
            var auth_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            
            var warning_icon = new Gtk.Image.from_icon_name("dialog-warning-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            warning_icon.halign = Gtk.Align.CENTER;
            
            var warning_label = new Gtk.Label("This device is requesting authorization to connect.");
            warning_label.wrap = true;
            warning_label.max_width_chars = 50;
            warning_label.halign = Gtk.Align.CENTER;
            warning_label.get_style_context().add_class("dim-label");
            
            auth_box.pack_start(warning_icon, false, false, 0);
            auth_box.pack_start(warning_label, false, false, 0);
            
            content_box.pack_start(auth_box, false, false, 0);
        }
        
        /**
         * Setup dialog buttons
         */
        private void setup_buttons() {
            switch (request.method) {
                case PairingMethod.PIN_CODE:
                case PairingMethod.PASSKEY_ENTRY:
                    add_button("Cancel", Gtk.ResponseType.CANCEL);
                    add_button("Pair", Gtk.ResponseType.OK);
                    set_default_response(Gtk.ResponseType.OK);
                    break;
                
                case PairingMethod.PASSKEY_DISPLAY:
                    add_button("Cancel", Gtk.ResponseType.CANCEL);
                    add_button("Done", Gtk.ResponseType.OK);
                    set_default_response(Gtk.ResponseType.OK);
                    break;
                
                case PairingMethod.PASSKEY_CONFIRMATION:
                    add_button("Reject", Gtk.ResponseType.CANCEL);
                    add_button("Confirm", Gtk.ResponseType.OK);
                    set_default_response(Gtk.ResponseType.OK);
                    break;
                
                case PairingMethod.AUTHORIZATION:
                case PairingMethod.SERVICE_AUTHORIZATION:
                    add_button("Deny", Gtk.ResponseType.CANCEL);
                    add_button("Authorize", Gtk.ResponseType.OK);
                    set_default_response(Gtk.ResponseType.OK);
                    break;
            }
            
            // Connect response handler
            response.connect(on_dialog_response);
        }
        
        /**
         * Handle dialog response
         */
        private void on_dialog_response(int response_id) {
            if (response_id == Gtk.ResponseType.OK) {
                handle_accept();
            } else {
                handle_reject();
            }
        }
        
        /**
         * Handle accept response
         */
        private void handle_accept() {
            switch (request.method) {
                case PairingMethod.PIN_CODE:
                    var pin = pin_entry.get_text();
                    if (pin.length == 0) {
                        show_error("Please enter a PIN code");
                        return;
                    }
                    request.response_provided(true, pin);
                    break;
                
                case PairingMethod.PASSKEY_ENTRY:
                    var passkey = (uint32)passkey_entry.get_value();
                    request.response_provided(true, @"$passkey");
                    break;
                
                case PairingMethod.PASSKEY_DISPLAY:
                case PairingMethod.PASSKEY_CONFIRMATION:
                case PairingMethod.AUTHORIZATION:
                case PairingMethod.SERVICE_AUTHORIZATION:
                    request.response_provided(true, null);
                    break;
            }
            
            destroy();
        }
        
        /**
         * Handle reject response
         */
        private void handle_reject() {
            request.response_provided(false, null);
            destroy();
        }
        
        /**
         * Show error message
         */
        private void show_error(string message) {
            var error_dialog = new Gtk.MessageDialog(
                this,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.ERROR,
                Gtk.ButtonsType.OK,
                message
            );
            error_dialog.run();
            error_dialog.destroy();
        }
    }
    
    /**
     * Simple pairing notification for display-only passkeys
     */
    public class PairingNotification : Gtk.Window {
        private PairingRequest request;
        
        public PairingNotification(PairingRequest request) {
            Object(
                type: Gtk.WindowType.POPUP,
                type_hint: Gdk.WindowTypeHint.NOTIFICATION,
                skip_taskbar_hint: true,
                skip_pager_hint: true,
                decorated: false
            );
            
            this.request = request;
            
            setup_ui();
            position_notification();
            
            // Auto-close after 30 seconds
            Timeout.add_seconds(30, () => {
                destroy();
                return Source.REMOVE;
            });
        }
        
        /**
         * Setup notification UI
         */
        private void setup_ui() {
            set_default_size(300, -1);
            
            var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            main_box.margin = 16;
            main_box.get_style_context().add_class("notification");
            
            // Header
            var header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            var icon = new Gtk.Image.from_icon_name("bluetooth-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            
            var title_label = new Gtk.Label("Bluetooth Pairing");
            title_label.halign = Gtk.Align.START;
            title_label.hexpand = true;
            title_label.get_style_context().add_class("notification-title");
            
            var close_button = new Gtk.Button.from_icon_name("window-close-symbolic", Gtk.IconSize.BUTTON);
            close_button.get_style_context().add_class("flat");
            close_button.clicked.connect(() => destroy());
            
            header_box.pack_start(icon, false, false, 0);
            header_box.pack_start(title_label, true, true, 0);
            header_box.pack_end(close_button, false, false, 0);
            
            // Device name
            var device_label = new Gtk.Label(request.device_name);
            device_label.halign = Gtk.Align.START;
            device_label.get_style_context().add_class("device-name");
            
            // Passkey display
            if (request.passkey != null) {
                var passkey_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
                
                var instruction_label = new Gtk.Label("Enter this passkey on the device:");
                instruction_label.halign = Gtk.Align.START;
                instruction_label.get_style_context().add_class("dim-label");
                
                var passkey_str = @"$(request.passkey)";
                while (passkey_str.length < 6) {
                    passkey_str = "0" + passkey_str;
                }
                
                var passkey_label = new Gtk.Label(passkey_str);
                passkey_label.halign = Gtk.Align.CENTER;
                passkey_label.get_style_context().add_class("passkey-large");
                
                passkey_box.pack_start(instruction_label, false, false, 0);
                passkey_box.pack_start(passkey_label, false, false, 0);
                
                main_box.pack_start(header_box, false, false, 0);
                main_box.pack_start(device_label, false, false, 0);
                main_box.pack_start(passkey_box, false, false, 0);
            } else {
                main_box.pack_start(header_box, false, false, 0);
                main_box.pack_start(device_label, false, false, 0);
            }
            
            add(main_box);
            show_all();
        }
        
        /**
         * Position notification in top-right corner
         */
        private void position_notification() {
            var screen = get_screen();
            var monitor = screen.get_display().get_primary_monitor();
            var geometry = monitor.get_geometry();
            
            int x = geometry.x + geometry.width - 320;
            int y = geometry.y + 20;
            
            move(x, y);
        }
    }
}
