/*
 * gem-freebsd-cursor-render Stage G: a read-only "observer" -- queries
 * the CURRENT state of crtc 51 from a SEPARATE, independently-opened fd,
 * while gemd is still running and holding the device. This asks the
 * kernel directly "what do you think is actually configured right now",
 * independent of anything gemd's own process believes about itself.
 *
 * Run this WHILE gemd is running (after its own drmModeSetCrtc has
 * already succeeded), from a second terminal/SSH session.
 *
 * Usage: ./drm-stage-g /dev/drm/0
 */

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <xf86drm.h>
#include <xf86drmMode.h>

int main(int argc, char **argv)
{
    int fd;
    drmModeResPtr res = NULL;
    int i;

    if (argc != 2) {
        fprintf(stderr, "usage: %s /dev/drm/N\n", argv[0]);
        return 2;
    }

    fd = open(argv[1], O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "open(%s) failed: %s\n", argv[1], strerror(errno));
        return 1;
    }
    printf("opened %s as a second, independent fd (fd=%d)\n", argv[1], fd);

    res = drmModeGetResources(fd);
    if (res == NULL) {
        fprintf(stderr, "drmModeGetResources failed: %s\n", strerror(errno));
        close(fd);
        return 1;
    }

    printf("\n--- querying every CRTC's actual current state ---\n");
    for (i = 0; i < res->count_crtcs; ++i) {
        drmModeCrtcPtr crtc = drmModeGetCrtc(fd, res->crtcs[i]);

        if (crtc == NULL) {
            printf("crtc %u: drmModeGetCrtc failed: %s\n", res->crtcs[i],
                   strerror(errno));
            continue;
        }
        printf("crtc %u:\n", crtc->crtc_id);
        printf("  buffer_id (currently scanned-out fb): %u\n",
               crtc->buffer_id);
        printf("  x=%d y=%d\n", crtc->x, crtc->y);
        printf("  width=%u height=%u\n", crtc->width, crtc->height);
        printf("  mode_valid=%d\n", crtc->mode_valid);
        if (crtc->mode_valid) {
            printf("  mode: %dx%d @ %uHz, name=\"%s\"\n",
                   crtc->mode.hdisplay, crtc->mode.vdisplay,
                   crtc->mode.vrefresh, crtc->mode.name);
        }
        drmModeFreeCrtc(crtc);
    }

    printf("\n--- querying every connector's actual current state ---\n");
    for (i = 0; i < res->count_connectors; ++i) {
        drmModeConnectorPtr conn = drmModeGetConnector(fd, res->connectors[i]);

        if (conn == NULL) {
            continue;
        }
        printf("connector %u: type=%u connection=%s encoder_id=%u\n",
               conn->connector_id, conn->connector_type,
               conn->connection == DRM_MODE_CONNECTED    ? "connected"
               : conn->connection == DRM_MODE_DISCONNECTED ? "disconnected"
                                                            : "unknown",
               conn->encoder_id);
        drmModeFreeConnector(conn);
    }

    drmModeFreeResources(res);
    close(fd);
    printf("\ndone, fd closed cleanly (this was a read-only observer, "
           "gemd's own state should be completely undisturbed)\n");
    return 0;
}
