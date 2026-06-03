#include <CGhostty.h>

#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

typedef void *ade_native_app_t;
typedef void *ade_native_config_t;
typedef void *ade_native_surface_t;

typedef enum ade_native_platform {
    ADE_NATIVE_PLATFORM_INVALID = 0,
    ADE_NATIVE_PLATFORM_MACOS = 1,
    ADE_NATIVE_PLATFORM_IOS = 2
} ade_native_platform_t;

typedef struct ade_native_platform_macos {
    void *nsview;
} ade_native_platform_macos_t;

typedef struct ade_native_platform_ios {
    void *uiview;
} ade_native_platform_ios_t;

typedef union ade_native_platform_value {
    ade_native_platform_macos_t macos;
    ade_native_platform_ios_t ios;
} ade_native_platform_value_t;

typedef struct ade_native_env_var {
    const char *key;
    const char *value;
} ade_native_env_var_t;

typedef enum ade_native_surface_context {
    ADE_NATIVE_SURFACE_CONTEXT_WINDOW = 0,
    ADE_NATIVE_SURFACE_CONTEXT_TAB = 1,
    ADE_NATIVE_SURFACE_CONTEXT_SPLIT = 2
} ade_native_surface_context_t;

typedef struct ade_native_surface_config {
    ade_native_platform_t platform_tag;
    ade_native_platform_value_t platform;
    void *userdata;
    double scale_factor;
    float font_size;
    const char *working_directory;
    const char *command;
    ade_native_env_var_t *env_vars;
    size_t env_var_count;
    const char *initial_input;
    bool wait_after_command;
    ade_native_surface_context_t context;
} ade_native_surface_config_t;

typedef struct ade_native_runtime_config {
    void *userdata;
    bool supports_selection_clipboard;
    void (*wakeup_cb)(void *);
    void *action_cb;
    bool (*read_clipboard_cb)(void *, int, void *);
    void (*confirm_read_clipboard_cb)(void *, const char *, void *, int);
    void (*write_clipboard_cb)(void *, int, const void *, size_t, bool);
    void (*close_surface_cb)(void *, bool);
} ade_native_runtime_config_t;

typedef struct ade_native_api {
    int (*ghostty_init)(uintptr_t, char **);
    ade_native_config_t (*config_new)(void);
    void (*config_free)(ade_native_config_t);
    void (*config_load_default_files)(ade_native_config_t);
    void (*config_finalize)(ade_native_config_t);
    ade_native_app_t (*app_new)(const ade_native_runtime_config_t *, ade_native_config_t);
    void (*app_free)(ade_native_app_t);
    void (*app_tick)(ade_native_app_t);
    ade_native_surface_config_t (*surface_config_new)(void);
    ade_native_surface_t (*surface_new)(ade_native_app_t, const ade_native_surface_config_t *);
    void (*surface_free)(ade_native_surface_t);
    void (*surface_set_focus)(ade_native_surface_t, bool);
    void (*surface_set_content_scale)(ade_native_surface_t, double, double);
    void (*surface_set_size)(ade_native_surface_t, uint32_t, uint32_t);
    bool (*surface_needs_confirm_quit)(ade_native_surface_t);
    bool (*surface_process_exited)(ade_native_surface_t);
    void (*surface_draw)(ade_native_surface_t);
} ade_native_api_t;

typedef struct ade_native_context {
    ade_native_app_t app;
    ade_native_config_t config;
} ade_native_context_t;

static bool app_initialized = false;
static uint64_t next_surface_id = 1;
static uint64_t initialize_call_count = 0;
static void *native_handle = NULL;
static void *native_sparkle_handle = NULL;
static ade_native_api_t native_api = { 0 };
static ade_native_context_t native_context = { 0 };

static const char *ade_native_ghostty_path(void) {
    const char *path = getenv("ADE_GHOSTTY_APP_BINARY");
    return path != NULL && strlen(path) > 0 ? path : "/Applications/Ghostty.app/Contents/MacOS/ghostty";
}

static const char *ade_native_sparkle_path(void) {
    const char *path = getenv("ADE_GHOSTTY_SPARKLE_BINARY");
    return path != NULL && strlen(path) > 0
        ? path
        : "/Applications/Ghostty.app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle";
}

