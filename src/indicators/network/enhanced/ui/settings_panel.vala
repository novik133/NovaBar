/**
 * Enhanced Network Indicator - Settings Panel
 * 
 * This file implements the SettingsPanel component that provides comprehensive
 * network settings management including network profile management interface,
 * proxy configuration, DNS settings dialogs, and security/privacy settings.
 */

using GLib;
using Gtk;

namespace EnhancedNetwork {

    /**
     * Network profile list row widget
     */
    private class NetworkProfileRow : Gtk.ListBoxRow {
        private NetworkProfile profile;
        private Gtk.Box main_box;
        private Gtk.Label name_label;
        private Gtk.Label description_label;
        private Gtk.Switch active_switch;
        private Gtk.Button edit_button;
        private Gtk.Button delete_button;
        
        public NetworkProfileRow(NetworkProfile profile) {
            this.profile = profile;
            setup_ui();
            update_display();
            
            // Connect to profile changes
            profile.configuration_changed.connect(update_display);
        }
        
        private void setup_ui() {
            main_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            main_box.margin = 8;
            add(main_box);
            
            // Profile info box
            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            main_box.pack_start(info_box, true, true, 0);
            
            // Profile name
            name_label = new Gtk.Label(profile.name);
            name_label.halign = Gtk.Align.START;
            name_label.get_style_context().add_class("profile-name");
            info_box.pack_start(name_label, false, false, 0);
            
            // Profile description
            description_label = new Gtk.Label(profile.description);
            description_label.halign = Gtk.Align.START;
            description_label.get_style_context().add_class("dim-label");
            description_label.get_style_context().add_class("caption");
            info_box.pack_start(description_label, false, false, 0);
            
            // Active switch
            active_switch = new Gtk.Switch();
            active_switch.active = profile.is_active;
            active_switch.notify["active"].connect(on_active_toggled);
            main_box.pack_start(active_switch, false, false, 0);
            
            // Edit button
            edit_button = new Gtk.Button.from_icon_name("document-edit-symbolic", Gtk.IconSize.BUTTON);
            edit_button.tooltip_text = "Edit profile";
            edit_button.clicked.connect(on_edit_clicked);
            main_box.pack_start(edit_button, false, false, 0);
            
            // Delete button
            delete_button = new Gtk.Button.from_icon_name("edit-delete-symbolic", Gtk.IconSize.BUTTON);
            delete_button.tooltip_text = "Delete profile";
            delete_button.get_style_context().add_class("destructive-action");
            delete_button.clicked.connect(on_delete_clicked);
            main_box.pack_start(delete_button, false, false, 0);
            
            show_all();
        }
        
        private void update_display() {
            name_label.set_text(profile.name);
            description_label.set_text(profile.description);
            active_switch.active = profile.is_active;
            
            // Update style based on active state
            if (profile.is_active) {
                name_label.get_style_context().add_class("active-profile");
            } else {
                name_label.get_style_context().remove_class("active-profile");
            }
        }
        
        private void on_active_toggled() {
            if (active_switch.active) {
                profile_activation_requested(profile);
            } else {
                profile_deactivation_requested(profile);
            }
        }
        
        private void on_edit_clicked() {
            profile_edit_requested(profile);
        }
        
        private void on_delete_clicked() {
            profile_delete_requested(profile);
        }
        
        public NetworkProfile get_profile() {
            return profile;
        }
        
        public signal void profile_activation_requested(NetworkProfile profile);
        public signal void profile_deactivation_requested(NetworkProfile profile);
        public signal void profile_edit_requested(NetworkProfile profile);
        public signal void profile_delete_requested(NetworkProfile profile);
    }

    /**
     * Proxy configuration dialog
     */
    private class ProxyConfigDialog : Gtk.Dialog {
        private AdvancedProxyConfig config;
        private Gtk.Switch enabled_switch;
        private Gtk.ComboBoxText protocol_combo;
        private Gtk.Entry host_entry;
        private Gtk.SpinButton port_spin;
        private Gtk.Switch auth_switch;
        private Gtk.Entry username_entry;
        private Gtk.Entry password_entry;
        private Gtk.TextView bypass_hosts_view;
        private Gtk.Entry pac_url_entry;
        
        public ProxyConfigDialog(Gtk.Window parent, AdvancedProxyConfig config) {
            Object(
                title: "Proxy Configuration",
                transient_for: parent,
                modal: true,
                destroy_with_parent: true
            );
            
            this.config = config;
            setup_ui();
            load_configuration();
            
            add_button("Cancel", Gtk.ResponseType.CANCEL);
            add_button("Apply", Gtk.ResponseType.OK);
            
            set_default_response(Gtk.ResponseType.OK);
        }
        
