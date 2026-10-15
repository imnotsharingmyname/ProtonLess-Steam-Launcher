#ifndef NP_OVERLAY_TEST_CHECK_H
#define NP_OVERLAY_TEST_CHECK_H

#include <stdio.h>

#define NP_SKIP 3

#define CHECK(cond, ...)                     \
	do {                                 \
		if (!(cond)) {               \
			printf("FAIL: ");    \
			printf(__VA_ARGS__); \
			printf("\n");        \
			return 1;            \
		}                            \
	} while (0)

#define SKIP_IF(cond, ...)                   \
	do {                                 \
		if (cond) {                  \
			printf("SKIP: ");    \
			printf(__VA_ARGS__); \
			printf("\n");        \
			return NP_SKIP;      \
		}                            \
	} while (0)

#endif