static bool ade_should_use_native_renderer(void) {
    if (getenv("ADE_GHOSTTY_DISABLE_NATIVE") != NULL) { return false; }
    return getenv("ADE_GHOSTTY_ENABLE_NATIVE") != NULL;
}

static bool ade_load_symbol(void **slot, const char *name, bool required) {
    *slot = dlsym(native_handle, name);
    return *slot != NULL || !required;
}

static void ade_native_tick_context(void *userdata) {
    (void)userdata;
    if (native_context.app != NULL && native_api.app_tick != NULL) {
        native_api.app_tick(native_context.app);
    }
}

static void ade_native_wakeup(void *userdata) {
    dispatch_async_f(dispatch_get_main_queue(), userdata, ade_native_tick_context);
}

static bool ade_native_action(void *app, ...) {
    (void)app;
    return false;
}

static bool ade_native_read_clipboard(void *userdata, int clipboard, void *state) {
    (void)userdata;
    (void)clipboard;
    (void)state;
    return false;
}

static void ade_native_confirm_read_clipboard(
    void *userdata,
    const char *string,
    void *state,
    int request
) {
    (void)userdata;
    (void)string;
    (void)state;
    (void)request;
}

static void ade_native_write_clipboard(
    void *userdata,
    int clipboard,
    const void *content,
    size_t content_count,
    bool confirm
) {
    (void)userdata;
    (void)clipboard;
    (void)content;
    (void)content_count;
    (void)confirm;
}

static void ade_native_close_surface(void *userdata, bool process_alive) {
    (void)userdata;
    (void)process_alive;
}

static bool ade_load_native_api(void) {
    if (native_handle != NULL) { return true; }
    if (!ade_should_use_native_renderer()) { return false; }

    native_sparkle_handle = dlopen(ade_native_sparkle_path(), RTLD_LAZY | RTLD_GLOBAL);
    (void)native_sparkle_handle;

    native_handle = dlopen(ade_native_ghostty_path(), RTLD_LAZY | RTLD_LOCAL);
    if (native_handle == NULL) { return false; }

    bool ok = true;
    ok = ade_load_symbol((void **)&native_api.ghostty_init, "ghostty_init", true) && ok;
    ok = ade_load_symbol((void **)&native_api.config_new, "ghostty_config_new", true) && ok;
    ok = ade_load_symbol((void **)&native_api.config_free, "ghostty_config_free", false) && ok;
    ok = ade_load_symbol((void **)&native_api.config_load_default_files, "ghostty_config_load_default_files", false) && ok;
    ok = ade_load_symbol((void **)&native_api.config_finalize, "ghostty_config_finalize", true) && ok;
    ok = ade_load_symbol((void **)&native_api.app_new, "ghostty_app_new", true) && ok;
    ok = ade_load_symbol((void **)&native_api.app_free, "ghostty_app_free", true) && ok;
    ok = ade_load_symbol((void **)&native_api.app_tick, "ghostty_app_tick", true) && ok;
    ok = ade_load_symbol((void **)&native_api.surface_config_new, "ghostty_surface_config_new", true) && ok;
    ok = ade_load_symbol((void **)&native_api.surface_new, "ghostty_surface_new", true) && ok;
    ok = ade_load_symbol((void **)&native_api.surface_free, "ghostty_surface_free", true) && ok;
    ok = ade_load_symbol((void **)&native_api.surface_set_focus, "ghostty_surface_set_focus", true) && ok;
    ok = ade_load_symbol((void **)&native_api.surface_set_content_scale, "ghostty_surface_set_content_scale", true) && ok;
    ok = ade_load_symbol((void **)&native_api.surface_set_size, "ghostty_surface_set_size", true) && ok;
    ok = ade_load_symbol((void **)&native_api.surface_needs_confirm_quit, "ghostty_surface_needs_confirm_quit", true) && ok;
    ok = ade_load_symbol((void **)&native_api.surface_process_exited, "ghostty_surface_process_exited", true) && ok;
    ok = ade_load_symbol((void **)&native_api.surface_draw, "ghostty_surface_draw", false) && ok;

    if (!ok) {
        dlclose(native_handle);
        native_handle = NULL;
        memset(&native_api, 0, sizeof(native_api));
        return false;
    }

    return true;
}