        private void setup_ui() {
            var content = get_content_area();
            content.margin = 12;
            content.spacing = 8;
            
            var grid = new Gtk.Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 8;
            content.pack_start(grid, true, true, 0);
            
            int row = 0;
            
            // Enable proxy
            grid.attach(new Gtk.Label("Enable Proxy:"), 0, row, 1, 1);
            enabled_switch = new Gtk.Switch();
            enabled_switch.notify["active"].connect(on_enabled_toggled);
            grid.attach(enabled_switch, 1, row++, 1, 1);
            
            // Protocol
            grid.attach(new Gtk.Label("Protocol:"), 0, row, 1, 1);
            protocol_combo = new Gtk.ComboBoxText();
            protocol_combo.append_text("HTTP");
            protocol_combo.append_text("HTTPS");
            protocol_combo.append_text("SOCKS4");
            protocol_combo.append_text("SOCKS5");
            protocol_combo.append_text("FTP");
            grid.attach(protocol_combo, 1, row++, 1, 1);
            
            // Host
            grid.attach(new Gtk.Label("Host:"), 0, row, 1, 1);
            host_entry = new Gtk.Entry();
            host_entry.placeholder_text = "proxy.example.com";
            grid.attach(host_entry, 1, row++, 1, 1);
            
            // Port
            grid.attach(new Gtk.Label("Port:"), 0, row, 1, 1);
            port_spin = new Gtk.SpinButton.with_range(1, 65535, 1);
            port_spin.value = 8080;
            grid.attach(port_spin, 1, row++, 1, 1);
            
            // Authentication
            grid.attach(new Gtk.Label("Requires Authentication:"), 0, row, 1, 1);
            auth_switch = new Gtk.Switch();
            auth_switch.notify["active"].connect(on_auth_toggled);
            grid.attach(auth_switch, 1, row++, 1, 1);
            
            // Username
            grid.attach(new Gtk.Label("Username:"), 0, row, 1, 1);
            username_entry = new Gtk.Entry();
            username_entry.sensitive = false;
            grid.attach(username_entry, 1, row++, 1, 1);
            
            // Password
            grid.attach(new Gtk.Label("Password:"), 0, row, 1, 1);
            password_entry = new Gtk.Entry();
            password_entry.visibility = false;
            password_entry.sensitive = false;
            grid.attach(password_entry, 1, row++, 1, 1);
            
            // Bypass hosts
            grid.attach(new Gtk.Label("Bypass Hosts:"), 0, row, 1, 1);
            var bypass_frame = new Gtk.Frame(null);
            var bypass_scroll = new Gtk.ScrolledWindow(null, null);
            bypass_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            bypass_scroll.set_size_request(300, 100);
            bypass_hosts_view = new Gtk.TextView();
            bypass_hosts_view.wrap_mode = Gtk.WrapMode.WORD;
            bypass_scroll.add(bypass_hosts_view);
            bypass_frame.add(bypass_scroll);
            grid.attach(bypass_frame, 1, row++, 1, 1);
            
            // PAC URL
            grid.attach(new Gtk.Label("PAC URL:"), 0, row, 1, 1);
            pac_url_entry = new Gtk.Entry();
            pac_url_entry.placeholder_text = "http://example.com/proxy.pac";
            grid.attach(pac_url_entry, 1, row++, 1, 1);
            
            show_all();
        }
        
        private void load_configuration() {
            enabled_switch.active = config.enabled;
            protocol_combo.active = (int)config.protocol;
            host_entry.text = config.host;
            port_spin.value = config.port;
            auth_switch.active = config.requires_auth;
            username_entry.text = config.username;
            password_entry.text = config.password;
            pac_url_entry.text = config.pac_url;
            
            // Load bypass hosts
            var buffer = bypass_hosts_view.get_buffer();
            buffer.text = string.joinv("\n", config.bypass_hosts);
            
            on_enabled_toggled();
            on_auth_toggled();
        }
        
        private void on_enabled_toggled() {
            bool enabled = enabled_switch.active;
            protocol_combo.sensitive = enabled;
            host_entry.sensitive = enabled;
            port_spin.sensitive = enabled;
            auth_switch.sensitive = enabled;
            bypass_hosts_view.sensitive = enabled;
            pac_url_entry.sensitive = enabled;
            
            on_auth_toggled();
        }
        
