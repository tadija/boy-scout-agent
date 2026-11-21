#ifndef BSA_PROCESS_SUPPORT_H
#define BSA_PROCESS_SUPPORT_H
#include <sys/types.h>
// Returns a POSIX error number, or zero and the child PID on success.
int bsa_spawn(const char *executable, char *const argv[], char *const envp[],
              const char *cwd, int input_fd, int output_fd, pid_t *child);
#endif
