/**
 * Enhanced Bluetooth Indicator - Keyboard Navigation Helper
 * 
 * This file provides keyboard navigation utilities and focus management
 * for all UI components in the enhanced Bluetooth indicator.
 */

using GLib;
using Gtk;

namespace EnhancedBluetooth {

    /**
     * Keyboard navigation helper class
     */
    public class KeyboardNavigationHelper : GLib.Object {
        private Gtk.Widget root_widget;
        private GenericArray<Gtk.Widget> focusable_widgets;
        private int current_focus_index;
        
        public KeyboardNavigationHelper(Gtk.Widget root) {
            this.root_widget = root;
            this.focusable_widgets = new GenericArray<Gtk.Widget>();
            this.current_focus_index = -1;
            
            build_focus_chain();
        }
        
        /**
         * Build the focus chain for keyboard navigation
         */
        public void build_focus_chain() {
            focusable_widgets.remove_range(0, focusable_widgets.length);
            current_focus_index = -1;
            
            collect_focusable_widgets(root_widget);
            
            debug("KeyboardNavigationHelper: Built focus chain with %u widgets", focusable_widgets.length);
        }
        
        /**
         * Recursively collect focusable widgets
         */
        private void collect_focusable_widgets(Gtk.Widget widget) {
            if (widget == null || !widget.visible) return;
            
            // Check if widget can receive focus
            if (widget.can_focus && widget.sensitive) {
                focusable_widgets.add(widget);
            }
            
            // Recursively check children
            if (widget is Gtk.Container) {
                var container = widget as Gtk.Container;
                container.foreach((child) => {
                    collect_focusable_widgets(child);
                });
            }
        }
        
        /**
         * Move focus to next widget in chain
         */
        public bool focus_next() {
            if (focusable_widgets.length == 0) return false;
            
            current_focus_index = (current_focus_index + 1) % (int)focusable_widgets.length;
            var widget = focusable_widgets[current_focus_index];
            
            if (widget.visible && widget.sensitive) {
                widget.grab_focus();
                return true;
            }
            
            // Try next widget if current is not focusable
            return focus_next();
        }
        
        /**
         * Move focus to previous widget in chain
         */
        public bool focus_previous() {
            if (focusable_widgets.length == 0) return false;
            
            current_focus_index = (current_focus_index - 1 + (int)focusable_widgets.length) % (int)focusable_widgets.length;
            var widget = focusable_widgets[current_focus_index];
            
            if (widget.visible && widget.sensitive) {
                widget.grab_focus();
                return true;
            }
            
            // Try previous widget if current is not focusable
            return focus_previous();
        }
        
        /**
         * Focus first widget in chain
         */
        public bool focus_first() {
            if (focusable_widgets.length == 0) return false;
            
            current_focus_index = 0;
            var widget = focusable_widgets[0];
            
            if (widget.visible && widget.sensitive) {
                widget.grab_focus();
                return true;
            }
            
            return focus_next();
        }
        
        /**
         * Focus last widget in chain
         */
        public bool focus_last() {
            if (focusable_widgets.length == 0) return false;
            
            current_focus_index = (int)focusable_widgets.length - 1;
            var widget = focusable_widgets[current_focus_index];
            
            if (widget.visible && widget.sensitive) {
                widget.grab_focus();
                return true;
            }
            
            return focus_previous();
        }
        
        /**
         * Update current focus index based on focused widget
         */
        public void update_focus_index(Gtk.Widget focused_widget) {
            for (uint i = 0; i < focusable_widgets.length; i++) {
                if (focusable_widgets[i] == focused_widget) {
                    current_focus_index = (int)i;
                    break;
                }
            }
        }
        
        /**
         * Get currently focused widget index
         */
        public int get_current_focus_index() {
            return current_focus_index;
        }
        
        /**
         * Get total number of focusable widgets
         */
        public uint get_focusable_count() {
            return focusable_widgets.length;
        }
    }

    /**
     * Keyboard shortcut definitions
     */
    public class KeyboardShortcuts : GLib.Object {
        public const uint KEY_REFRESH = Gdk.Key.F5;
        public const uint KEY_SEARCH = Gdk.Key.f; // Ctrl+F
        public const uint KEY_ESCAPE = Gdk.Key.Escape;
        public const uint KEY_ENTER = Gdk.Key.Return;
        public const uint KEY_SPACE = Gdk.Key.space;
        public const uint KEY_TAB = Gdk.Key.Tab;
        public const uint KEY_UP = Gdk.Key.Up;
        public const uint KEY_DOWN = Gdk.Key.Down;
        public const uint KEY_LEFT = Gdk.Key.Left;
        public const uint KEY_RIGHT = Gdk.Key.Right;
        public const uint KEY_HOME = Gdk.Key.Home;
        public const uint KEY_END = Gdk.Key.End;
        public const uint KEY_PAGE_UP = Gdk.Key.Page_Up;
        public const uint KEY_PAGE_DOWN = Gdk.Key.Page_Down;
        public const uint KEY_DELETE = Gdk.Key.Delete;
        public const uint KEY_MENU = Gdk.Key.Menu;
        public const uint KEY_F10 = Gdk.Key.F10;
        