        private void on_auth_toggled() {
            bool auth_enabled = auth_switch.active && enabled_switch.active;
            username_entry.sensitive = auth_enabled;
            password_entry.sensitive = auth_enabled;
        }
        
        public AdvancedProxyConfig get_configuration() {
            var new_config = new AdvancedProxyConfig();
            
            new_config.enabled = enabled_switch.active;
            new_config.protocol = (ProxyProtocol)protocol_combo.active;
            new_config.host = host_entry.text;
            new_config.port = (uint16)port_spin.value;
            new_config.requires_auth = auth_switch.active;
            new_config.username = username_entry.text;
            new_config.password = password_entry.text;
            new_config.pac_url = pac_url_entry.text;
            
            // Parse bypass hosts
            var buffer = bypass_hosts_view.get_buffer();
            Gtk.TextIter start, end;
            buffer.get_bounds(out start, out end);
            var bypass_text = buffer.get_text(start, end, false);
            
            if (bypass_text.length > 0) {
                new_config.bypass_hosts = bypass_text.split("\n");
            }
            
            return new_config;
        }
    }

    /**
     * DNS configuration dialog
     */
    private class DNSConfigDialog : Gtk.Dialog {
        private AdvancedDNSConfig config;
        private Gtk.Switch custom_dns_switch;
        private Gtk.TextView primary_servers_view;
        private Gtk.TextView fallback_servers_view;
        private Gtk.Switch doh_switch;
        private Gtk.ComboBoxText doh_provider_combo;
        private Gtk.Entry custom_doh_entry;
        private Gtk.Switch dot_switch;
        private Gtk.Entry dot_server_entry;
        private Gtk.SpinButton dot_port_spin;
        private Gtk.Switch dnssec_switch;
        private Gtk.Switch block_malware_switch;
        private Gtk.Switch block_ads_switch;
        
        public DNSConfigDialog(Gtk.Window parent, AdvancedDNSConfig config) {
            Object(
                title: "DNS Configuration",
                transient_for: parent,
                modal: true,
                destroy_with_parent: true
            );
            
            this.config = config;
            setup_ui();
            load_configuration();
            
            add_button("Cancel", Gtk.ResponseType.CANCEL);
            add_button("Apply", Gtk.ResponseType.OK);
            
            set_default_response(Gtk.ResponseType.OK);
        }
        
