/**
 * NovaBar Settings Window
 */

namespace Settings {

    private static Gtk.CssProvider? _active_theme_provider = null;
    
    private static void apply_theme_css(Gtk.CssProvider css, int priority) {
        var screen = Gdk.Screen.get_default();
        if (_active_theme_provider != null) {
            Gtk.StyleContext.remove_provider_for_screen(screen, _active_theme_provider);
        }
        _active_theme_provider = css;
        Gtk.StyleContext.add_provider_for_screen(screen, css, priority);
    }

    public class SettingsWindow : Gtk.Window {
        public signal void logo_icon_changed(string icon_name);
        
        private Gtk.Stack stack;
        private Gtk.ComboBoxText theme_combo;
        private Gtk.Entry icon_entry;
        private Gtk.ListBox sidebar;
        
        public SettingsWindow() {
            title = "NovaBar Settings";
            set_default_size(680, 520);
            set_resizable(false);
            window_position = Gtk.WindowPosition.CENTER;
            
            load_settings_css();
            get_style_context().add_class("nova-settings-window");
            
            var header = new Gtk.HeaderBar();
            header.show_close_button = true;
            header.title = "Settings";
            header.get_style_context().add_class("nova-settings-header");
            set_titlebar(header);
            
            var root = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            root.get_style_context().add_class("nova-settings-root");
            
            // --- Sidebar ---
            var sidebar_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            sidebar_box.get_style_context().add_class("nova-settings-sidebar");
            sidebar_box.set_size_request(190, -1);
            
            var sidebar_label = new Gtk.Label("NovaBar");
            sidebar_label.get_style_context().add_class("nova-settings-sidebar-title");
            sidebar_label.halign = Gtk.Align.START;
            sidebar_label.margin_start = 18;
            sidebar_label.margin_top = 16;
            sidebar_label.margin_bottom = 12;
            sidebar_box.pack_start(sidebar_label, false, false, 0);
            
            sidebar = new Gtk.ListBox();
            sidebar.get_style_context().add_class("nova-settings-sidebar-list");
            sidebar.selection_mode = Gtk.SelectionMode.SINGLE;
            sidebar.activate_on_single_click = true;
            
            add_sidebar_row("preferences-desktop-theme-symbolic", "Appearance");
            add_sidebar_row("network-wireless-symbolic", "Network");
            add_sidebar_row("help-about-symbolic", "About");
            
            sidebar.row_activated.connect(on_sidebar_row_activated);
            sidebar_box.pack_start(sidebar, true, true, 0);
            
            // --- Content area ---
            stack = new Gtk.Stack();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            stack.transition_duration = 200;
            stack.hexpand = true;
            stack.vexpand = true;
            
            stack.add_named(create_appearance_page(), "appearance");
            stack.add_named(create_network_page(), "network");
            stack.add_named(create_about_page(), "about");
            
            var content_frame = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            content_frame.get_style_context().add_class("nova-settings-content");
            content_frame.pack_start(stack, true, true, 0);
            
            var sep = new Gtk.Separator(Gtk.Orientation.VERTICAL);
            
            root.pack_start(sidebar_box, false, false, 0);
            root.pack_start(sep, false, false, 0);
            root.pack_start(content_frame, true, true, 0);
            
            add(root);
            
            // Select first row
            sidebar.select_row(sidebar.get_row_at_index(0));
        }
        
