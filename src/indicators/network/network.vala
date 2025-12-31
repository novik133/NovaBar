/**
 * Network Indicator - Modern macOS-style network popover
 */

namespace Indicators {

    public class Network : Gtk.Button {
        private Gtk.Image icon;
        private NetworkPopup? popup;
        private NM.Client? nm_client;
        private NM.DeviceWifi? wifi_device;
        
        public Network() {
            get_style_context().add_class("flat");
            get_style_context().add_class("indicator");
            
            icon = new Gtk.Image.from_icon_name("network-wireless-symbolic", Gtk.IconSize.MENU);
            add(icon);
            
            setup_nm();
            
            clicked.connect(show_popup);
        }
        
        private void show_popup() {
            if (popup != null && popup.visible) {
                popup.hide();
                return;
            }
            
            // Get button position on screen
            int x, y;
            Gtk.Allocation alloc;
            get_allocation(out alloc);
            get_window().get_origin(out x, out y);
            
            x += alloc.x + alloc.width / 2;
            y += alloc.y + alloc.height + 4;
            
            if (popup == null) {
                popup = new NetworkPopup(nm_client, wifi_device);
            }
            popup.refresh();
            popup.show_at(x, y);
        }
        
        private void setup_nm() {
            try {
                nm_client = new NM.Client(null);
                find_wifi_device();
                update_icon();
                nm_client.notify["connectivity"].connect(update_icon);
            } catch (Error e) {
                warning("NetworkManager not available: %s", e.message);
            }
        }
        
        private void find_wifi_device() {
            if (nm_client == null) return;
            
            foreach (var device in nm_client.get_devices()) {
                if (device is NM.DeviceWifi) {
                    wifi_device = (NM.DeviceWifi)device;
                    wifi_device.notify["state"].connect(update_icon);
                    break;
                }
            }
        }
        
        private void update_icon() {
            if (nm_client == null) {
                icon.set_from_icon_name("network-offline-symbolic", Gtk.IconSize.MENU);
                return;
            }
            
            if (wifi_device != null && wifi_device.get_state() == NM.DeviceState.ACTIVATED) {
                var ap = wifi_device.get_active_access_point();
                if (ap != null) {
                    var strength = ap.get_strength();
                    if (strength > 80) icon.set_from_icon_name("network-wireless-signal-excellent-symbolic", Gtk.IconSize.MENU);
                    else if (strength > 55) icon.set_from_icon_name("network-wireless-signal-good-symbolic", Gtk.IconSize.MENU);
                    else if (strength > 30) icon.set_from_icon_name("network-wireless-signal-ok-symbolic", Gtk.IconSize.MENU);
                    else icon.set_from_icon_name("network-wireless-signal-weak-symbolic", Gtk.IconSize.MENU);
                    return;
                }
            }
            
            foreach (var device in nm_client.get_devices()) {
                if (device is NM.DeviceEthernet && device.get_state() == NM.DeviceState.ACTIVATED) {
                    icon.set_from_icon_name("network-wired-symbolic", Gtk.IconSize.MENU);
                    return;
                }
            }
            
            if (nm_client.wireless_get_enabled()) {
                icon.set_from_icon_name("network-wireless-symbolic", Gtk.IconSize.MENU);
                icon.set_from_icon_name("network-wireless-disabled-symbolic", Gtk.IconSize.MENU);
            }
        }
    }
    
    private class NetworkPopup : Gtk.Window {
        private Gtk.Box content_box;
        private NM.Client? nm_client;
        private NM.DeviceWifi? wifi_device;
        
        public NetworkPopup(NM.Client? client, NM.DeviceWifi? wifi) {
            Object(type: Gtk.WindowType.POPUP);
            Backend.setup_popup(this, 28);
            
            this.nm_client = client;
            this.wifi_device = wifi;
            
            set_keep_above(true);
            set_app_paintable(true);
            
            var screen = get_screen();
            var visual = screen.get_rgba_visual();
            if (visual != null) set_visual(visual);
            
            // Draw rounded background manually
            draw.connect((cr) => {
                int w = get_allocated_width();
                int h = get_allocated_height();
                
                // Rounded rectangle
                double r = 12;
                cr.new_sub_path();
                cr.arc(w - r, r, r, -Math.PI/2, 0);
                cr.arc(w - r, h - r, r, 0, Math.PI/2);
                cr.arc(r, h - r, r, Math.PI/2, Math.PI);
                cr.arc(r, r, r, Math.PI, 3*Math.PI/2);
                cr.close_path();
                
                cr.set_source_rgba(0.24, 0.24, 0.24, 0.95);
                cr.fill_preserve();
                cr.set_source_rgba(1, 1, 1, 0.15);
                cr.set_line_width(1);
                cr.stroke();
                
                return false;
            });
            
            // Close on Escape
            key_press_event.connect((e) => {
                if (e.keyval == Gdk.Key.Escape) { hide(); return true; }
                return false;
            });
            
            // Close on click outside
            button_press_event.connect((e) => {
                int w, h;
                get_size(out w, out h);
                if (e.x < 0 || e.y < 0 || e.x > w || e.y > h) {
                    ungrab_input();
                    hide();
                }
                return false;
            });
            
            focus_out_event.connect(() => { ungrab_input(); hide(); return false; });
            
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            content_box.set_size_request(280, -1);
            content_box.margin = 12;
            
            add(content_box);
        }
        
