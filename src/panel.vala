/**
 * NovaOS Panel - Main panel window
 */

public class NovaPanel : Gtk.Window {
    private const int PANEL_HEIGHT = 28;
    
    private Gtk.Box container;
    private Gtk.Box left_box;
    private Gtk.Box center_box;
    private Gtk.Box right_box;
    private LogoMenu.NovaMenu logo_menu;
    
    public NovaPanel(Gtk.Application app) {
        Object(application: app);
        
        // Wayland: must init layer-shell BEFORE realize
        if (Backend.is_wayland()) {
            Debug.log("Panel", "Setting up Wayland layer-shell...");
            Backend.Wayland.setup_panel_window(this, PANEL_HEIGHT);
        }
        
        set_decorated(false);
        set_skip_taskbar_hint(true);
        set_skip_pager_hint(true);
        set_keep_above(true);
        stick();
        
        // X11: setup after window hints
        if (Backend.is_x11()) {
            Debug.log("Panel", "Setting up X11 panel window...");
            Backend.X11.setup_panel_window(this, PANEL_HEIGHT);
        }
        
        Debug.log("Panel", "Setting up geometry...");
        setup_geometry();
        Debug.log("Panel", "Setting up layout...");
        setup_layout();
        Debug.log("Panel", "Loading CSS...");
        load_css();
        
        Debug.log("Panel", "Calling show_all...");
        show_all();
        Debug.log("Panel", "Panel construction complete");
    }
    
    private void setup_geometry() {
        var display = Gdk.Display.get_default();
        var monitor = display.get_primary_monitor() ?? display.get_monitor(0);
        if (monitor == null) {
            Debug.log("Panel", "ERROR: No monitor found");
            return;
        }
        var geom = monitor.get_geometry();
        Debug.log("Panel", "Monitor geometry: %dx%d at %d,%d".printf(geom.width, geom.height, geom.x, geom.y));
        
        set_default_size(geom.width, PANEL_HEIGHT);
        
        // Only move window on X11, Wayland uses layer-shell anchors
        if (Backend.is_x11()) {
            move(geom.x, geom.y);
        }
    }
    
    private void setup_layout() {
        // Enable right-click
        add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
        button_press_event.connect((e) => {
            if (e.button == 3) {
                show_context_menu(e);
                return true;
            }
            return false;
        });
        
        container = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        container.get_style_context().add_class("panel-container");
        
        left_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
        left_box.margin_start = 8;
        
        center_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        center_box.hexpand = true;
        center_box.halign = Gtk.Align.START;
        
        right_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
        right_box.margin_end = 8;
        
        // Left: Logo menu
        logo_menu = new LogoMenu.NovaMenu();
        left_box.pack_start(logo_menu, false, false, 0);
        
        // Center: Global menu
        Debug.log("Panel", "Creating GlobalMenu...");
        var menubar = new GlobalMenu.MenuBar();
        center_box.pack_start(menubar, false, false, 0);
        Debug.log("Panel", "GlobalMenu created successfully");
        
        // Right: Indicators
        Debug.log("Panel", "Creating DateTime indicator...");
        right_box.pack_end(new Indicators.DateTime(), false, false, 0);
        Debug.log("Panel", "Creating ControlCenter indicator...");
        right_box.pack_end(new Indicators.ControlCenter(), false, false, 0);
        Debug.log("Panel", "Creating Notifications indicator...");
        right_box.pack_end(new Indicators.Notifications(), false, false, 0);
        Debug.log("Panel", "Creating Battery indicator...");
        right_box.pack_end(new Indicators.Battery(), false, false, 0);
        Debug.log("Panel", "Creating Sound indicator...");
        right_box.pack_end(new Indicators.Sound(), false, false, 0);
        Debug.log("Panel", "Creating Enhanced Bluetooth indicator...");
        right_box.pack_end(new Indicators.Enhanced.BluetoothIndicator(), false, false, 0);
        Debug.log("Panel", "Creating Enhanced Network indicator...");
        right_box.pack_end(new Indicators.Enhanced.NetworkIndicator(), false, false, 0);
        Debug.log("Panel", "All indicators created successfully");
        
        container.pack_start(left_box, false, false, 0);
        container.pack_start(center_box, true, true, 0);
        container.pack_end(right_box, false, false, 0);
        
        Debug.log("Panel", "Adding container to window...");
        add(container);
        
        Debug.log("Panel", "Setting up realize callback...");
        // Set panel window for global menu after realize
        realize.connect(() => {
            Debug.log("Panel", "Panel realized, setting panel window for global menu...");
            menubar.set_panel_window(this);
            Debug.log("Panel", "Panel window set for global menu");
        });
        Debug.log("Panel", "Layout setup complete");
    }
    
