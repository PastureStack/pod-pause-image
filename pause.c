#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t exiting = 0;

static void reap_children(void) {
    int saved_errno = errno;
    while (waitpid(-1, NULL, WNOHANG) > 0) {
    }
    errno = saved_errno;
}

static void handle_signal(int signal_number) {
    if (signal_number == SIGTERM || signal_number == SIGINT) {
        exiting = 1;
    }
    reap_children();
}

int main(void) {
    struct sigaction action = {0};
    sigset_t blocked_signals;
    sigset_t previous_mask;

    sigemptyset(&blocked_signals);
    sigaddset(&blocked_signals, SIGTERM);
    sigaddset(&blocked_signals, SIGINT);
    sigaddset(&blocked_signals, SIGCHLD);
    if (sigprocmask(SIG_BLOCK, &blocked_signals, &previous_mask) < 0) {
        perror("sigprocmask");
        return EXIT_FAILURE;
    }

    sigemptyset(&action.sa_mask);
    action.sa_handler = handle_signal;
    action.sa_flags = SA_NOCLDSTOP;

    if (sigaction(SIGTERM, &action, NULL) < 0 ||
        sigaction(SIGINT, &action, NULL) < 0 ||
        sigaction(SIGCHLD, &action, NULL) < 0) {
        perror("sigaction");
        return EXIT_FAILURE;
    }

    while (!exiting) {
        sigsuspend(&previous_mask);
        reap_children();
    }

    if (sigprocmask(SIG_SETMASK, &previous_mask, NULL) < 0) {
        perror("sigprocmask");
        return EXIT_FAILURE;
    }

    reap_children();
    return EXIT_SUCCESS;
}
