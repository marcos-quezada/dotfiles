/*
 * Standalone, minimal libseat isolation test -- matching this project's
 * proven "isolate before integrating" pattern from the DRM stage-a/b/c
 * tests (gem-freebsd-port) before touching raster.c/hid.c themselves.
 *
 * Deliberately does the absolute minimum: open a seat, print its name,
 * open exactly one device via the seat (the DRM device, since that's
 * the higher-risk one given the earlier confirmed DRM-master/VT-switch
 * hang incident), then close everything down cleanly.
 *
 * SAFETY: takes the DRM device path as a REQUIRED command-line argument,
 * same rule as every drm-stage-*.c test in gem-freebsd-port -- never
 * default/auto-probe a device path. This machine has a second DRM node
 * (NVIDIA) confirmed to kernel-panic when opened by any DRM-aware
 * client.
 *
 * Usage: ./libseat-stage-a /dev/drm/0
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <libseat.h>

static int g_enabled;
static int g_got_disable;

static void on_enable_seat(struct libseat *seat, void *userdata)
{
    (void)seat;
    (void)userdata;
    fprintf(stderr, "[libseat-stage-a] enable_seat callback fired\n");
    g_enabled = 1;
}

static void on_disable_seat(struct libseat *seat, void *userdata)
{
    (void)userdata;
    fprintf(stderr, "[libseat-stage-a] disable_seat callback fired -- "
                    "acknowledging immediately\n");
    g_got_disable = 1;
    g_enabled = 0;
    /*
     * Per libseat.h's own doc comment: this MUST be acknowledged
     * shortly after receiving the event, or the seat provider may
     * forcibly revoke devices. Confirmed as a real, load-bearing
     * contract detail, not optional cleanup.
     */
    if (libseat_disable_seat(seat) != 0) {
        fprintf(stderr,
                "[libseat-stage-a] libseat_disable_seat failed: %s\n",
                strerror(errno));
    }
}

int main(int argc, char **argv)
{
    static const struct libseat_seat_listener listener = {
        .enable_seat = on_enable_seat,
        .disable_seat = on_disable_seat,
    };
    struct libseat *seat;
    const char *device_path;
    int device_id;
    int fd = -1;
    int seat_fd;
    int ret;

    if (argc != 2) {
        fprintf(stderr,
                "usage: %s /dev/drm/N   (REQUIRED, no default -- this "
                "machine has a second DRM node confirmed to panic the "
                "kernel if opened)\n",
                argv[0]);
        return 2;
    }
    device_path = argv[1];

    seat = libseat_open_seat(&listener, NULL);
    if (seat == NULL) {
        fprintf(stderr, "libseat_open_seat failed: %s\n", strerror(errno));
        return 1;
    }
    fprintf(stderr, "[libseat-stage-a] seat opened, name=%s\n",
            libseat_seat_name(seat));

    /*
     * enable_seat may fire synchronously inside libseat_open_seat, or
     * may require a dispatch first, depending on backend. Give it one
     * chance to dispatch before assuming it's not coming.
     */
    seat_fd = libseat_get_fd(seat);
    if (seat_fd < 0) {
        fprintf(stderr, "libseat_get_fd failed: %s\n", strerror(errno));
        goto cleanup;
    }
    if (!g_enabled) {
        ret = libseat_dispatch(seat, 1000);
        fprintf(stderr,
                "[libseat-stage-a] initial dispatch returned %d, "
                "g_enabled=%d\n",
                ret, g_enabled);
    }

    device_id = libseat_open_device(seat, device_path, &fd);
    if (device_id < 0) {
        fprintf(stderr, "libseat_open_device(%s) failed: %s\n", device_path,
                strerror(errno));
        goto cleanup;
    }
    fprintf(stderr,
            "[libseat-stage-a] opened %s via seat: device_id=%d fd=%d\n",
            device_path, device_id, fd);

    /*
     * Deliberately do NOT call any DRM-mode-setting ioctl here (no
     * drmModeSetCrtc, no drmSetMaster) -- this test is purely about
     * confirming libseat's own open/close lifecycle works, not about
     * re-testing DRM mode-setting, which is already proven in
     * gem-freebsd-port's Stage A/B/C tests.
     */
    sleep(2);

    fprintf(stderr, "[libseat-stage-a] closing device...\n");
    if (libseat_close_device(seat, device_id) != 0) {
        fprintf(stderr, "libseat_close_device failed: %s\n", strerror(errno));
    }

cleanup:
    fprintf(stderr, "[libseat-stage-a] closing seat...\n");
    if (libseat_close_seat(seat) != 0) {
        fprintf(stderr, "libseat_close_seat failed: %s\n", strerror(errno));
        return 1;
    }
    fprintf(stderr, "[libseat-stage-a] clean shutdown, got_disable=%d\n",
            g_got_disable);
    return 0;
}