    private Gtk.Window? context_popup = null;
    
    private void show_context_menu(Gdk.EventButton e) {
        if (context_popup != null && context_popup.visible) {
            dismiss_context_popup();
            return;
        }
        
        context_popup = new Gtk.Window(Gtk.WindowType.POPUP);
        Backend.setup_popup(context_popup, PANEL_HEIGHT);
        context_popup.set_keep_above(true);
        context_popup.set_app_paintable(true);
        
        var screen = context_popup.get_screen();
        var visual = screen.get_rgba_visual();
        if (visual != null) context_popup.set_visual(visual);
        
        context_popup.draw.connect((cr) => {
            int w = context_popup.get_allocated_width();
            int h = context_popup.get_allocated_height();
            double r = 10;
            cr.new_sub_path();
            cr.arc(w - r, r, r, -Math.PI/2, 0);
            cr.arc(w - r, h - r, r, 0, Math.PI/2);
            cr.arc(r, h - r, r, Math.PI/2, Math.PI);
            cr.arc(r, r, r, Math.PI, 3*Math.PI/2);
            cr.close_path();
            cr.set_source_rgba(0.22, 0.22, 0.22, 0.96);
            cr.fill_preserve();
            cr.set_source_rgba(1, 1, 1, 0.12);
            cr.set_line_width(1);
            cr.stroke();
            return false;
        });
        
        context_popup.key_press_event.connect((ev) => {
            if (ev.keyval == Gdk.Key.Escape) { dismiss_context_popup(); return true; }
            return false;
        });
        context_popup.button_press_event.connect((ev) => {
            int w, h;
            context_popup.get_size(out w, out h);
            if (ev.x < 0 || ev.y < 0 || ev.x > w || ev.y > h) { dismiss_context_popup(); }
            return false;
        });
        context_popup.focus_out_event.connect(() => { dismiss_context_popup(); return false; });
        
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        box.margin = 6;
        box.set_size_request(200, -1);
        
        var settings_btn = new Gtk.Button.with_label("NovaBar Settings...");
        settings_btn.get_style_context().add_class("flat");
        settings_btn.halign = Gtk.Align.FILL;
        ((Gtk.Label)settings_btn.get_child()).halign = Gtk.Align.START;
        ((Gtk.Label)settings_btn.get_child()).margin_start = 6;
        settings_btn.clicked.connect(() => {
            dismiss_context_popup();
            var win = new Settings.SettingsWindow();
            win.logo_icon_changed.connect((icon) => logo_menu.set_icon(icon));
            win.show_all();
        });
        box.pack_start(settings_btn, false, false, 0);
        
        context_popup.add(box);
        
        int x = (int)e.x_root;
        int y = (int)e.y_root;
        context_popup.show_all();
        Backend.position_popup(context_popup, x, y, PANEL_HEIGHT);
        if (Backend.is_x11()) {
            var seat = Gdk.Display.get_default().get_default_seat();
            if (seat != null && context_popup.get_window() != null) {
                seat.grab(context_popup.get_window(), Gdk.SeatCapabilities.ALL, true, null, null, null);
            }
        }
        context_popup.present();
    }
    
    private void dismiss_context_popup() {
        if (context_popup == null) return;
        var seat = Gdk.Display.get_default().get_default_seat();
        if (seat != null) seat.ungrab();
        context_popup.hide();
        context_popup.destroy();
        context_popup = null;
    }
    
    private void load_css() {
        // CSS is now loaded by Settings.load_saved_theme()
    }
}