        private void setup_ui() {
            var content = get_content_area();
            content.margin = 12;
            content.spacing = 8;
            
            var notebook = new Gtk.Notebook();
            content.pack_start(notebook, true, true, 0);
            
            // Basic DNS tab
            var basic_grid = new Gtk.Grid();
            basic_grid.margin = 12;
            basic_grid.column_spacing = 12;
            basic_grid.row_spacing = 8;
            notebook.append_page(basic_grid, new Gtk.Label("Basic"));
            
            int row = 0;
            
            // Custom DNS
            basic_grid.attach(new Gtk.Label("Use Custom DNS:"), 0, row, 1, 1);
            custom_dns_switch = new Gtk.Switch();
            custom_dns_switch.notify["active"].connect(on_custom_dns_toggled);
            basic_grid.attach(custom_dns_switch, 1, row++, 1, 1);
            
            // Primary servers
            basic_grid.attach(new Gtk.Label("Primary Servers:"), 0, row, 1, 1);
            var primary_frame = new Gtk.Frame(null);
            var primary_scroll = new Gtk.ScrolledWindow(null, null);
            primary_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            primary_scroll.set_size_request(300, 80);
            primary_servers_view = new Gtk.TextView();
            primary_servers_view.wrap_mode = Gtk.WrapMode.WORD;
            primary_scroll.add(primary_servers_view);
            primary_frame.add(primary_scroll);
            basic_grid.attach(primary_frame, 1, row++, 1, 1);
            
            // Fallback servers
            basic_grid.attach(new Gtk.Label("Fallback Servers:"), 0, row, 1, 1);
            var fallback_frame = new Gtk.Frame(null);
            var fallback_scroll = new Gtk.ScrolledWindow(null, null);
            fallback_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            fallback_scroll.set_size_request(300, 80);
            fallback_servers_view = new Gtk.TextView();
            fallback_servers_view.wrap_mode = Gtk.WrapMode.WORD;
            fallback_scroll.add(fallback_servers_view);
            fallback_frame.add(fallback_scroll);
            basic_grid.attach(fallback_frame, 1, row++, 1, 1);
            
            // Advanced DNS tab
            var advanced_grid = new Gtk.Grid();
            advanced_grid.margin = 12;
            advanced_grid.column_spacing = 12;
            advanced_grid.row_spacing = 8;
            notebook.append_page(advanced_grid, new Gtk.Label("Advanced"));
            
            row = 0;
            
            // DNS-over-HTTPS
            advanced_grid.attach(new Gtk.Label("DNS-over-HTTPS:"), 0, row, 1, 1);
            doh_switch = new Gtk.Switch();
            doh_switch.notify["active"].connect(on_doh_toggled);
            advanced_grid.attach(doh_switch, 1, row++, 1, 1);
            
            // DoH Provider
            advanced_grid.attach(new Gtk.Label("DoH Provider:"), 0, row, 1, 1);
            doh_provider_combo = new Gtk.ComboBoxText();
            doh_provider_combo.append_text("Cloudflare");
            doh_provider_combo.append_text("Google");
            doh_provider_combo.append_text("Quad9");
            doh_provider_combo.append_text("OpenDNS");
            doh_provider_combo.append_text("Custom");
            doh_provider_combo.changed.connect(on_doh_provider_changed);
            advanced_grid.attach(doh_provider_combo, 1, row++, 1, 1);
            
            // Custom DoH URL
            advanced_grid.attach(new Gtk.Label("Custom DoH URL:"), 0, row, 1, 1);
            custom_doh_entry = new Gtk.Entry();
            custom_doh_entry.placeholder_text = "https://example.com/dns-query";
            advanced_grid.attach(custom_doh_entry, 1, row++, 1, 1);
            
            // DNS-over-TLS
            advanced_grid.attach(new Gtk.Label("DNS-over-TLS:"), 0, row, 1, 1);
            dot_switch = new Gtk.Switch();
            dot_switch.notify["active"].connect(on_dot_toggled);
            advanced_grid.attach(dot_switch, 1, row++, 1, 1);
            
            // DoT Server
            advanced_grid.attach(new Gtk.Label("DoT Server:"), 0, row, 1, 1);
            dot_server_entry = new Gtk.Entry();
            dot_server_entry.placeholder_text = "cloudflare-dns.com";
            advanced_grid.attach(dot_server_entry, 1, row++, 1, 1);
            
            // DoT Port
            advanced_grid.attach(new Gtk.Label("DoT Port:"), 0, row, 1, 1);
            dot_port_spin = new Gtk.SpinButton.with_range(1, 65535, 1);
            dot_port_spin.value = 853;
            advanced_grid.attach(dot_port_spin, 1, row++, 1, 1);
            
            // Security tab
            var security_grid = new Gtk.Grid();
            security_grid.margin = 12;
            security_grid.column_spacing = 12;
            security_grid.row_spacing = 8;
            notebook.append_page(security_grid, new Gtk.Label("Security"));
            
            row = 0;
            
            // DNSSEC
            security_grid.attach(new Gtk.Label("Enable DNSSEC:"), 0, row, 1, 1);
            dnssec_switch = new Gtk.Switch();
            security_grid.attach(dnssec_switch, 1, row++, 1, 1);
            
            // Block malware
            security_grid.attach(new Gtk.Label("Block Malware:"), 0, row, 1, 1);
            block_malware_switch = new Gtk.Switch();
            security_grid.attach(block_malware_switch, 1, row++, 1, 1);
            
            // Block ads
            security_grid.attach(new Gtk.Label("Block Ads:"), 0, row, 1, 1);
            block_ads_switch = new Gtk.Switch();
            security_grid.attach(block_ads_switch, 1, row++, 1, 1);
            
            show_all();
        }
        
        private void load_configuration() {
            custom_dns_switch.active = config.custom_dns_enabled;
            
            // Load DNS servers
            var primary_buffer = primary_servers_view.get_buffer();
            primary_buffer.text = string.joinv("\n", config.primary_servers);
            
            var fallback_buffer = fallback_servers_view.get_buffer();
            fallback_buffer.text = string.joinv("\n", config.fallback_servers);
            
            // Load DoH settings
            doh_switch.active = config.doh_enabled;
            doh_provider_combo.active = (int)config.doh_provider;
            custom_doh_entry.text = config.custom_doh_url;
            
            // Load DoT settings
            dot_switch.active = config.dot_enabled;
            dot_server_entry.text = config.dot_server;
            dot_port_spin.value = config.dot_port;
            
            // Load security settings
            dnssec_switch.active = config.enable_dnssec;
            block_malware_switch.active = config.block_malware;
            block_ads_switch.active = config.block_ads;
            
            on_custom_dns_toggled();
            on_doh_toggled();
            on_dot_toggled();
            on_doh_provider_changed();
        }
        
