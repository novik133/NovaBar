/**
 * Wayland Toplevel Tracker using wlr-foreign-toplevel-management
 */

namespace Toplevel {
    
    private static WaylandTracker? wayland_tracker_instance = null;
    
    private static void wayland_toplevel_callback(string? app_id, string? title, int focused) {
        if (wayland_tracker_instance != null) {
            wayland_tracker_instance.handle_toplevel_event(app_id, title, focused);
        }
    }
    
    public class WaylandTracker : Object, Tracker {
        private uint32 panel_id;
        private WindowInfo? current;
        private bool initialized = false;
        
        public void start() {
            wayland_tracker_instance = this;
            
#if HAVE_WAYLAND
            if (WlrToplevel.init() != 0) {
                initialized = true;
                WlrToplevel.set_callback(wayland_toplevel_callback);
                Timeout.add(100, poll_events);
            } else {
                show_fallback();
            }
#else
            show_fallback();
#endif
        }
        
        private void show_fallback() {
            current = new WindowInfo(0, "Desktop", "");
            Idle.add(() => {
                active_window_changed(current);
                return false;
            });
        }
        
        public void set_panel_id(uint32 id) {
            panel_id = id;
        }
        
        public WindowInfo? get_active_window() {
            return current;
        }
        
#if HAVE_WAYLAND
        private bool poll_events() {
            if (!initialized) return false;
            WlrToplevel.read_events();
            WlrToplevel.dispatch();
            return true;
        }
#endif
        
        public void handle_toplevel_event(string? app_id, string? title, int focused) {
            if (focused == 0) return;
            
            string display_name = "Desktop";
            if (title != null && title.length > 0) {
                display_name = title;
            } else if (app_id != null && app_id.length > 0) {
                display_name = app_id;
            }
            
            var id = (uint32)(display_name.hash());
            
            if (current == null || current.id != id) {
                current = new WindowInfo(id, display_name, app_id ?? "");
                active_window_changed(current);
            }
        }
        
        ~WaylandTracker() {
            wayland_tracker_instance = null;
#if HAVE_WAYLAND
            if (initialized) {
                WlrToplevel.cleanup();
            }
#endif
        }
    }
}
