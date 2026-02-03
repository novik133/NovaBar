/**
 * X11 Panel Setup - Strut reservation and X11-specific window setup
 */

namespace Backend.X11 {
    
    public void setup_panel_window(Gtk.Window window, int panel_height) {
        window.set_type_hint(Gdk.WindowTypeHint.DOCK);
        
        window.realize.connect(() => {
            reserve_strut(window, panel_height);
        });
    }
    
    private void reserve_strut(Gtk.Window window, int panel_height) {
        var gdk_window = window.get_window();
        if (gdk_window == null) return;
        
        var display = window.get_display();
        var monitor = display.get_primary_monitor() ?? display.get_monitor(0);
        var geom = monitor.get_geometry();
        
        var xwin = (Gdk.X11.Window)gdk_window;
        unowned X.Display xdisplay = ((Gdk.X11.Display)display).get_xdisplay();
        var xid = xwin.get_xid();
        
        long strut[12] = { 0, 0, panel_height, 0, 0, 0, 0, 0, geom.x, geom.x + geom.width - 1, 0, 0 };
        var atom = xdisplay.intern_atom("_NET_WM_STRUT_PARTIAL", false);
        xdisplay.change_property((X.Window)xid, atom, X.XA_CARDINAL, 32, X.PropMode.Replace, (uchar[])strut, 12);
    }
    
    public uint32 get_window_xid(Gtk.Window window) {
        var gdk_window = window.get_window();
        if (gdk_window == null) return 0;
        return (uint32)((Gdk.X11.Window)gdk_window).get_xid();
    }
}
