/**
 * Enhanced Bluetooth Indicator - Adapter Manager Tests
 * 
 * Tests for adapter management functionality including:
 * - Adapter discovery
 * - Power control
 * - Discovery control
 * - Property monitoring
 * - Multi-adapter support
 */

using GLib;

namespace EnhancedBluetooth.Tests {

    /**
     * Test suite for AdapterManager
     */
    public class AdapterManagerTest : Object {
        
        public static int tests_run = 0;
        public static int tests_passed = 0;
        public static int tests_failed = 0;
    
    /**
     * Test adapter model completeness
     * Validates: Requirements 1.3
     */
    public static void test_adapter_model_completeness() {
            print("TEST: Adapter Model Completeness\n");
            tests_run++;
            
            try {
                // Create adapter model
                var adapter = new BluetoothAdapter();
                
                // Set all required properties
                adapter.object_path = "/org/bluez/hci0";
                adapter.address = "00:11:22:33:44:55";
                adapter.alias = "Test Adapter";
                adapter.name = "hci0";
                adapter.powered = true;
                adapter.discoverable = false;
                adapter.pairable = true;
                adapter.discoverable_timeout = 180;
                adapter.pairable_timeout = 0;
                adapter.discovering = false;
                adapter.uuids = new string[] {
                    "00001801-0000-1000-8000-00805f9b34fb",
                    "0000110e-0000-1000-8000-00805f9b34fb"
                };
                adapter.modalias = "usb:v1D6Bp0246d0540";
                
                // Verify all properties are accessible
                assert(adapter.object_path == "/org/bluez/hci0");
                assert(adapter.address == "00:11:22:33:44:55");
                assert(adapter.alias == "Test Adapter");
                assert(adapter.name == "hci0");
                assert(adapter.powered == true);
                assert(adapter.discoverable == false);
                assert(adapter.pairable == true);
                assert(adapter.discoverable_timeout == 180);
                assert(adapter.pairable_timeout == 0);
                assert(adapter.discovering == false);
                assert(adapter.uuids.length == 2);
                assert(adapter.modalias == "usb:v1D6Bp0246d0540");
                
                // Test computed properties
                adapter.is_default = true;
                adapter.device_count = 5;
                adapter.connected_device_count = 2;
                
                assert(adapter.is_default == true);
                assert(adapter.device_count == 5);
                assert(adapter.connected_device_count == 2);
                
                // Test display name
                string display_name = adapter.get_display_name();
                assert(display_name != null);
                assert(display_name.length > 0);
                
                // Test status text
                string status = adapter.get_status_text();
                assert(status != null);
                assert(status.length > 0);
                
                print("  ✓ Adapter model exposes all required properties\n");
                print("  ✓ Computed properties work correctly\n");
                print("  ✓ Display methods return valid strings\n");
                tests_passed++;
                
            } catch (Error e) {
                print("  ✗ FAILED: %s\n", e.message);
                tests_failed++;
            }
        }
        
