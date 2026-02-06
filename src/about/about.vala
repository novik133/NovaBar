/**
 * About This Computer - Modern system info window
 */

namespace About {

    public class AboutWindow : Gtk.Window {
        private Gtk.Stack stack;
        private Gtk.ListBox sidebar;
        
        public AboutWindow() {
            title = "About This Computer";
            set_default_size(700, 500);
            set_resizable(false);
            window_position = Gtk.WindowPosition.CENTER;
            
            load_about_css();
            
            var header = new Gtk.HeaderBar();
            header.show_close_button = true;
            header.title = "About This Computer";
            header.get_style_context().add_class("about-header");
            set_titlebar(header);
            
            var root = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            
            // --- Sidebar ---
            var sidebar_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            sidebar_box.get_style_context().add_class("about-sidebar");
            sidebar_box.set_size_request(180, -1);
            
            var sidebar_title = new Gtk.Label("System");
            sidebar_title.get_style_context().add_class("about-sidebar-title");
            sidebar_title.halign = Gtk.Align.START;
            sidebar_title.margin_start = 18;
            sidebar_title.margin_top = 16;
            sidebar_title.margin_bottom = 12;
            sidebar_box.pack_start(sidebar_title, false, false, 0);
            
            sidebar = new Gtk.ListBox();
            sidebar.get_style_context().add_class("about-sidebar-list");
            sidebar.selection_mode = Gtk.SelectionMode.SINGLE;
            sidebar.activate_on_single_click = true;
            
            add_sidebar_row("computer-symbolic", "Overview");
            add_sidebar_row("video-display-symbolic", "Displays");
            add_sidebar_row("drive-harddisk-symbolic", "Storage");
            
            sidebar.row_activated.connect(on_sidebar_row_activated);
            sidebar_box.pack_start(sidebar, true, true, 0);
            
            // --- Content ---
            stack = new Gtk.Stack();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            stack.transition_duration = 200;
            stack.hexpand = true;
            stack.vexpand = true;
            
            stack.add_named(create_overview_page(), "overview");
            stack.add_named(create_displays_page(), "displays");
            stack.add_named(create_storage_page(), "storage");
            
            var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            content_box.pack_start(stack, true, true, 0);
            
            var sep = new Gtk.Separator(Gtk.Orientation.VERTICAL);
            
            root.pack_start(sidebar_box, false, false, 0);
            root.pack_start(sep, false, false, 0);
            root.pack_start(content_box, true, true, 0);
            
            add(root);
            sidebar.select_row(sidebar.get_row_at_index(0));
        }
        
        // --- CSS ---
        
        private void load_about_css() {
            var css = new Gtk.CssProvider();
            try {
                css.load_from_data("""
                    .about-header {
                        border-bottom: 1px solid alpha(@theme_fg_color, 0.08);
                    }
                    .about-sidebar {
                        background-color: alpha(@theme_bg_color, 0.6);
                    }
                    .about-sidebar-title {
                        font-size: 13px;
                        font-weight: 700;
                        opacity: 0.5;
                        letter-spacing: 0.5px;
                    }
                    .about-sidebar-list {
                        background: transparent;
                    }
                    .about-sidebar-list row {
                        padding: 8px 16px;
                        margin: 2px 8px;
                        border-radius: 8px;
                        background: transparent;
                    }
                    .about-sidebar-list row:selected {
                        background-color: alpha(@theme_selected_bg_color, 0.85);
                    }
                    .about-sidebar-list row:hover:not(:selected) {
                        background-color: alpha(@theme_fg_color, 0.06);
                    }
                    .about-sidebar-icon {
                        margin-right: 10px;
                        opacity: 0.75;
                    }
                    .about-sidebar-label {
                        font-size: 13px;
                        font-weight: 500;
                    }
                    .about-page-title {
                        font-size: 22px;
                        font-weight: 700;
                    }
                    .about-page-subtitle {
                        font-size: 12px;
                        opacity: 0.55;
                    }
                    .about-card {
                        background-color: alpha(@theme_fg_color, 0.04);
                        border-radius: 12px;
                        padding: 4px 0;
                    }
                    .about-card-row {
                        padding: 10px 16px;
                        min-height: 18px;
                    }
                    .about-card-row-label {
                        font-size: 13px;
                        opacity: 0.55;
                        font-weight: 500;
                    }
                    .about-card-row-value {
                        font-size: 13px;
                    }
                    .about-card-separator {
                        margin-left: 16px;
                        margin-right: 16px;
                        opacity: 0.15;
                    }
                    .about-section-header {
                        font-size: 12px;
                        font-weight: 600;
                        opacity: 0.45;
                        letter-spacing: 0.3px;
                    }
                    .about-hero-name {
                        font-size: 24px;
                        font-weight: 300;
                    }
                    .about-hero-version {
                        font-size: 12px;
                        opacity: 0.5;
                    }
                    .about-display-card {
                        background-color: alpha(@theme_fg_color, 0.04);
                        border-radius: 12px;
                        padding: 16px;
                    }
                    .about-display-name {
                        font-size: 14px;
                        font-weight: 600;
                    }
                    .about-display-res {
                        font-size: 12px;
                        opacity: 0.55;
                    }
                    .about-storage-card {
                        background-color: alpha(@theme_fg_color, 0.04);
                        border-radius: 12px;
                        padding: 16px;
                    }
                    .about-storage-name {
                        font-size: 14px;
                        font-weight: 600;
                    }
                    .about-storage-detail {
                        font-size: 12px;
                        opacity: 0.55;
                    }
                    .about-storage-bar trough {
                        min-height: 8px;
                        border-radius: 4px;
                    }
                    .about-storage-bar progress {
                        min-height: 8px;
                        border-radius: 4px;
                        background-color: @theme_selected_bg_color;
                    }
                """);
            } catch (Error e) {}
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 2
            );
        }
        
