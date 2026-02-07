/**
 * Enhanced Bluetooth Indicator - Main Bluetooth Panel
 * 
 * This file provides the main Bluetooth management panel with device list,
 * filtering, sorting, and device action buttons.
 */

using GLib;
using Gtk;

namespace EnhancedBluetooth {

    /**
     * Main Bluetooth management panel
     */
    public class BluetoothPanel : Gtk.Box {
        private BluetoothController controller;
        private bool is_refreshing;
        
        // UI components
        private Gtk.Box header_box;
        private Gtk.ComboBoxText adapter_selector;
        private Gtk.Button scan_button;
        private Gtk.Spinner discovery_spinner;
        private Gtk.Label discovery_label;
        
        private Gtk.Box filter_box;
        private Gtk.ComboBoxText device_type_filter;
        private Gtk.ComboBoxText connection_filter;
        private Gtk.ComboBoxText sort_selector;
        
        private Gtk.ScrolledWindow device_list_scroll;
        private Gtk.ListBox device_list;
        private Gtk.Label empty_state_label;
        
        // Accessibility helpers
        private KeyboardNavigationHelper? keyboard_nav;
        private ListNavigationHelper? list_nav;
        private AccessibilityHelper accessibility;
        private BluetoothStatusAnnouncer? status_announcer;
        
        // State
        private string? current_adapter_path;
        private DeviceType current_device_type_filter;
        private ConnectionFilter current_connection_filter;
        private EnhancedBluetooth.SortOrder current_sort_order;
        private string current_search_term;
        private HashTable<string, DeviceRow> device_rows;
        private string? last_connected_device_path;
        
        /**
         * Signal emitted when panel needs refresh
         */
        public signal void refresh_requested();
        
        /**
         * Signal emitted when device is selected
         */
        public signal void device_selected(BluetoothDevice device);
        
        public bool refreshing { 
            get { return is_refreshing; } 
        }
        
        public BluetoothPanel(BluetoothController controller) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            
            this.controller = controller;
            this.is_refreshing = false;
            this.current_device_type_filter = DeviceType.UNKNOWN; // All devices
            this.current_connection_filter = ConnectionFilter.ALL;
            this.current_sort_order = EnhancedBluetooth.SortOrder.NAME;
            this.current_search_term = "";
            this.device_rows = new HashTable<string, DeviceRow>(str_hash, str_equal);
            this.last_connected_device_path = null;
            
            // Initialize accessibility helpers
            this.accessibility = AccessibilityHelper.get_instance();
            this.status_announcer = new BluetoothStatusAnnouncer(controller);
            
            margin = 12;
            get_style_context().add_class("bluetooth-panel");
            
            // Enable keyboard event handling
            can_focus = true;
            
            setup_ui();
            setup_event_handlers();
            setup_keyboard_shortcuts();
            setup_accessibility();
            refresh();
        }
        
        /**
         * Setup the panel UI
         */
        private void setup_ui() {
            // Header with adapter selector and scan button
            setup_header();
            pack_start(header_box, false, false, 0);
            
            // Separator
            pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 4);
            
            // Filter and sort controls
            setup_filters();
            pack_start(filter_box, false, false, 0);
            
