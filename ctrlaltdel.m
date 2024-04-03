/* ctrlaltdel.m (https://github.com/takeiteasy/tools) (Mac only)
 Description: Monitor key presses and open Activity Monitor when
              ctrl,alt+del has been pressed. Like windows
 Build: clang ctrlaltdel.m -o ctrlaltdel -framework Carbon -framework AppKit
 
 The MIT License (MIT)

 Copyright (c) 2024 George Watson

 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge,
 publish, distribute, sublicense, and/or sell copies of the Software,
 and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#include <Carbon/Carbon.h>
#include <AppKit/AppKit.h>

static CFMachPortRef tap = nil;

static int CheckPrivileges(void) {
    const void *keys[] = { kAXTrustedCheckOptionPrompt };
    const void *values[] = { kCFBooleanTrue };
    CFDictionaryRef options = CFDictionaryCreate(kCFAllocatorDefault,
                                                 keys, values, sizeof(keys) / sizeof(*keys),
                                                 &kCFCopyStringDictionaryKeyCallBacks,
                                                 &kCFTypeDictionaryValueCallBacks);
    int result = AXIsProcessTrustedWithOptions(options);
    CFRelease(options);
    if (!result) {
        fprintf(stderr, "ERROR: Process requires accessibility permissions\n");
        return 2;
    }
    return 0;
}

typedef enum {
    MOD_SHIFT     = 1 << 0,
    MOD_CONTROL   = 1 << 1,
    MOD_ALT       = 1 << 2,
    MOD_SUPER     = 1 << 3
} KeyModifier;

static const int CtrlAlt = MOD_CONTROL | MOD_ALT;

static unsigned int ConvertMacMod(unsigned int flags) {
    int result = 0;
    if (flags & kCGEventFlagMaskShift)
        result |= MOD_SHIFT;
    if (flags & kCGEventFlagMaskControl)
        result |= MOD_CONTROL;
    if (flags & kCGEventFlagMaskAlternate)
        result |= MOD_ALT;
    if (flags & kCGEventFlagMaskCommand)
        result |= MOD_SUPER;
    return result;
}

static long AlreadyOpened(void) {
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
    for (int i = 0; i < CFArrayGetCount(windowList); i++) {
        NSDictionary *dict = CFArrayGetValueAtIndex(windowList, i);
        NSString *parentName = (NSString*)[dict objectForKey:@"kCGWindowOwnerName"];
        if ([parentName isEqualToString:@"Activity Monitor"])
            return [(NSNumber*)[dict objectForKey:@"kCGWindowOwnerPID"] integerValue];
    }
    return 0;
}

static CGEventRef EventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *ref) {
    int action = 0;
    switch (type) {
        case kCGEventKeyDown: {
            uint32_t flags = (uint32_t)CGEventGetFlags(event);
            uint16_t keycode = (uint16_t)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
            uint32_t mods = ConvertMacMod(flags);
            if (keycode == kVK_ForwardDelete && mods == CtrlAlt) {
                pid_t pid = (pid_t)AlreadyOpened();
                if (pid) {
                    AXUIElementRef axWindows = AXUIElementCreateApplication(pid);
                    NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
                    [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
                    AXUIElementPerformAction(axWindows, kAXRaiseAction);
                } else {
                    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
                    NSURL *url = [NSURL fileURLWithPath:[workspace fullPathForApplication:@"Activity Monitor"]];
                    NSError *error = nil;
                    [workspace launchApplicationAtURL:url
                                              options:0
                                        configuration:[NSDictionary dictionaryWithObject:@[]
                                                                                  forKey:NSWorkspaceLaunchConfigurationArguments]
                                                error:&error];
                    if (error) {
                        fprintf(stderr, "%s\n", [[error localizedDescription] UTF8String]);
                        assert(0);
                    }
                }
            }
            break;
        }
        case kCGEventTapDisabledByTimeout:
        case kCGEventTapDisabledByUserInput:
            CGEventTapEnable(tap, 1);
        default:
            break;
    }
    return action ? NULL : event;
}

int main(int argc, const char *argv[]) {
    int error = CheckPrivileges();
    if (error)
        return error;
    
    tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, kCGEventMaskForAllEvents, EventCallback, NULL);
    assert(tap);
    CFRunLoopSourceRef loop = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
    CGEventTapEnable(tap, 1);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), loop, kCFRunLoopCommonModes);
    CFRunLoopRun();
    return 0;
}
