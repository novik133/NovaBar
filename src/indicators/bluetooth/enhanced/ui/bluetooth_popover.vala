/**
 * Enhanced Bluetooth Indicator - Bluetooth Popover Container
 * 
 * This file provides the main popover container for the Bluetooth indicator,
 * embedding the BluetoothPanel and handling popover lifecycle.
 */

using GLib;
using Gtk;

namespace EnhancedBluetooth {

    /**
     * Main Bluetooth popover container
     * 
     * This class provides the popover window that displays the Bluetooth management
     * panel. It handles sizing, positioning, show/hide events, and integrates with
     * the BluetoothController for data.
     */
    public class BluetoothPopover : Gtk.Window {
        private BluetoothController controller;
        private BluetoothPanel panel;
        private Gtk.Box main_box;
        
        // Keyboard navigation
        private KeyboardNavigationHelper? keyboard_nav;
        
        /**
         * Signal emitted when the popover is closed
         */
        public signal void closed();
        
        /**
         * Signal emitted when refresh is requested
         */
        public signal void refresh_requested();
        
        public BluetoothPopover(BluetoothController controller) {
            GLib.Object(type: Gtk.WindowType.POPUP);
            Backend.setup_popup(this, 28);
            
            this.controller = controller;
            
            setup_popover_properties();
            setup_ui();
            setup_event_handlers();
            setup_keyboard_navigation();
            
            debug("BluetoothPopover: Container initialized");
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
            
            // Custom drawing for rounded corners and transparency
            draw.connect((cr) => {
                int w = get_allocated_width();
                int h = get_allocated_height();
                double r = 12;
                
                // Draw rounded rectangle path
                cr.new_sub_path();
                cr.arc(w - r, r, r, -Math.PI/2, 0);
                cr.arc(w - r, h - r, r, 0, Math.PI/2);
                cr.arc(r, h - r, r, Math.PI/2, Math.PI);
                cr.arc(r, r, r, Math.PI, 3*Math.PI/2);
                cr.close_path();
                
                // Fill with semi-transparent dark background
                cr.set_source_rgba(0.24, 0.24, 0.24, 0.95);
                cr.fill_preserve();
                
                // Draw border
                cr.set_source_rgba(1, 1, 1, 0.15);
                cr.set_line_width(1);
                cr.stroke();
                
                return false;
            });
            
            // Handle clicks outside the popover to close it
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
            
            // NOTE: Do NOT use focus_out_event to close the popup.
            // ComboBox dropdowns, MenuButtons, and other child widgets
            // steal focus when opened, which would incorrectly close
            // the entire popup.
            
            get_style_context().add_class("bluetooth-popover");
            
            debug("BluetoothPopover: Properties setup complete");
        }
        
        /**
         * Release input grab
         */
        private void ungrab_input() {
            var seat = Gdk.Display.get_default().get_default_seat();
            if (seat != null) seat.ungrab();
        }
        
        /**
         * Show the popover at specific coordinates
         */
        public void show_at(int x, int y) {
            show_all();
            Backend.position_popup(this, x, y, 28);
            
            // Grab pointer on X11 so clicks outside dismiss the popup.
            // Only grab POINTER — grabbing ALL prevents ComboBox dropdowns
            // and other child widgets from receiving keyboard/focus events.
            if (Backend.is_x11()) {
                var seat = Gdk.Display.get_default().get_default_seat();
                if (seat != null && get_window() != null) {
                    seat.grab(get_window(), Gdk.SeatCapabilities.ALL_POINTING, true, null, null, null);
                }
            }
            
            present();
            
            debug("BluetoothPopover: Shown at (%d, %d)", x, y);
        }
        
        /**
         * Show the popover (compatibility method)
         */
        public void popup() {
            // No-op for compatibility; use show_at() instead
            debug("BluetoothPopover: popup() called - use show_at() instead");
        }
        
        /**
         * Setup the main UI structure
         */
        private void setup_ui() {
            main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            
            // Create header bar
            var header_bar = create_header_bar();
            main_box.pack_start(header_bar, false, false, 0);
            
            // Add separator
            var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            main_box.pack_start(separator, false, false, 0);
            
            // Create and embed BluetoothPanel
            panel = new BluetoothPanel(controller);
            main_box.pack_start(panel, true, true, 0);
            
            add(main_box);
            
            debug("BluetoothPopover: UI structure setup complete");
        }
        
        /**
         * Create the header bar
         */
        private Gtk.HeaderBar create_header_bar() {
            var header_bar = new Gtk.HeaderBar();
            header_bar.set_show_close_button(false);
            header_bar.set_title("Bluetooth");
            header_bar.get_style_context().add_class("popover-header");
            
            // Refresh button
            var refresh_button = new Gtk.Button.from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON);
            refresh_button.set_tooltip_text("Refresh device list");
            refresh_button.get_style_context().add_class("flat");
            refresh_button.clicked.connect(on_refresh_clicked);
            AccessibilityHelper.mark_as_button(refresh_button, "Refresh Bluetooth device list");
            
