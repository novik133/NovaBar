/**
 * NovaOS Panel - Application entry point
 */

namespace Debug {
    private static bool _verbose = false;
    
    public void init(string[] args) {
        foreach (var arg in args) {
            if (arg == "-v" || arg == "--verbose") {
                _verbose = true;
                break;
            }
        }
    }
    
    public void log(string component, string message) {
        if (_verbose) {
            print("[%s] %s\n", component, message);
        }
    }
    
    public bool is_verbose() {
        return _verbose;
    }
}

public class NovaApp : Gtk.Application {
    
    public NovaApp() {
        Object(application_id: "org.novaos.panel", flags: ApplicationFlags.FLAGS_NONE);
    }
    
    protected override void startup() {
        base.startup();
        Debug.log("App", "startup() called");
    }
    
    protected override void activate() {
        Debug.log("App", "activate() called");
        
        // Set application icon
        string[] icon_paths = {
            "/usr/share/icons/hicolor/256x256/apps/novabar.png",
            "/usr/share/pixmaps/novabar.png",
            Path.build_filename(Environment.get_current_dir(), "data", "icons", "macos-style-icon-ofmenu-bar.png")
        };
        foreach (var path in icon_paths) {
            if (FileUtils.test(path, FileTest.EXISTS)) {
                try {
                    Gtk.Window.set_default_icon(new Gdk.Pixbuf.from_file_at_scale(path, 256, 256, true));
                    Debug.log("App", "Set application icon from: " + path);
                    break;
                } catch (Error e) {}
            }
        }
        
        Debug.log("App", "Loading theme...");
        Settings.load_saved_theme();
        Debug.log("App", "Creating panel...");
        var panel = new NovaPanel(this);
        Debug.log("App", "Showing panel...");
        panel.show();
        Debug.log("App", "Panel activated");
    }
    