        private void on_custom_dns_toggled() {
            bool enabled = custom_dns_switch.active;
            primary_servers_view.sensitive = enabled;
            fallback_servers_view.sensitive = enabled;
        }
        
        private void on_doh_toggled() {
            bool enabled = doh_switch.active;
            doh_provider_combo.sensitive = enabled;
            on_doh_provider_changed();
        }
        
        private void on_dot_toggled() {
            bool enabled = dot_switch.active;
            dot_server_entry.sensitive = enabled;
            dot_port_spin.sensitive = enabled;
        }
        
        private void on_doh_provider_changed() {
            bool custom_enabled = doh_switch.active && doh_provider_combo.active == 4; // Custom
            custom_doh_entry.sensitive = custom_enabled;
        }
        
        public AdvancedDNSConfig get_configuration() {
            var new_config = new AdvancedDNSConfig();
            
            new_config.custom_dns_enabled = custom_dns_switch.active;
            
            // Parse primary servers
            var primary_buffer = primary_servers_view.get_buffer();
            Gtk.TextIter start, end;
            primary_buffer.get_bounds(out start, out end);
            var primary_text = primary_buffer.get_text(start, end, false);
            if (primary_text.length > 0) {
                new_config.primary_servers = primary_text.split("\n");
            }
            
            // Parse fallback servers
            var fallback_buffer = fallback_servers_view.get_buffer();
            fallback_buffer.get_bounds(out start, out end);
            var fallback_text = fallback_buffer.get_text(start, end, false);
            if (fallback_text.length > 0) {
                new_config.fallback_servers = fallback_text.split("\n");
            }
            
            // DoH settings
            new_config.doh_enabled = doh_switch.active;
            new_config.doh_provider = (DoHProvider)doh_provider_combo.active;
            new_config.custom_doh_url = custom_doh_entry.text;
            
            // DoT settings
            new_config.dot_enabled = dot_switch.active;
            new_config.dot_server = dot_server_entry.text;
            new_config.dot_port = (uint16)dot_port_spin.value;
            
            // Security settings
            new_config.enable_dnssec = dnssec_switch.active;
            new_config.block_malware = block_malware_switch.active;
            new_config.block_ads = block_ads_switch.active;
            
            return new_config;
        }
    }

    /**
     * Network settings and configuration panel
     */
    public class SettingsPanel : NetworkPanel {
        private Gtk.ListBox profile_list;
        private Gtk.Button create_profile_button;
        private Gtk.Button import_profiles_button;
        private Gtk.Button export_profiles_button;
        private Gtk.Button proxy_config_button;
        private Gtk.Button dns_config_button;
        private Gtk.Switch mac_randomization_switch;
        private Gtk.Switch auto_connect_switch;
        private Gtk.Switch remember_passwords_switch;
        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Label status_label;
        
        private GenericArray<NetworkProfile> current_profiles;
        
        /**
         * Signal emitted when profile management is requested
         */
        public signal void profile_management_requested();
        
        /**
         * Signal emitted when proxy configuration is requested
         */
        public signal void proxy_configuration_requested();
        
        /**
         * Signal emitted when DNS configuration is requested
         */
        public signal void dns_configuration_requested();
        
        public SettingsPanel(NetworkController controller) {
            base(controller, "settings");
            current_profiles = new GenericArray<NetworkProfile>();
            
            setup_ui();
            setup_controller_signals();
            
            // Initial load
            refresh();
        }
        
