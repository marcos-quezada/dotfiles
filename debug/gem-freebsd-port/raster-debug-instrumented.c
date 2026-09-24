/*
 * Implements native FreeBSD DRM/KMS output for GEM. VDI draws into a
 * packed monochrome shadow surface (the same format rasta and the Linux
 * backend use) and this backend expands it into a DRM "dumb buffer"
 * scanned out directly by the GPU -- there is no fbdev-equivalent raw
 * framebuffer device on FreeBSD (confirmed against vt(4)/syscons(4)'s own
 * FILES sections: neither lists one), so this goes through the real
 * DRM/KMS dumb-buffer API instead, validated standalone before any of
 * this file existed (staging/gem-freebsd-port/drm-stage-{a,b,c}.c).
 *
 * SAFETY: this backend never enumerates or opens more than the single
 * DRM device it is configured for. On this project's own development
 * machine, a second DRM node exists for a secondary/PRIME GPU that is
 * confirmed (via a real, reproducible kernel panic, root-caused with a
 * full kgdb backtrace) to crash the kernel when opened by any DRM-aware
 * client. Auto-probing multiple /dev/drm/N nodes to "find the right one"
 * would risk touching that device by accident. The device path is always
 * explicit: GEM_FREEBSD_DRM env var, or the conservative default below.
 *
 * MIT License (see: LICENSE)
 * Copyright (C) 2026 tomaz stih
 */

#define _POSIX_C_SOURCE 200809L

#include "platform/raster.h"

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include <devctl.h>

#include <xf86drm.h>
#include <xf86drmMode.h>

/*
 * Dumb-buffer create/map/destroy: not wrapped by libdrm's own
 * convenience API (only mode-setting calls are), so these mirror the
 * kernel uAPI directly -- verified against FreeBSD's own
 * sys/dev/drm2/drm_mode.h / drm.h, and cross-checked live: this
 * project's actual installed libdrm/kernel headers already declare
 * these structs, so including them here would conflict. Declared with
 * `struct drm_mode_create_dumb` etc. left to the system headers pulled
 * in by xf86drmMode.h; only the ioctl numbers are defined locally in
 * case a given libdrm version doesn't expose them under these names.
 */
#ifndef DRM_IOCTL_MODE_CREATE_DUMB
#define DRM_IOCTL_MODE_CREATE_DUMB DRM_IOWR(0xB2, struct drm_mode_create_dumb)
#endif
#ifndef DRM_IOCTL_MODE_MAP_DUMB
#define DRM_IOCTL_MODE_MAP_DUMB DRM_IOWR(0xB3, struct drm_mode_map_dumb)
#endif
#ifndef DRM_IOCTL_MODE_DESTROY_DUMB
#define DRM_IOCTL_MODE_DESTROY_DUMB \
    DRM_IOWR(0xB4, struct drm_mode_destroy_dumb)
#endif

static gem_raster_surface_t g_surface;
static uint8_t *g_dumb_pixels;
static uint64_t g_dumb_size;
static uint32_t g_dumb_handle;
static uint32_t g_dumb_pitch;
static uint32_t g_fb_id;
static int g_drm_fd = -1;
static uint32_t g_connector_id;
static drmModeCrtcPtr g_saved_crtc;
static int g_power_cycled_after_first_content;

static const char *drm_device_path(void)
{
    const char *path = getenv("GEM_FREEBSD_DRM");

    return (path != NULL && path[0] != '\0') ? path : "/dev/drm/0";
}

/*
 * set bit -> black ink, clear -> white paper. Same shadow polarity
 * convention as rasta and the Linux backend; do not "fix" it here.
 */
static uint32_t shadow_bit_to_xrgb8888(int bit_set)
{
    return bit_set ? 0x00000000u : 0x00ffffffu;
}