            // Settings button
            var settings_button = new Gtk.Button.from_icon_name("preferences-system-symbolic", Gtk.IconSize.BUTTON);
            settings_button.set_tooltip_text("Bluetooth settings");
            settings_button.get_style_context().add_class("flat");
            settings_button.clicked.connect(on_settings_clicked);
            AccessibilityHelper.mark_as_button(settings_button, "Open Bluetooth settings");
            
            header_bar.pack_end(settings_button);
            header_bar.pack_end(refresh_button);
            
            // Add focus indicators
            new FocusIndicator(refresh_button);
            new FocusIndicator(settings_button);
            
            return header_bar;
        }
        
        /**
         * Setup event handlers
         */
        private void setup_event_handlers() {
            // Panel events
            panel.refresh_requested.connect(() => {
                refresh_requested();
            });
            
            // Controller events
            controller.adapter_state_changed.connect(on_adapter_state_changed);
            controller.device_found.connect(on_device_found);
            controller.device_connected.connect(on_device_connected);
            controller.device_disconnected.connect(on_device_disconnected);
            controller.error_occurred.connect(on_error_occurred);
            
            // Key press events for navigation
            key_press_event.connect(on_key_press);
            
            debug("BluetoothPopover: Event handlers setup complete");
        }
        
        /**
         * Setup keyboard navigation
         */
        private void setup_keyboard_navigation() {
            // Initialize keyboard navigation helper
            keyboard_nav = new KeyboardNavigationHelper(this);
            
            // Rebuild focus chain when popover is shown
            show.connect(() => {
                if (keyboard_nav != null) {
                    keyboard_nav.build_focus_chain();
                }
            });
            
            debug("BluetoothPopover: Keyboard navigation setup complete");
        }
        
        /**
         * Refresh popover content
         */
        public void refresh() {
            panel.refresh();
            debug("BluetoothPopover: Content refreshed");
        }
        
        /**
         * Apply search filter to device list
         */
        public void apply_search_filter(string search_term) {
            panel.apply_search_filter(search_term);
        }
        
        /**
         * Handle refresh button click
         */
        private void on_refresh_clicked() {
            refresh();
            refresh_requested();
        }
        
        /**
         * Handle settings button click
         */
        private void on_settings_clicked() {
            // Open system Bluetooth settings
            try {
                // Try common Bluetooth settings applications
                string[] commands = {
                    "gnome-control-center bluetooth",
                    "blueman-manager",
                    "blueberry",
                    "systemsettings5 kcm_bluetooth"
                };
                
                bool launched = false;
                foreach (var cmd in commands) {
                    try {
                        Process.spawn_command_line_async(cmd);
                        launched = true;
                        break;
                    } catch (Error e) {
                        // Try next command
                        continue;
                    }
                }
                
                if (!launched) {
                    warning("BluetoothPopover: No Bluetooth settings application found");
                }
            } catch (Error e) {
                warning("BluetoothPopover: Failed to open settings: %s", e.message);
            }
        }
        
        /**
         * Handle adapter state changes
         */
        private void on_adapter_state_changed(BluetoothAdapter adapter) {
            // Panel will handle this, but we can add popover-level logic here if needed
            debug("BluetoothPopover: Adapter state changed: %s", adapter.object_path);
        }
        
        /**
         * Handle device found
         */
        private void on_device_found(BluetoothDevice device) {
            // Panel will handle this
            debug("BluetoothPopover: Device found: %s", device.get_display_name());
        }
        
        /**
         * Handle device connected
         */
        private void on_device_connected(BluetoothDevice device) {
            // Panel will handle this
            debug("BluetoothPopover: Device connected: %s", device.get_display_name());
        }
        
        /**
         * Handle device disconnected
         */
        private void on_device_disconnected(BluetoothDevice device) {
            // Panel will handle this
            debug("BluetoothPopover: Device disconnected: %s", device.get_display_name());
        }
        
        /**
         * Handle errors
         */
        private void on_error_occurred(BluetoothError error) {
            warning("BluetoothPopover: Error occurred: %s", error.message);
            // Could show error notification in popover if desired
        }
        
        /**
         * Handle key press events for navigation
         */
        private bool on_key_press(Gdk.EventKey event) {
            // Handle Escape key to close popover
            if (event.keyval == KeyboardShortcuts.KEY_ESCAPE) {
                ungrab_input();
                hide();
                closed();
                return true;
            }
            
            // Handle F5 for refresh
            if (event.keyval == KeyboardShortcuts.KEY_REFRESH) {
                refresh();
                return true;
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
         * Get the embedded panel
         */
        public BluetoothPanel get_panel() {
            return panel;
        }
        
        /**
         * Check if popover is currently visible
         */
        public new bool get_visible() {
            return visible;
        }
    }
}
