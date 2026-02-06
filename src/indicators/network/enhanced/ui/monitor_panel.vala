/**
 * Enhanced Network Indicator - Monitor Panel
 * 
 * This file implements the MonitorPanel component that provides comprehensive
 * network performance monitoring including bandwidth monitoring display with
 * real-time graphs, speed test interface, and connection quality metrics.
 */

using GLib;
using Gtk;

namespace EnhancedNetwork {

    /**
     * Bandwidth graph widget for real-time display
     */
    private class BandwidthGraph : Gtk.DrawingArea {
        private GenericArray<BandwidthData> history_data;
        private const uint MAX_HISTORY_POINTS = 60; // 2 minutes at 2-second intervals
        private const uint GRAPH_HEIGHT = 120;
        private const uint GRAPH_MARGIN = 10;
        
        public BandwidthGraph() {
            history_data = new GenericArray<BandwidthData>();
            set_size_request(300, (int)GRAPH_HEIGHT);
            
            draw.connect(on_draw);
        }
        
        public void add_data_point(BandwidthData data) {
            history_data.add(data);
            
            // Keep only recent data points
            while (history_data.length > MAX_HISTORY_POINTS) {
                history_data.remove_index(0);
            }
            
            queue_draw();
        }
        
        public void clear_data() {
            history_data.remove_range(0, history_data.length);
            queue_draw();
        }
        
        private bool on_draw(Cairo.Context cr) {
            Gtk.Allocation allocation;
            get_allocation(out allocation);
            var width = allocation.width;
            var height = allocation.height;
            
            // Clear background
            cr.set_source_rgb(0.95, 0.95, 0.95);
            cr.rectangle(0, 0, width, height);
            cr.fill();
            
            if (history_data.length < 2) {
                // Draw placeholder text
                cr.set_source_rgb(0.5, 0.5, 0.5);
                cr.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
                cr.set_font_size(12);
                
                var text = "Collecting data...";
                Cairo.TextExtents extents;
                cr.text_extents(text, out extents);
                
                cr.move_to((width - extents.width) / 2, (height + extents.height) / 2);
                cr.show_text(text);
                return true;
            }
            
            // Find max speed for scaling
            uint64 max_speed = 1024; // Minimum 1 KB/s scale
            for (uint i = 0; i < history_data.length; i++) {
                var data = history_data[i];
                var total_speed = data.get_total_speed();
                if (total_speed > max_speed) {
                    max_speed = total_speed;
                }
            }
            
            // Draw grid lines
            cr.set_source_rgb(0.8, 0.8, 0.8);
            cr.set_line_width(1);
            
            // Horizontal grid lines
            for (int i = 1; i < 4; i++) {
                var y = GRAPH_MARGIN + (height - 2 * GRAPH_MARGIN) * i / 4;
                cr.move_to(GRAPH_MARGIN, y);
                cr.line_to(width - GRAPH_MARGIN, y);
                cr.stroke();
            }
            
            // Vertical grid lines
            for (int i = 1; i < 6; i++) {
                var x = GRAPH_MARGIN + (width - 2 * GRAPH_MARGIN) * i / 6;
                cr.move_to(x, GRAPH_MARGIN);
                cr.line_to(x, height - GRAPH_MARGIN);
                cr.stroke();
            }
            
            // Draw download speed line (blue)
            cr.set_source_rgb(0.2, 0.6, 1.0);
            cr.set_line_width(2);
            
            var graph_width = width - 2 * GRAPH_MARGIN;
            var graph_height = height - 2 * GRAPH_MARGIN;
            
            for (uint i = 0; i < history_data.length; i++) {
                var data = history_data[i];
                var x = GRAPH_MARGIN + graph_width * i / (MAX_HISTORY_POINTS - 1);
                var y = height - GRAPH_MARGIN - (graph_height * data.download_speed / max_speed);
                
                if (i == 0) {
                    cr.move_to(x, y);
                } else {
                    cr.line_to(x, y);
                }
            }
            cr.stroke();
            
            // Draw upload speed line (red)
            cr.set_source_rgb(1.0, 0.4, 0.2);
            cr.set_line_width(2);
            
            for (uint i = 0; i < history_data.length; i++) {
                var data = history_data[i];
                var x = GRAPH_MARGIN + graph_width * i / (MAX_HISTORY_POINTS - 1);
                var y = height - GRAPH_MARGIN - (graph_height * data.upload_speed / max_speed);
                
                if (i == 0) {
                    cr.move_to(x, y);
                } else {
                    cr.line_to(x, y);
                }
            }
            cr.stroke();
            
            // Draw legend
            cr.set_source_rgb(0.2, 0.2, 0.2);
            cr.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(10);
            
            // Download legend
            cr.set_source_rgb(0.2, 0.6, 1.0);
            cr.rectangle(10, 10, 15, 3);
            cr.fill();
            cr.set_source_rgb(0.2, 0.2, 0.2);
            cr.move_to(30, 18);
            cr.show_text("Download");
            
            // Upload legend
            cr.set_source_rgb(1.0, 0.4, 0.2);
            cr.rectangle(10, 20, 15, 3);
            cr.fill();
            cr.set_source_rgb(0.2, 0.2, 0.2);
            cr.move_to(30, 28);
            cr.show_text("Upload");
            
            // Max speed label
            var max_speed_text = format_speed(max_speed);
            cr.move_to(width - 80, 18);
            cr.show_text("Max: " + max_speed_text);
            
            return true;
        }
        