static bool ade_initialize_native_context(void) {
    if (native_context.app != NULL) { return true; }
    if (!ade_load_native_api()) { return false; }

    char *argv[] = { "Atelier", NULL };
    if (native_api.ghostty_init(1, argv) != 0) { return false; }

    native_context.config = native_api.config_new();
    if (native_context.config == NULL) { return false; }
    if (native_api.config_load_default_files != NULL) {
        native_api.config_load_default_files(native_context.config);
    }
    native_api.config_finalize(native_context.config);

    ade_native_runtime_config_t runtime = {
        .userdata = &native_context,
        .supports_selection_clipboard = true,
        .wakeup_cb = ade_native_wakeup,
        .action_cb = (void *)ade_native_action,
        .read_clipboard_cb = ade_native_read_clipboard,
        .confirm_read_clipboard_cb = ade_native_confirm_read_clipboard,
        .write_clipboard_cb = ade_native_write_clipboard,
        .close_surface_cb = ade_native_close_surface
    };

    native_context.app = native_api.app_new(&runtime, native_context.config);
    return native_context.app != NULL;
}

static void ade_reset_native_context(void) {
    if (native_context.app != NULL && native_api.app_free != NULL) {
        native_api.app_free(native_context.app);
    }
    native_context.app = NULL;

    if (native_context.config != NULL && native_api.config_free != NULL) {
        native_api.config_free(native_context.config);
    }
    native_context.config = NULL;
}

const char *ade_ghostty_pinned_revision(void) {
    return ADE_GHOSTTY_PINNED_REVISION;
}

uint64_t ade_ghostty_initialize_call_count(void) {
    return initialize_call_count;
}

void ade_ghostty_reset_for_testing(void) {
    ade_reset_native_context();
    app_initialized = false;
    next_surface_id = 1;
    initialize_call_count = 0;
}

ade_ghostty_init_result_t ade_ghostty_initialize(bool force_failure) {
    initialize_call_count++;
    if (force_failure) {
        return (ade_ghostty_init_result_t) {
            .code = ADE_GHOSTTY_INIT_FAILED,
            .message = "Pinned libghostty app context initialization failed",
            .app_context = { .id = 0 }
        };
    }

    (void)ade_initialize_native_context();

    app_initialized = true;
    return (ade_ghostty_init_result_t) {
        .code = ADE_GHOSTTY_OK,
        .message = "ok",
        .app_context = { .id = 1 }
    };
}

ade_ghostty_surface_result_t ade_ghostty_create_surface(
    ade_ghostty_app_context_t app_context,
    const char *working_directory,
    const char *command,
    const char *arguments_json,
    const char *environment_json,
    const char *inherited_surface_id,
    void *native_view,
    double scale_factor,
    uint32_t width_px,
    uint32_t height_px,
    float font_size,
    bool force_failure
) {
    (void)arguments_json;
    (void)environment_json;

    if (!app_initialized || app_context.id != 1) {
        return (ade_ghostty_surface_result_t) {
            .code = ADE_GHOSTTY_INVALID_APP_CONTEXT,
            .message = "Ghostty app context is not initialized",
            .surface = { 0 }
        };
    }

    if (force_failure || working_directory == NULL || strlen(working_directory) == 0) {
        return (ade_ghostty_surface_result_t) {
            .code = ADE_GHOSTTY_SURFACE_CREATE_FAILED,
            .message = "Pinned libghostty surface creation failed",
            .surface = { 0 }
        };
    }

    uint64_t inherited_id = 0;
    if (inherited_surface_id != NULL && strlen(inherited_surface_id) > 0) {
        inherited_id = strtoull(inherited_surface_id, NULL, 10);
    }

    ade_native_surface_t native_surface = NULL;
    char *native_working_directory = NULL;
    char *native_command = NULL;
    if (native_context.app != NULL && native_view != NULL) {
        ade_native_surface_config_t config = native_api.surface_config_new();
        native_working_directory = strdup(working_directory);
        if (native_working_directory == NULL) {
            return (ade_ghostty_surface_result_t) {
                .code = ADE_GHOSTTY_SURFACE_CREATE_FAILED,
                .message = "Failed to retain Ghostty working directory",
                .surface = { 0 }
            };
        }
        if (command != NULL) {
            native_command = strdup(command);
            if (native_command == NULL) {
                free(native_working_directory);
                return (ade_ghostty_surface_result_t) {
                    .code = ADE_GHOSTTY_SURFACE_CREATE_FAILED,
                    .message = "Failed to retain Ghostty launch command",
                    .surface = { 0 }
                };
            }
        }

        config.platform_tag = ADE_NATIVE_PLATFORM_MACOS;
        config.platform.macos.nsview = native_view;
        config.userdata = native_view;
        config.scale_factor = scale_factor > 0 ? scale_factor : 1;
        config.font_size = font_size;
        config.working_directory = native_working_directory;
        config.command = native_command;
        config.context = ADE_NATIVE_SURFACE_CONTEXT_TAB;
        native_surface = native_api.surface_new(native_context.app, &config);
        if (native_surface != NULL) {
            native_api.surface_set_content_scale(native_surface, config.scale_factor, config.scale_factor);
            native_api.surface_set_size(native_surface, width_px > 0 ? width_px : 1, height_px > 0 ? height_px : 1);
        } else {
            free(native_working_directory);
            free(native_command);
            native_working_directory = NULL;
            native_command = NULL;
        }
    }

    return (ade_ghostty_surface_result_t) {
        .code = ADE_GHOSTTY_OK,
        .message = native_surface != NULL ? "native" : "stub",
        .surface = {
            .id = next_surface_id++,
            .app_context_id = app_context.id,
            .uses_native_renderer = native_surface != NULL,
            .focused = false,
            .exited = false,
            .close_allowed = true,
            .has_inherited_context = inherited_id > 0,
            .inherited_surface_id = inherited_id,
            .exit_status = 0,
            .columns = 80,
            .rows = 24,
            .native_surface = native_surface,
            .native_working_directory = native_working_directory,
            .native_command = native_command
        }
    };
}