        private void load_settings_css() {
            var css = new Gtk.CssProvider();
            try {
                css.load_from_data("""
                    .nova-settings-header {
                        border-bottom: 1px solid alpha(@theme_fg_color, 0.08);
                    }
                    .nova-settings-sidebar {
                        background-color: alpha(@theme_bg_color, 0.6);
                        border-right: none;
                    }
                    .nova-settings-sidebar-title {
                        font-size: 13px;
                        font-weight: 700;
                        opacity: 0.5;
                        letter-spacing: 0.5px;
                    }
                    .nova-settings-sidebar-list {
                        background: transparent;
                    }
                    .nova-settings-sidebar-list row {
                        padding: 8px 16px;
                        margin: 2px 8px;
                        border-radius: 8px;
                        background: transparent;
                    }
                    .nova-settings-sidebar-list row:selected {
                        background-color: alpha(@theme_selected_bg_color, 0.85);
                    }
                    .nova-settings-sidebar-list row:hover:not(:selected) {
                        background-color: alpha(@theme_fg_color, 0.06);
                    }
                    .nova-sidebar-row-icon {
                        margin-right: 10px;
                        opacity: 0.75;
                    }
                    .nova-sidebar-row-label {
                        font-size: 13px;
                        font-weight: 500;
                    }
                    .nova-settings-content {
                        padding: 0;
                    }
                    .nova-page-title {
                        font-size: 22px;
                        font-weight: 700;
                    }
                    .nova-page-subtitle {
                        font-size: 12px;
                        opacity: 0.55;
                    }
                    .nova-card {
                        background-color: alpha(@theme_fg_color, 0.04);
                        border-radius: 12px;
                        padding: 4px 0;
                    }
                    .nova-card-row {
                        padding: 12px 16px;
                        min-height: 20px;
                    }
                    .nova-card-row-label {
                        font-size: 13px;
                    }
                    .nova-card-row-sublabel {
                        font-size: 11px;
                        opacity: 0.5;
                    }
                    .nova-card-separator {
                        margin-left: 16px;
                        margin-right: 16px;
                        opacity: 0.15;
                    }
                    .nova-section-header {
                        font-size: 12px;
                        font-weight: 600;
                        opacity: 0.45;
                        letter-spacing: 0.3px;
                    }
                    .nova-about-logo {
                        margin-bottom: 4px;
                    }
                    .nova-about-name {
                        font-size: 26px;
                        font-weight: 300;
                    }
                    .nova-about-version {
                        font-size: 12px;
                        opacity: 0.5;
                        margin-bottom: 8px;
                    }
                    .nova-about-author {
                        font-size: 13px;
                        opacity: 0.7;
                    }
                    .nova-about-link {
                        font-size: 12px;
                    }
                    .nova-about-support-btn {
                        padding: 8px 24px;
                        border-radius: 8px;
                        font-weight: 600;
                        font-size: 13px;
                    }
                    .nova-about-copyright {
                        font-size: 11px;
                        opacity: 0.35;
                    }
                    .nova-save-btn {
                        padding: 6px 28px;
                        border-radius: 8px;
                        font-weight: 600;
                    }
                """);
            } catch (Error e) {
                warning("Settings CSS load error: %s", e.message);
            }
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 2
            );
        }
        
        // --- Sidebar helpers ---
        
        private void add_sidebar_row(string icon_name, string label_text) {
            var row_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            
            var icon = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.MENU);
            icon.get_style_context().add_class("nova-sidebar-row-icon");
            
            var label = new Gtk.Label(label_text);
            label.get_style_context().add_class("nova-sidebar-row-label");
            label.halign = Gtk.Align.START;
            
            row_box.pack_start(icon, false, false, 0);
            row_box.pack_start(label, false, false, 0);
            
