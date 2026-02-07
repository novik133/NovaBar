/**
 * Enhanced Bluetooth Indicator - File Transfer Model
 * 
 * Represents an ongoing file transfer operation.
 */

namespace EnhancedBluetooth {

    /**
     * Represents an ongoing file transfer
     */
    public class FileTransfer : Object {
        public string object_path { get; set; }
        public string session_path { get; set; }
        public string device_path { get; set; }
        public string filename { get; set; }
        public string local_path { get; set; }
        public uint64 size { get; set; }
        public uint64 transferred { get; set; }
        public TransferStatus status { get; set; default = TransferStatus.QUEUED; }
        public TransferDirection direction { get; set; }
        public DateTime started { get; set; }
        public DateTime? completed { get; set; }

        // For calculating transfer speed
        private uint64 last_transferred = 0;
        private DateTime last_update;

        /**
         * Constructor
         */
        public FileTransfer() {
            started = new DateTime.now_local();
            last_update = started;
        }

        /**
         * Get progress percentage (0-100)
         */
        public double progress_percentage {
            get {
                if (size == 0) {
                    return 0.0;
                }
                return ((double)transferred / (double)size) * 100.0;
            }
        }

        /**
         * Get transfer speed in bytes per second
         */
        public uint64 bytes_per_second {
            get {
                var now = new DateTime.now_local();
                var elapsed = now.difference(last_update);
                
                if (elapsed == 0) {
                    return 0;
                }
                
                var bytes_diff = transferred - last_transferred;
                var seconds = (double)elapsed / TimeSpan.SECOND;
                
                if (seconds == 0) {
                    return 0;
                }
                
                return (uint64)(bytes_diff / seconds);
            }
        }

        /**
         * Get estimated time remaining
         */
        public TimeSpan estimated_time_remaining {
            get {
                var speed = bytes_per_second;
                if (speed == 0 || transferred >= size) {
                    return 0;
                }
                
                var remaining_bytes = size - transferred;
                var seconds = remaining_bytes / speed;
                
                return (int64)seconds * TimeSpan.SECOND;
            }
        }

        /**
         * Update transfer progress
         */
        public void update_progress(uint64 new_transferred) {
            last_transferred = transferred;
            transferred = new_transferred;
            last_update = new DateTime.now_local();
            
            if (transferred >= size) {
                status = TransferStatus.COMPLETE;
                completed = new DateTime.now_local();
            }
        }

        /**
         * Get status text
         */
        public string get_status_text() {
            switch (status) {
                case TransferStatus.QUEUED:
                    return "Queued";
                case TransferStatus.ACTIVE:
                    return "Transferring";
                case TransferStatus.SUSPENDED:
                    return "Paused";
                case TransferStatus.COMPLETE:
                    return "Complete";
                case TransferStatus.ERROR:
                    return "Failed";
                default:
                    return "Unknown";
            }
        }

        /**
         * Get progress text with size information
         */
        public string get_progress_text() {
            var transferred_mb = (double)transferred / (1024.0 * 1024.0);
            var size_mb = (double)size / (1024.0 * 1024.0);
            
            if (status == TransferStatus.COMPLETE) {
                return "%.1f MB".printf(size_mb);
            }
            
            var speed = bytes_per_second;
            var speed_kb = (double)speed / 1024.0;
            
            if (speed > 0) {
                return "%.1f / %.1f MB (%.0f KB/s)".printf(
                    transferred_mb,
                    size_mb,
                    speed_kb
                );
            }
            
            return "%.1f / %.1f MB".printf(transferred_mb, size_mb);
        }

        /**
         * Format time span as human-readable string
         */
        public static string format_time_span(TimeSpan span) {
            var seconds = span / TimeSpan.SECOND;
            
            if (seconds < 60) {
                return "%lld sec".printf(seconds);
            }
            
            var minutes = seconds / 60;
            if (minutes < 60) {
                return "%lld min".printf(minutes);
            }
            
            var hours = minutes / 60;
            minutes = minutes % 60;
            return "%lld:%02lld hr".printf(hours, minutes);
        }
    }
}
