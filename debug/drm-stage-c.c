/*
 * gem-freebsd-port Stage C: mode-set test (the real display-touching step).
 *
 * Purpose: confirm we can actually push a dumb buffer to the screen via
 * drmModeSetCrtc, hold it briefly, then restore the original CRTC state
 * cleanly -- this is the last piece raster.c's FreeBSD backend needs
 * (open -> allocate buffer -> present it -> tear down).
 *
 * SAFETY:
 *  - Only run this from a plain vt console (Ctrl+Alt+F<n> to a text tty),
 *    NOT from inside an active Sway session. Sway already holds DRM
 *    master; competing for it from here is exactly the scenario we're
 *    trying to avoid.
 *  - This program deliberately saves the original CRTC config with
 *    drmModeGetCrtc BEFORE changing anything, and restores it in the
 *    same run before exiting -- including on early-exit error paths.
 *  - If anything looks wrong after it exits, switch to a different vt
 *    (Ctrl+Alt+F<n>) and back -- that forces a repaint. Full reboot is
 *    always available as a last resort; nothing here persists past a
 *    reboot regardless (see the loader.conf-driven font discussion).
 *
 * Usage: ./drm-stage-c /dev/drm/0
 * Never point this at /dev/drm/1 on this machine (NVIDIA, confirmed to
 * panic the kernel when opened by a DRM-aware client).
 */

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include <xf86drm.h>
#include <xf86drmMode.h>

/* Verified against FreeBSD's own sys/dev/drm2/drm_mode.h / drm.h */
struct drm_mode_create_dumb {
    uint32_t height;
    uint32_t width;
    uint32_t bpp;
    uint32_t flags;
    uint32_t handle;
    uint32_t pitch;
    uint64_t size;
};

struct drm_mode_map_dumb {
    uint32_t handle;
    uint32_t pad;
    uint64_t offset;
};

struct drm_mode_destroy_dumb {
    uint32_t handle;
};

#define DRM_IOCTL_MODE_CREATE_DUMB  DRM_IOWR(0xB2, struct drm_mode_create_dumb)
#define DRM_IOCTL_MODE_MAP_DUMB     DRM_IOWR(0xB3, struct drm_mode_map_dumb)
#define DRM_IOCTL_MODE_DESTROY_DUMB DRM_IOWR(0xB4, struct drm_mode_destroy_dumb)

