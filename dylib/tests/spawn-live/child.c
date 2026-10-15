// Prints its own environment so the caller can see whether the insert reached it.
#include <stdio.h>
extern char **environ;
int main(void) { for (int i = 0; environ[i]; i++) puts(environ[i]); return 0; }