        // Bluetooth-specific shortcuts
        public const uint KEY_BLUETOOTH_TOGGLE = Gdk.Key.b; // Ctrl+B
        public const uint KEY_SCAN = Gdk.Key.s; // Ctrl+S
        public const uint KEY_LAST_DEVICE = Gdk.Key.l; // Ctrl+L
        
        /**
         * Check if key event matches shortcut with modifiers
         */
        public static bool matches_shortcut(Gdk.EventKey event, uint keyval, Gdk.ModifierType modifiers = 0) {
            return event.keyval == keyval && (event.state & modifiers) == modifiers;
        }
        
        /**
         * Check if key event is a navigation key
         */
        public static bool is_navigation_key(Gdk.EventKey event) {
            switch (event.keyval) {
                case KEY_TAB:
                case KEY_UP:
                case KEY_DOWN:
                case KEY_LEFT:
                case KEY_RIGHT:
                case KEY_HOME:
                case KEY_END:
                case KEY_PAGE_UP:
                case KEY_PAGE_DOWN:
                    return true;
                default:
                    return false;
            }
        }
        
        /**
         * Check if key event is an activation key
         */
        public static bool is_activation_key(Gdk.EventKey event) {
            switch (event.keyval) {
                case KEY_ENTER:
                case Gdk.Key.KP_Enter:
                case KEY_SPACE:
                    return true;
                default:
                    return false;
            }
        }
    }

    /**
     * Focus indicator helper for visual focus feedback
     */
    public class FocusIndicator : GLib.Object {
        private Gtk.Widget widget;
        private string original_css_class;
        
        public FocusIndicator(Gtk.Widget widget) {
            this.widget = widget;
            this.original_css_class = "";
            
            setup_focus_events();
        }
        
        /**
         * Setup focus event handlers
         */
        private void setup_focus_events() {
            widget.focus_in_event.connect(on_focus_in);
            widget.focus_out_event.connect(on_focus_out);
        }
        
        /**
         * Handle focus in events
         */
        private bool on_focus_in(Gdk.EventFocus event) {
            widget.get_style_context().add_class("keyboard-focus");
            return false;
        }
        
        /**
         * Handle focus out events
         */
        private bool on_focus_out(Gdk.EventFocus event) {
            widget.get_style_context().remove_class("keyboard-focus");
            return false;
        }
        
        /**
         * Add custom focus styling
         */
        public void add_focus_style(string css_class) {
            original_css_class = css_class;
        }
        
        /**
         * Remove focus indicator
         */
        public void remove_focus_indicator() {
            widget.get_style_context().remove_class("keyboard-focus");
            if (original_css_class.length > 0) {
                widget.get_style_context().remove_class(original_css_class);
            }
        }
    }

    /**
     * List navigation helper for keyboard navigation in lists
     */
    public class ListNavigationHelper : GLib.Object {
        private Gtk.ListBox listbox;
        private GenericArray<Gtk.ListBoxRow> visible_rows;
        private int current_row_index;
        
        /**
         * Signal emitted when context menu is requested for a row
         */
        public signal void context_menu_requested(Gtk.ListBoxRow row);
        
        public ListNavigationHelper(Gtk.ListBox listbox) {
            this.listbox = listbox;
            this.visible_rows = new GenericArray<Gtk.ListBoxRow>();
            this.current_row_index = -1;
            
            setup_list_navigation();
        }
        
        /**
         * Setup list navigation
         */
        private void setup_list_navigation() {
            listbox.key_press_event.connect(on_list_key_press);
            listbox.row_selected.connect(on_row_selected);
            
            update_visible_rows();
        }
        
        /**
         * Update list of visible rows
         */
        public void update_visible_rows() {
            visible_rows.remove_range(0, visible_rows.length);
            current_row_index = -1;
            
            listbox.foreach((widget) => {
                if (widget is Gtk.ListBoxRow && widget.visible) {
                    var row = widget as Gtk.ListBoxRow;
                    visible_rows.add(row);
                }
            });
        }
        