            sidebar.insert(row_box, -1);
        }
        
        private void on_sidebar_row_activated(Gtk.ListBoxRow row) {
            var index = row.get_index();
            switch (index) {
                case 0: stack.set_visible_child_name("appearance"); break;
                case 1: stack.set_visible_child_name("network"); break;
                case 2: stack.set_visible_child_name("about"); break;
            }
        }
        
        // --- Card / row helpers ---
        
        private Gtk.Box create_card() {
            var card = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            card.get_style_context().add_class("nova-card");
            return card;
        }
        
        private void card_add_separator(Gtk.Box card) {
            var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            sep.get_style_context().add_class("nova-card-separator");
            card.pack_start(sep, false, false, 0);
        }
        
        private Gtk.Box card_add_row_with_widget(Gtk.Box card, string label_text, string? sublabel_text, Gtk.Widget widget, bool add_sep) {
            if (add_sep) card_add_separator(card);
            
            var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            row.get_style_context().add_class("nova-card-row");
            
            var labels_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            labels_box.hexpand = true;
            labels_box.valign = Gtk.Align.CENTER;
            
            var label = new Gtk.Label(label_text);
            label.get_style_context().add_class("nova-card-row-label");
            label.halign = Gtk.Align.START;
            labels_box.pack_start(label, false, false, 0);
            
            if (sublabel_text != null) {
                var sub = new Gtk.Label(sublabel_text);
                sub.get_style_context().add_class("nova-card-row-sublabel");
                sub.halign = Gtk.Align.START;
                sub.set_line_wrap(true);
                sub.max_width_chars = 40;
                labels_box.pack_start(sub, false, false, 0);
            }
            
            row.pack_start(labels_box, true, true, 0);
            
            widget.valign = Gtk.Align.CENTER;
            row.pack_end(widget, false, false, 0);
            
            card.pack_start(row, false, false, 0);
            return row;
        }
        
        private Gtk.Label create_section_header(string text) {
            var label = new Gtk.Label(text.up());
            label.get_style_context().add_class("nova-section-header");
            label.halign = Gtk.Align.START;
            label.margin_start = 4;
            return label;
        }
        
        // --- Pages ---
        
        private Gtk.Widget create_appearance_page() {
            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            
            var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 16);
            page.margin = 32;
            page.margin_top = 24;
            page.valign = Gtk.Align.START;
            
            // Page title
            var title = new Gtk.Label("Appearance");
            title.get_style_context().add_class("nova-page-title");
            title.halign = Gtk.Align.START;
            page.pack_start(title, false, false, 0);
            
            var subtitle = new Gtk.Label("Customize the look and feel of your panel");
            subtitle.get_style_context().add_class("nova-page-subtitle");
            subtitle.halign = Gtk.Align.START;
            subtitle.margin_bottom = 8;
            page.pack_start(subtitle, false, false, 0);
            
            // Theme card
            page.pack_start(create_section_header("Theme"), false, false, 0);
            
            var theme_card = create_card();
            
            theme_combo = new Gtk.ComboBoxText();
            theme_combo.append("dark", "Dark");
            theme_combo.append("light", "Light");
            theme_combo.active_id = get_current_theme();
            card_add_row_with_widget(theme_card, "Color scheme", "Choose between light and dark appearance", theme_combo, false);
            
            page.pack_start(theme_card, false, false, 0);
            
            // Logo card
            page.pack_start(create_section_header("Branding"), false, false, 0);
            
            var logo_card = create_card();
            
            var icon_widget_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            
            icon_entry = new Gtk.Entry();
            icon_entry.text = get_saved_logo_icon();
            icon_entry.placeholder_text = "distributor-logo";
            icon_entry.set_size_request(160, -1);
            icon_entry.set_icon_from_icon_name(Gtk.EntryIconPosition.PRIMARY, "emblem-photos-symbolic");
            icon_widget_box.pack_start(icon_entry, false, false, 0);
            
            var browse_btn = new Gtk.Button.from_icon_name("folder-open-symbolic", Gtk.IconSize.BUTTON);
            browse_btn.set_tooltip_text("Browse for a custom icon image");
            browse_btn.get_style_context().add_class("flat");
            browse_btn.clicked.connect(on_browse_icon_clicked);
            icon_widget_box.pack_start(browse_btn, false, false, 0);
            
            card_add_row_with_widget(logo_card, "Logo icon", "Icon name or custom image file for the panel menu", icon_widget_box, false);
            
            page.pack_start(logo_card, false, false, 0);
            
            // Save button
            var btn_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            btn_box.halign = Gtk.Align.END;
            btn_box.margin_top = 8;
            
            var save_btn = new Gtk.Button.with_label("Apply");
            save_btn.get_style_context().add_class("suggested-action");
            save_btn.get_style_context().add_class("nova-save-btn");
            save_btn.clicked.connect(save_settings);
            btn_box.pack_end(save_btn, false, false, 0);
            
            page.pack_start(btn_box, false, false, 0);
            
            scroll.add(page);
            return scroll;
        }
        
        private Gtk.Widget create_network_page() {
            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            
            var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 16);
            page.margin = 32;
            page.margin_top = 24;
            page.valign = Gtk.Align.START;
            
            var title = new Gtk.Label("Network");
            title.get_style_context().add_class("nova-page-title");
            title.halign = Gtk.Align.START;
            page.pack_start(title, false, false, 0);
            
            var subtitle = new Gtk.Label("Configure network indicator behavior");
            subtitle.get_style_context().add_class("nova-page-subtitle");
            subtitle.halign = Gtk.Align.START;
            subtitle.margin_bottom = 8;
            page.pack_start(subtitle, false, false, 0);
            
            // Connection card
            page.pack_start(create_section_header("Connection"), false, false, 0);
            
            var conn_card = create_card();
            
            var auto_switch = new Gtk.Switch();
            auto_switch.active = get_network_setting("auto_connect", true);
            auto_switch.notify["active"].connect(() => {
                set_network_setting("auto_connect", auto_switch.active.to_string());
            });
            card_add_row_with_widget(conn_card, "Auto-connect", "Automatically join known networks", auto_switch, false);
            
            page.pack_start(conn_card, false, false, 0);
            
            // Notifications card
            page.pack_start(create_section_header("Notifications"), false, false, 0);
            
            var notif_card = create_card();
            
            var notif_switch = new Gtk.Switch();
            notif_switch.active = get_network_setting("show_notifications", true);
            notif_switch.notify["active"].connect(() => {
                set_network_setting("show_notifications", notif_switch.active.to_string());
            });
            card_add_row_with_widget(notif_card, "Network alerts", "Show notifications for connection changes", notif_switch, false);
            
            var bw_switch = new Gtk.Switch();
            bw_switch.active = get_network_setting("show_bandwidth", true);
            bw_switch.notify["active"].connect(() => {
                set_network_setting("show_bandwidth", bw_switch.active.to_string());
            });
            card_add_row_with_widget(notif_card, "Bandwidth monitor", "Display real-time bandwidth usage", bw_switch, true);
            
            page.pack_start(notif_card, false, false, 0);
            
            scroll.add(page);
            return scroll;
        }
        
        private void save_settings() {
            set_theme(theme_combo.active_id);
            save_logo_icon(icon_entry.text.strip());
            logo_icon_changed(icon_entry.text.strip());
        }
        
        private Gtk.Widget create_about_page() {
            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            
            var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            page.margin = 32;
            page.margin_top = 40;
            page.valign = Gtk.Align.CENTER;
            page.halign = Gtk.Align.CENTER;
            
            // Logo
            var logo = new Gtk.Image.from_icon_name("preferences-desktop", Gtk.IconSize.DIALOG);
            logo.pixel_size = 80;
            logo.get_style_context().add_class("nova-about-logo");
            page.pack_start(logo, false, false, 0);
            
            // Name
            var name_label = new Gtk.Label("NovaBar");
            name_label.get_style_context().add_class("nova-about-name");
            page.pack_start(name_label, false, false, 0);
            
            // Version
            var version_label = new Gtk.Label("Version 0.1.4");
            version_label.get_style_context().add_class("nova-about-version");
            page.pack_start(version_label, false, false, 0);
            
            // Author
            var author = new Gtk.Label("Created by Kamil 'Novik' Nowicki");
            author.get_style_context().add_class("nova-about-author");
            author.margin_top = 12;
            page.pack_start(author, false, false, 0);
            
            // Links card
            var links_card = create_card();
            links_card.margin_top = 16;
            links_card.set_size_request(320, -1);
            
            var email_link = create_about_link_row("mail-unread-symbolic", "novik@noviktech.com", "mailto:novik@noviktech.com");
            links_card.pack_start(email_link, false, false, 0);
            card_add_separator(links_card);
            
            var web_link = create_about_link_row("web-browser-symbolic", "noviktech.com", "https://noviktech.com");
            links_card.pack_start(web_link, false, false, 0);
            card_add_separator(links_card);
            
            var github_link = create_about_link_row("applications-development-symbolic", "GitHub", "https://github.com/novik133/NovaBar");
            links_card.pack_start(github_link, false, false, 0);
            
            page.pack_start(links_card, false, false, 0);
            
            // Support button
            var kofi_btn = new Gtk.Button.with_label("Support on Ko-fi");
            kofi_btn.get_style_context().add_class("suggested-action");
            kofi_btn.get_style_context().add_class("nova-about-support-btn");
            kofi_btn.margin_top = 16;
            kofi_btn.halign = Gtk.Align.CENTER;
            kofi_btn.clicked.connect(() => {
                try { Process.spawn_command_line_async("xdg-open https://ko-fi.com/novadesktop"); } catch (Error e) {}
            });
            page.pack_start(kofi_btn, false, false, 0);
            
            // Copyright
            var copyright = new Gtk.Label("© 2025-2026 Kamil Nowicki  ·  GPL-3.0 License");
            copyright.get_style_context().add_class("nova-about-copyright");
            copyright.margin_top = 20;
            page.pack_start(copyright, false, false, 0);
            
            scroll.add(page);
            return scroll;
        }
        
        private Gtk.Widget create_about_link_row(string icon_name, string label_text, string uri) {
            var btn = new Gtk.Button();
            btn.get_style_context().add_class("flat");
            btn.get_style_context().add_class("nova-card-row");
            
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            
            var icon = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.SMALL_TOOLBAR);
            icon.opacity = 0.6;
            box.pack_start(icon, false, false, 0);
            
            var label = new Gtk.Label(label_text);
            label.get_style_context().add_class("nova-about-link");
            label.halign = Gtk.Align.START;
            label.hexpand = true;
            box.pack_start(label, true, true, 0);
            
            var arrow = new Gtk.Image.from_icon_name("go-next-symbolic", Gtk.IconSize.MENU);
            arrow.opacity = 0.3;
            box.pack_end(arrow, false, false, 0);
            
            btn.add(box);
            btn.clicked.connect(() => {
                try { Process.spawn_command_line_async("xdg-open " + uri); } catch (Error e) {}
            });
            
            return btn;
        }
        
        private void on_browse_icon_clicked() {
            var dialog = new Gtk.FileChooserDialog(
                "Select Icon Image",
                this,
                Gtk.FileChooserAction.OPEN,
                "_Cancel", Gtk.ResponseType.CANCEL,
                "_Open", Gtk.ResponseType.ACCEPT
            );
            
            // Image file filter
            var img_filter = new Gtk.FileFilter();
            img_filter.set_filter_name("Image files");
            img_filter.add_mime_type("image/png");
            img_filter.add_mime_type("image/svg+xml");
            img_filter.add_mime_type("image/x-xpixmap");
            img_filter.add_mime_type("image/x-icon");
            img_filter.add_mime_type("image/jpeg");
            img_filter.add_pattern("*.png");
            img_filter.add_pattern("*.svg");
            img_filter.add_pattern("*.xpm");
            img_filter.add_pattern("*.ico");
            img_filter.add_pattern("*.jpg");
            img_filter.add_pattern("*.jpeg");
            dialog.add_filter(img_filter);
            
            // All files filter
            var all_filter = new Gtk.FileFilter();
            all_filter.set_filter_name("All files");
            all_filter.add_pattern("*");
            dialog.add_filter(all_filter);
            
            // Start in common icon directories
            var pixmaps = "/usr/share/pixmaps";
            if (FileUtils.test(pixmaps, FileTest.IS_DIR)) {
                dialog.set_current_folder(pixmaps);
            }
            
            dialog.set_preview_widget(new Gtk.Image());
            dialog.update_preview.connect(() => {
                var path = dialog.get_preview_filename();
                if (path == null) return;
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale(path, 64, 64, true);
                    ((Gtk.Image)dialog.get_preview_widget()).set_from_pixbuf(pixbuf);
                    dialog.set_preview_widget_active(true);
                } catch (Error e) {
                    dialog.set_preview_widget_active(false);
                }
            });
            
            if (dialog.run() == Gtk.ResponseType.ACCEPT) {
                icon_entry.text = dialog.get_filename();
            }
            dialog.destroy();
        }
        
        private string get_current_theme() {
            var settings = Gtk.Settings.get_default();
            return settings.gtk_application_prefer_dark_theme ? "dark" : "light";
        }
        
        private void set_theme(string theme) {
            var settings = Gtk.Settings.get_default();
            settings.gtk_application_prefer_dark_theme = (theme == "dark");
            reload_panel_css(theme);
            try {
                var config_dir = Environment.get_user_config_dir() + "/novabar";
                DirUtils.create_with_parents(config_dir, 0755);
                FileUtils.set_contents(config_dir + "/theme", theme);
            } catch (Error e) {}
        }
        
        private string get_saved_logo_icon() {
            try {
                var config_file = Environment.get_user_config_dir() + "/novabar/logo_icon";
                if (FileUtils.test(config_file, FileTest.EXISTS)) {
                    string icon;
                    FileUtils.get_contents(config_file, out icon);
                    return icon.strip();
                }
            } catch (Error e) {}
            return "distributor-logo";
        }
        
        private void save_logo_icon(string icon_name) {
            try {
                var config_dir = Environment.get_user_config_dir() + "/novabar";
                DirUtils.create_with_parents(config_dir, 0755);
                var name = icon_name == "" ? "distributor-logo" : icon_name;
                FileUtils.set_contents(config_dir + "/logo_icon", name);
            } catch (Error e) {}
        }
        
        private void reload_panel_css(string theme) {
            var css = new Gtk.CssProvider();
            string filename = theme == "light" ? "novaos-light.css" : "novaos.css";
            string[] paths = {
                "/usr/share/novaos/" + filename,
                Path.build_filename(Environment.get_current_dir(), "data", filename)
            };
            
            foreach (var path in paths) {
                if (FileUtils.test(path, FileTest.EXISTS)) {
                    try { css.load_from_path(path); break; } catch (Error e) {}
                }
            }
            
            apply_theme_css(css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1);
        }
    }
    
    public void load_saved_theme() {
        try {
            string theme = "dark";
            var config_file = Environment.get_user_config_dir() + "/novabar/theme";
            if (FileUtils.test(config_file, FileTest.EXISTS)) {
                FileUtils.get_contents(config_file, out theme);
                theme = theme.strip();
            }
            
            var settings = Gtk.Settings.get_default();
            settings.gtk_application_prefer_dark_theme = (theme == "dark");
            
            // Load appropriate CSS
            var css = new Gtk.CssProvider();
            string filename = theme == "light" ? "novaos-light.css" : "novaos.css";
            string[] paths = {
                "/usr/share/novaos/" + filename,
                Path.build_filename(Environment.get_current_dir(), "data", filename)
            };
            
            foreach (var path in paths) {
                if (FileUtils.test(path, FileTest.EXISTS)) {
                    try { css.load_from_path(path); break; } catch (Error e) {}
                }
            }
            
            apply_theme_css(css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {}
    }
    
    public string get_logo_icon() {
        try {
            var config_file = Environment.get_user_config_dir() + "/novabar/logo_icon";
            if (FileUtils.test(config_file, FileTest.EXISTS)) {
                string icon;
                FileUtils.get_contents(config_file, out icon);
                var saved = icon.strip();
                if (saved != "" && saved != "distributor-logo") {
                    return saved;
                }
            }
        } catch (Error e) {}
        return detect_distro_icon();
    }
    
    public string detect_distro_icon() {
        string? distro_id = null;
        try {
            string contents;
            if (FileUtils.get_contents("/etc/os-release", out contents)) {
                foreach (var line in contents.split("\n")) {
                    if (line.has_prefix("ID=")) {
                        distro_id = line.substring(3).replace("\"", "").down();
                        break;
                    }
                }
            }
        } catch (Error e) {}
        
        if (distro_id != null) {
            // Try distro-specific icon names
            string[] candidates = {
                "distributor-logo-" + distro_id,
                distro_id + "-logo",
                distro_id
            };
            var theme = Gtk.IconTheme.get_default();
            foreach (var icon in candidates) {
                if (theme.has_icon(icon)) {
                    return icon;
                }
            }
        }
        
        // Fallback to generic
        return "distributor-logo";
    }
}

namespace Settings {
    public bool get_network_setting(string key, bool default_value) {
        try {
            var config_file = Environment.get_user_config_dir() + "/novabar/network_" + key;
            if (FileUtils.test(config_file, FileTest.EXISTS)) {
                string value;
                FileUtils.get_contents(config_file, out value);
                return value.strip() == "true";
            }
        } catch (Error e) {}
        return default_value;
    }
    
    public void set_network_setting(string key, string value) {
        try {
            var config_dir = Environment.get_user_config_dir() + "/novabar";
            DirUtils.create_with_parents(config_dir, 0755);
            FileUtils.set_contents(config_dir + "/network_" + key, value);
        } catch (Error e) {}
    }
}