        private string format_speed(uint64 speed) {
            if (speed >= 1000000000) { // >= 1 GB/s
                return "%.1f GB/s".printf(speed / 1000000000.0);
            } else if (speed >= 1000000) { // >= 1 MB/s
                return "%.1f MB/s".printf(speed / 1000000.0);
            } else if (speed >= 1000) { // >= 1 KB/s
                return "%.1f KB/s".printf(speed / 1000.0);
            } else {
                return "%llu B/s".printf(speed);
            }
        }
    }

    /**
     * Speed test result display widget
     */
    private class SpeedTestResultWidget : Gtk.Box {
        private Gtk.Label download_label;
        private Gtk.Label upload_label;
        private Gtk.Label ping_label;
        private Gtk.Label grade_label;
        private Gtk.Label server_label;
        private Gtk.Label timestamp_label;
        
        public SpeedTestResultWidget() {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            
            setup_ui();
        }
        
        private void setup_ui() {
            get_style_context().add_class("speed-test-result");
            margin = 12;
            
            // Title
            var title_label = new Gtk.Label("Speed Test Results");
            title_label.get_style_context().add_class("heading");
            title_label.halign = Gtk.Align.START;
            pack_start(title_label, false, false, 0);
            
            // Results grid
            var grid = new Gtk.Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 6;
            pack_start(grid, false, false, 0);
            
            int row = 0;
            
            // Download speed
            grid.attach(new Gtk.Label("Download:"), 0, row, 1, 1);
            download_label = new Gtk.Label("--");
            download_label.halign = Gtk.Align.START;
            download_label.get_style_context().add_class("monospace");
            grid.attach(download_label, 1, row++, 1, 1);
            
            // Upload speed
            grid.attach(new Gtk.Label("Upload:"), 0, row, 1, 1);
            upload_label = new Gtk.Label("--");
            upload_label.halign = Gtk.Align.START;
            upload_label.get_style_context().add_class("monospace");
            grid.attach(upload_label, 1, row++, 1, 1);
            
            // Ping
            grid.attach(new Gtk.Label("Ping:"), 0, row, 1, 1);
            ping_label = new Gtk.Label("--");
            ping_label.halign = Gtk.Align.START;
            ping_label.get_style_context().add_class("monospace");
            grid.attach(ping_label, 1, row++, 1, 1);
            
            // Grade
            grid.attach(new Gtk.Label("Grade:"), 0, row, 1, 1);
            grade_label = new Gtk.Label("--");
            grade_label.halign = Gtk.Align.START;
            grade_label.get_style_context().add_class("grade-label");
            grid.attach(grade_label, 1, row++, 1, 1);
            
            // Server
            grid.attach(new Gtk.Label("Server:"), 0, row, 1, 1);
            server_label = new Gtk.Label("--");
            server_label.halign = Gtk.Align.START;
            server_label.get_style_context().add_class("dim-label");
            grid.attach(server_label, 1, row++, 1, 1);
            
            // Timestamp
            grid.attach(new Gtk.Label("Tested:"), 0, row, 1, 1);
            timestamp_label = new Gtk.Label("--");
            timestamp_label.halign = Gtk.Align.START;
            timestamp_label.get_style_context().add_class("dim-label");
            grid.attach(timestamp_label, 1, row++, 1, 1);
            
            show_all();
        }
        
