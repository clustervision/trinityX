#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

int main (int argc, char *argv[]) {
    char cmd[50], uid[6];

    if (argc == 2 && strcmp(argv[1], "clean") == 0)
        strcpy(cmd, "/usr/local/bin/mpi-dclean");
    else
        strcpy(cmd, "/usr/local/bin/mpi-drun.sh");

    sprintf(uid, " %d", getuid());
    strcat(cmd, uid);

    setuid(0);
    system(cmd);

    return 0;
}

