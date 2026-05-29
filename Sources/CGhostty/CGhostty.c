#include <CGhostty.h>

#include <string.h>
#include <stdlib.h>

static bool app_initialized = false;
static uint64_t next_surface_id = 1;
static uint64_t initialize_call_count = 0;

const char *ade_ghostty_pinned_revision(void) {
    return ADE_GHOSTTY_PINNED_REVISION;
}

uint64_t ade_ghostty_initialize_call_count(void) {
    return initialize_call_count;
}

void ade_ghostty_reset_for_testing(void) {
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
    const char *inherited_surface_id,
    bool force_failure
) {
    (void) command;
    (void) arguments_json;
    (void) inherited_surface_id;

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

    return (ade_ghostty_surface_result_t) {
        .code = ADE_GHOSTTY_OK,
        .message = "ok",
        .surface = {
            .id = next_surface_id++,
            .app_context_id = app_context.id,
            .focused = false,
            .exited = false,
            .close_allowed = true,
            .has_inherited_context = inherited_id > 0,
            .inherited_surface_id = inherited_id,
            .columns = 80,
            .rows = 24
        }
    };
}

void ade_ghostty_focus_surface(ade_ghostty_surface_t *surface, bool focused) {
    if (surface == NULL) { return; }
    surface->focused = focused;
}

void ade_ghostty_resize_surface(ade_ghostty_surface_t *surface, int32_t columns, int32_t rows) {
    if (surface == NULL) { return; }
    surface->columns = columns;
    surface->rows = rows;
}

bool ade_ghostty_surface_can_close(ade_ghostty_surface_t surface) {
    return surface.close_allowed;
}

bool ade_ghostty_surface_has_exited(ade_ghostty_surface_t surface) {
    return surface.exited;
}
