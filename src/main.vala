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
        Debug.log("App", "Loading theme...");
        Settings.load_saved_theme();
        Debug.log("App", "Creating panel...");
        var panel = new NovaPanel(this);
        Debug.log("App", "Showing panel...");
        panel.show();
        Debug.log("App", "Panel activated");
    }
    
    public static int main(string[] args) {
        Debug.init(args);
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
