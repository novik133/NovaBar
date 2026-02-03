/**
 * LogoMenu - Nova logo menu with system actions
 */

namespace LogoMenu {

    public class NovaMenu : Gtk.Button {
        private Gtk.Menu menu;
        private Gtk.Image icon;
        
        public NovaMenu() {
            icon = new Gtk.Image.from_icon_name(Settings.get_logo_icon(), Gtk.IconSize.MENU);
            set_image(icon);
            set_always_show_image(true);
            get_style_context().add_class("flat");
            get_style_context().add_class("nova-logo");
            menu = build_menu();
            menu.attach_to_widget(this, null);
            
            // Cancel menu when clicking on the button area
            menu.button_press_event.connect((e) => {
                int bx, by;
                get_window().get_origin(out bx, out by);
                Gtk.Allocation alloc;
                get_allocation(out alloc);
                
                int mx = (int)e.x_root;
                int my = (int)e.y_root;
                
                if (mx >= bx + alloc.x && mx <= bx + alloc.x + alloc.width &&
                    my >= by + alloc.y && my <= by + alloc.y + alloc.height) {
                    menu.popdown();
                    return true;
                }
                return false;
            });
            
            clicked.connect(() => {
                if (!menu.visible) {
                    menu.popup_at_widget(this, Gdk.Gravity.SOUTH_WEST, Gdk.Gravity.NORTH_WEST, null);
                }
            });
        }
        
        private Gtk.Menu build_menu() {
            var menu = new Gtk.Menu();
            
            add_item(menu, "About This Computer", () => show_about());
            menu.append(new Gtk.SeparatorMenuItem());
            
            add_item(menu, "System Settings...", () => launch("xfce4-settings-manager"));
            add_item(menu, "App Store...", () => launch("pamac-manager"));
            menu.append(new Gtk.SeparatorMenuItem());
            
            add_item(menu, "Force Quit...", () => launch("xkill"));
            menu.append(new Gtk.SeparatorMenuItem());
            
            add_item(menu, "Sleep", () => run_command("systemctl suspend"));
            add_item(menu, "Restart...", () => run_command("systemctl reboot"));
            add_item(menu, "Shut Down...", () => run_command("systemctl poweroff"));
            menu.append(new Gtk.SeparatorMenuItem());
            
            add_item(menu, "Lock Screen", () => run_command("xflock4"));
            add_item(menu, "Log Out...", () => run_command("xfce4-session-logout"));
            
            menu.show_all();
            return menu;
        }
        
        private void add_item(Gtk.Menu menu, string label, owned Func callback) {
            var item = new Gtk.MenuItem.with_label(label);
            item.activate.connect(() => callback());
            menu.append(item);
        }
        
        private void show_about() {
            var window = new About.AboutWindow();
            window.show_all();
        }
        
        private void launch(string app) {
            try {
                Process.spawn_command_line_async(app);
            } catch (Error e) {}
        }
        
        private void run_command(string cmd) {
            try {
                Process.spawn_command_line_async(cmd);
            } catch (Error e) {}
        }
        
        private delegate void Func();
        
        public void set_icon(string icon_name) {
            icon.set_from_icon_name(icon_name, Gtk.IconSize.MENU);
        }
    }
}
