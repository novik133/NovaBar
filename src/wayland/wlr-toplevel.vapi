/**
 * Vala bindings for wlr-foreign-toplevel-management
 */

[CCode (cheader_filename = "wlr-toplevel.h")]
namespace WlrToplevel {
    [CCode (cname = "wlr_toplevel_init")]
    public int init();
    
    [CCode (cname = "wlr_toplevel_set_callback")]
    public void set_callback(ToplevelCallbackFunc cb);
    
    [CCode (cname = "ToplevelCallbackFunc", has_target = false)]
    public delegate void ToplevelCallbackFunc(string? app_id, string? title, int focused);
    
    [CCode (cname = "wlr_toplevel_dispatch")]
    public int dispatch();
    
    [CCode (cname = "wlr_toplevel_get_fd")]
    public int get_fd();
    
    [CCode (cname = "wlr_toplevel_read_events")]
    public void read_events();
    
    [CCode (cname = "wlr_toplevel_cleanup")]
    public void cleanup();
}
