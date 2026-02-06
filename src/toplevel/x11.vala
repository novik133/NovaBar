/**
 * X11 Toplevel Tracker - Window tracking using libwnck
 */

namespace Toplevel {
    
    public class X11Tracker : Object, Tracker {
        private Wnck.Screen screen;
        private uint32 panel_id;
        private WindowInfo? current;
        
        public void start() {
            Debug.log("X11Tracker", "Getting default screen...");
            screen = Wnck.Screen.get_default();
            Debug.log("X11Tracker", "Connecting active_window_changed signal...");
            screen.active_window_changed.connect(on_active_changed);
            
            Debug.log("X11Tracker", "Adding idle callback...");
            Idle.add(() => {
                Debug.log("X11Tracker", "Idle callback executing...");
                on_active_changed(null);
                Debug.log("X11Tracker", "Initial active window check complete");
                return false;
            });
            Debug.log("X11Tracker", "X11Tracker start() complete");
        }
        
        public void set_panel_id(uint32 id) {
            panel_id = id;
        }
        
        public WindowInfo? get_active_window() {
            return current;
        }
        
        private void on_active_changed(Wnck.Window? prev) {
            var window = screen.get_active_window();
            if (window == null) return;
            
            var xid = (uint32)window.get_xid();
            if (xid == panel_id) return;
            if (current != null && current.id == xid) return;
            
            var wtype = window.get_window_type();
            if (wtype == Wnck.WindowType.DESKTOP || wtype == Wnck.WindowType.DOCK) return;
            
            var app = window.get_application();
            var app_name = app != null ? app.get_name() : window.get_name();
            
            current = new WindowInfo(xid, app_name, window.get_name());
            active_window_changed(current);
        }
    }
}