        private void ungrab_input() {
            var display = Gdk.Display.get_default();
            var seat = display.get_default_seat();
            if (seat != null) seat.ungrab();
        }
        
        public void show_at(int x, int y) {
            show_all();
            Backend.position_popup(this, x, y, 28);
            
            if (Backend.is_x11()) {
                var display = Gdk.Display.get_default();
                var seat = display.get_default_seat();
                if (seat != null && get_window() != null) {
                    seat.grab(get_window(), Gdk.SeatCapabilities.ALL, true, null, null, null);
                }
            }
            
            present();
        }
        
        public void refresh() {
            content_box.foreach((w) => w.destroy());
            
            if (nm_client == null) {
                var label = new Gtk.Label("NetworkManager not available");
                label.margin = 16;
                content_box.pack_start(label, false, false, 0);
                content_box.show_all();
                return;
            }
            
            // Request scan
            if (wifi_device != null) {
                wifi_device.request_scan_async.begin(null, (obj, res) => {
                    try { wifi_device.request_scan_async.end(res); } catch (Error e) {}
                });
            }
            
            add_wifi_section();
            add_ethernet_section();
            add_settings_button();
            content_box.show_all();
        }
        
        private void add_wifi_section() {
            var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            header.margin_bottom = 8;
            
            var wifi_label = new Gtk.Label("Wi-Fi");
            wifi_label.get_style_context().add_class("section-title");
            wifi_label.halign = Gtk.Align.START;
            wifi_label.hexpand = true;
            
            var wifi_switch = new Gtk.Switch();
            wifi_switch.active = nm_client.wireless_get_enabled();
            wifi_switch.notify["active"].connect(() => {
                nm_client.wireless_set_enabled(wifi_switch.active);
                Timeout.add(1000, () => { refresh(); return false; });
            });
            
            header.pack_start(wifi_label, true, true, 0);
            header.pack_end(wifi_switch, false, false, 0);
            content_box.pack_start(header, false, false, 0);
            
            if (!nm_client.wireless_get_enabled() || wifi_device == null) {
                print("WiFi disabled or no device\n");
                return;
            }
            
            // Current connection
            var active_ap = wifi_device.get_active_access_point();
            string? active_ssid = null;
            if (active_ap != null) {
                active_ssid = get_ssid(active_ap);
                print("Active: %s\n", active_ssid);
                var row = create_network_row(active_ssid, active_ap.get_strength(), true, false);
                content_box.pack_start(row, false, false, 0);
                content_box.pack_start(create_separator(), false, false, 0);
            }
            
            // Other networks label
            var other_label = new Gtk.Label("Other Networks");
            other_label.get_style_context().add_class("dim-label");
            other_label.halign = Gtk.Align.START;
            other_label.margin_top = 4;
            other_label.margin_bottom = 4;
            content_box.pack_start(other_label, false, false, 0);
            
            // Get all access points
            var aps = wifi_device.get_access_points();
            print("Total APs: %u\n", aps.length);
            
            // Build list and sort
            var ap_list = new GenericArray<NM.AccessPoint>();
            foreach (var ap in aps) {
                ap_list.add(ap);
            }
            ap_list.sort((a, b) => (int)b.get_strength() - (int)a.get_strength());
            
            var seen_ssids = new GenericArray<string>();
            int count = 0;
            
            for (int i = 0; i < ap_list.length; i++) {
                var ap = ap_list[i];
                var ssid = get_ssid(ap);
                
                // Skip empty SSIDs
                if (ssid == null || ssid == "" || ssid.length == 0) continue;
                
                // Skip active network
                if (active_ssid != null && ssid == active_ssid) continue;
                
                // Skip duplicates
                bool duplicate = false;
                for (int j = 0; j < seen_ssids.length; j++) {
                    if (seen_ssids[j] == ssid) {
                        duplicate = true;
                        break;
                    }
                }
                if (duplicate) continue;
                
                seen_ssids.add(ssid);
                
                var secured = ap.get_flags() != NM.@80211ApFlags.NONE || 
                              ap.get_wpa_flags() != NM.@80211ApSecurityFlags.NONE ||
                              ap.get_rsn_flags() != NM.@80211ApSecurityFlags.NONE;
                
                var row = create_network_row(ssid, ap.get_strength(), false, secured);
                content_box.pack_start(row, false, false, 0);
                
                count++;
                if (count >= 10) break;
            }
            
            if (count == 0) {
                var scanning = new Gtk.Label("No networks found");
                scanning.get_style_context().add_class("dim-label");
                scanning.margin = 8;
                content_box.pack_start(scanning, false, false, 0);
            }
        }
        