static void teardown_drm(int restore_crtc)
{
    if (restore_crtc && g_saved_crtc != NULL && g_drm_fd >= 0) {
        (void)drmModeSetCrtc(g_drm_fd, g_saved_crtc->crtc_id,
                             g_saved_crtc->buffer_id, g_saved_crtc->x,
                             g_saved_crtc->y, &g_connector_id, 1,
                             &g_saved_crtc->mode);
    }
    if (g_saved_crtc != NULL) {
        drmModeFreeCrtc(g_saved_crtc);
        g_saved_crtc = NULL;
    }
    if (g_fb_id != 0u && g_drm_fd >= 0) {
        drmModeRmFB(g_drm_fd, g_fb_id);
        g_fb_id = 0u;
    }
    if (g_dumb_pixels != NULL) {
        (void)munmap(g_dumb_pixels, g_dumb_size);
        g_dumb_pixels = NULL;
    }
    if (g_dumb_handle != 0u && g_drm_fd >= 0) {
        struct drm_mode_destroy_dumb dreq;

        memset(&dreq, 0, sizeof(dreq));
        dreq.handle = g_dumb_handle;
        (void)drmIoctl(g_drm_fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
        g_dumb_handle = 0u;
    }
    if (g_drm_fd >= 0) {
        close(g_drm_fd);
        g_drm_fd = -1;
    }
}

/*
 * Confirmed via direct evidence this session (not guessed): neither
 * drmModeSetCrtc succeeding nor a DPMS property OFF/ON cycle is
 * sufficient to make this hardware's eDP link actually display content
 * for a freshly-opened client on a cold boot -- only an ACTUAL PCI
 * power-state cycle of the GPU device does (confirmed via `devctl
 * suspend drmn0` / `devctl resume drmn0`, cross-checked against dmesg
 * showing real `pci_set_powerstate`/`pci_enable_io` transitions, and an
 * HDA audio codec reacting with "unsolicited response" messages
 * consistent with a real display-link retraining event). This performs
 * the same operation devctl(8) does, via the documented devctl(3) C API
 * (devctl_suspend()/devctl_resume()), rather than shelling out.
 *
 * The device name is machine-specific (this project's own convention,
 * matching GEM_FREEBSD_DRM's existing env-var-override pattern) --
 * override via GEM_FREEBSD_DRM_DEVCTL if a different machine's GPU
 * newbus device name differs from the default below.
 *
 * Confirmed via a clean, dmesg-verified test (kernel ring buffer
 * cleared beforehand, so no stale entries): a SINGLE cycle is not
 * always enough -- consistent with real eDP link training genuinely
 * being flaky at the hardware level (a documented, known category of
 * behavior, not specific to this driver). No clean way exists to query
 * "did the link actually train" from userspace to decide whether a
 * retry is needed, so this pragmatically cycles twice, unconditionally,
 * matching exactly what was empirically confirmed to work. Override the
 * cycle count via GEM_FREEBSD_DRM_POWERCYCLES if a different machine
 * needs more (or fewer, though 1 is not recommended given the evidence).
 */
static void power_cycle_gpu_device(void)
{
    const char *device = getenv("GEM_FREEBSD_DRM_DEVCTL");
    const char *count_env = getenv("GEM_FREEBSD_DRM_POWERCYCLES");
    int count = 2;
    int attempt;

    if (device == NULL || device[0] == '\0') {
        device = "drmn0";
    }
    if (count_env != NULL && count_env[0] != '\0') {
        char *end = NULL;
        long parsed = strtol(count_env, &end, 10);

        if (end != count_env && *end == '\0' && parsed >= 1L &&
            parsed <= 10L) {
            count = (int)parsed;
        }
    }

    for (attempt = 1; attempt <= count; ++attempt) {
        fprintf(stderr,
                "[raster-debug] power-cycling %s via devctl_suspend/resume "
                "(attempt %d/%d)\n",
                device, attempt, count);

        if (devctl_suspend(device) != 0) {
            fprintf(stderr, "[raster-debug] devctl_suspend(%s) failed: %s\n",
                    device, strerror(errno));
            continue;
        }
        usleep(300000);
        if (devctl_resume(device) != 0) {
            fprintf(stderr, "[raster-debug] devctl_resume(%s) failed: %s\n",
                    device, strerror(errno));
            continue;
        }
        fprintf(stderr, "[raster-debug] power-cycle attempt %d/%d of %s "
                        "completed\n",
                attempt, count, device);
        if (attempt < count) {
            fprintf(stderr,
                    "[raster-debug] waiting 3s before next attempt (a "
                    "manual retry that worked had a real, multi-second "
                    "human-timescale gap; testing whether that settle "
                    "time itself matters, not just the retry count)\n");
            sleep(3); /* settle time between cycles -- was 300ms, testing
                       * a much longer gap given 300ms didn't work */
        }
    }
}

int gem_raster_init(uint16_t width, uint16_t height, gem_raster_format_t format)
{
    drmModeResPtr res = NULL;
    drmModeConnectorPtr conn = NULL;
    drmModeEncoderPtr enc = NULL;
    struct drm_mode_create_dumb creq;
    struct drm_mode_map_dumb mreq;
    size_t pitch;
    size_t shadow_size;
    int i;
    int ok = 0;

    /*
     * When stderr is redirected to a file (not a terminal), it's
     * normally fully buffered, not line-buffered -- meaning these debug
     * prints could sit unflushed for a long time while gemd keeps
     * running, making the log file look "stuck" even though real
     * activity is happening. Force unbuffered output so every line
     * appears immediately, matching what we actually need for live
     * debugging.
     */
    setvbuf(stderr, NULL, _IONBF, 0);

    fprintf(stderr, "[raster-debug] gem_raster_init called: width=%u height=%u format=%d\n",
            width, height, (int)format);

    if (format != GEM_RASTER_MONO1) {
        fprintf(stderr, "[raster-debug] rejected: format != MONO1\n");
        errno = EINVAL;
        return 0;
    }

    g_drm_fd = open(drm_device_path(), O_RDWR | O_CLOEXEC);
    if (g_drm_fd < 0) {
        fprintf(stderr, "[raster-debug] open(%s) failed: %s\n",
                drm_device_path(), strerror(errno));
        return 0;
    }
    fprintf(stderr, "[raster-debug] opened %s, fd=%d\n", drm_device_path(),
            g_drm_fd);

    res = drmModeGetResources(g_drm_fd);
    if (res == NULL) {
        fprintf(stderr, "[raster-debug] drmModeGetResources failed: %s\n",
                strerror(errno));
        goto fail;
    }
    for (i = 0; i < res->count_connectors; ++i) {
        conn = drmModeGetConnector(g_drm_fd, res->connectors[i]);
        if (conn != NULL && conn->connection == DRM_MODE_CONNECTED &&
            conn->count_modes > 0) {
            break;
        }
        if (conn != NULL) {
            drmModeFreeConnector(conn);
            conn = NULL;
        }
    }
    if (conn == NULL || conn->encoder_id == 0u) {
        fprintf(stderr, "[raster-debug] no connected connector with an "
                        "encoder found\n");
        goto fail;
    }
    fprintf(stderr, "[raster-debug] using connector %u, mode %dx%d\n",
            conn->connector_id, conn->modes[0].hdisplay,
            conn->modes[0].vdisplay);
    enc = drmModeGetEncoder(g_drm_fd, conn->encoder_id);
    if (enc == NULL || enc->crtc_id == 0u) {
        fprintf(stderr, "[raster-debug] encoder has no crtc\n");
        goto fail;
    }
    g_connector_id = conn->connector_id;

    /* Save the CRTC's current state so gem_raster_shutdown can restore
     * it exactly, leaving the console/compositor state untouched. */
    g_saved_crtc = drmModeGetCrtc(g_drm_fd, enc->crtc_id);
    if (g_saved_crtc == NULL) {
        fprintf(stderr, "[raster-debug] drmModeGetCrtc (save) failed: %s\n",
                strerror(errno));
        goto fail;
    }

    /* width/height 0 (or oversized) -> use the connector's current mode,
     * matching the Linux backend's "0 means fill the device" contract. */
    if (width == 0u || width > conn->modes[0].hdisplay) {
        width = (uint16_t)conn->modes[0].hdisplay;
    }
    if (height == 0u || height > conn->modes[0].vdisplay) {
        height = (uint16_t)conn->modes[0].vdisplay;
    }
    if (width == 0u || height == 0u) {
        fprintf(stderr, "[raster-debug] resolved width/height still 0\n");
        errno = ENOTSUP;
        goto fail;
    }

    memset(&creq, 0, sizeof(creq));
    creq.width = width;
    creq.height = height;
    creq.bpp = 32u;
    if (drmIoctl(g_drm_fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq) < 0) {
        fprintf(stderr, "[raster-debug] CREATE_DUMB failed: %s\n",
                strerror(errno));
        goto fail;
    }
    g_dumb_handle = creq.handle;
    g_dumb_pitch = creq.pitch;
    g_dumb_size = creq.size;
    fprintf(stderr, "[raster-debug] dumb buffer: handle=%u pitch=%u size=%llu\n",
            creq.handle, creq.pitch, (unsigned long long)creq.size);

    memset(&mreq, 0, sizeof(mreq));
    mreq.handle = creq.handle;
    if (drmIoctl(g_drm_fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq) < 0) {
        fprintf(stderr, "[raster-debug] MAP_DUMB failed: %s\n",
                strerror(errno));
        goto fail;
    }
    g_dumb_pixels = mmap(NULL, g_dumb_size, PROT_READ | PROT_WRITE,
                         MAP_SHARED, g_drm_fd, (off_t)mreq.offset);
    if (g_dumb_pixels == MAP_FAILED) {
        fprintf(stderr, "[raster-debug] mmap failed: %s\n", strerror(errno));
        g_dumb_pixels = NULL;
        goto fail;
    }
    memset(g_dumb_pixels, 0, g_dumb_size);

    if (drmModeAddFB(g_drm_fd, creq.width, creq.height, 24, 32, creq.pitch,
                     creq.handle, &g_fb_id) < 0) {
        fprintf(stderr, "[raster-debug] drmModeAddFB failed: %s\n",
                strerror(errno));
        goto fail;
    }
    fprintf(stderr, "[raster-debug] added fb id %u, calling drmModeSetCrtc...\n",
            g_fb_id);
    if (drmModeSetCrtc(g_drm_fd, enc->crtc_id, g_fb_id, 0, 0, &g_connector_id,
                       1, &conn->modes[0]) < 0) {
        fprintf(stderr, "[raster-debug] drmModeSetCrtc failed: %s\n",
                strerror(errno));
        goto fail;
    }
    fprintf(stderr, "[raster-debug] drmModeSetCrtc succeeded\n");

    pitch = ((size_t)width + 7u) / 8u;
    if (pitch > UINT16_MAX) {
        fprintf(stderr, "[raster-debug] pitch overflow\n");
        errno = EOVERFLOW;
        goto fail;
    }
    shadow_size = pitch * (size_t)height;
    g_surface.pixels = calloc(1u, shadow_size);
    if (g_surface.pixels == NULL) {
        fprintf(stderr, "[raster-debug] shadow buffer calloc failed\n");
        goto fail;
    }
    g_surface.width = width;
    g_surface.height = height;
    g_surface.pitch = (uint16_t)pitch;
    g_surface.format = format;
    ok = 1;
    fprintf(stderr, "[raster-debug] gem_raster_init SUCCEEDED: %ux%u pitch=%u\n",
            g_surface.width, g_surface.height, g_surface.pitch);

fail:
    if (!ok) {
        fprintf(stderr, "[raster-debug] gem_raster_init FAILED\n");
    }
    if (enc != NULL) {
        drmModeFreeEncoder(enc);
    }
    if (conn != NULL) {
        drmModeFreeConnector(conn);
    }
    if (res != NULL) {
        drmModeFreeResources(res);
    }
    if (!ok) {
        /* Only restore the CRTC if we actually changed it (g_fb_id set). */
        teardown_drm(g_fb_id != 0u);
    }
    return ok;
}

int gem_raster_resync(void)
{
    return g_surface.pixels != NULL && g_dumb_pixels != NULL;
}

void gem_raster_shutdown(void)
{
    teardown_drm(1);
    free(g_surface.pixels);
    memset(&g_surface, 0, sizeof(g_surface));
    g_dumb_pitch = 0u;
    g_power_cycled_after_first_content = 0;
}

gem_raster_surface_t *gem_raster_surface(void)
{
    return (g_surface.pixels != NULL) ? &g_surface : NULL;
}

void gem_raster_present_rect(int x, int y, int width, int height)
{
    const uint8_t *source = g_surface.pixels;
    int x0;
    int y0;
    int64_t x1;
    int64_t y1;
    int row_y;
    static unsigned long call_count;
    unsigned long set_bits = 0;
    unsigned long clear_bits = 0;
    int verbose;

    ++call_count;
    verbose = (call_count <= 5 || (call_count >= 25 && call_count <= 35) ||
               call_count % 200 == 0);
    if (verbose) {
        fprintf(stderr,
                "[raster-debug] present_rect call #%lu: x=%d y=%d w=%d h=%d "
                "source=%p dumb=%p\n",
                call_count, x, y, width, height, (const void *)source,
                (const void *)g_dumb_pixels);
    }

    if (source == NULL || g_dumb_pixels == NULL || width <= 0 || height <= 0) {
        return;
    }

    x0 = x;
    y0 = y;
    x1 = (int64_t)x + width - 1;
    y1 = (int64_t)y + height - 1;
    if (x0 < 0) {
        x0 = 0;
    }
    if (y0 < 0) {
        y0 = 0;
    }
    if (x1 >= (int)g_surface.width) {
        x1 = (int)g_surface.width - 1;
    }
    if (y1 >= (int)g_surface.height) {
        y1 = (int)g_surface.height - 1;
    }
    if (x0 > x1 || y0 > y1) {
        return;
    }

    for (row_y = y0; row_y <= y1; ++row_y) {
        uint32_t *dst_row =
            (uint32_t *)(g_dumb_pixels + (size_t)row_y * g_dumb_pitch);
        const uint8_t *src_row = source + (size_t)row_y * g_surface.pitch;
        int col_x;

        for (col_x = x0; col_x <= x1; ++col_x) {
            uint8_t bits = src_row[col_x / 8];
            int bit_set = (bits & (uint8_t)(0x80u >> (col_x & 7))) != 0u;

            if (bit_set) {
                ++set_bits;
            } else {
                ++clear_bits;
            }
            dst_row[col_x] = shadow_bit_to_xrgb8888(bit_set);
        }
    }

    if (verbose) {
        uint32_t *first_row = (uint32_t *)g_dumb_pixels;
        uint32_t readback_0 = first_row[0];
        uint32_t readback_mid =
            first_row[(size_t)g_surface.width / 2u];

        fprintf(stderr,
                "[raster-debug]   shadow bits in this rect: set(black)=%lu "
                "clear(white)=%lu\n",
                set_bits, clear_bits);
        fprintf(stderr,
                "[raster-debug]   dumb buffer readback: pixel[0]=0x%08x "
                "pixel[mid]=0x%08x\n",
                readback_0, readback_mid);
    }

    /*
     * Deferred, one-time power-cycle: every case that actually worked
     * this session had real content ALREADY written into the buffer
     * before a devctl power-cycle happened -- never before. Doing the
     * cycle during gem_raster_init() (before any real content exists)
     * was tested and confirmed NOT sufficient, regardless of retry
     * count or delay between retries. This tests the buffer-state
     * variable directly: cycle once, here, after the FIRST real write
     * has actually landed, then re-present the whole screen afterward
     * since the cycle likely blanks the display again.
     *
     * Refined further: cycling after just the FIRST write was still too
     * early -- every manual devctl success happened after gemd/desktop
     * had been running and drawing for a while (the full desktop UI
     * already up, cursor tracking already active), not right after the
     * very first write. Deferred to call #30 instead of call #1, giving
     * AES substantially more time to finish its real startup drawing
     * first.
     */
    if (!g_power_cycled_after_first_content && call_count >= 30u) {
        g_power_cycled_after_first_content = 1;
        fprintf(stderr,
                "[raster-debug] call #%lu -- now doing the deferred "
                "power-cycle (waited for real drawing activity, not just "
                "the first write)\n",
                call_count);
        power_cycle_gpu_device();
        fprintf(stderr,
                "[raster-debug] re-presenting the whole screen after the "
                "deferred power-cycle\n");
        gem_raster_present();
    }
}

void gem_raster_present(void)
{
    if (g_surface.pixels == NULL) {
        return;
    }
    gem_raster_present_rect(0, 0, (int)g_surface.width, (int)g_surface.height);
}

void gem_raster_clear(void)
{
    if (g_surface.pixels != NULL) {
        size_t shadow_size = (size_t)g_surface.pitch * g_surface.height;

        memset(g_surface.pixels, 0, shadow_size);
    }
    if (g_dumb_pixels != NULL && g_dumb_size != 0u) {
        memset(g_dumb_pixels, 0, g_dumb_size);
    }
}

void gem_raster_set_palette(uint8_t index, uint8_t red, uint8_t green,
                            uint8_t blue)
{
    /* MONO1 is the only format this backend accepts (see gem_raster_init);
     * matches the Linux backend's own no-op stub for the same reason. */
    (void)index;
    (void)red;
    (void)green;
    (void)blue;
}
