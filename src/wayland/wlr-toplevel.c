/**
 * wlr-foreign-toplevel-management client implementation
 * Tracks focused windows on wlroots-based Wayland compositors
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <poll.h>
#include <wayland-client.h>

// Generated protocol header - will be in build directory
#include "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"

// Simple callback without user_data for Vala
typedef void (*ToplevelCallbackFunc)(const char* app_id, const char* title, int focused);

static ToplevelCallbackFunc simple_callback = NULL;

void wlr_toplevel_set_callback(ToplevelCallbackFunc cb) {
    simple_callback = cb;
}

static struct wl_display *display = NULL;
static struct wl_registry *registry = NULL;
static struct zwlr_foreign_toplevel_manager_v1 *toplevel_manager = NULL;

// Current focused toplevel info
static char *current_app_id = NULL;
static char *current_title = NULL;
static int current_focused = 0;

// Toplevel handle tracking
struct toplevel_handle {
    struct zwlr_foreign_toplevel_handle_v1 *handle;
    char *app_id;
    char *title;
    int focused;
    struct toplevel_handle *next;
};

static struct toplevel_handle *toplevels = NULL;

static void toplevel_handle_title(void *data,
        struct zwlr_foreign_toplevel_handle_v1 *handle, const char *title) {
    struct toplevel_handle *t = data;
    free(t->title);
    t->title = title ? strdup(title) : NULL;
}

static void toplevel_handle_app_id(void *data,
        struct zwlr_foreign_toplevel_handle_v1 *handle, const char *app_id) {
    struct toplevel_handle *t = data;
    free(t->app_id);
    t->app_id = app_id ? strdup(app_id) : NULL;
}

static void toplevel_handle_state(void *data,
        struct zwlr_foreign_toplevel_handle_v1 *handle,
        struct wl_array *state) {
    struct toplevel_handle *t = data;
    int was_focused = t->focused;
    t->focused = 0;
    
    uint32_t *entry;
    wl_array_for_each(entry, state) {
        if (*entry == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED) {
            t->focused = 1;
            break;
        }
    }
    
    // Notify if focus changed
    if (t->focused && !was_focused && simple_callback) {
        simple_callback(t->app_id ? t->app_id : "", t->title ? t->title : "", t->focused);
    }
}

static void toplevel_handle_done(void *data,
        struct zwlr_foreign_toplevel_handle_v1 *handle) {
    // State update complete
}

static void toplevel_handle_closed(void *data,
        struct zwlr_foreign_toplevel_handle_v1 *handle) {
    struct toplevel_handle *t = data;
    
    // Remove from list
    struct toplevel_handle **pp = &toplevels;
    while (*pp) {
        if (*pp == t) {
            *pp = t->next;
            break;
        }
        pp = &(*pp)->next;
    }
    
    free(t->app_id);
    free(t->title);
    zwlr_foreign_toplevel_handle_v1_destroy(handle);
    free(t);
}

static void toplevel_handle_output_enter(void *data,
        struct zwlr_foreign_toplevel_handle_v1 *handle,
        struct wl_output *output) {}

static void toplevel_handle_output_leave(void *data,
        struct zwlr_foreign_toplevel_handle_v1 *handle,
        struct wl_output *output) {}

static void toplevel_handle_parent(void *data,
        struct zwlr_foreign_toplevel_handle_v1 *handle,
        struct zwlr_foreign_toplevel_handle_v1 *parent) {}

static const struct zwlr_foreign_toplevel_handle_v1_listener toplevel_handle_listener = {
    .title = toplevel_handle_title,
    .app_id = toplevel_handle_app_id,
    .output_enter = toplevel_handle_output_enter,
    .output_leave = toplevel_handle_output_leave,
    .state = toplevel_handle_state,
    .done = toplevel_handle_done,
    .closed = toplevel_handle_closed,
    .parent = toplevel_handle_parent,
};

static void toplevel_manager_handle_toplevel(void *data,
        struct zwlr_foreign_toplevel_manager_v1 *manager,
        struct zwlr_foreign_toplevel_handle_v1 *handle) {
    struct toplevel_handle *t = calloc(1, sizeof(*t));
    t->handle = handle;
    t->next = toplevels;
    toplevels = t;
    
    zwlr_foreign_toplevel_handle_v1_add_listener(handle, &toplevel_handle_listener, t);
}

static void toplevel_manager_handle_finished(void *data,
        struct zwlr_foreign_toplevel_manager_v1 *manager) {
    zwlr_foreign_toplevel_manager_v1_destroy(manager);
    toplevel_manager = NULL;
}

static const struct zwlr_foreign_toplevel_manager_v1_listener toplevel_manager_listener = {
    .toplevel = toplevel_manager_handle_toplevel,
    .finished = toplevel_manager_handle_finished,
};

static void registry_handle_global(void *data, struct wl_registry *registry,
        uint32_t name, const char *interface, uint32_t version) {
    if (strcmp(interface, zwlr_foreign_toplevel_manager_v1_interface.name) == 0) {
        toplevel_manager = wl_registry_bind(registry, name,
            &zwlr_foreign_toplevel_manager_v1_interface, 3);
        zwlr_foreign_toplevel_manager_v1_add_listener(toplevel_manager,
            &toplevel_manager_listener, NULL);
    }
}

static void registry_handle_global_remove(void *data, struct wl_registry *registry,
        uint32_t name) {}

static const struct wl_registry_listener registry_listener = {
    .global = registry_handle_global,
    .global_remove = registry_handle_global_remove,
};

// Public API for Vala

int wlr_toplevel_init(void) {
    display = wl_display_connect(NULL);
    if (!display) {
        return 0;
    }
    
    registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    
    if (!toplevel_manager) {
        wl_registry_destroy(registry);
        wl_display_disconnect(display);
        display = NULL;
        return 0;
    }
    
    wl_display_roundtrip(display);
    return 1;
}

int wlr_toplevel_dispatch(void) {
    if (!display) return 0;
    return wl_display_dispatch_pending(display) >= 0 && 
           wl_display_flush(display) >= 0;
}

int wlr_toplevel_get_fd(void) {
    if (!display) return -1;
    return wl_display_get_fd(display);
}

void wlr_toplevel_read_events(void) {
    if (display) {
        // Non-blocking read
        while (wl_display_prepare_read(display) != 0) {
            wl_display_dispatch_pending(display);
        }
        wl_display_flush(display);
        
        // Check if there's data to read (non-blocking)
        struct pollfd pfd = { wl_display_get_fd(display), POLLIN, 0 };
        if (poll(&pfd, 1, 0) > 0) {
            wl_display_read_events(display);
            wl_display_dispatch_pending(display);
        } else {
            wl_display_cancel_read(display);
        }
    }
}

void wlr_toplevel_cleanup(void) {
    struct toplevel_handle *t = toplevels;
    while (t) {
        struct toplevel_handle *next = t->next;
        free(t->app_id);
        free(t->title);
        if (t->handle) {
            zwlr_foreign_toplevel_handle_v1_destroy(t->handle);
        }
        free(t);
        t = next;
    }
    toplevels = NULL;
    
    if (toplevel_manager) {
        zwlr_foreign_toplevel_manager_v1_destroy(toplevel_manager);
        toplevel_manager = NULL;
    }
    if (registry) {
        wl_registry_destroy(registry);
        registry = NULL;
    }
    if (display) {
        wl_display_disconnect(display);
        display = NULL;
    }
}