        public void update_result(SpeedTestResult result) {
            if (result.test_successful) {
                download_label.set_text("%.1f Mbps".printf(result.get_download_mbps()));
                upload_label.set_text("%.1f Mbps".printf(result.get_upload_mbps()));
                ping_label.set_text("%u ms".printf(result.ping_ms));
                grade_label.set_text(result.get_speed_grade());
                server_label.set_text(result.server_location ?? "Unknown");
                
                var time_format = result.test_time.format("%H:%M:%S");
                timestamp_label.set_text(time_format ?? "");
                
                // Update grade label style
                grade_label.get_style_context().remove_class("grade-excellent");
                grade_label.get_style_context().remove_class("grade-good");
                grade_label.get_style_context().remove_class("grade-fair");
                grade_label.get_style_context().remove_class("grade-poor");
                
                var grade = result.get_speed_grade().down();
                if (grade.contains("excellent")) {
                    grade_label.get_style_context().add_class("grade-excellent");
                } else if (grade.contains("good")) {
                    grade_label.get_style_context().add_class("grade-good");
                } else if (grade.contains("fair")) {
                    grade_label.get_style_context().add_class("grade-fair");
                } else {
                    grade_label.get_style_context().add_class("grade-poor");
                }
            } else {
                download_label.set_text("Failed");
                upload_label.set_text("Failed");
                ping_label.set_text("Failed");
                grade_label.set_text("Test Failed");
                server_label.set_text("--");
                timestamp_label.set_text("--");
                
                if (result.error_message != null) {
                    server_label.set_text("Error: " + result.error_message);
                }
            }
        }
        
        public void clear_result() {
            download_label.set_text("--");
            upload_label.set_text("--");
            ping_label.set_text("--");
            grade_label.set_text("--");
            server_label.set_text("--");
            timestamp_label.set_text("--");
        }
    }

    /**
     * Connection quality metrics widget
     */
    private class ConnectionQualityWidget : Gtk.Box {
        private Gtk.Label current_speed_label;
        private Gtk.Label total_usage_label;
        private Gtk.Label latency_label;
        private Gtk.Label packet_loss_label;
        private Gtk.ProgressBar quality_bar;
        private Gtk.Label quality_label;
        
        public ConnectionQualityWidget() {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            
            setup_ui();
        }
        
        private void setup_ui() {
            get_style_context().add_class("connection-quality");
            margin = 12;
            
            // Title
            var title_label = new Gtk.Label("Connection Quality");
            title_label.get_style_context().add_class("heading");
            title_label.halign = Gtk.Align.START;
            pack_start(title_label, false, false, 0);
            
            // Quality bar
            quality_bar = new Gtk.ProgressBar();
            quality_bar.show_text = false;
            quality_bar.margin_bottom = 4;
            pack_start(quality_bar, false, false, 0);
            
            quality_label = new Gtk.Label("Excellent");
            quality_label.halign = Gtk.Align.CENTER;
            quality_label.get_style_context().add_class("quality-label");
            pack_start(quality_label, false, false, 0);
            
            // Metrics grid
            var grid = new Gtk.Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 6;
            grid.margin_top = 8;
            pack_start(grid, false, false, 0);
            
            int row = 0;
            
            // Current speed
            grid.attach(new Gtk.Label("Current Speed:"), 0, row, 1, 1);
            current_speed_label = new Gtk.Label("--");
            current_speed_label.halign = Gtk.Align.START;
            current_speed_label.get_style_context().add_class("monospace");
            grid.attach(current_speed_label, 1, row++, 1, 1);
            
            // Total usage
            grid.attach(new Gtk.Label("Session Usage:"), 0, row, 1, 1);
            total_usage_label = new Gtk.Label("--");
            total_usage_label.halign = Gtk.Align.START;
            total_usage_label.get_style_context().add_class("monospace");
            grid.attach(total_usage_label, 1, row++, 1, 1);
            
            // Latency
            grid.attach(new Gtk.Label("Latency:"), 0, row, 1, 1);
            latency_label = new Gtk.Label("--");
            latency_label.halign = Gtk.Align.START;
            latency_label.get_style_context().add_class("monospace");
            grid.attach(latency_label, 1, row++, 1, 1);
            
            // Packet loss
            grid.attach(new Gtk.Label("Packet Loss:"), 0, row, 1, 1);
            packet_loss_label = new Gtk.Label("--");
            packet_loss_label.halign = Gtk.Align.START;
            packet_loss_label.get_style_context().add_class("monospace");
            grid.attach(packet_loss_label, 1, row++, 1, 1);
            
            show_all();
        }
        
        public void update_quality(BandwidthData data) {
            // Update current speed
            current_speed_label.set_text(data.get_speed_description());
            
            // Update total usage
            total_usage_label.set_text(data.get_usage_description());
            
            // Update latency
            if (data.latency_ms > 0) {
                latency_label.set_text("%u ms".printf(data.latency_ms));
            } else {
                latency_label.set_text("--");
            }
            
            // Update packet loss
            if (data.packet_loss_percent >= 0) {
                packet_loss_label.set_text("%.1f%%".printf(data.packet_loss_percent));
            } else {
                packet_loss_label.set_text("--");
            }
            
            // Calculate and update quality score
            update_quality_score(data);
        }
        
