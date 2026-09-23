/*
 * gem-freebsd-port Stage B: dumb-buffer allocation test.
 *
 * Purpose: confirm we can allocate a CPU-writable pixel buffer via DRM's
 * "dumb buffer" API on the Intel device and write test pixels into it.
 * Still makes NO display changes -- no drmModeSetCrtc, no master grab.
 * This is the mmap-a-pixel-buffer equivalent of what Linux's fbdev gave
 * GEM for free; on FreeBSD this is the real replacement mechanism.
 *
 * The struct layouts and ioctl numbers below are copied verbatim from
 * FreeBSD's own DRM uAPI header (sys/dev/drm2/drm_mode.h / drm.h,
 * confirmed via direct source read against cgit.freebsd.org) rather than
 * assumed from memory or guessed include paths -- this is the same
 * stable "dumb buffer" contract shared with Linux and unchanged since
 * introduced.
 *
 * Usage: ./drm-stage-b /dev/drm/0
 *
 * Same warning as Stage A: never point this at /dev/drm/1 on this
 * machine (the NVIDIA node, confirmed to panic the kernel when opened by
 * a DRM-aware client).
 */

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include <xf86drm.h>

/* Verified against FreeBSD's own sys/dev/drm2/drm_mode.h */
struct drm_mode_create_dumb {
    uint32_t height;
    uint32_t width;
    uint32_t bpp;
    uint32_t flags;
    /* handle, pitch, size are returned by the kernel */
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

/* Verified against FreeBSD's own sys/dev/drm2/drm.h */
#define DRM_IOCTL_MODE_CREATE_DUMB  DRM_IOWR(0xB2, struct drm_mode_create_dumb)
#define DRM_IOCTL_MODE_MAP_DUMB     DRM_IOWR(0xB3, struct drm_mode_map_dumb)
#define DRM_IOCTL_MODE_DESTROY_DUMB DRM_IOWR(0xB4, struct drm_mode_destroy_dumb)

int main(int argc, char **argv)
{
    int fd;
    struct drm_mode_create_dumb creq;
    struct drm_mode_map_dumb mreq;
    struct drm_mode_destroy_dumb dreq;
    void *map;
    int rc;

    if (argc != 2) {
        fprintf(stderr, "usage: %s /dev/drm/N\n", argv[0]);
        fprintf(stderr,
                "example (Intel, confirmed on this machine): %s "
                "/dev/drm/0\n",
                argv[0]);
        return 2;
    }

    printf("opening %s\n", argv[1]);
    fd = open(argv[1], O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "open(%s) failed: %s\n", argv[1], strerror(errno));
        return 1;
    }

    memset(&creq, 0, sizeof(creq));
    creq.width = 800;
    creq.height = 600;
    creq.bpp = 32;

    rc = drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq);
    if (rc < 0) {
        fprintf(stderr, "DRM_IOCTL_MODE_CREATE_DUMB failed: %s\n",
                strerror(errno));
        close(fd);
        return 1;
    }
    printf("created dumb buffer: handle=%u pitch=%u size=%llu\n",
           creq.handle, creq.pitch, (unsigned long long)creq.size);

    memset(&mreq, 0, sizeof(mreq));
    mreq.handle = creq.handle;
    rc = drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq);
    if (rc < 0) {
        fprintf(stderr, "DRM_IOCTL_MODE_MAP_DUMB failed: %s\n",
                strerror(errno));
        goto destroy;
    }

    map = mmap(NULL, creq.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd,
               (off_t)mreq.offset);
    if (map == MAP_FAILED) {
        fprintf(stderr, "mmap failed: %s\n", strerror(errno));
        goto destroy;
    }
    printf("mapped %llu bytes at %p\n", (unsigned long long)creq.size, map);

    /* Write a simple test pattern into memory only -- never presented to
     * the screen. Just confirms the mapping is genuinely writable. */
    memset(map, 0x55, creq.size);
    printf("wrote test pattern into the mapped buffer (in memory only, "
           "nothing displayed)\n");

    munmap(map, creq.size);
    printf("unmapped cleanly\n");

destroy:
    memset(&dreq, 0, sizeof(dreq));
    dreq.handle = creq.handle;
    rc = drmIoctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
    if (rc < 0) {
        fprintf(stderr, "DRM_IOCTL_MODE_DESTROY_DUMB failed: %s\n",
                strerror(errno));
    } else {
        printf("destroyed dumb buffer cleanly\n");
    }

    close(fd);
    printf("done, fd closed cleanly\n");
    return 0;
}
