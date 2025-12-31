/**
 * NovaBar Settings Window
 */

namespace Settings {

    public class SettingsWindow : Gtk.Window {
        public signal void logo_icon_changed(string icon_name);
        
        private Gtk.Stack stack;
        private Gtk.ComboBoxText theme_combo;
        private Gtk.Entry icon_entry;
        
        public SettingsWindow() {
            title = "NovaBar Settings";
            set_default_size(450, 400);
            set_resizable(false);
            window_position = Gtk.WindowPosition.CENTER;
            
            var header = new Gtk.HeaderBar();
            header.show_close_button = false;
            header.title = "NovaBar Settings";
            set_titlebar(header);
            
            var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            
            stack = new Gtk.Stack();
            stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
            
            var switcher = new Gtk.StackSwitcher();
            switcher.stack = stack;
            switcher.halign = Gtk.Align.CENTER;
            switcher.margin = 12;
            
            stack.add_titled(create_theme_tab(), "theme", "Theme");
            stack.add_titled(create_about_tab(), "about", "About");
            
            main_box.pack_start(switcher, false, false, 0);
            main_box.pack_start(stack, true, true, 0);
            main_box.pack_end(create_button_box(), false, false, 12);
            
            add(main_box);
        }
        
        private Gtk.Widget create_button_box() {
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            box.halign = Gtk.Align.END;
            box.margin_end = 12;
            
            var close_btn = new Gtk.Button.with_label("Close");
            close_btn.clicked.connect(() => destroy());
            
            var save_btn = new Gtk.Button.with_label("Save");
            save_btn.get_style_context().add_class("suggested-action");
            save_btn.clicked.connect(save_settings);
            
            box.pack_start(close_btn, false, false, 0);
            box.pack_start(save_btn, false, false, 0);
            return box;
        }
        
        private Gtk.Widget create_theme_tab() {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 16);
            box.margin = 24;
            box.valign = Gtk.Align.START;
            
            var label = new Gtk.Label("Appearance");
            label.get_style_context().add_class("settings-section-title");
            label.halign = Gtk.Align.START;
            box.pack_start(label, false, false, 0);
            
            // Theme
            var theme_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            var theme_label = new Gtk.Label("Theme:");
            theme_label.halign = Gtk.Align.START;
            theme_box.pack_start(theme_label, false, false, 0);
            
            theme_combo = new Gtk.ComboBoxText();
            theme_combo.append("light", "Light");
            theme_combo.append("dark", "Dark");
            theme_combo.active_id = get_current_theme();
            theme_box.pack_start(theme_combo, false, false, 0);
            box.pack_start(theme_box, false, false, 0);
            
            // Logo icon
            var icon_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            var icon_label = new Gtk.Label("Logo Icon:");
            icon_label.halign = Gtk.Align.START;
            icon_box.pack_start(icon_label, false, false, 0);
            
            icon_entry = new Gtk.Entry();
            icon_entry.text = get_saved_logo_icon();
            icon_entry.placeholder_text = "distributor-logo";
            icon_box.pack_start(icon_entry, true, true, 0);
            box.pack_start(icon_box, false, false, 0);
            
            return box;
        }
        
        private void save_settings() {
            set_theme(theme_combo.active_id);
            save_logo_icon(icon_entry.text.strip());
            logo_icon_changed(icon_entry.text.strip());
            destroy();
        }
        
        private Gtk.Widget create_about_tab() {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            box.margin = 24;
            box.valign = Gtk.Align.CENTER;
            
            // Logo
            var logo = new Gtk.Image.from_icon_name("preferences-desktop", Gtk.IconSize.DIALOG);
            logo.pixel_size = 64;
            box.pack_start(logo, false, false, 0);
            
            // Name and version
            var name_label = new Gtk.Label("NovaBar");
            name_label.get_style_context().add_class("about-os-name");
            box.pack_start(name_label, false, false, 0);
            
            var version_label = new Gtk.Label("Version 0.1.1");
            version_label.get_style_context().add_class("dim-label");
            box.pack_start(version_label, false, false, 0);
            
            // Author info
            var author_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            author_box.margin_top = 16;
            
            var author = new Gtk.Label("Created by Kamil 'Novik' Nowicki");
            author_box.pack_start(author, false, false, 0);
            
            var email_btn = new Gtk.LinkButton.with_label("mailto:novik@noviktech.com", "novik@noviktech.com");
            author_box.pack_start(email_btn, false, false, 0);
            
            var website_btn = new Gtk.LinkButton.with_label("https://noviktech.com", "noviktech.com");
            author_box.pack_start(website_btn, false, false, 0);
            
            var github_btn = new Gtk.LinkButton.with_label("https://github.com/novik133/NovaBar", "GitHub");
            author_box.pack_start(github_btn, false, false, 0);
            
            box.pack_start(author_box, false, false, 0);
            
            // Copyright and license
            var copyright = new Gtk.Label("© 2025 Kamil Nowicki");
            copyright.get_style_context().add_class("dim-label");
            copyright.margin_top = 16;
            box.pack_start(copyright, false, false, 0);
            
            var license_btn = new Gtk.LinkButton.with_label("https://www.gnu.org/licenses/gpl-3.0.en.html", "GPL-3.0 License");
            box.pack_start(license_btn, false, false, 0);
            
            return box;
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
            
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1
            );
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
            
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {}
    }
    
    public string get_logo_icon() {
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
}