        private void update_quality_score(BandwidthData data) {
            double quality_score = 1.0; // Start with perfect score
            
            // Reduce score based on latency
            if (data.latency_ms > 100) {
                quality_score -= 0.3;
            } else if (data.latency_ms > 50) {
                quality_score -= 0.1;
            }
            
            // Reduce score based on packet loss
            if (data.packet_loss_percent > 5.0) {
                quality_score -= 0.4;
            } else if (data.packet_loss_percent > 1.0) {
                quality_score -= 0.2;
            }
            
            // Reduce score based on speed (if very low)
            var total_speed = data.get_total_speed();
            if (total_speed < 1000) { // Less than 1 KB/s
                quality_score -= 0.5;
            } else if (total_speed < 10000) { // Less than 10 KB/s
                quality_score -= 0.2;
            }
            
            // Ensure score is between 0 and 1
            quality_score = double.max(0.0, double.min(1.0, quality_score));
            
            // Update progress bar
            quality_bar.set_fraction(quality_score);
            
            // Update quality label and style
            string quality_text;
            string quality_class;
            
            if (quality_score >= 0.8) {
                quality_text = "Excellent";
                quality_class = "quality-excellent";
            } else if (quality_score >= 0.6) {
                quality_text = "Good";
                quality_class = "quality-good";
            } else if (quality_score >= 0.4) {
                quality_text = "Fair";
                quality_class = "quality-fair";
            } else {
                quality_text = "Poor";
                quality_class = "quality-poor";
            }
            
            quality_label.set_text(quality_text);
            
            // Update style classes
            quality_label.get_style_context().remove_class("quality-excellent");
            quality_label.get_style_context().remove_class("quality-good");
            quality_label.get_style_context().remove_class("quality-fair");
            quality_label.get_style_context().remove_class("quality-poor");
            quality_label.get_style_context().add_class(quality_class);
        }
    }

    /**
     * Network performance monitoring panel
     */
    public class MonitorPanel : NetworkPanel {
        private BandwidthGraph bandwidth_graph;
        private SpeedTestResultWidget speed_test_widget;
        private ConnectionQualityWidget quality_widget;
        private Gtk.Button speed_test_button;
        private Gtk.Button clear_data_button;
        private Gtk.Spinner speed_test_spinner;
        private Gtk.Label status_label;
        private Gtk.ScrolledWindow scrolled_window;
        
        private bool speed_test_running;
        
        /**
         * Signal emitted when speed test is requested
         */
        public signal void speed_test_requested();
        
        public MonitorPanel(NetworkController controller) {
            base(controller, "monitor");
            
            setup_ui();
            setup_controller_signals();
            
            // Start monitoring
            refresh();
        }
        
        private void setup_ui() {
            // Header with controls
            var header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            header_box.margin_bottom = 8;
            pack_start(header_box, false, false, 0);
            
            // Speed test button
            speed_test_button = new Gtk.Button.with_label("Run Speed Test");
            speed_test_button.get_style_context().add_class("suggested-action");
            speed_test_button.clicked.connect(on_speed_test_clicked);
            header_box.pack_start(speed_test_button, false, false, 0);
            
            // Speed test spinner
            speed_test_spinner = new Gtk.Spinner();
            speed_test_spinner.no_show_all = true;
            header_box.pack_start(speed_test_spinner, false, false, 0);
            
            // Clear data button
            clear_data_button = new Gtk.Button.with_label("Clear Data");
            clear_data_button.clicked.connect(on_clear_data_clicked);
            header_box.pack_start(clear_data_button, false, false, 0);
            
            // Status label
            status_label = new Gtk.Label("Monitoring network performance...");
            status_label.get_style_context().add_class("dim-label");
            status_label.halign = Gtk.Align.START;
            pack_start(status_label, false, false, 0);
            
            // Scrolled window for content
            scrolled_window = new Gtk.ScrolledWindow(null, null);
            scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_min_content_height(400);
            pack_start(scrolled_window, true, true, 0);
            
            // Main content box
            var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            content_box.margin = 8;
            scrolled_window.add(content_box);
            
            // Bandwidth graph section
            var graph_frame = new Gtk.Frame("Real-time Bandwidth");
            graph_frame.get_style_context().add_class("monitor-section");
            content_box.pack_start(graph_frame, false, false, 0);
            
            bandwidth_graph = new BandwidthGraph();
            graph_frame.add(bandwidth_graph);
            
            // Connection quality section
            var quality_frame = new Gtk.Frame("Connection Quality");
            quality_frame.get_style_context().add_class("monitor-section");
            content_box.pack_start(quality_frame, false, false, 0);
            
            quality_widget = new ConnectionQualityWidget();
            quality_frame.add(quality_widget);
            
            // Speed test results section
            var speed_test_frame = new Gtk.Frame("Speed Test");
            speed_test_frame.get_style_context().add_class("monitor-section");
            content_box.pack_start(speed_test_frame, false, false, 0);
            
            speed_test_widget = new SpeedTestResultWidget();
            speed_test_frame.add(speed_test_widget);
            
            show_all();
        }
        
