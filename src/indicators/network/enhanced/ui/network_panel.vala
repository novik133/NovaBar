/**
 * Enhanced Network Indicator - Base Network Panel
 * 
 * This file provides the base class for all network management panels
 * with common functionality and interface definitions.
 */

using GLib;
using Gtk;

namespace EnhancedNetwork {

    /**
     * Base class for all network management panels
     */
    public abstract class NetworkPanel : Gtk.Box {
        protected NetworkController controller;
        protected string panel_name;
        protected bool is_refreshing;
        
        /**
         * Signal emitted when panel needs refresh
         */
        public signal void refresh_requested();
        
        /**
         * Signal emitted when panel state changes
         */
        public signal void panel_state_changed();
        
        public bool refreshing { 
            get { return is_refreshing; } 
        }
        
        protected NetworkPanel(NetworkController controller, string name) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 8);
            
            this.controller = controller;
            this.panel_name = name;
            this.is_refreshing = false;
            
            margin = 12;
            get_style_context().add_class("network-panel");
            get_style_context().add_class(@"$(name)-panel");
        }
        
        /**
         * Refresh panel content - must be implemented by subclasses
         */
        public abstract void refresh();
        
        /**
         * Apply search filter - must be implemented by subclasses
         */
        public abstract void apply_search_filter(string search_term);
        
        /**
         * Focus first search result - must be implemented by subclasses
         */
        public abstract void focus_first_result();
        
        /**
         * Get panel display name
         */
        public string get_panel_name() {
            return panel_name;
        }
        
        /**
         * Set refreshing state
         */
        protected void set_refreshing(bool refreshing) {
            is_refreshing = refreshing;
            panel_state_changed();
        }
    }
}