/**
 * Backend detection - Runtime X11/Wayland detection
 */

namespace Backend {
    
    public enum DisplayServer {
        X11,
        WAYLAND,
        UNKNOWN
    }
    
    private DisplayServer? _cached = null;
    
    public DisplayServer get_display_server() {
        if (_cached != null) return _cached;
        
        var backend = Environment.get_variable("GDK_BACKEND");
        if (backend == "wayland") {
            Debug.log("Backend", "Detected Wayland via GDK_BACKEND");
            _cached = DisplayServer.WAYLAND;
            return _cached;
        }
        if (backend == "x11") {
            Debug.log("Backend", "Detected X11 via GDK_BACKEND");
            _cached = DisplayServer.X11;
            return _cached;
        }
        
        var display = Gdk.Display.get_default();
        if (display != null) {
            var type_name = display.get_type().name();
            Debug.log("Backend", "GdkDisplay type: " + type_name);
            if (type_name == "GdkWaylandDisplay") {
                _cached = DisplayServer.WAYLAND;
            } else if (type_name == "GdkX11Display") {
                _cached = DisplayServer.X11;
            } else {
                Debug.log("Backend", "WARNING: Unknown display type");
                _cached = DisplayServer.UNKNOWN;
            }
        } else {
            Debug.log("Backend", "ERROR: No display available");
            _cached = DisplayServer.UNKNOWN;
        }
        
        return _cached;
    }
    
    public bool is_wayland() {
        return get_display_server() == DisplayServer.WAYLAND;
    }
    
    public bool is_x11() {
        return get_display_server() == DisplayServer.X11;
    }
}