        private void setup_controller_signals() {
            // Connect to bandwidth monitor signals
            controller.bandwidth_monitor.bandwidth_updated.connect(on_bandwidth_updated);
            controller.bandwidth_monitor.speed_test_started.connect(on_speed_test_started);
            controller.bandwidth_monitor.speed_test_completed.connect(on_speed_test_completed);
            controller.bandwidth_monitor.performance_degraded.connect(on_performance_degraded);
        }
        
        public override void refresh() {
            set_refreshing(true);
            status_label.set_text("Starting network monitoring...");
            
            // The bandwidth monitor should already be running
            // Just update the status
            Timeout.add(1000, () => {
                set_refreshing(false);
                status_label.set_text("Monitoring active connections...");
                return false;
            });
        }
        
        public override void apply_search_filter(string search_term) {
            // Monitor panel doesn't have searchable content
            // This method is required by the base class but not used
        }
        
        public override void focus_first_result() {
            // Focus the speed test button as the primary action
            speed_test_button.grab_focus();
        }
        
        private void on_speed_test_clicked() {
            if (speed_test_running) {
                return;
            }
            
            speed_test_running = true;
            speed_test_button.sensitive = false;
            speed_test_spinner.show();
            speed_test_spinner.start();
            
            status_label.set_text("Running speed test...");
            
            // Clear previous results
            speed_test_widget.clear_result();
            
            // Request speed test from controller
            controller.bandwidth_monitor.perform_speed_test.begin((obj, res) => {
                try {
                    var result = controller.bandwidth_monitor.perform_speed_test.end(res);
                    // Result will be handled by the speed_test_completed signal
                } catch (Error e) {
                    warning("MonitorPanel: Speed test error: %s", e.message);
                    status_label.set_text("Speed test failed: " + e.message);
                    
                    speed_test_running = false;
                    speed_test_button.sensitive = true;
                    speed_test_spinner.stop();
                    speed_test_spinner.hide();
                }
            });
        }
        
        private void on_clear_data_clicked() {
            bandwidth_graph.clear_data();
            speed_test_widget.clear_result();
            status_label.set_text("Data cleared. Monitoring continues...");
        }
        
        private void on_bandwidth_updated(BandwidthData data) {
            // Update bandwidth graph
            bandwidth_graph.add_data_point(data);
            
            // Update connection quality
            quality_widget.update_quality(data);
            
            // Update status
            var speed_text = data.get_speed_description();
            status_label.set_text(@"Current speed: $(speed_text)");
        }
        
        private void on_speed_test_started() {
            speed_test_running = true;
            speed_test_button.sensitive = false;
            speed_test_spinner.show();
            speed_test_spinner.start();
            status_label.set_text("Speed test in progress...");
        }
        
        private void on_speed_test_completed(SpeedTestResult result) {
            speed_test_running = false;
            speed_test_button.sensitive = true;
            speed_test_spinner.stop();
            speed_test_spinner.hide();
            
            // Update speed test widget
            speed_test_widget.update_result(result);
            
            if (result.test_successful) {
                double down_mbps = result.get_download_mbps();
                double up_mbps = result.get_upload_mbps();
                status_label.set_text(@"Speed test completed: $(down_mbps) Mbps down, $(up_mbps) Mbps up");
            } else {
                status_label.set_text("Speed test failed: " + (result.error_message ?? "Unknown error"));
            }
        }
        
        private void on_performance_degraded(PerformanceAlert alert) {
            // Show performance alert in status
            status_label.set_text(@"Performance alert: $(alert.title)");
            
            // Could also show a notification or highlight the quality widget
            quality_widget.get_style_context().add_class("performance-warning");
            
            // Remove warning style after a few seconds
            Timeout.add_seconds(5, () => {
                quality_widget.get_style_context().remove_class("performance-warning");
                return false;
            });
        }
    }
}