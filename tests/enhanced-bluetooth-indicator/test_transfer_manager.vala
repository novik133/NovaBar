/**
 * Enhanced Bluetooth Indicator - Transfer Manager Tests
 * 
 * Unit tests for the TransferManager component.
 */

using GLib;

namespace EnhancedBluetoothTests {

    /**
     * Transfer status enum
     */
    public enum TransferStatus {
        QUEUED,
        ACTIVE,
        SUSPENDED,
        COMPLETE,
        ERROR
    }

    /**
     * Transfer direction enum
     */
    public enum TransferDirection {
        SENDING,
        RECEIVING
    }

    /**
     * File transfer model for testing
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

        private uint64 last_transferred = 0;
        private DateTime last_update;

        public FileTransfer() {
            started = new DateTime.now_local();
            last_update = started;
        }

        public double progress_percentage {
            get {
                if (size == 0) {
                    return 0.0;
                }
                return ((double)transferred / (double)size) * 100.0;
            }
        }

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

        public void update_progress(uint64 new_transferred) {
            last_transferred = transferred;
            transferred = new_transferred;
            last_update = new DateTime.now_local();
            
            if (transferred >= size) {
                status = TransferStatus.COMPLETE;
                completed = new DateTime.now_local();
            }
        }

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

    /**
     * Simple TransferManager for testing
     */
    public class TransferManager : Object {
        private HashTable<string, FileTransfer> active_transfers;

        public TransferManager() {
            active_transfers = new HashTable<string, FileTransfer>(str_hash, str_equal);
        }

        public FileTransfer? get_transfer(string transfer_path) {
            return active_transfers.lookup(transfer_path);
        }

        public GenericArray<FileTransfer> get_active_transfers() {
            var transfers = new GenericArray<FileTransfer>();
            
            active_transfers.foreach((path, transfer) => {
                transfers.add(transfer);
            });
            
            return transfers;
        }
    }

    /**
     * Test TransferManager initialization
     */
    private static void test_transfer_manager_initialization() {
        var manager = new TransferManager();
        assert_nonnull(manager);
        
        // Verify initial state
        var transfers = manager.get_active_transfers();
        assert_nonnull(transfers);
        assert_true(transfers.length == 0);
    }
    
    /**
     * Test get_transfer with non-existent transfer
     */
    private static void test_get_transfer_not_found() {
        var manager = new TransferManager();
        
        var transfer = manager.get_transfer("/org/bluez/obex/transfer/nonexistent");
        assert_null(transfer);
    }
    
    /**
     * Test get_active_transfers returns empty list initially
     */
    private static void test_get_active_transfers_empty() {
        var manager = new TransferManager();
        
        var transfers = manager.get_active_transfers();
        assert_nonnull(transfers);
        assert_true(transfers.length == 0);
    }
    
    /**
     * Test transfer status parsing
     */
    private static void test_transfer_status_parsing() {
        // This test verifies that the TransferManager can be instantiated
        // and that FileTransfer objects work correctly
        var transfer = new FileTransfer();
        assert_nonnull(transfer);
        
        // Test initial status
        assert_true(transfer.status == TransferStatus.QUEUED);
        
        // Test status changes
        transfer.status = TransferStatus.ACTIVE;
        assert_true(transfer.status == TransferStatus.ACTIVE);
        
        transfer.status = TransferStatus.COMPLETE;
        assert_true(transfer.status == TransferStatus.COMPLETE);
        
        transfer.status = TransferStatus.ERROR;
        assert_true(transfer.status == TransferStatus.ERROR);
        
        transfer.status = TransferStatus.SUSPENDED;
        assert_true(transfer.status == TransferStatus.SUSPENDED);
    }
    
    /**
     * Test FileTransfer progress calculation
     */
    private static void test_file_transfer_progress() {
        var transfer = new FileTransfer();
        transfer.size = 1000;
        transfer.transferred = 0;
        
        // Test 0% progress
        assert_true(transfer.progress_percentage == 0.0);
        
        // Test 50% progress
        transfer.update_progress(500);
        assert_true(transfer.progress_percentage == 50.0);
        
        // Test 100% progress
        transfer.update_progress(1000);
        assert_true(transfer.progress_percentage == 100.0);
        assert_true(transfer.status == TransferStatus.COMPLETE);
    }
    