        private void setup_ui() {
            // Header with controls
            var header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            header_box.margin_bottom = 8;
            pack_start(header_box, false, false, 0);
            
            // Create profile button
            create_profile_button = new Gtk.Button.with_label("Create Profile");
            create_profile_button.get_style_context().add_class("suggested-action");
            create_profile_button.clicked.connect(on_create_profile_clicked);
            header_box.pack_start(create_profile_button, false, false, 0);
            
            // Import profiles button
            import_profiles_button = new Gtk.Button.with_label("Import");
            import_profiles_button.clicked.connect(on_import_profiles_clicked);
            header_box.pack_start(import_profiles_button, false, false, 0);
            
            // Export profiles button
            export_profiles_button = new Gtk.Button.with_label("Export");
            export_profiles_button.clicked.connect(on_export_profiles_clicked);
            header_box.pack_start(export_profiles_button, false, false, 0);
            
            // Status label
            status_label = new Gtk.Label("Loading network settings...");
            status_label.get_style_context().add_class("dim-label");
            status_label.halign = Gtk.Align.START;
            pack_start(status_label, false, false, 0);
            
            // Scrolled window for content
            scrolled_window = new Gtk.ScrolledWindow(null, null);
            scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_min_content_height(400);
            pack_start(scrolled_window, true, true, 0);
            
            // Main content box
            var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            content_box.margin = 8;
            scrolled_window.add(content_box);
            
            // Network profiles section
            var profiles_frame = new Gtk.Frame("Network Profiles");
            profiles_frame.get_style_context().add_class("settings-section");
            content_box.pack_start(profiles_frame, false, false, 0);
            
            var profiles_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            profiles_box.margin = 12;
            profiles_frame.add(profiles_box);
            
            profile_list = new Gtk.ListBox();
            profile_list.selection_mode = Gtk.SelectionMode.NONE;
            profiles_box.pack_start(profile_list, false, false, 0);
            
            // Advanced configuration section
            var advanced_frame = new Gtk.Frame("Advanced Configuration");
            advanced_frame.get_style_context().add_class("settings-section");
            content_box.pack_start(advanced_frame, false, false, 0);
            
            var advanced_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            advanced_box.margin = 12;
            advanced_frame.add(advanced_box);
            
            // Proxy configuration
            var proxy_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            proxy_box.pack_start(new Gtk.Label("Proxy Configuration:"), false, false, 0);
            proxy_config_button = new Gtk.Button.with_label("Configure");
            proxy_config_button.clicked.connect(on_proxy_config_clicked);
            proxy_box.pack_end(proxy_config_button, false, false, 0);
            advanced_box.pack_start(proxy_box, false, false, 0);
            
            // DNS configuration
            var dns_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            dns_box.pack_start(new Gtk.Label("DNS Configuration:"), false, false, 0);
            dns_config_button = new Gtk.Button.with_label("Configure");
            dns_config_button.clicked.connect(on_dns_config_clicked);
            dns_box.pack_end(dns_config_button, false, false, 0);
            advanced_box.pack_start(dns_box, false, false, 0);
            
            // Privacy and security section
            var privacy_frame = new Gtk.Frame("Privacy & Security");
            privacy_frame.get_style_context().add_class("settings-section");
            content_box.pack_start(privacy_frame, false, false, 0);
            
            var privacy_grid = new Gtk.Grid();
            privacy_grid.margin = 12;
            privacy_grid.column_spacing = 12;
            privacy_grid.row_spacing = 8;
            privacy_frame.add(privacy_grid);
            
            int row = 0;
            
            // MAC randomization
            privacy_grid.attach(new Gtk.Label("MAC Address Randomization:"), 0, row, 1, 1);
            mac_randomization_switch = new Gtk.Switch();
            mac_randomization_switch.notify["active"].connect(on_mac_randomization_toggled);
            privacy_grid.attach(mac_randomization_switch, 1, row++, 1, 1);
            
            // Auto connect
            privacy_grid.attach(new Gtk.Label("Auto-connect to Known Networks:"), 0, row, 1, 1);
            auto_connect_switch = new Gtk.Switch();
            auto_connect_switch.notify["active"].connect(on_auto_connect_toggled);
            privacy_grid.attach(auto_connect_switch, 1, row++, 1, 1);
            
            // Remember passwords
            privacy_grid.attach(new Gtk.Label("Remember Network Passwords:"), 0, row, 1, 1);
            remember_passwords_switch = new Gtk.Switch();
            remember_passwords_switch.notify["active"].connect(on_remember_passwords_toggled);
            privacy_grid.attach(remember_passwords_switch, 1, row++, 1, 1);
            
            show_all();
        }
        
        private void setup_controller_signals() {
            // Connect to profile manager signals
            controller.profile_manager.profile_created.connect(on_profile_created);
            controller.profile_manager.profile_deleted.connect(on_profile_deleted);
            controller.profile_manager.profile_updated.connect(on_profile_updated);
            controller.profile_manager.active_profile_changed.connect(on_active_profile_changed);
            controller.profile_manager.import_export_completed.connect(on_import_export_completed);
            
            // Connect to advanced config manager signals
            controller.advanced_config_manager.configuration_applied.connect(on_configuration_applied);
        }
        
