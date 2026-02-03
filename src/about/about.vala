/**
 * About This Computer - macOS-style system info window
 */

namespace About {

    public class AboutWindow : Gtk.Window {
        private Gtk.Stack stack;
        private Gtk.StackSwitcher switcher;
        
        public AboutWindow() {
            title = "About This Computer";
            set_default_size(540, 400);
            set_resizable(false);
            window_position = Gtk.WindowPosition.CENTER;
            
            var header = new Gtk.HeaderBar();
            header.show_close_button = true;
            header.title = "About This Computer";
            set_titlebar(header);
            
            var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            
            stack = new Gtk.Stack();
            stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
            
            switcher = new Gtk.StackSwitcher();
            switcher.stack = stack;
            switcher.halign = Gtk.Align.CENTER;
            switcher.margin = 12;
            
            stack.add_titled(create_overview_tab(), "overview", "Overview");
            stack.add_titled(create_displays_tab(), "displays", "Displays");
            stack.add_titled(create_storage_tab(), "storage", "Storage");
            
            main_box.pack_start(switcher, false, false, 0);
            main_box.pack_start(stack, true, true, 0);
            
            add(main_box);
        }
        
        private Gtk.Widget create_overview_tab() {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 16);
            box.margin = 24;
            box.valign = Gtk.Align.CENTER;
            
            // Distro logo
            var logo = new Gtk.Image.from_icon_name("distributor-logo", Gtk.IconSize.DIALOG);
            logo.pixel_size = 128;
            box.pack_start(logo, false, false, 0);
            
            // OS Name
            var os_name = new Gtk.Label(get_os_name());
            os_name.get_style_context().add_class("about-os-name");
            box.pack_start(os_name, false, false, 0);
            
            // Info grid
            var grid = new Gtk.Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 8;
            grid.halign = Gtk.Align.CENTER;
            
            int row = 0;
            add_info_row(grid, row++, "Version", get_os_version());
            add_info_row(grid, row++, "Kernel", get_kernel());
            add_info_row(grid, row++, "Processor", get_cpu());
            add_info_row(grid, row++, "Memory", get_memory());
            add_info_row(grid, row++, "Graphics", get_gpu());
            
            box.pack_start(grid, false, false, 0);
            
            return box;
        }
        
        private Gtk.Widget create_displays_tab() {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 16);
            box.margin = 24;
            
            var displays = get_displays();
            foreach (var display in displays) {
                var frame = new Gtk.Frame(null);
                frame.get_style_context().add_class("about-display-frame");
                
                var display_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 16);
                display_box.margin = 16;
                
                var icon = new Gtk.Image.from_icon_name("video-display-symbolic", Gtk.IconSize.DIALOG);
                icon.pixel_size = 64;
                display_box.pack_start(icon, false, false, 0);
                
                var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
                
                var name_label = new Gtk.Label(display.name);
                name_label.get_style_context().add_class("about-display-name");
                name_label.halign = Gtk.Align.START;
                info_box.pack_start(name_label, false, false, 0);
                
                var res_label = new Gtk.Label(display.resolution);
                res_label.get_style_context().add_class("dim-label");
                res_label.halign = Gtk.Align.START;
                info_box.pack_start(res_label, false, false, 0);
                
                display_box.pack_start(info_box, true, true, 0);
                frame.add(display_box);
                box.pack_start(frame, false, false, 0);
            }
            
            return box;
        }
        
        private Gtk.Widget create_storage_tab() {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 16);
            box.margin = 24;
            
            var disks = get_storage();
            foreach (var disk in disks) {
                var frame = new Gtk.Frame(null);
                
                var disk_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
                disk_box.margin = 16;
                
                var header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
                
                var icon = new Gtk.Image.from_icon_name("drive-harddisk-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                header_box.pack_start(icon, false, false, 0);
                
                var name_label = new Gtk.Label(disk.name);
                name_label.get_style_context().add_class("about-display-name");
                name_label.halign = Gtk.Align.START;
                header_box.pack_start(name_label, false, false, 0);
                
                var size_label = new Gtk.Label(disk.total);
                size_label.halign = Gtk.Align.END;
                size_label.hexpand = true;
                header_box.pack_end(size_label, false, false, 0);
                
                disk_box.pack_start(header_box, false, false, 0);
                
                var progress = new Gtk.ProgressBar();
                progress.set_fraction(disk.used_fraction);
                disk_box.pack_start(progress, false, false, 0);
                
                var usage_label = new Gtk.Label("%s available of %s".printf(disk.available, disk.total));
                usage_label.get_style_context().add_class("dim-label");
                usage_label.halign = Gtk.Align.START;
                disk_box.pack_start(usage_label, false, false, 0);
                
                frame.add(disk_box);
                box.pack_start(frame, false, false, 0);
            }
            
            return box;
        }
        
        private void add_info_row(Gtk.Grid grid, int row, string label, string value) {
            var lbl = new Gtk.Label(label);
            lbl.halign = Gtk.Align.END;
            lbl.get_style_context().add_class("dim-label");
            grid.attach(lbl, 0, row);
            
            var val = new Gtk.Label(value);
            val.halign = Gtk.Align.START;
            val.selectable = true;
            grid.attach(val, 1, row);
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
                            name = "Macintosh HD",
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
