#pragma once

// C shim — Header Search Paths includes $(SRCROOT)/../.. (repo root)
#include <core/shim/vd.h>

// Odin core (core/squeeze.odin)
const char* squeeze_version(void);
int squeeze_add(int a, int b);