        public override void refresh() {
            set_refreshing(true);
            status_label.set_text("Loading network profiles...");
            
            // Load profiles
            var profiles = controller.profile_manager.get_all_profiles();
            update_profile_list(profiles);
            
            // Load privacy settings (placeholder - would load from settings)
            mac_randomization_switch.active = true;
            auto_connect_switch.active = true;
            remember_passwords_switch.active = true;
            
            set_refreshing(false);
            status_label.set_text(@"Loaded $(profiles.length) network profile$(profiles.length == 1 ? "" : "s")");
        }
        
        public override void apply_search_filter(string search_term) {
            // Filter profiles by name or description
            profile_list.set_filter_func((row) => {
                var profile_row = row as NetworkProfileRow;
                if (profile_row == null) return true;
                
                var profile = profile_row.get_profile();
                var search_lower = search_term.down();
                
                return (profile.name != null && profile.name.down().contains(search_lower)) ||
                       (profile.description != null && profile.description.down().contains(search_lower));
            });
        }
        
        public override void focus_first_result() {
            var first_row = profile_list.get_row_at_index(0);
            if (first_row != null) {
                first_row.grab_focus();
            } else {
                create_profile_button.grab_focus();
            }
        }
        
        private void update_profile_list(GenericArray<NetworkProfile> profiles) {
            current_profiles = profiles;
            
            // Clear existing rows
            profile_list.foreach((widget) => {
                profile_list.remove(widget);
            });
            
            // Add profile rows
            for (uint i = 0; i < profiles.length; i++) {
                var profile = profiles[i];
                var row = new NetworkProfileRow(profile);
                
                row.profile_activation_requested.connect(on_profile_activation_requested);
                row.profile_deactivation_requested.connect(on_profile_deactivation_requested);
                row.profile_edit_requested.connect(on_profile_edit_requested);
                row.profile_delete_requested.connect(on_profile_delete_requested);
                
                profile_list.add(row);
            }
            
            profile_list.show_all();
        }
        
        private void on_create_profile_clicked() {
            var dialog = new Gtk.Dialog.with_buttons(
                "Create Network Profile",
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                "Cancel", Gtk.ResponseType.CANCEL,
                "Create", Gtk.ResponseType.OK
            );
            
            var content = dialog.get_content_area();
            content.margin = 12;
            content.spacing = 8;
            
            var grid = new Gtk.Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 8;
            content.pack_start(grid, true, true, 0);
            
            // Profile name
            grid.attach(new Gtk.Label("Name:"), 0, 0, 1, 1);
            var name_entry = new Gtk.Entry();
            name_entry.placeholder_text = "Profile name";
            grid.attach(name_entry, 1, 0, 1, 1);
            
            // Profile description
            grid.attach(new Gtk.Label("Description:"), 0, 1, 1, 1);
            var description_entry = new Gtk.Entry();
            description_entry.placeholder_text = "Optional description";
            grid.attach(description_entry, 1, 1, 1, 1);
            
            dialog.show_all();
            
            var response = dialog.run();
            if (response == Gtk.ResponseType.OK) {
                var name = name_entry.text.strip();
                var description = description_entry.text.strip();
                
                if (name.length > 0) {
                    controller.profile_manager.create_profile(name, description);
                    status_label.set_text(@"Created profile: $(name)");
                }
            }
            
            dialog.destroy();
        }
        
        private void on_import_profiles_clicked() {
            var dialog = new Gtk.FileChooserDialog(
                "Import Network Profiles",
                get_toplevel() as Gtk.Window,
                Gtk.FileChooserAction.OPEN,
                "Cancel", Gtk.ResponseType.CANCEL,
                "Import", Gtk.ResponseType.ACCEPT
            );
            
            // Add file filters
            var json_filter = new Gtk.FileFilter();
            json_filter.set_name("JSON Files");
            json_filter.add_pattern("*.json");
            dialog.add_filter(json_filter);
            
            var all_filter = new Gtk.FileFilter();
            all_filter.set_name("All Files");
            all_filter.add_pattern("*");
            dialog.add_filter(all_filter);
            
            var response = dialog.run();
            if (response == Gtk.ResponseType.ACCEPT) {
                var file_path = dialog.get_filename();
                controller.profile_manager.import_profiles.begin(file_path, ProfileFormat.JSON);
                status_label.set_text("Importing profiles...");
            }
            
            dialog.destroy();
        }
        