void ade_ghostty_focus_surface(ade_ghostty_surface_t *surface, bool focused) {
    if (surface == NULL) { return; }
    surface->focused = focused;
    if (surface->uses_native_renderer && surface->native_surface != NULL && native_api.surface_set_focus != NULL) {
        native_api.surface_set_focus(surface->native_surface, focused);
    }
}

void ade_ghostty_resize_surface(
    ade_ghostty_surface_t *surface,
    int32_t columns,
    int32_t rows,
    uint32_t width_px,
    uint32_t height_px,
    double scale_factor
) {
    if (surface == NULL) { return; }
    surface->columns = columns;
    surface->rows = rows;
    if (surface->uses_native_renderer && surface->native_surface != NULL) {
        native_api.surface_set_content_scale(surface->native_surface, scale_factor, scale_factor);
        native_api.surface_set_size(surface->native_surface, width_px > 0 ? width_px : 1, height_px > 0 ? height_px : 1);
    }
}

bool ade_ghostty_surface_can_close(ade_ghostty_surface_t surface) {
    if (surface.uses_native_renderer && surface.native_surface != NULL &&
        native_api.surface_needs_confirm_quit != NULL) {
        return !native_api.surface_needs_confirm_quit(surface.native_surface);
    }
    return surface.close_allowed;
}

bool ade_ghostty_surface_has_exited(ade_ghostty_surface_t surface) {
    if (surface.uses_native_renderer && surface.native_surface != NULL &&
        native_api.surface_process_exited != NULL) {
        return native_api.surface_process_exited(surface.native_surface);
    }
    return surface.exited;
}

int32_t ade_ghostty_surface_exit_status(ade_ghostty_surface_t surface) {
    return surface.exit_status;
}

void ade_ghostty_tick_app(ade_ghostty_app_context_t app_context) {
    if (app_context.id != 1 || native_context.app == NULL || native_api.app_tick == NULL) { return; }
    native_api.app_tick(native_context.app);
}

void ade_ghostty_draw_surface(ade_ghostty_surface_t surface) {
    if (!surface.uses_native_renderer || surface.native_surface == NULL || native_api.surface_draw == NULL) { return; }
    native_api.surface_draw(surface.native_surface);
}

void ade_ghostty_destroy_surface(ade_ghostty_surface_t *surface) {
    if (surface == NULL) { return; }
    if (surface->uses_native_renderer && surface->native_surface != NULL && native_api.surface_free != NULL) {
        native_api.surface_free(surface->native_surface);
    }
    free(surface->native_working_directory);
    free(surface->native_command);
    memset(surface, 0, sizeof(*surface));
}
