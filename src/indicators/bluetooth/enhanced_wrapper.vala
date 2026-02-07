/**
 * Enhanced Bluetooth Indicator Wrapper
 * 
 * This file provides a wrapper to expose the enhanced Bluetooth indicator
 * in the Indicators namespace for compatibility with NovaBar's indicator system.
 * 
 * The wrapper allows seamless switching between the basic and enhanced Bluetooth
 * indicators through a feature flag, ensuring backward compatibility while
 * providing access to advanced Bluetooth management features.
 */

namespace Indicators {
    
    namespace Enhanced {
        
        /**
         * Wrapper class for the enhanced Bluetooth indicator
         * 
         * This class wraps the EnhancedBluetooth.BluetoothIndicator to provide
         * compatibility with NovaBar's indicator system while maintaining
         * all enhanced functionality including:
         * - Comprehensive device management
         * - Audio profile switching
         * - File transfer support
         * - Advanced pairing workflows
         * - Accessibility features
         */
        public class BluetoothIndicator : Gtk.EventBox {
            private EnhancedBluetooth.BluetoothIndicator enhanced_indicator;
            private bool initialized;
            
            /**
             * Signal emitted when Bluetooth state changes
             */
            public signal void bluetooth_state_changed(EnhancedBluetooth.BluetoothState state);
            
            /**
             * Signal emitted when device connection status changes
             */
            public signal void device_status_changed(string device_path, bool connected);
            
            /**
             * Constructor - creates the enhanced Bluetooth indicator wrapper
             */
            public BluetoothIndicator() {
                GLib.Object();
                
                initialized = false;
                
                // Create the enhanced indicator
                enhanced_indicator = new EnhancedBluetooth.BluetoothIndicator();
                
                // Add the enhanced indicator as child
                add(enhanced_indicator);
                
                // Forward signals from enhanced indicator
                enhanced_indicator.bluetooth_state_changed.connect((state) => {
                    bluetooth_state_changed(state);
                });
                
                enhanced_indicator.device_status_changed.connect((device_path, connected) => {
                    device_status_changed(device_path, connected);
                });
                
                // Forward button press events
                button_press_event.connect((event) => {
                    if (event.button == 1) { // Left click
                        enhanced_indicator.clicked();
                        return true;
                    }
                    return false;
                });
                
                // Initialize controller asynchronously
                Idle.add(() => {
                    initialize_async.begin();
                    return false;
                });
                
                Debug.log("EnhancedBluetoothWrapper", "Enhanced Bluetooth indicator wrapper created");
            }
            
            /**
             * Initialize the enhanced Bluetooth indicator asynchronously
             */
            private async void initialize_async() {
                try {
                    Debug.log("EnhancedBluetoothWrapper", "Initializing enhanced Bluetooth indicator...");
                    
                    var success = yield enhanced_indicator.initialize_controller();
                    
                    if (success) {
                        initialized = true;
                        Debug.log("EnhancedBluetoothWrapper", "Enhanced Bluetooth indicator initialized successfully");
                    } else {
                        initialized = false;
                        Debug.log("EnhancedBluetoothWrapper", "Failed to initialize enhanced Bluetooth indicator");
                    }
                } catch (Error e) {
                    initialized = false;
                    Debug.log("EnhancedBluetoothWrapper", 
                             "Error initializing enhanced Bluetooth indicator: %s".printf(e.message ?? ""));
                }
            }
            
            /**
             * Check if the enhanced indicator is initialized
             */
            public bool is_initialized() {
                return initialized;
            }
            
            /**
             * Get the current Bluetooth state
             */
            public EnhancedBluetooth.BluetoothState get_bluetooth_state() {
                return enhanced_indicator.indicator_state;
            }
            
            /**
             * Refresh the indicator state
             */
            public async void refresh() {
                if (initialized) {
                    yield enhanced_indicator.refresh_state();
                }
            }
            
            /**
             * Show a notification
             */
            public void show_notification(string message, EnhancedBluetooth.NotificationType type) {
                enhanced_indicator.show_notification(message, type);
            }
            
            /**
             * Hide the current notification
             */
            public void hide_notification() {
                enhanced_indicator.hide_notification();
            }
            
            /**
             * Get the enhanced indicator instance (for advanced usage)
             */
            public EnhancedBluetooth.BluetoothIndicator get_enhanced_indicator() {
                return enhanced_indicator;
            }
        }
    }
    
    /**
     * Factory function to create the appropriate Bluetooth indicator
     * 
     * This function checks for a feature flag or environment variable to determine
     * whether to create the enhanced or basic Bluetooth indicator, ensuring
     * backward compatibility while allowing users to opt into enhanced features.
     * 
     * Feature flag priority:
     * 1. Environment variable: NOVABAR_ENHANCED_BLUETOOTH=1
     * 2. Configuration file setting (if implemented)
     * 3. Default: Use basic indicator for stability
     * 
     * @return A Gtk.Widget containing either the enhanced or basic Bluetooth indicator
     */
    public Gtk.Widget create_bluetooth_indicator() {
        // Check environment variable for enhanced mode
        var enhanced_mode = Environment.get_variable("NOVABAR_ENHANCED_BLUETOOTH");
        
        if (enhanced_mode != null && enhanced_mode == "1") {
            Debug.log("BluetoothIndicatorFactory", "Creating enhanced Bluetooth indicator");
            return new Enhanced.BluetoothIndicator();
        } else {
            Debug.log("BluetoothIndicatorFactory", "Creating basic Bluetooth indicator");
            return new Indicators.Bluetooth();
        }
    }
}