int main(int argc, char **argv)
{
    int fd;
    drmModeResPtr res = NULL;
    drmModeConnectorPtr conn = NULL;
    drmModeEncoderPtr enc = NULL;
    drmModeCrtcPtr saved_crtc = NULL;
    struct drm_mode_create_dumb creq;
    struct drm_mode_map_dumb mreq;
    struct drm_mode_destroy_dumb dreq;
    void *map = NULL;
    uint32_t fb_id = 0;
    int i, rc, ret = 1;
    int have_dumb = 0;

    if (argc != 2) {
        fprintf(stderr, "usage: %s /dev/drm/N\n", argv[0]);
        return 2;
    }

    fd = open(argv[1], O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "open(%s) failed: %s\n", argv[1], strerror(errno));
        return 1;
    }

    res = drmModeGetResources(fd);
    if (res == NULL) {
        fprintf(stderr, "drmModeGetResources failed: %s\n", strerror(errno));
        goto out;
    }

    /* Find the first connected connector with at least one mode. */
    for (i = 0; i < res->count_connectors; ++i) {
        conn = drmModeGetConnector(fd, res->connectors[i]);
        if (conn != NULL && conn->connection == DRM_MODE_CONNECTED &&
            conn->count_modes > 0) {
            break;
        }
        if (conn != NULL) {
            drmModeFreeConnector(conn);
            conn = NULL;
        }
    }
    if (conn == NULL) {
        fprintf(stderr, "no connected connector with a mode found\n");
        goto out;
    }
    printf("using connector %u, mode %dx%d\n", conn->connector_id,
           conn->modes[0].hdisplay, conn->modes[0].vdisplay);

    if (conn->encoder_id == 0) {
        fprintf(stderr, "connector has no current encoder\n");
        goto out;
    }
    enc = drmModeGetEncoder(fd, conn->encoder_id);
    if (enc == NULL || enc->crtc_id == 0) {
        fprintf(stderr, "encoder has no current crtc\n");
        goto out;
    }
    printf("using crtc %u\n", enc->crtc_id);

    /* Save the CRTC's current state so we can restore it exactly. */
    saved_crtc = drmModeGetCrtc(fd, enc->crtc_id);
    if (saved_crtc == NULL) {
        fprintf(stderr, "drmModeGetCrtc (save) failed: %s\n",
                strerror(errno));
        goto out;
    }
    printf("saved original crtc state (mode %ux%u, fb %u) for restore\n",
           saved_crtc->width, saved_crtc->height, saved_crtc->buffer_id);

    /* Allocate a dumb buffer sized to the mode we're about to set. */
    memset(&creq, 0, sizeof(creq));
    creq.width = (uint32_t)conn->modes[0].hdisplay;
    creq.height = (uint32_t)conn->modes[0].vdisplay;
    creq.bpp = 32;
    rc = drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq);
    if (rc < 0) {
        fprintf(stderr, "DRM_IOCTL_MODE_CREATE_DUMB failed: %s\n",
                strerror(errno));
        goto out;
    }
    have_dumb = 1;

    memset(&mreq, 0, sizeof(mreq));
    mreq.handle = creq.handle;
    rc = drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq);
    if (rc < 0) {
        fprintf(stderr, "DRM_IOCTL_MODE_MAP_DUMB failed: %s\n",
                strerror(errno));
        goto destroy_dumb;
    }

    map = mmap(NULL, creq.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd,
               (off_t)mreq.offset);
    if (map == MAP_FAILED) {
        fprintf(stderr, "mmap failed: %s\n", strerror(errno));
        map = NULL;
        goto destroy_dumb;
    }

    /* Fill with a plain solid color (mid-gray) -- deliberately boring,
     * so it's obviously our test buffer and not mistaken for anything
     * else on screen. XRGB8888: 0x00 alpha byte, then R,G,B. */
    {
        uint32_t *pixels = (uint32_t *)map;
        uint32_t count = creq.size / 4;
        uint32_t j;
        for (j = 0; j < count; ++j) {
            pixels[j] = 0x00808080u;
        }
    }
    printf("filled buffer with solid gray test pattern\n");

    rc = drmModeAddFB(fd, creq.width, creq.height, 24, 32, creq.pitch,
                       creq.handle, &fb_id);
    if (rc < 0) {
        fprintf(stderr, "drmModeAddFB failed: %s\n", strerror(errno));
        goto destroy_dumb;
    }
    printf("added framebuffer id %u\n", fb_id);

    printf("setting crtc %u to show the test pattern for 3 seconds...\n",
           enc->crtc_id);
    rc = drmModeSetCrtc(fd, enc->crtc_id, fb_id, 0, 0, &conn->connector_id, 1,
                         &conn->modes[0]);
    if (rc < 0) {
        fprintf(stderr, "drmModeSetCrtc (test pattern) failed: %s\n",
                strerror(errno));
        goto remove_fb;
    }

    sleep(3);

    printf("restoring original crtc state...\n");
    rc = drmModeSetCrtc(fd, saved_crtc->crtc_id, saved_crtc->buffer_id,
                         saved_crtc->x, saved_crtc->y, &conn->connector_id, 1,
                         &saved_crtc->mode);
    if (rc < 0) {
        fprintf(stderr,
                "drmModeSetCrtc (restore) failed: %s -- switch to another "
                "vt and back to force a repaint\n",
                strerror(errno));
    } else {
        printf("restored cleanly\n");
        ret = 0;
    }

remove_fb:
    if (fb_id != 0) {
        drmModeRmFB(fd, fb_id);
    }

destroy_dumb:
    if (map != NULL) {
        munmap(map, creq.size);
    }
    if (have_dumb) {
        memset(&dreq, 0, sizeof(dreq));
        dreq.handle = creq.handle;
        drmIoctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
    }

out:
    if (saved_crtc != NULL) {
        drmModeFreeCrtc(saved_crtc);
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
    close(fd);
    printf("done, fd closed cleanly\n");
    return ret;
}
