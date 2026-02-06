/**
 * Enhanced Network Indicator Wrapper
 * 
 * This file provides a wrapper to expose the enhanced network indicator
 * in the Indicators namespace for compatibility with NovaBar's indicator system.
 */

namespace Indicators {
    
    namespace Enhanced {
        
        /**
         * Wrapper class for the enhanced network indicator
         * 
         * This class wraps the EnhancedNetwork.NetworkIndicator to provide
         * compatibility with NovaBar's indicator system while maintaining
         * all enhanced functionality.
         */
        public class NetworkIndicator : Gtk.EventBox {
            private EnhancedNetwork.NetworkIndicator enhanced_indicator;
            
            public NetworkIndicator() {
                GLib.Object();
                
                // Create the enhanced indicator
                enhanced_indicator = new EnhancedNetwork.NetworkIndicator();
                
                // Add the enhanced indicator as child
                add(enhanced_indicator);
                
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
                
                Debug.log("EnhancedNetworkWrapper", "Enhanced network indicator wrapper created");
            }
            
            private async void initialize_async() {
                try {
                    var success = yield enhanced_indicator.initialize_controller();
                    if (success) {
                        Debug.log("EnhancedNetworkWrapper", "Enhanced network indicator initialized successfully");
                    } else {
                        Debug.log("EnhancedNetworkWrapper", "Failed to initialize enhanced network indicator");
                    }
                } catch (Error e) {
                    Debug.log("EnhancedNetworkWrapper", "Error initializing enhanced network indicator: %s".printf(e.message ?? ""));
                }
            }
        }
    }
}