            // Device list
            setup_device_list();
            pack_start(device_list_scroll, true, true, 0);
        }
        
        /**
         * Setup header with adapter selector and scan button
         */
        private void setup_header() {
            header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            header_box.get_style_context().add_class("panel-header");
            
            // Adapter selector
            var adapter_label = new Gtk.Label("Adapter:");
            adapter_label.halign = Gtk.Align.START;
            
            adapter_selector = new Gtk.ComboBoxText();
            adapter_selector.set_tooltip_text("Select Bluetooth adapter");
            adapter_selector.hexpand = true;
            
            // Scan button with spinner
            var scan_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            
            scan_button = new Gtk.Button.with_label("Scan");
            scan_button.set_tooltip_text("Scan for nearby Bluetooth devices");
            scan_button.get_style_context().add_class("suggested-action");
            
            discovery_spinner = new Gtk.Spinner();
            discovery_spinner.set_size_request(16, 16);
            discovery_spinner.no_show_all = true;
            
            discovery_label = new Gtk.Label("");
            discovery_label.get_style_context().add_class("dim-label");
            discovery_label.no_show_all = true;
            
            scan_box.pack_start(scan_button, false, false, 0);
            scan_box.pack_start(discovery_spinner, false, false, 0);
            scan_box.pack_start(discovery_label, false, false, 0);
            
            header_box.pack_start(adapter_label, false, false, 0);
            header_box.pack_start(adapter_selector, true, true, 0);
            header_box.pack_end(scan_box, false, false, 0);
        }
        
        /**
         * Setup filter and sort controls
         */
        private void setup_filters() {
            filter_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            filter_box.get_style_context().add_class("filter-box");
            
            // Device type filter
            var type_label = new Gtk.Label("Type:");
            type_label.halign = Gtk.Align.START;
            
            device_type_filter = new Gtk.ComboBoxText();
            device_type_filter.append("all", "All Devices");
            device_type_filter.append("audio", "Audio");
            device_type_filter.append("input", "Input");
            device_type_filter.append("phone", "Phone");
            device_type_filter.append("computer", "Computer");
            device_type_filter.append("peripheral", "Peripheral");
            device_type_filter.append("wearable", "Wearable");
            device_type_filter.set_active_id("all");
            device_type_filter.set_tooltip_text("Filter devices by type");
            
            // Connection status filter
            var connection_label = new Gtk.Label("Status:");
            connection_label.halign = Gtk.Align.START;
            
            connection_filter = new Gtk.ComboBoxText();
            connection_filter.append("all", "All");
            connection_filter.append("connected", "Connected");
            connection_filter.append("paired", "Paired");
            connection_filter.append("available", "Available");
            connection_filter.set_active_id("all");
            connection_filter.set_tooltip_text("Filter devices by connection status");
            
            // Sort order selector
            var sort_label = new Gtk.Label("Sort:");
            sort_label.halign = Gtk.Align.START;
            
            sort_selector = new Gtk.ComboBoxText();
            sort_selector.append("name", "Name");
            sort_selector.append("signal", "Signal Strength");
            sort_selector.append("status", "Connection Status");
            sort_selector.set_active_id("name");
            sort_selector.set_tooltip_text("Sort devices by");
            
            filter_box.pack_start(type_label, false, false, 0);
            filter_box.pack_start(device_type_filter, false, false, 0);
            filter_box.pack_start(connection_label, false, false, 0);
            filter_box.pack_start(connection_filter, false, false, 0);
            filter_box.pack_start(sort_label, false, false, 0);
            filter_box.pack_start(sort_selector, false, false, 0);
        }
        
        /**
         * Setup device list
         */
        private void setup_device_list() {
            device_list_scroll = new Gtk.ScrolledWindow(null, null);
            device_list_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            device_list_scroll.set_size_request(-1, 300);
            
            device_list = new Gtk.ListBox();
            device_list.set_selection_mode(Gtk.SelectionMode.SINGLE);
            device_list.set_activate_on_single_click(false);
            device_list.get_style_context().add_class("device-list");
            
            // Empty state
            empty_state_label = new Gtk.Label("No devices found");
            empty_state_label.get_style_context().add_class("dim-label");
            empty_state_label.margin = 40;
            device_list.set_placeholder(empty_state_label);
            
            device_list_scroll.add(device_list);
        }
        
        /**
         * Setup event handlers
         */
        private void setup_event_handlers() {
            // Adapter selector
            adapter_selector.changed.connect(on_adapter_changed);
            
            // Scan button
            scan_button.clicked.connect(on_scan_clicked);
            
            // Filters
            device_type_filter.changed.connect(on_filter_changed);
            connection_filter.changed.connect(on_filter_changed);
            sort_selector.changed.connect(on_sort_changed);
            
            // Device list
            device_list.row_activated.connect(on_device_row_activated);
            
            // Controller events
            controller.adapter_state_changed.connect(on_adapter_state_changed);
            controller.device_found.connect(on_device_found);
            controller.device_connected.connect(on_device_connected);
            controller.device_disconnected.connect(on_device_disconnected);
        }
        
        /**
         * Refresh panel content
         */
        public void refresh() {
            is_refreshing = true;
            
            // Update adapter list
            update_adapter_list();
            
            // Update device list
            update_device_list();
            
            is_refreshing = false;
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
                scan_button.sensitive = false;
                return;
            }
            
            adapter_selector.sensitive = true;
            
            foreach (var adapter in adapters) {
                var display_name = adapter.get_display_name();
                adapter_selector.append(adapter.object_path, display_name);
            }
            
            // Select default adapter
            var default_adapter = adapters[0];
            adapter_selector.set_active_id(default_adapter.object_path);
            current_adapter_path = default_adapter.object_path;
            
            scan_button.sensitive = default_adapter.powered;
        }
        
        /**
         * Update device list
         */
        private void update_device_list() {
            // Clear existing rows
            device_list.foreach((widget) => {
                device_list.remove(widget);
            });
            device_rows.remove_all();
            
            if (current_adapter_path == null) {
                return;
            }
            
            // Get devices for current adapter
            var devices = controller.get_devices(current_adapter_path);
            
            // Apply filters
            var filtered_devices = apply_filters(devices);
            
            // Apply sorting
            var sorted_devices = apply_sorting(filtered_devices);
            
            // Create device rows
            foreach (var device in sorted_devices) {
                add_device_row(device);
            }
            
            device_list.show_all();
        }
        
        /**
         * Apply filters to device list
         */
        private GenericArray<BluetoothDevice> apply_filters(GenericArray<BluetoothDevice> devices) {
            var filtered = new GenericArray<BluetoothDevice>();
            
            for (uint i = 0; i < devices.length; i++) {
                var device = devices[i];
                // Apply device type filter
                if (current_device_type_filter != DeviceType.UNKNOWN) {
                    if (device.device_type != current_device_type_filter) {
                        continue;
                    }
                }
                
                // Apply connection status filter
                if (current_connection_filter != ConnectionFilter.ALL) {
                    if (current_connection_filter == ConnectionFilter.CONNECTED && !device.connected) {
                        continue;
                    }
                    if (current_connection_filter == ConnectionFilter.PAIRED && !device.paired) {
                        continue;
                    }
                    if (current_connection_filter == ConnectionFilter.AVAILABLE && device.paired) {
                        continue;
                    }
                }
                
                // Apply search filter
                if (current_search_term.length > 0) {
                    var name_lower = device.get_display_name().down();
                    var address_lower = device.address.down();
                    var search_lower = current_search_term.down();
                    
                    if (!name_lower.contains(search_lower) && !address_lower.contains(search_lower)) {
                        continue;
                    }
                }
                
                filtered.add(device);
            }
            
            return filtered;
        }
        
        /**
         * Apply sorting to device list
         */
        private GenericArray<BluetoothDevice> apply_sorting(GenericArray<BluetoothDevice> devices) {
            var sorted = new GenericArray<BluetoothDevice>();
            
            // Copy devices to array for sorting
            for (uint i = 0; i < devices.length; i++) {
                sorted.add(devices[i]);
            }
            
            // Capture sort order in local variable for lambda
            var sort_order = current_sort_order;
            
            sorted.sort_with_data((a, b) => {
                if (sort_order == EnhancedBluetooth.SortOrder.NAME) {
                    return a.get_display_name().collate(b.get_display_name());
                } else if (sort_order == EnhancedBluetooth.SortOrder.SIGNAL_STRENGTH) {
                    // Higher RSSI first (less negative)
                    return b.rssi - a.rssi;
                } else if (sort_order == EnhancedBluetooth.SortOrder.CONNECTION_STATUS) {
                    // Connected > Paired > Available
                    int a_priority = a.connected ? 2 : (a.paired ? 1 : 0);
                    int b_priority = b.connected ? 2 : (b.paired ? 1 : 0);
                    return b_priority - a_priority;
                } else {
                    return 0;
                }
            });
            
            return sorted;
        }
        
        /**
         * Add device row to list
         */
        private void add_device_row(BluetoothDevice device) {
            var row = new DeviceRow(device, controller);
            device_rows[device.object_path] = row;
            device_list.add(row);
        }
        
        /**
         * Apply search filter
         */
        public void apply_search_filter(string search_term) {
            current_search_term = search_term;
            update_device_list();
        }
        
        /**
         * Focus first search result
         */
        public void focus_first_result() {
            var first_row = device_list.get_row_at_index(0);
            if (first_row != null) {
                device_list.select_row(first_row);
                first_row.grab_focus();
            }
        }
        
        /**
         * Handle adapter selection change
         */
        private void on_adapter_changed() {
            var adapter_path = adapter_selector.get_active_id();
            if (adapter_path == null || adapter_path == "none") {
                current_adapter_path = null;
                scan_button.sensitive = false;
                update_device_list();
                return;
            }
            
            current_adapter_path = adapter_path;
            
            // Update scan button state
            var adapters = controller.get_adapters();
            foreach (var adapter in adapters) {
                if (adapter.object_path == adapter_path) {
                    scan_button.sensitive = adapter.powered;
                    break;
                }
            }
            
            update_device_list();
        }
        
        /**
         * Handle scan button click
         */
        private void on_scan_clicked() {
            if (current_adapter_path == null) {
                return;
            }
            
            // Check if already discovering
            var adapters = controller.get_adapters();
            foreach (var adapter in adapters) {
                if (adapter.object_path == current_adapter_path) {
                    if (adapter.discovering) {
                        // Stop discovery — must use .begin() since we're in a sync method
                        stop_discovery.begin();
                    } else {
                        // Start discovery — must use .begin() since we're in a sync method
                        start_discovery.begin();
                    }
                    break;
                }
            }
        }
        
        /**
         * Start device discovery
         */
        private async void start_discovery() {
            if (current_adapter_path == null) {
                return;
            }
            
            try {
                yield controller.start_discovery(current_adapter_path);
                
                // Update UI
                scan_button.label = "Stop";
                scan_button.get_style_context().remove_class("suggested-action");
                scan_button.get_style_context().add_class("destructive-action");
                
                discovery_spinner.visible = true;
                discovery_spinner.active = true;
                discovery_label.label = "Scanning...";
                discovery_label.visible = true;
                
            } catch (Error e) {
                warning("Failed to start discovery: %s", e.message);
            }
        }
        
        /**
         * Stop device discovery
         */
        private async void stop_discovery() {
            if (current_adapter_path == null) {
                return;
            }
            
            try {
                yield controller.stop_discovery(current_adapter_path);
                
                // Update UI
                scan_button.label = "Scan";
                scan_button.get_style_context().remove_class("destructive-action");
                scan_button.get_style_context().add_class("suggested-action");
                
                discovery_spinner.visible = false;
                discovery_spinner.active = false;
                discovery_label.visible = false;
                
            } catch (Error e) {
                warning("Failed to stop discovery: %s", e.message);
            }
        }
        
        /**
         * Handle filter changes
         */
        private void on_filter_changed() {
            // Update device type filter
            var type_id = device_type_filter.get_active_id();
            switch (type_id) {
                case "audio":
                    current_device_type_filter = DeviceType.AUDIO;
                    break;
                case "input":
                    current_device_type_filter = DeviceType.INPUT;
                    break;
                case "phone":
                    current_device_type_filter = DeviceType.PHONE;
                    break;
                case "computer":
                    current_device_type_filter = DeviceType.COMPUTER;
                    break;
                case "peripheral":
                    current_device_type_filter = DeviceType.PERIPHERAL;
                    break;
                case "wearable":
                    current_device_type_filter = DeviceType.WEARABLE;
                    break;
                default:
                    current_device_type_filter = DeviceType.UNKNOWN;
                    break;
            }
            
            // Update connection filter
            var connection_id = connection_filter.get_active_id();
            switch (connection_id) {
                case "connected":
                    current_connection_filter = ConnectionFilter.CONNECTED;
                    break;
                case "paired":
                    current_connection_filter = ConnectionFilter.PAIRED;
                    break;
                case "available":
                    current_connection_filter = ConnectionFilter.AVAILABLE;
                    break;
                default:
                    current_connection_filter = ConnectionFilter.ALL;
                    break;
            }
            
            update_device_list();
        }
        
        /**
         * Handle sort order change
         */
        private void on_sort_changed() {
            var sort_id = sort_selector.get_active_id();
            switch (sort_id) {
                case "signal":
                    current_sort_order = EnhancedBluetooth.SortOrder.SIGNAL_STRENGTH;
                    break;
                case "status":
                    current_sort_order = EnhancedBluetooth.SortOrder.CONNECTION_STATUS;
                    break;
                default:
                    current_sort_order = EnhancedBluetooth.SortOrder.NAME;
                    break;
            }
            
            update_device_list();
        }
        
        /**
         * Handle device row activation
         */
        private void on_device_row_activated(Gtk.ListBoxRow row) {
            if (row is DeviceRow) {
                var device_row = row as DeviceRow;
                device_selected(device_row.device);
            }
        }
        
        /**
         * Handle adapter state changes
         */
        private void on_adapter_state_changed(BluetoothAdapter adapter) {
            Idle.add(() => {
                if (adapter.object_path == current_adapter_path) {
                    scan_button.sensitive = adapter.powered;
                    
                    // Update discovery UI
                    if (!adapter.discovering) {
                        scan_button.label = "Scan";
                        scan_button.get_style_context().remove_class("destructive-action");
                        scan_button.get_style_context().add_class("suggested-action");
                        discovery_spinner.visible = false;
                        discovery_spinner.active = false;
                        discovery_label.visible = false;
                    }
                }
                return Source.REMOVE;
            });
        }
        
        /**
         * Handle device found
         */
        private void on_device_found(BluetoothDevice device) {
            Idle.add(() => {
                if (device.adapter_path == current_adapter_path) {
                    update_device_list();
                }
                return Source.REMOVE;
            });
        }
        
        /**
         * Handle device connected
         */
        private void on_device_connected(BluetoothDevice device) {
            Idle.add(() => {
                if (device.adapter_path == current_adapter_path) {
                    var row = device_rows[device.object_path];
                    if (row != null) {
                        row.update_device(device);
                    }
                    update_last_connected_device(device);
                }
                return Source.REMOVE;
            });
        }
        
        /**
         * Handle device disconnected
         */
        private void on_device_disconnected(BluetoothDevice device) {
            Idle.add(() => {
                if (device.adapter_path == current_adapter_path) {
                    var row = device_rows[device.object_path];
                    if (row != null) {
                        row.update_device(device);
                    }
                }
                return Source.REMOVE;
            });
        }
        
        /**
         * Setup keyboard shortcuts
         */
        private void setup_keyboard_shortcuts() {
            key_press_event.connect(on_key_press);
        }
        
        /**
         * Handle key press events for keyboard shortcuts
         */
        private bool on_key_press(Gdk.EventKey event) {
            // Ctrl+B: Toggle Bluetooth power
            if (KeyboardShortcuts.matches_shortcut(event, KeyboardShortcuts.KEY_BLUETOOTH_TOGGLE, Gdk.ModifierType.CONTROL_MASK)) {
                toggle_bluetooth_power();
                return true;
            }
            
            // Ctrl+S: Start/stop scan
            if (KeyboardShortcuts.matches_shortcut(event, KeyboardShortcuts.KEY_SCAN, Gdk.ModifierType.CONTROL_MASK)) {
                on_scan_clicked();
                return true;
            }
            
            // Ctrl+L: Connect to last device
            if (KeyboardShortcuts.matches_shortcut(event, KeyboardShortcuts.KEY_LAST_DEVICE, Gdk.ModifierType.CONTROL_MASK)) {
                connect_to_last_device();
                return true;
            }
            
            // Escape: Close popover (handled by parent)
            if (event.keyval == KeyboardShortcuts.KEY_ESCAPE) {
                return false; // Let parent handle
            }
            
            return false;
        }
        
        /**
         * Toggle Bluetooth power for current adapter
         */
        private void toggle_bluetooth_power() {
            if (current_adapter_path == null) {
                accessibility.announce("No Bluetooth adapter available", AnnouncementPriority.HIGH);
                return;
            }
            
            var adapters = controller.get_adapters();
            foreach (var adapter in adapters) {
                if (adapter.object_path == current_adapter_path) {
                    var new_state = !adapter.powered;
                    controller.set_adapter_powered.begin(adapter.object_path, new_state, (obj, res) => {
                        try {
                            controller.set_adapter_powered.end(res);
                            accessibility.announce(
                                new_state ? "Bluetooth enabled" : "Bluetooth disabled",
                                AnnouncementPriority.NORMAL
                            );
                        } catch (Error e) {
                            accessibility.announce(
                                @"Failed to toggle Bluetooth: $(e.message)",
                                AnnouncementPriority.HIGH
                            );
                        }
                    });
                    break;
                }
            }
        }
        
        /**
         * Connect to last connected device
         */
        private void connect_to_last_device() {
            if (last_connected_device_path == null) {
                // Find most recently connected device
                var devices = controller.get_devices(current_adapter_path);
                BluetoothDevice? last_device = null;
                
                foreach (var device in devices) {
                    if (device.paired && !device.connected) {
                        if (last_device == null || 
                            (device.last_seen != null && last_device.last_seen != null &&
                             device.last_seen.compare(last_device.last_seen) > 0)) {
                            last_device = device;
                        }
                    }
                }
                
                if (last_device != null) {
                    last_connected_device_path = last_device.object_path;
                } else {
                    accessibility.announce("No paired devices available", AnnouncementPriority.NORMAL);
                    return;
                }
            }
            
            // Connect to the device
            controller.connect_device.begin(last_connected_device_path, (obj, res) => {
                try {
                    controller.connect_device.end(res);
                    BluetoothDevice? device = null;
                    var devices = controller.get_devices(current_adapter_path);
                    for (uint i = 0; i < devices.length; i++) {
                        if (devices[i].object_path == last_connected_device_path) {
                            device = devices[i];
                            break;
                        }
                    }
                    if (device != null) {
                        accessibility.announce(
                            @"Connecting to $(device.get_display_name())",
                            AnnouncementPriority.NORMAL
                        );
                    }
                } catch (Error e) {
                    accessibility.announce(
                        @"Failed to connect: $(e.message)",
                        AnnouncementPriority.HIGH
                    );
                }
            });
        }
        
        /**
         * Setup accessibility features
         */
        private void setup_accessibility() {
            // Setup keyboard navigation
            keyboard_nav = new KeyboardNavigationHelper(this);
            
            // Setup list navigation
            list_nav = new ListNavigationHelper(device_list);
            list_nav.context_menu_requested.connect(on_device_context_menu);
            
            // Add announcement label to UI
            var announcement_label = accessibility.get_announcement_label();
            if (announcement_label != null) {
                pack_end(announcement_label, false, false, 0);
            }
            
            // Set accessible properties for main components
            AccessibilityHelper.mark_as_combo_box(adapter_selector, "Bluetooth adapter selector");
            AccessibilityHelper.mark_as_button(scan_button, "Scan for devices");
            AccessibilityHelper.mark_as_combo_box(device_type_filter, "Device type filter");
            AccessibilityHelper.mark_as_combo_box(connection_filter, "Connection status filter");
            AccessibilityHelper.mark_as_combo_box(sort_selector, "Sort order");
            AccessibilityHelper.mark_as_list(device_list, "Bluetooth devices");
            
            // Add focus indicators
            new FocusIndicator(adapter_selector);
            new FocusIndicator(scan_button);
            new FocusIndicator(device_type_filter);
            new FocusIndicator(connection_filter);
            new FocusIndicator(sort_selector);
            
            // Set tooltips with keyboard shortcuts
            scan_button.set_tooltip_text("Scan for nearby Bluetooth devices (Ctrl+S)");
            
            // Announce keyboard shortcuts
            debug("Keyboard shortcuts: Ctrl+B (toggle Bluetooth), Ctrl+S (scan), Ctrl+L (connect to last device)");
        }
        
        /**
         * Handle device context menu request
         */
        private void on_device_context_menu(Gtk.ListBoxRow row) {
            if (row is DeviceRow) {
                var device_row = row as DeviceRow;
                // Show context menu for device
                device_row.show_context_menu();
            }
        }
        
        /**
         * Update last connected device
         */
        private void update_last_connected_device(BluetoothDevice device) {
            if (device.connected) {
                last_connected_device_path = device.object_path;
            }
        }
    }
    
    /**
     * Connection filter enum
     */
    private enum ConnectionFilter {
        ALL,
        CONNECTED,
        PAIRED,
        AVAILABLE
    }
    
    /**
     * Device row widget
     */
    private class DeviceRow : Gtk.ListBoxRow {
        public BluetoothDevice device { get; private set; }
        private BluetoothController controller;
        
        private Gtk.Box main_box;
        private Gtk.Image device_icon;
        private Gtk.Label device_name_label;
        private Gtk.Label device_info_label;
        private Gtk.Image signal_icon;
        private Gtk.Box action_box;
        private Gtk.Button connect_button;
        private Gtk.Button pair_button;
        private Gtk.MenuButton more_button;
        
        public DeviceRow(BluetoothDevice device, BluetoothController controller) {
            this.device = device;
            this.controller = controller;
            
            setup_ui();
            update_device(device);
            setup_accessibility();
        }
        
        private void setup_ui() {
            main_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            main_box.margin = 8;
            
            // Device icon
            device_icon = new Gtk.Image();
            device_icon.set_pixel_size(32);
            
            // Device info
            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            info_box.hexpand = true;
            info_box.halign = Gtk.Align.START;
            
            device_name_label = new Gtk.Label("");
            device_name_label.halign = Gtk.Align.START;
            device_name_label.get_style_context().add_class("device-name");
            
            device_info_label = new Gtk.Label("");
            device_info_label.halign = Gtk.Align.START;
            device_info_label.get_style_context().add_class("dim-label");
            device_info_label.get_style_context().add_class("device-info");
            
            info_box.pack_start(device_name_label, false, false, 0);
            info_box.pack_start(device_info_label, false, false, 0);
            
            // Signal strength icon
            signal_icon = new Gtk.Image();
            signal_icon.set_pixel_size(16);
            
            // Action buttons
            action_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            
            connect_button = new Gtk.Button.with_label("Connect");
            connect_button.get_style_context().add_class("flat");
            connect_button.clicked.connect(on_connect_clicked);
            
            pair_button = new Gtk.Button.with_label("Pair");
            pair_button.get_style_context().add_class("flat");
            pair_button.clicked.connect(on_pair_clicked);
            
            more_button = new Gtk.MenuButton();
            more_button.set_image(new Gtk.Image.from_icon_name("view-more-symbolic", Gtk.IconSize.BUTTON));
            more_button.get_style_context().add_class("flat");
            setup_more_menu();
            
            action_box.pack_start(connect_button, false, false, 0);
            action_box.pack_start(pair_button, false, false, 0);
            action_box.pack_start(more_button, false, false, 0);
            
            main_box.pack_start(device_icon, false, false, 0);
            main_box.pack_start(info_box, true, true, 0);
            main_box.pack_start(signal_icon, false, false, 0);
            main_box.pack_end(action_box, false, false, 0);
            
            add(main_box);
        }
        
        private void setup_more_menu() {
            var menu = new GLib.Menu();
            
            menu.append("Trust", "device.trust");
            menu.append("Block", "device.block");
            menu.append("Forget", "device.forget");
            
            more_button.set_menu_model(menu);
            
            // Setup actions
            var action_group = new SimpleActionGroup();
            
            var trust_action = new SimpleAction("trust", null);
            trust_action.activate.connect(on_trust_clicked);
            action_group.add_action(trust_action);
            
            var block_action = new SimpleAction("block", null);
            block_action.activate.connect(on_block_clicked);
            action_group.add_action(block_action);
            
            var forget_action = new SimpleAction("forget", null);
            forget_action.activate.connect(on_forget_clicked);
            action_group.add_action(forget_action);
            
            insert_action_group("device", action_group);
        }
        
        public void update_device(BluetoothDevice updated_device) {
            this.device = updated_device;
            
            // Update icon
            device_icon.set_from_icon_name(device.get_device_type_icon(), Gtk.IconSize.DND);
            
            // Update name
            device_name_label.label = device.get_display_name();
            
            // Update info
            var info_parts = new GenericArray<string>();
            info_parts.add(device.address);
            
            if (device.connected) {
                info_parts.add("Connected");
            } else if (device.paired) {
                info_parts.add("Paired");
            }
            
            if (device.battery_percentage != null) {
                info_parts.add(@"Battery: $(device.battery_percentage)%");
            }
            
            // Convert GenericArray to string array
            string[] info_array = new string[info_parts.length];
            for (uint i = 0; i < info_parts.length; i++) {
                info_array[i] = info_parts[i];
            }
            device_info_label.label = string.joinv(" • ", info_array);
            
            // Update signal icon
            if (device.connected && device.rssi != 0) {
                signal_icon.set_from_icon_name(device.get_signal_strength_icon(), Gtk.IconSize.BUTTON);
                signal_icon.visible = true;
            } else {
                signal_icon.visible = false;
            }
            
            // Update action buttons
            if (device.connected) {
                connect_button.label = "Disconnect";
                connect_button.visible = true;
                pair_button.visible = false;
            } else if (device.paired) {
                connect_button.label = "Connect";
                connect_button.visible = true;
                pair_button.visible = false;
            } else {
                connect_button.visible = false;
                pair_button.visible = true;
            }
            
            // Update accessibility
            var accessible_name = AccessibleErrorFormatter.format_device_status(device);
            AccessibilityHelper.set_accessible_name(this, accessible_name);
            AccessibilityHelper.set_accessible_name(connect_button, 
                device.connected ? "Disconnect device" : "Connect to device");
        }
        
        private void on_connect_clicked() {
            if (device.connected) {
                controller.disconnect_device.begin(device.object_path);
            } else {
                controller.connect_device.begin(device.object_path);
            }
        }
        
        private void on_pair_clicked() {
            controller.pair_device.begin(device.object_path);
        }
        
        private void on_trust_clicked() {
            controller.trust_device.begin(device.object_path, !device.trusted);
        }
        
        private void on_block_clicked() {
            controller.trust_device.begin(device.object_path, false);
            // Note: Block functionality would need to be added to controller
        }
        
        private void on_forget_clicked() {
            controller.unpair_device.begin(device.object_path);
        }
        
        /**
         * Setup accessibility for device row
         */
        private void setup_accessibility() {
            // Set accessible name and role
            var accessible_name = AccessibleErrorFormatter.format_device_status(device);
            AccessibilityHelper.mark_as_list_item(this, accessible_name);
            
            // Set accessible properties for buttons
            AccessibilityHelper.mark_as_button(connect_button, 
                device.connected ? "Disconnect device" : "Connect to device");
            AccessibilityHelper.mark_as_button(pair_button, "Pair with device");
            AccessibilityHelper.mark_as_button(more_button, "More options");
            
            // Add focus indicators
            new FocusIndicator(connect_button);
            new FocusIndicator(pair_button);
            new FocusIndicator(more_button);
        }
        
        /**
         * Show context menu for device
         */
        public void show_context_menu() {
            // Trigger the more button menu
            more_button.clicked();
        }
    }
}
