/*
 * gem-freebsd-cursor-render Stage E: isolates whether repeated writes to
 * a SMALL region (matching gemd's real cursor-update size, ~17x17) also
 * cause the black-screen symptom, or whether it's specifically the
 * full-buffer repeated rewrite (Stage D) that does. The background is
 * written ONCE (matching Stage C's already-proven-working single fill),
 * then only a small moving square is repeatedly rewritten afterward --
 * this is a much closer match to gemd's actual captured workload (two
 * full-screen writes at startup, then almost entirely 17x17 rects).
 *
 * Usage: ./drm-stage-e /dev/drm/0
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
    int frame;
    uint32_t pitch_pixels;

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

    saved_crtc = drmModeGetCrtc(fd, enc->crtc_id);
    if (saved_crtc == NULL) {
        fprintf(stderr, "drmModeGetCrtc (save) failed: %s\n",
                strerror(errno));
        goto out;
    }

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
    pitch_pixels = creq.pitch / 4u;

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

    /* ONE-TIME background fill, matching Stage C's already-proven
     * single-write pattern -- solid mid-gray. */
    {
        uint32_t *pixels = (uint32_t *)map;
        uint32_t count = creq.size / 4u;
        uint32_t j;

        for (j = 0; j < count; ++j) {
            pixels[j] = 0x00808080u;
        }
    }
    printf("wrote one-time solid gray background\n");

    rc = drmModeAddFB(fd, creq.width, creq.height, 24, 32, creq.pitch,
                       creq.handle, &fb_id);
    if (rc < 0) {
        fprintf(stderr, "drmModeAddFB failed: %s\n", strerror(errno));
        goto destroy_dumb;
    }
    printf("added framebuffer id %u\n", fb_id);

    rc = drmModeSetCrtc(fd, enc->crtc_id, fb_id, 0, 0, &conn->connector_id, 1,
                         &conn->modes[0]);
    if (rc < 0) {
        fprintf(stderr, "drmModeSetCrtc failed: %s\n", strerror(errno));
        goto remove_fb;
    }
    printf("drmModeSetCrtc succeeded, now repeatedly writing only a 17x17 "
           "moving square for ~10s (matching gemd's real cursor-update "
           "size)...\n");

    /* Repeatedly rewrite only a small, moving 17x17 square -- matching
     * gemd's real captured workload much more closely than Stage D's
     * full-buffer rewrite. */
    for (frame = 0; frame < 500; ++frame) {
        uint32_t *pixels = (uint32_t *)map;
        uint32_t color = (frame % 2 == 0) ? 0x00ff0000u : 0x000000ffu;
        int x0 = 100 + (frame % 40) * 20;
        int y0 = 100 + (frame % 20) * 10;
        int dx, dy;

        for (dy = 0; dy < 17; ++dy) {
            for (dx = 0; dx < 17; ++dx) {
                int x = x0 + dx;
                int y = y0 + dy;

                if (x < (int)creq.width && y < (int)creq.height) {
                    pixels[(size_t)y * pitch_pixels + (size_t)x] = color;
                }
            }
        }
        if (frame % 50 == 0) {
            printf("frame %d: wrote 17x17 square at (%d,%d) color 0x%08x\n",
                   frame, x0, y0, color);
        }
        usleep(20000);
    }

    printf("done writing, restoring original crtc state...\n");
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