        /**
         * Handle key press events in list
         */
        private bool on_list_key_press(Gdk.EventKey event) {
            switch (event.keyval) {
                case Gdk.Key.Up:
                    return navigate_up();
                    
                case Gdk.Key.Down:
                    return navigate_down();
                    
                case Gdk.Key.Home:
                    return navigate_first();
                    
                case Gdk.Key.End:
                    return navigate_last();
                    
                case Gdk.Key.Page_Up:
                    return navigate_page_up();
                    
                case Gdk.Key.Page_Down:
                    return navigate_page_down();
                    
                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                case Gdk.Key.space:
                    return activate_current_row();
                    
                case Gdk.Key.Menu:
                case Gdk.Key.F10:
                    return show_context_menu();
                    
                default:
                    return false;
            }
        }
        
        /**
         * Navigate to previous row
         */
        private bool navigate_up() {
            if (visible_rows.length == 0) return false;
            
            if (current_row_index > 0) {
                current_row_index--;
            } else {
                current_row_index = (int)visible_rows.length - 1; // Wrap to last
            }
            
            select_current_row();
            return true;
        }
        
        /**
         * Navigate to next row
         */
        private bool navigate_down() {
            if (visible_rows.length == 0) return false;
            
            if (current_row_index < (int)visible_rows.length - 1) {
                current_row_index++;
            } else {
                current_row_index = 0; // Wrap to first
            }
            
            select_current_row();
            return true;
        }
        
        /**
         * Navigate to first row
         */
        private bool navigate_first() {
            if (visible_rows.length == 0) return false;
            
            current_row_index = 0;
            select_current_row();
            return true;
        }
        
        /**
         * Navigate to last row
         */
        private bool navigate_last() {
            if (visible_rows.length == 0) return false;
            
            current_row_index = (int)visible_rows.length - 1;
            select_current_row();
            return true;
        }
        
        /**
         * Navigate page up (5 rows)
         */
        private bool navigate_page_up() {
            if (visible_rows.length == 0) return false;
            
            current_row_index = int.max(0, current_row_index - 5);
            select_current_row();
            return true;
        }
        
        /**
         * Navigate page down (5 rows)
         */
        private bool navigate_page_down() {
            if (visible_rows.length == 0) return false;
            
            current_row_index = int.min((int)visible_rows.length - 1, current_row_index + 5);
            select_current_row();
            return true;
        }
        
        /**
         * Select current row and ensure it's visible
         */
        private void select_current_row() {
            if (current_row_index >= 0 && current_row_index < visible_rows.length) {
                var row = visible_rows[current_row_index];
                listbox.select_row(row);
                
                // Ensure row is visible by scrolling if needed
                var adjustment = get_list_adjustment();
                if (adjustment != null) {
                    var row_allocation = Gtk.Allocation();
                    row.get_allocation(out row_allocation);
                    
                    var visible_min = adjustment.value;
                    var visible_max = adjustment.value + adjustment.page_size;
                    
                    if (row_allocation.y < visible_min) {
                        adjustment.value = row_allocation.y;
                    } else if (row_allocation.y + row_allocation.height > visible_max) {
                        adjustment.value = row_allocation.y + row_allocation.height - adjustment.page_size;
                    }
                }
            }
        }
        
        /**
         * Get scrolled window adjustment for the list
         */
        private Gtk.Adjustment? get_list_adjustment() {
            var parent = listbox.get_parent();
            while (parent != null) {
                if (parent is Gtk.ScrolledWindow) {
                    var scrolled = parent as Gtk.ScrolledWindow;
                    return scrolled.get_vadjustment();
                }
                parent = parent.get_parent();
            }
            return null;
        }
        
        /**
         * Activate current row
         */
        private bool activate_current_row() {
            if (current_row_index >= 0 && current_row_index < visible_rows.length) {
                var row = visible_rows[current_row_index];
                listbox.row_activated(row);
                return true;
            }
            return false;
        }
        
        /**
         * Show context menu for current row
         */
        private bool show_context_menu() {
            if (current_row_index >= 0 && current_row_index < visible_rows.length) {
                var row = visible_rows[current_row_index];
                
                // Emit context menu signal instead of creating synthetic event
                context_menu_requested(row);
                return true;
            }
            return false;
        }
        
        /**
         * Handle row selection events
         */
        private void on_row_selected(Gtk.ListBoxRow? row) {
            if (row != null) {
                // Update current index based on selected row
                for (uint i = 0; i < visible_rows.length; i++) {
                    if (visible_rows[i] == row) {
                        current_row_index = (int)i;
                        break;
                    }
                }
            }
        }
        
        /**
         * Get currently selected row index
         */
        public int get_current_index() {
            return current_row_index;
        }
        
        /**
         * Set current row by index
         */
        public void set_current_index(int index) {
            if (index >= 0 && index < visible_rows.length) {
                current_row_index = index;
                select_current_row();
            }
        }
    }
}
