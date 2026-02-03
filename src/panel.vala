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
        Debug.log("Panel", "Creating Bluetooth indicator...");
        right_box.pack_end(new Indicators.Bluetooth(), false, false, 0);
        Debug.log("Panel", "Creating Network indicator...");
        // Temporarily disable Network indicator to test if it's causing the hang
        // right_box.pack_end(new Indicators.Network(), false, false, 0);
        Debug.log("Panel", "All indicators created successfully (Network disabled for testing)");
        
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
    
    private void show_context_menu(Gdk.EventButton e) {
        var menu = new Gtk.Menu();
        
        var settings_item = new Gtk.MenuItem.with_label("NovaBar Settings...");
        settings_item.activate.connect(() => {
            var win = new Settings.SettingsWindow();
            win.logo_icon_changed.connect((icon) => logo_menu.set_icon(icon));
            win.show_all();
        });
        menu.append(settings_item);
        
        menu.show_all();
        menu.popup_at_pointer(e);
    }
    
    private void load_css() {
        // CSS is now loaded by Settings.load_saved_theme()
    }
}
