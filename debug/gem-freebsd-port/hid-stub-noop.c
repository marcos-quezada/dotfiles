/*
 * TEMPORARY diagnostic stub for gem-freebsd-cursor-render's isolation
 * test: gem_hid_init() does nothing and reports zero devices, so gemd
 * runs with raster.c fully active but no evdev device access at all.
 * If the display works correctly with this stub in place, that isolates
 * the black-screen mystery to concurrent evdev access interfering with
 * DRM scanout somehow. If it still shows black, this rules that out.
 *
 * NOT a real implementation -- revert to the real hid.c (round4/hid.c)
 * once this test is done either way.
 */

#include "platform/hid.h"

int gem_hid_init(void)
{
    return 0;
}

void gem_hid_shutdown(void)
{
}

int gem_hid_poll(gem_hid_event_t *event)
{
    (void)event;
    return 0;
}
