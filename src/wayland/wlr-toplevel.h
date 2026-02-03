/**
 * Header for wlr-toplevel C implementation
 */

#ifndef WLR_TOPLEVEL_H
#define WLR_TOPLEVEL_H

typedef void (*ToplevelCallbackFunc)(const char* app_id, const char* title, int focused);

int wlr_toplevel_init(void);
void wlr_toplevel_set_callback(ToplevelCallbackFunc cb);
int wlr_toplevel_dispatch(void);
int wlr_toplevel_get_fd(void);
void wlr_toplevel_read_events(void);
void wlr_toplevel_cleanup(void);

#endif