        private Gtk.Widget create_separator() {
            var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            sep.margin_top = 8;
            sep.margin_bottom = 8;
            return sep;
        }
        
        private Gtk.Button create_network_row(string ssid, uint8 strength, bool connected, bool secured) {
            var btn = new Gtk.Button();
            btn.get_style_context().add_class("flat");
            btn.get_style_context().add_class("network-row");
            
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            box.margin = 6;
            
            string icon_name;
            if (strength > 80) icon_name = "network-wireless-signal-excellent-symbolic";
            else if (strength > 55) icon_name = "network-wireless-signal-good-symbolic";
            else if (strength > 30) icon_name = "network-wireless-signal-ok-symbolic";
            else icon_name = "network-wireless-signal-weak-symbolic";
            
            var signal_icon = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.MENU);
            box.pack_start(signal_icon, false, false, 0);
            
            var label = new Gtk.Label(ssid);
            label.halign = Gtk.Align.START;
            label.hexpand = true;
            label.ellipsize = Pango.EllipsizeMode.END;
            label.max_width_chars = 25;
            box.pack_start(label, true, true, 0);
            
            if (secured && !connected) {
                var lock_icon = new Gtk.Image.from_icon_name("channel-secure-symbolic", Gtk.IconSize.MENU);
                lock_icon.opacity = 0.5;
                box.pack_end(lock_icon, false, false, 0);
            }
            
            if (connected) {
                var check = new Gtk.Image.from_icon_name("object-select-symbolic", Gtk.IconSize.MENU);
                box.pack_end(check, false, false, 0);
            }
            
            btn.add(box);
            
            if (!connected) {
                var s = ssid;
                btn.clicked.connect(() => connect_to_network(s));
            }
            
            return btn;
        }
        
        private void add_ethernet_section() {
            foreach (var device in nm_client.get_devices()) {
                if (!(device is NM.DeviceEthernet)) continue;
                if (device.get_state() != NM.DeviceState.ACTIVATED) continue;
                
                content_box.pack_start(create_separator(), false, false, 0);
                
                var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
                row.margin = 6;
                
                var icon = new Gtk.Image.from_icon_name("network-wired-symbolic", Gtk.IconSize.MENU);
                row.pack_start(icon, false, false, 0);
                
                var label = new Gtk.Label("Ethernet");
                label.halign = Gtk.Align.START;
                label.hexpand = true;
                row.pack_start(label, true, true, 0);
                
                var check = new Gtk.Image.from_icon_name("object-select-symbolic", Gtk.IconSize.MENU);
                row.pack_end(check, false, false, 0);
                
                content_box.pack_start(row, false, false, 0);
            }
        }
        
        private void add_settings_button() {
            content_box.pack_start(create_separator(), false, false, 0);
            
            var btn = new Gtk.Button.with_label("Network Settings...");
            btn.get_style_context().add_class("flat");
            btn.clicked.connect(() => {
                hide();
                try { Process.spawn_command_line_async("nm-connection-editor"); } catch (Error e) {}
            });
            content_box.pack_start(btn, false, false, 0);
        }
        
        private string get_ssid(NM.AccessPoint ap) {
            var ssid_bytes = ap.get_ssid();
            if (ssid_bytes == null) return "";
            unowned uint8[] data = ssid_bytes.get_data();
            if (data == null || data.length == 0) return "";
            // Convert bytes to valid UTF-8
            string raw = (string)data;
            if (raw.validate()) return raw;
            // Invalid UTF-8, show hex
            var sb = new StringBuilder();
            foreach (uint8 b in data) {
                if (b >= 32 && b < 127) sb.append_c((char)b);
                else sb.append_printf("\\x%02x", b);
            }
            return sb.str;
        }
        
        private void connect_to_network(string ssid) {
            hide();
            foreach (var conn in nm_client.get_connections()) {
                var setting = conn.get_setting_wireless();
                if (setting != null) {
                    var conn_ssid = setting.get_ssid();
                    if (conn_ssid != null && (string)conn_ssid.get_data() == ssid) {
                        nm_client.activate_connection_async.begin(conn, wifi_device, null, null);
                        return;
                    }
                }
            }
            try { Process.spawn_command_line_async("nm-connection-editor --create --type=wifi"); } catch (Error e) {}
        }
    }
}
