/**
 * Toplevel Tracker - Abstract interface for window tracking
 */

namespace Toplevel {
    
    public class WindowInfo : Object {
        public string app_id { get; set; }
        public string title { get; set; }
        public uint32 id { get; set; }
        
        public WindowInfo(uint32 id, string app_id, string title) {
            this.id = id;
            this.app_id = app_id;
            this.title = title;
        }
    }
    
    public interface Tracker : Object {
        public signal void active_window_changed(WindowInfo? window);
        public abstract void start();
        public abstract WindowInfo? get_active_window();
        public abstract void set_panel_id(uint32 id);
    }
    
    public Tracker create_tracker() {
        if (Backend.is_wayland()) {
            return new WaylandTracker();
        } else {
            return new X11Tracker();
        }
    }
}
