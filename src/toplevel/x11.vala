/**
 * X11 Toplevel Tracker - Window tracking using libwnck
 */

namespace Toplevel {
    
    public class X11Tracker : Object, Tracker {
        private Wnck.Screen screen;
        private uint32 panel_id;
        private WindowInfo? current;
        
        public void start() {
            screen = Wnck.Screen.get_default();
            screen.active_window_changed.connect(on_active_changed);
            
            Idle.add(() => {
                on_active_changed(null);
                return false;
            });
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