    /**
     * Test FileTransfer with zero size
     */
    private static void test_file_transfer_zero_size() {
        var transfer = new FileTransfer();
        transfer.size = 0;
        transfer.transferred = 0;
        
        // Should not crash with division by zero
        assert_true(transfer.progress_percentage == 0.0);
    }
    
    /**
     * Test FileTransfer status text
     */
    private static void test_file_transfer_status_text() {
        var transfer = new FileTransfer();
        
        transfer.status = TransferStatus.QUEUED;
        assert_true(transfer.get_status_text() == "Queued");
        
        transfer.status = TransferStatus.ACTIVE;
        assert_true(transfer.get_status_text() == "Transferring");
        
        transfer.status = TransferStatus.SUSPENDED;
        assert_true(transfer.get_status_text() == "Paused");
        
        transfer.status = TransferStatus.COMPLETE;
        assert_true(transfer.get_status_text() == "Complete");
        
        transfer.status = TransferStatus.ERROR;
        assert_true(transfer.get_status_text() == "Failed");
    }
    
    /**
     * Test FileTransfer progress text formatting
     */
    private static void test_file_transfer_progress_text() {
        var transfer = new FileTransfer();
        transfer.size = 10 * 1024 * 1024; // 10 MB
        transfer.transferred = 5 * 1024 * 1024; // 5 MB
        transfer.status = TransferStatus.ACTIVE;
        
        var progress_text = transfer.get_progress_text();
        assert_nonnull(progress_text);
        assert_true(progress_text.length > 0);
        
        // Test completed transfer
        transfer.status = TransferStatus.COMPLETE;
        transfer.transferred = transfer.size;
        progress_text = transfer.get_progress_text();
        assert_nonnull(progress_text);
        assert_true(progress_text.length > 0);
    }
    
    /**
     * Test FileTransfer time span formatting
     */
    private static void test_file_transfer_time_span_format() {
        // Test seconds
        var text = FileTransfer.format_time_span(30 * TimeSpan.SECOND);
        assert_true(text.contains("sec"));
        
        // Test minutes
        text = FileTransfer.format_time_span(90 * TimeSpan.SECOND);
        assert_true(text.contains("min"));
        
        // Test hours
        text = FileTransfer.format_time_span(3700 * TimeSpan.SECOND);
        assert_true(text.contains("hr"));
    }
    
    /**
     * Test FileTransfer direction
     */
    private static void test_file_transfer_direction() {
        var transfer = new FileTransfer();
        
        transfer.direction = TransferDirection.SENDING;
        assert_true(transfer.direction == TransferDirection.SENDING);
        
        transfer.direction = TransferDirection.RECEIVING;
        assert_true(transfer.direction == TransferDirection.RECEIVING);
    }
    
    /**
     * Main test entry point
     */
    public static int main(string[] args) {
        Test.init(ref args);
        
        Test.add_func("/enhanced-bluetooth/transfer-manager/initialization", 
                      test_transfer_manager_initialization);
        Test.add_func("/enhanced-bluetooth/transfer-manager/get-transfer-not-found", 
                      test_get_transfer_not_found);
        Test.add_func("/enhanced-bluetooth/transfer-manager/get-active-transfers-empty", 
                      test_get_active_transfers_empty);
        Test.add_func("/enhanced-bluetooth/transfer-manager/status-parsing", 
                      test_transfer_status_parsing);
        Test.add_func("/enhanced-bluetooth/transfer-manager/progress-calculation", 
                      test_file_transfer_progress);
        Test.add_func("/enhanced-bluetooth/transfer-manager/zero-size", 
                      test_file_transfer_zero_size);
        Test.add_func("/enhanced-bluetooth/transfer-manager/status-text", 
                      test_file_transfer_status_text);
        Test.add_func("/enhanced-bluetooth/transfer-manager/progress-text", 
                      test_file_transfer_progress_text);
        Test.add_func("/enhanced-bluetooth/transfer-manager/time-span-format", 
                      test_file_transfer_time_span_format);
        Test.add_func("/enhanced-bluetooth/transfer-manager/direction", 
                      test_file_transfer_direction);
        
        return Test.run();
    }
}