        // --- Sidebar helpers ---
        
        private void add_sidebar_row(string icon_name, string label_text) {
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            var icon = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.MENU);
            icon.get_style_context().add_class("about-sidebar-icon");
            var label = new Gtk.Label(label_text);
            label.get_style_context().add_class("about-sidebar-label");
            label.halign = Gtk.Align.START;
            box.pack_start(icon, false, false, 0);
            box.pack_start(label, false, false, 0);
            sidebar.insert(box, -1);
        }
        
        private void on_sidebar_row_activated(Gtk.ListBoxRow row) {
            switch (row.get_index()) {
                case 0: stack.set_visible_child_name("overview"); break;
                case 1: stack.set_visible_child_name("displays"); break;
                case 2: stack.set_visible_child_name("storage"); break;
            }
        }
        
        // --- Card helpers ---
        
        private Gtk.Box create_card() {
            var card = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            card.get_style_context().add_class("about-card");
            return card;
        }
        
        private void card_separator(Gtk.Box card) {
            var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            sep.get_style_context().add_class("about-card-separator");
            card.pack_start(sep, false, false, 0);
        }
        
        private void card_info_row(Gtk.Box card, string label, string value, bool sep) {
            if (sep) card_separator(card);
            var row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            row.get_style_context().add_class("about-card-row");
            
            var lbl = new Gtk.Label(label);
            lbl.get_style_context().add_class("about-card-row-label");
            lbl.halign = Gtk.Align.START;
            lbl.set_size_request(90, -1);
            row.pack_start(lbl, false, false, 0);
            
            var val = new Gtk.Label(value);
            val.get_style_context().add_class("about-card-row-value");
            val.halign = Gtk.Align.START;
            val.hexpand = true;
            val.selectable = true;
            val.ellipsize = Pango.EllipsizeMode.END;
            row.pack_start(val, true, true, 0);
            
            card.pack_start(row, false, false, 0);
        }
        
        private Gtk.Label section_header(string text) {
            var label = new Gtk.Label(text.up());
            label.get_style_context().add_class("about-section-header");
            label.halign = Gtk.Align.START;
            label.margin_start = 4;
            return label;
        }
        
        // --- Pages ---
        
        private Gtk.Widget create_overview_page() {
            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            
            var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            page.margin = 32;
            page.margin_top = 24;
            page.valign = Gtk.Align.START;
            
            // Hero section
            var hero = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            hero.halign = Gtk.Align.CENTER;
            hero.margin_bottom = 12;
            
            var logo = new Gtk.Image.from_icon_name(Settings.get_logo_icon(), Gtk.IconSize.DIALOG);
            logo.pixel_size = 96;
            hero.pack_start(logo, false, false, 0);
            
            var os_label = new Gtk.Label(get_os_name());
            os_label.get_style_context().add_class("about-hero-name");
            hero.pack_start(os_label, false, false, 0);
            
            var ver_text = get_os_version();
            if (ver_text != "") {
                var ver_label = new Gtk.Label(ver_text);
                ver_label.get_style_context().add_class("about-hero-version");
                hero.pack_start(ver_label, false, false, 0);
            }
            
            page.pack_start(hero, false, false, 0);
            
            // System info card
            page.pack_start(section_header("System"), false, false, 0);
            
            var sys_card = create_card();
            card_info_row(sys_card, "Kernel", get_kernel(), false);
            card_info_row(sys_card, "Processor", get_cpu(), true);
            card_info_row(sys_card, "Memory", get_memory(), true);
            card_info_row(sys_card, "Graphics", get_gpu(), true);
            page.pack_start(sys_card, false, false, 0);
            
            scroll.add(page);
            return scroll;
        }
        
        private Gtk.Widget create_displays_page() {
            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            
            var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 16);
            page.margin = 32;
            page.margin_top = 24;
            page.valign = Gtk.Align.START;
            
            var title = new Gtk.Label("Displays");
            title.get_style_context().add_class("about-page-title");
            title.halign = Gtk.Align.START;
            page.pack_start(title, false, false, 0);
            
            var subtitle = new Gtk.Label("Connected monitors and their resolutions");
            subtitle.get_style_context().add_class("about-page-subtitle");
            subtitle.halign = Gtk.Align.START;
            subtitle.margin_bottom = 8;
            page.pack_start(subtitle, false, false, 0);
            
            var displays = get_displays();
            if (displays.length == 0) {
                var empty = new Gtk.Label("No display information available");
                empty.opacity = 0.5;
                empty.margin_top = 24;
                page.pack_start(empty, false, false, 0);
            } else {
                foreach (var display in displays) {
                    var card = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 16);
                    card.get_style_context().add_class("about-display-card");
                    
                    var icon = new Gtk.Image.from_icon_name("video-display-symbolic", Gtk.IconSize.DND);
                    icon.pixel_size = 48;
                    icon.opacity = 0.6;
                    icon.valign = Gtk.Align.CENTER;
                    card.pack_start(icon, false, false, 0);
                    
                    var info = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
                    info.valign = Gtk.Align.CENTER;
                    
                    var name_lbl = new Gtk.Label(display.name);
                    name_lbl.get_style_context().add_class("about-display-name");
                    name_lbl.halign = Gtk.Align.START;
                    info.pack_start(name_lbl, false, false, 0);
                    
                    var res_lbl = new Gtk.Label(display.resolution);
                    res_lbl.get_style_context().add_class("about-display-res");
                    res_lbl.halign = Gtk.Align.START;
                    info.pack_start(res_lbl, false, false, 0);
                    
                    card.pack_start(info, true, true, 0);
                    page.pack_start(card, false, false, 0);
                }
            }
            
            scroll.add(page);
            return scroll;
        }
        
        private Gtk.Widget create_storage_page() {
            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            
            var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 16);
            page.margin = 32;
            page.margin_top = 24;
            page.valign = Gtk.Align.START;
            
            var title = new Gtk.Label("Storage");
            title.get_style_context().add_class("about-page-title");
            title.halign = Gtk.Align.START;
            page.pack_start(title, false, false, 0);
            
            var subtitle = new Gtk.Label("Disk usage and available space");
            subtitle.get_style_context().add_class("about-page-subtitle");
            subtitle.halign = Gtk.Align.START;
            subtitle.margin_bottom = 8;
            page.pack_start(subtitle, false, false, 0);
            
            var disks = get_storage();
            if (disks.length == 0) {
                var empty = new Gtk.Label("No storage information available");
                empty.opacity = 0.5;
                empty.margin_top = 24;
                page.pack_start(empty, false, false, 0);
            } else {
                foreach (var disk in disks) {
                    var card = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
                    card.get_style_context().add_class("about-storage-card");
                    
                    // Header row
                    var hdr = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
                    
                    var icon = new Gtk.Image.from_icon_name("drive-harddisk-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                    icon.opacity = 0.6;
                    hdr.pack_start(icon, false, false, 0);
                    
                    var name_lbl = new Gtk.Label(disk.name);
                    name_lbl.get_style_context().add_class("about-storage-name");
                    name_lbl.halign = Gtk.Align.START;
                    hdr.pack_start(name_lbl, true, true, 0);
                    
                    var total_lbl = new Gtk.Label(disk.total);
                    total_lbl.get_style_context().add_class("about-storage-detail");
                    hdr.pack_end(total_lbl, false, false, 0);
                    
                    card.pack_start(hdr, false, false, 0);
                    
                    // Progress bar
                    var bar = new Gtk.ProgressBar();
                    bar.set_fraction(disk.used_fraction);
                    bar.get_style_context().add_class("about-storage-bar");
                    card.pack_start(bar, false, false, 0);
                    
                    // Usage detail
                    var detail = new Gtk.Label("%s available of %s".printf(disk.available, disk.total));
                    detail.get_style_context().add_class("about-storage-detail");
                    detail.halign = Gtk.Align.START;
                    card.pack_start(detail, false, false, 0);
                    
                    page.pack_start(card, false, false, 0);
                }
            }
            
            scroll.add(page);
            return scroll;
        }
        
        private string get_os_name() {
            try {
                string content;
                FileUtils.get_contents("/etc/os-release", out content);
                foreach (var line in content.split("\n")) {
                    if (line.has_prefix("PRETTY_NAME=")) {
                        return line.substring(13).replace("\"", "");
                    }
                }
            } catch (Error e) {}
            return "Linux";
        }
        
        private string get_os_version() {
            try {
                string content;
                FileUtils.get_contents("/etc/os-release", out content);
                foreach (var line in content.split("\n")) {
                    if (line.has_prefix("VERSION=")) {
                        return line.substring(8).replace("\"", "");
                    }
                }
            } catch (Error e) {}
            return "";
        }
        
        private string get_kernel() {
            try {
                string output;
                Process.spawn_command_line_sync("uname -r", out output, null, null);
                return output.strip();
            } catch (Error e) {}
            return "";
        }
        
        private string get_cpu() {
            try {
                string content;
                FileUtils.get_contents("/proc/cpuinfo", out content);
                foreach (var line in content.split("\n")) {
                    if (line.has_prefix("model name")) {
                        int idx = line.index_of(":");
                        if (idx > 0) return line.substring(idx + 2).strip();
                    }
                }
            } catch (Error e) {}
            return "";
        }
        
        private string get_memory() {
            try {
                string content;
                FileUtils.get_contents("/proc/meminfo", out content);
                foreach (var line in content.split("\n")) {
                    if (line.has_prefix("MemTotal:")) {
                        var parts = line.split_set(" \t");
                        foreach (var p in parts) {
                            if (p.length > 0 && p[0].isdigit()) {
                                int64 kb = int64.parse(p);
                                return "%.1f GB".printf(kb / 1048576.0);
                            }
                        }
                    }
                }
            } catch (Error e) {}
            return "";
        }
        
        private string get_gpu() {
            try {
                string output;
                Process.spawn_command_line_sync("lspci", out output, null, null);
                foreach (var line in output.split("\n")) {
                    if (line.contains("VGA") || line.contains("3D")) {
                        int idx = line.index_of(": ");
                        if (idx > 0) return line.substring(idx + 2);
                    }
                }
            } catch (Error e) {}
            return "";
        }
        
        private struct DisplayInfo { string name; string resolution; }
        
        private DisplayInfo[] get_displays() {
            DisplayInfo[] displays = {};
            try {
                string output;
                Process.spawn_command_line_sync("xrandr --query", out output, null, null);
                string? current_name = null;
                foreach (var line in output.split("\n")) {
                    if (line.contains(" connected")) {
                        var parts = line.split(" ");
                        current_name = parts[0];
                    } else if (current_name != null && line.contains("*")) {
                        var parts = line.strip().split(" ");
                        displays += DisplayInfo() { name = current_name, resolution = parts[0] };
                        current_name = null;
                    }
                }
            } catch (Error e) {}
            return displays;
        }
        
        private struct StorageInfo { string name; string total; string available; double used_fraction; }
        
        private StorageInfo[] get_storage() {
            StorageInfo[] disks = {};
            try {
                string output;
                Process.spawn_command_line_sync("df -h /", out output, null, null);
                var lines = output.split("\n");
                if (lines.length > 1) {
                    var parts = lines[1].split_set(" \t");
                    string[] vals = {};
                    foreach (var p in parts) {
                        if (p.length > 0) vals += p;
                    }
                    if (vals.length >= 4) {
                        string total = vals[1];
                        string used = vals[2];
                        string avail = vals[3];
                        double used_d = double.parse(used.substring(0, used.length - 1));
                        double total_d = double.parse(total.substring(0, total.length - 1));
                        disks += StorageInfo() {
                            name = vals[0],
                            total = total,
                            available = avail,
                            used_fraction = used_d / total_d
                        };
                    }
                }
            } catch (Error e) {}
            return disks;
        }
    }
}
