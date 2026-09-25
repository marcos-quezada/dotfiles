/*
 * Minimal, standalone isolation test for posix_openpt/grantpt/unlockpt/
 * ptsname/fork/exec -- matching this project's established
 * "isolate before integrating" pattern, to determine exactly where
 * gem_os_pty_spawn_shell()'s own sequence fails, independent of any
 * other GEM code.
 */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void)
{
    int master_fd;
    char *slave_name;
    pid_t pid;

    master_fd = posix_openpt(O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (master_fd < 0) {
        fprintf(stderr, "posix_openpt failed: %s (errno=%d)\n",
                strerror(errno), errno);
        return 1;
    }
    fprintf(stderr, "posix_openpt OK, fd=%d\n", master_fd);

    if (grantpt(master_fd) != 0) {
        fprintf(stderr, "grantpt failed: %s (errno=%d)\n", strerror(errno),
                errno);
        return 1;
    }
    fprintf(stderr, "grantpt OK\n");

    if (unlockpt(master_fd) != 0) {
        fprintf(stderr, "unlockpt failed: %s (errno=%d)\n", strerror(errno),
                errno);
        return 1;
    }
    fprintf(stderr, "unlockpt OK\n");

    slave_name = ptsname(master_fd);
    if (slave_name == NULL) {
        fprintf(stderr, "ptsname failed: %s (errno=%d)\n", strerror(errno),
                errno);
        return 1;
    }
    fprintf(stderr, "ptsname OK: %s\n", slave_name);

    pid = fork();
    if (pid < 0) {
        fprintf(stderr, "fork failed: %s (errno=%d)\n", strerror(errno),
                errno);
        return 1;
    }
    if (pid == 0) {
        int slave_fd = open(slave_name, O_RDWR);

        if (slave_fd < 0) {
            fprintf(stderr, "child: open(%s) failed: %s (errno=%d)\n",
                    slave_name, strerror(errno), errno);
            _exit(127);
        }
        fprintf(stderr, "child: opened slave fd=%d, execing /bin/sh\n",
                slave_fd);
        execl("/bin/sh", "/bin/sh", "-c", "echo hello from shell; exit 0",
              (char *)NULL);
        fprintf(stderr, "child: execl failed: %s (errno=%d)\n",
                strerror(errno), errno);
        _exit(127);
    }

    int status;
    waitpid(pid, &status, 0);
    fprintf(stderr, "parent: child exited, status=%d\n", status);
    return 0;
}
