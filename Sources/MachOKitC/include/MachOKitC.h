//
//  MachOKitC.h
//  MachOKitC
//
//  The module's umbrella header: every header in this directory, and a new
//  one goes here too (MachOKitCUmbrellaHeaderTests checks).
//
//  Without it, SwiftPM and Tuist give the module the whole directory as its
//  umbrella. A header added to the directory then changes no file a
//  prebuilt module recorded, so Xcode keeps reusing the module built before
//  it and Swift reports the new declarations as not in scope. Listing the
//  header here edits this file, which rebuilds the module.
//

#ifndef MACHOKIT_C_H
#define MACHOKIT_C_H

#include "aot_cache.h"
#include "backports.h"
#include "codesign.h"
#include "core_foundation.h"
#include "dyld_cache.h"
#include "dyld_cache_format.h"
#include "dyld_cache_loader.h"
#include "fixup-chains.h"
#include "lazy-load-dylib.h"
#include "mach-o.h"
#include "objc.h"
#include "swift.h"
#include "thread_state.h"

#endif