    /**
     * Test adapter configuration validation
     * Validates: Requirements 9.7
     */
    public static void test_adapter_validation() {
            print("\nTEST: Adapter Configuration Validation\n");
            tests_run++;
            
            try {
                var manager = new AdapterManager();
                
                // Test alias validation
                bool valid_alias = manager.validate_configuration(
                    "/org/bluez/hci0",
                    "Alias",
                    new Variant.string("My Bluetooth Adapter")
                );
                assert(valid_alias == true);
                print("  ✓ Valid alias accepted\n");
                
                // Test empty alias (invalid)
                bool empty_alias = manager.validate_configuration(
                    "/org/bluez/hci0",
                    "Alias",
                    new Variant.string("")
                );
                assert(empty_alias == false);
                print("  ✓ Empty alias rejected\n");
                
                // Test too long alias (invalid - BlueZ limit is 248 chars)
                string long_alias = string.nfill(249, 'a');
                bool long_alias_valid = manager.validate_configuration(
                    "/org/bluez/hci0",
                    "Alias",
                    new Variant.string(long_alias)
                );
                assert(long_alias_valid == false);
                print("  ✓ Too long alias rejected\n");
                
                // Test timeout validation
                bool valid_timeout = manager.validate_configuration(
                    "/org/bluez/hci0",
                    "DiscoverableTimeout",
                    new Variant.uint32(180)
                );
                assert(valid_timeout == true);
                print("  ✓ Valid timeout accepted\n");
                
                // Test unlimited timeout (0)
                bool unlimited_timeout = manager.validate_configuration(
                    "/org/bluez/hci0",
                    "DiscoverableTimeout",
                    new Variant.uint32(0)
                );
                assert(unlimited_timeout == true);
                print("  ✓ Unlimited timeout (0) accepted\n");
                
                // Test boolean properties (always valid)
                bool valid_powered = manager.validate_configuration(
                    "/org/bluez/hci0",
                    "Powered",
                    new Variant.boolean(true)
                );
                assert(valid_powered == true);
                print("  ✓ Boolean properties validated\n");
                
                tests_passed++;
                
            } catch (Error e) {
                print("  ✗ FAILED: %s\n", e.message);
                tests_failed++;
            }
        }
        
    /**
     * Test multi-adapter independence
     * Validates: Requirements 1.6, 10.4
     */
    public static void test_multi_adapter_independence() {
            print("\nTEST: Multi-Adapter Independence\n");
            tests_run++;
            
            try {
                // Create multiple adapter models
                var adapter1 = new BluetoothAdapter();
                adapter1.object_path = "/org/bluez/hci0";
                adapter1.address = "00:11:22:33:44:55";
                adapter1.alias = "Adapter 1";
                adapter1.powered = true;
                adapter1.discovering = false;
                
                var adapter2 = new BluetoothAdapter();
                adapter2.object_path = "/org/bluez/hci1";
                adapter2.address = "AA:BB:CC:DD:EE:FF";
                adapter2.alias = "Adapter 2";
                adapter2.powered = false;
                adapter2.discovering = false;
                
                // Verify adapters are independent
                assert(adapter1.object_path != adapter2.object_path);
                assert(adapter1.address != adapter2.address);
                assert(adapter1.powered != adapter2.powered);
                
                // Modify adapter1 state
                adapter1.powered = false;
                adapter1.discovering = true;
                
                // Verify adapter2 is unaffected
                assert(adapter2.powered == false);
                assert(adapter2.discovering == false);
                
                print("  ✓ Adapter models are independent\n");
                print("  ✓ State changes don't affect other adapters\n");
                
                // Test default adapter selection
                adapter1.is_default = true;
                adapter2.is_default = false;
                
                assert(adapter1.is_default == true);
                assert(adapter2.is_default == false);
                
                // Switch default
                adapter1.is_default = false;
                adapter2.is_default = true;
                
                assert(adapter1.is_default == false);
                assert(adapter2.is_default == true);
                
                print("  ✓ Default adapter selection works correctly\n");
                
                tests_passed++;
                
            } catch (Error e) {
                print("  ✗ FAILED: %s\n", e.message);
                tests_failed++;
            }
        }
    }
}

int main(string[] args) {
    print("\n=== Enhanced Bluetooth Indicator - Adapter Manager Tests ===\n\n");
    
    // Run tests
    EnhancedBluetooth.Tests.AdapterManagerTest.test_adapter_model_completeness();
    EnhancedBluetooth.Tests.AdapterManagerTest.test_adapter_validation();
    EnhancedBluetooth.Tests.AdapterManagerTest.test_multi_adapter_independence();
    
    // Print summary
    print("\n=== Test Summary ===\n");
    print("Tests run: %d\n", EnhancedBluetooth.Tests.AdapterManagerTest.tests_run);
    print("Tests passed: %d\n", EnhancedBluetooth.Tests.AdapterManagerTest.tests_passed);
    print("Tests failed: %d\n", EnhancedBluetooth.Tests.AdapterManagerTest.tests_failed);
    
    return EnhancedBluetooth.Tests.AdapterManagerTest.tests_failed > 0 ? 1 : 0;
}