    /**
     * Set up the environment so GTK apps export their menus via D-Bus
     * and hide their in-app menubars.
     */
    private static void setup_global_menu_environment() {
        // 1. Set GTK_MODULES so GTK apps load appmenu-gtk-module
        var gtk_modules = Environment.get_variable("GTK_MODULES") ?? "";
        if (!gtk_modules.contains("appmenu-gtk-module")) {
            if (gtk_modules.length > 0) {
                gtk_modules += ":appmenu-gtk-module";
            } else {
                gtk_modules = "appmenu-gtk-module";
            }
            Environment.set_variable("GTK_MODULES", gtk_modules, true);
        }

        // 2. Propagate to D-Bus activation env AND systemd user env
        //    This covers apps launched via D-Bus activation, systemd user
        //    services, and apps spawned by other D-Bus-activated apps.
        try {
            Process.spawn_command_line_sync(
                "dbus-update-activation-environment --systemd GTK_MODULES"
            );
        } catch (Error e) {}

        // 3. Write environment.d file so the setting persists across
        //    the entire user session (covers apps launched from panels,
        //    file managers, terminals opened later, etc.)
        try {
            var env_dir = Path.build_filename(
                Environment.get_user_config_dir(), "environment.d");
            DirUtils.create_with_parents(env_dir, 0755);
            var env_path = Path.build_filename(env_dir, "novabar-globalmenu.conf");
            var content = "GTK_MODULES=appmenu-gtk-module\n";
            FileUtils.set_contents(env_path, content);
        } catch (Error e) {}

        // 4. Tell GTK that the shell handles the menubar so
        //    appmenu-gtk-module hides the in-app GtkMenuBar.
        //    a) XFCE xfconf (live XSettings update)
        try {
            Process.spawn_command_line_sync(
                "xfconf-query -c xsettings -p /Gtk/ShellShowsMenubar -t bool -s true --create"
            );
            Process.spawn_command_line_sync(
                "xfconf-query -c xsettings -p /Gtk/ShellShowsAppMenu -t bool -s true --create"
            );
        } catch (Error e) {}

        //    b) gtk-3.0/settings.ini (fallback for non-XFCE desktops)
        try {
            var gtk3_dir = Path.build_filename(
                Environment.get_user_config_dir(), "gtk-3.0");
            var settings_path = Path.build_filename(gtk3_dir, "settings.ini");
            DirUtils.create_with_parents(gtk3_dir, 0755);
            string existing = "";
            try {
                FileUtils.get_contents(settings_path, out existing);
            } catch (Error e) {
                existing = "";
            }
            if (!existing.contains("gtk-shell-shows-menubar")) {
                if (!existing.contains("[Settings]")) {
                    existing = "[Settings]\n" + existing;
                }
                existing = existing.replace("[Settings]",
                    "[Settings]\ngtk-shell-shows-menubar=1\ngtk-shell-shows-app-menu=1");
                FileUtils.set_contents(settings_path, existing);
            }
        } catch (Error e) {}

        // 5. Write a GTK3 CSS override that hides GtkMenuBar in all apps.
        //    This is the bulletproof fallback: even if appmenu-gtk-module
        //    doesn't fully hide the widget, CSS will collapse it to zero height.
        try {
            var gtk3_dir = Path.build_filename(
                Environment.get_user_config_dir(), "gtk-3.0");
            var css_path = Path.build_filename(gtk3_dir, "gtk.css");
            DirUtils.create_with_parents(gtk3_dir, 0755);
            string css_content = "";
            try {
                FileUtils.get_contents(css_path, out css_content);
            } catch (Error e) {
                css_content = "";
            }
            var marker = "/* NovaBar global menu */";
            // Remove old version of our rule if present, then add updated one
            if (css_content.contains(marker)) {
                // Already has our marker — replace the block
                var start = css_content.index_of(marker);
                var end_marker = "/* end NovaBar global menu */";
                var end = css_content.index_of(end_marker);
                if (end > start) {
                    css_content = css_content.substring(0, start) +
                                  css_content.substring(end + end_marker.length);
                } else {
                    // Old format without end marker — remove from marker to next blank line
                    css_content = css_content.substring(0, start);
                }
            }
            var rule = "%s\nmenubar {\n  min-height: 0;\n  padding: 0;\n  margin: 0;\n  border: none;\n}\nmenubar > menuitem {\n  min-height: 0;\n  padding: 0;\n  margin: 0;\n}\n/* end NovaBar global menu */\n".printf(marker);
            css_content = css_content.strip() + "\n\n" + rule;
            FileUtils.set_contents(css_path, css_content);
        } catch (Error e) {}

        // 6. Write ~/.xprofile entry so GTK_MODULES is set at login time
        //    for ALL apps in the X session (not just D-Bus activated ones).
        try {
            var home = Environment.get_home_dir();
            var xprofile_path = Path.build_filename(home, ".xprofile");
            string xprofile = "";
            try {
                FileUtils.get_contents(xprofile_path, out xprofile);
            } catch (Error e) {
                xprofile = "";
            }
            var marker = "# NovaBar global menu";
            if (!xprofile.contains(marker)) {
                xprofile += "\n%s\nexport GTK_MODULES=\"appmenu-gtk-module${GTK_MODULES:+:$GTK_MODULES}\"\n".printf(marker);
                FileUtils.set_contents(xprofile_path, xprofile);
            }
        } catch (Error e) {}
    }

    public static int main(string[] args) {
        Debug.init(args);
        
        // ---- Global Menu environment setup ----
        setup_global_menu_environment();
        
        if (Debug.is_verbose()) {
            print("NovaBar starting in verbose mode...\n");
            print("Display: %s\n", Environment.get_variable("DISPLAY") ?? "(not set)");
            print("Wayland Display: %s\n", Environment.get_variable("WAYLAND_DISPLAY") ?? "(not set)");
            print("GDK_BACKEND: %s\n", Environment.get_variable("GDK_BACKEND") ?? "(not set)");
            print("XDG_SESSION_TYPE: %s\n", Environment.get_variable("XDG_SESSION_TYPE") ?? "(not set)");
        }
        // Filter out verbose flags before passing to GTK
        string[] filtered = {};
        foreach (var arg in args) {
            if (arg != "-v" && arg != "--verbose") {
                filtered += arg;
            }
        }
        Debug.log("Main", "Creating application...");
        var app = new NovaApp();
        Debug.log("Main", "Calling app.run()...");
        int status = app.run(filtered);
        Debug.log("Main", "app.run() returned %d".printf(status));
        return status;
    }
}