        private void on_export_profiles_clicked() {
            var dialog = new Gtk.FileChooserDialog(
                "Export Network Profiles",
                get_toplevel() as Gtk.Window,
                Gtk.FileChooserAction.SAVE,
                "Cancel", Gtk.ResponseType.CANCEL,
                "Export", Gtk.ResponseType.ACCEPT
            );
            
            dialog.set_current_name("network-profiles.json");
            
            var response = dialog.run();
            if (response == Gtk.ResponseType.ACCEPT) {
                var file_path = dialog.get_filename();
                controller.profile_manager.export_profiles.begin(file_path, ProfileFormat.JSON);
                status_label.set_text("Exporting profiles...");
            }
            
            dialog.destroy();
        }
        
        private void on_proxy_config_clicked() {
            var config = controller.advanced_config_manager.proxy_config;
            var dialog = new ProxyConfigDialog(get_toplevel() as Gtk.Window, config);
            
            var response = dialog.run();
            if (response == Gtk.ResponseType.OK) {
                var new_config = dialog.get_configuration();
                controller.advanced_config_manager.update_proxy_config.begin(new_config);
                status_label.set_text("Applying proxy configuration...");
            }
            
            dialog.destroy();
        }
        
        private void on_dns_config_clicked() {
            var config = controller.advanced_config_manager.dns_config;
            var dialog = new DNSConfigDialog(get_toplevel() as Gtk.Window, config);
            
            var response = dialog.run();
            if (response == Gtk.ResponseType.OK) {
                var new_config = dialog.get_configuration();
                controller.advanced_config_manager.update_dns_config.begin(new_config);
                status_label.set_text("Applying DNS configuration...");
            }
            
            dialog.destroy();
        }
        
        private void on_mac_randomization_toggled() {
            // Save MAC randomization setting
            status_label.set_text("MAC randomization " + (mac_randomization_switch.active ? "enabled" : "disabled"));
        }
        
        private void on_auto_connect_toggled() {
            // Save auto-connect setting
            status_label.set_text("Auto-connect " + (auto_connect_switch.active ? "enabled" : "disabled"));
        }
        
        private void on_remember_passwords_toggled() {
            // Save remember passwords setting
            status_label.set_text("Remember passwords " + (remember_passwords_switch.active ? "enabled" : "disabled"));
        }
        
        private void on_profile_activation_requested(NetworkProfile profile) {
            controller.profile_manager.activate_profile.begin(profile.id, (obj, res) => {
                try {
                    var success = controller.profile_manager.activate_profile.end(res);
                    if (success) {
                        status_label.set_text(@"Activated profile: $(profile.name)");
                    } else {
                        status_label.set_text(@"Failed to activate profile: $(profile.name)");
                    }
                } catch (Error e) {
                    status_label.set_text(@"Error activating profile: $(e.message)");
                }
            });
        }
        
        private void on_profile_deactivation_requested(NetworkProfile profile) {
            controller.profile_manager.deactivate_profile();
            status_label.set_text(@"Deactivated profile: $(profile.name)");
        }
        
        private void on_profile_edit_requested(NetworkProfile profile) {
            // Show profile edit dialog (simplified)
            status_label.set_text(@"Edit profile: $(profile.name) (not implemented)");
        }
        
        private void on_profile_delete_requested(NetworkProfile profile) {
            var dialog = new Gtk.MessageDialog(
                get_toplevel() as Gtk.Window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.YES_NO,
                @"Delete profile \"$(profile.name)\"?"
            );
            dialog.secondary_text = "This action cannot be undone.";
            
            var response = dialog.run();
            dialog.destroy();
            
            if (response == Gtk.ResponseType.YES) {
                controller.profile_manager.delete_profile(profile.id);
                status_label.set_text(@"Deleted profile: $(profile.name)");
            }
        }
        
        // Signal handlers
        private void on_profile_created(NetworkProfile profile) {
            refresh();
        }
        
        private void on_profile_deleted(string profile_id) {
            refresh();
        }
        
        private void on_profile_updated(NetworkProfile profile) {
            // Update specific row instead of full refresh for better performance
            refresh();
        }
        
        private void on_active_profile_changed(NetworkProfile? old_profile, NetworkProfile? new_profile) {
            refresh();
        }
        
        private void on_import_export_completed(bool success, string message) {
            status_label.set_text(message);
            if (success) {
                refresh();
            }
        }
        
        private void on_configuration_applied(string config_type, bool success, string message) {
            status_label.set_text(message);
        }
    }
}