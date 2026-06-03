#ifndef CGHOSTTY_H
#define CGHOSTTY_H

#include <stdbool.h>
#include <stdint.h>

// App-owned libghostty interop boundary.
//
// Pinned upstream source revision:
// https://github.com/ghostty-org/ghostty/tree/cb36966a752982014827a9cabcf630ec3788b3d9
//
// This target intentionally exposes only the tiny ABI that NativeMacADE needs.
// The implementation can be replaced with direct calls into the pinned
// libghostty binary without changing Swift consumers.

#define ADE_GHOSTTY_PINNED_REVISION "cb36966a752982014827a9cabcf630ec3788b3d9"

typedef enum ade_ghostty_error_code {
    ADE_GHOSTTY_OK = 0,
    ADE_GHOSTTY_INIT_FAILED = 1,
    ADE_GHOSTTY_SURFACE_CREATE_FAILED = 2,
    ADE_GHOSTTY_INVALID_APP_CONTEXT = 3,
    ADE_GHOSTTY_UNKNOWN_FAILURE = 255
} ade_ghostty_error_code_t;

typedef struct ade_ghostty_app_context {
    uint64_t id;
} ade_ghostty_app_context_t;

typedef struct ade_ghostty_surface {
    uint64_t id;
    uint64_t app_context_id;
    bool uses_native_renderer;
    bool focused;
    bool exited;
    bool close_allowed;
    bool has_inherited_context;
    uint64_t inherited_surface_id;
    int32_t exit_status;
    int32_t columns;
    int32_t rows;
    void *native_surface;
    void *native_working_directory;
    void *native_command;
} ade_ghostty_surface_t;

typedef enum ade_ghostty_key_action {
    ADE_GHOSTTY_KEY_RELEASE = 0,
    ADE_GHOSTTY_KEY_PRESS = 1,
    ADE_GHOSTTY_KEY_REPEAT = 2
} ade_ghostty_key_action_t;

typedef enum ade_ghostty_key_mods {
    ADE_GHOSTTY_MODS_NONE = 0,
    ADE_GHOSTTY_MODS_SHIFT = 1 << 0,
    ADE_GHOSTTY_MODS_CTRL = 1 << 1,
    ADE_GHOSTTY_MODS_ALT = 1 << 2,
    ADE_GHOSTTY_MODS_SUPER = 1 << 3,
    ADE_GHOSTTY_MODS_CAPS = 1 << 4,
    ADE_GHOSTTY_MODS_NUM = 1 << 5,
    ADE_GHOSTTY_MODS_SHIFT_RIGHT = 1 << 6,
    ADE_GHOSTTY_MODS_CTRL_RIGHT = 1 << 7,
    ADE_GHOSTTY_MODS_ALT_RIGHT = 1 << 8,
    ADE_GHOSTTY_MODS_SUPER_RIGHT = 1 << 9
} ade_ghostty_key_mods_t;

typedef struct ade_ghostty_key_event {
    ade_ghostty_key_action_t action;
    ade_ghostty_key_mods_t mods;
    ade_ghostty_key_mods_t consumed_mods;
    uint32_t keycode;
    const char *text;
    uint32_t unshifted_codepoint;
    bool composing;
} ade_ghostty_key_event_t;

typedef struct ade_ghostty_init_result {
    ade_ghostty_error_code_t code;
    const char *message;
    ade_ghostty_app_context_t app_context;
} ade_ghostty_init_result_t;

typedef struct ade_ghostty_surface_result {
    ade_ghostty_error_code_t code;
    const char *message;
    ade_ghostty_surface_t surface;
} ade_ghostty_surface_result_t;

const char *ade_ghostty_pinned_revision(void);
uint64_t ade_ghostty_initialize_call_count(void);
void ade_ghostty_reset_for_testing(void);

ade_ghostty_init_result_t ade_ghostty_initialize(bool force_failure);

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
);

void ade_ghostty_focus_surface(ade_ghostty_surface_t *surface, bool focused);
void ade_ghostty_resize_surface(
    ade_ghostty_surface_t *surface,
    int32_t columns,
    int32_t rows,
    uint32_t width_px,
    uint32_t height_px,
    double scale_factor
);
bool ade_ghostty_surface_can_close(ade_ghostty_surface_t surface);
bool ade_ghostty_surface_has_exited(ade_ghostty_surface_t surface);
int32_t ade_ghostty_surface_exit_status(ade_ghostty_surface_t surface);
void ade_ghostty_tick_app(ade_ghostty_app_context_t app_context);
void ade_ghostty_draw_surface(ade_ghostty_surface_t surface);
bool ade_ghostty_send_key(ade_ghostty_surface_t surface, ade_ghostty_key_event_t event);
void ade_ghostty_send_text(ade_ghostty_surface_t surface, const char *text, uintptr_t byte_count);
void ade_ghostty_destroy_surface(ade_ghostty_surface_t *surface);

#endif
