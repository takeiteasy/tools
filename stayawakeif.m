/* stayawakeif.m (https://github.com/takeiteasy/stay-awake) (Mac only)
 
 Description:
 
   Simple daemon to block sleep if certain programs are running.
   Programs should be defined in a config file called ".stayawake.conf"
   The config path should be either in the home directory or in the same
   directory as the stayawakeif executable.
 
   The contents of the config should be the application name or the app
   bundle identifier on seperate lines.
 
 Build: clang stayawakeif.m -framework Cocoa -framework IOKit -framework Foundation -o stayawakeif
 
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

#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#import <Cocoa/Cocoa.h>
#include <getopt.h>

static IOPMAssertionID __aid;
static BOOL __blocking = NO;
static NSMutableDictionary *__blocklist = NULL;
static BOOL __verbose = NO;

#define LOG(MSG)            \
    if (__verbose)          \
        NSLog(@"%@", @(MSG))
#define LOGF(MSG, ...)      \
    if (__verbose)          \
        NSLog(MSG, __VA_ARGS__);

static struct option long_options[] = {
    {"verbose", no_argument, NULL, 'v'},
    {"help", no_argument, NULL, 'h'},
    {"interval", required_argument, NULL, 'i'},
    {"config", required_argument, NULL, 'c'},
    {NULL, 0, NULL, 0}
};

static void usage(void) {
    puts("usage: stayawakeif [options] &\n");
    puts("  https://github.com/takeiteasy/stay-awake\n");
    puts("  Description:");
    puts("    Simple daemon to block sleep if certain programs are running.");
    puts("    Programs should be defined in a config file called \".stayawake.conf\"");
    puts("    The config path should be either in the home directory or in the same");
    puts("    directory as the stayawakeif executable.");
    puts("    The contents of the config should be the application name or the app");
    puts("    bundle identifier on seperate lines.\n");
    puts("  Arguments:");
    puts("    -v/--verbose  --  Enable verbose logging");
    puts("    -h/--help  --  Print this message");
    puts("    -i/--interval  --  Set the sleep interval (in seconds) between checks");
    puts("                       (default: 1s)");
    puts("    -c/--config  --  Set path to config");
    exit(1);
}

static int BlockSleep(void) {
    if (__blocking)
        return 0;
    __blocking = YES;
    LOG(" * SLEEPING BLOCKED");
    static CFStringRef reasonForActivity = CFSTR("DON'T SLEEP!");
    return IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn, reasonForActivity, &__aid) == kIOReturnSuccess;
}

static void AllowSleep(void) {
    if (__blocking) {
        __blocking = NO;
        LOG(" * SLEEPING ALLOWED");
        IOPMAssertionRelease(__aid);
    }
}

static int CheckWindows(void) {
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
    for (int i = 0; i < CFArrayGetCount(windowList); i++) {
        NSDictionary *dict = CFArrayGetValueAtIndex(windowList, i);
        NSNumber *parentPID = (NSNumber*)[dict objectForKey:@"kCGWindowOwnerPID"];
        NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:(pid_t)[parentPID integerValue]];
        __block NSString *bundleID = app.bundleIdentifier;
        __block NSString *parentName = (NSString*)[dict objectForKey:@"kCGWindowOwnerName"];
        __block BOOL found = NO;
        [__blocklist enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSString *line = (NSString*)key;
            int isBundleID = [(NSNumber*)obj intValue];
#define CHECK(A, B)                                  \
    do {                                             \
        if ([(A) caseInsensitiveCompare:(B)]) {      \
            LOGF(@"\"%@\" FOUND IN BLACKLIST", (B)); \
            found = YES;                             \
            *stop = YES;                             \
        }                                            \
    } while(0);
            if (isBundleID) {
                CHECK(line, bundleID);
            } else {
                CHECK(line, parentName);
            }
        }];
        if (found)
            return 1;
    }
    return 0;
}

static int IsBundleIDValid(NSString *bundleID) {
    static NSString *pattern = @"^([a-z]{2,}|\\d{3})(\\.([a-z0-9]+))+$";
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    assert(regex);
    NSRange range = [regex rangeOfFirstMatchInString:bundleID
                                             options:0
                                               range:NSMakeRange(0, bundleID.length)];
    return range.location != NSNotFound && range.length == bundleID.length;
}

static int LoadConfig(const char *_path) {
    NSString *path = [NSString stringWithUTF8String:_path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        return 0;
    LOGF(@" * LOADING CONFIG FROM \"%@\"", path);
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    assert(fileHandle);
    
    NSData *buffer;
    NSString *line;
    while ((buffer = [fileHandle availableData]) && [buffer length]) {
        line = [[NSString alloc] initWithData:buffer
                                     encoding:NSUTF8StringEncoding];
        [__blocklist setObject:[NSNumber numberWithInt:IsBundleIDValid(line)]
                        forKey:line];
        LOGF(@" * \"%@\" ADDED TO BLOCKLIST", line);
        [fileHandle seekToEndOfFile];
    }
    [fileHandle closeFile];
    return 1;
}

int main(int argc, char **argv) {
    int opt;
    char* msg = NULL;
    extern char* optarg;
    extern int optopt;
    const char *configPath = NULL;
    unsigned int sleepInterval = 1;
    while ((opt = getopt_long(argc, argv, "vhi:c:", long_options, NULL)) != -1) {
        switch (opt) {
            case 'i':
                if (!(sleepInterval = (unsigned int)atoi(optarg)))
                    usage();
                break;
            case 'c':
                configPath = optarg;
                break;
            case 'v':
                __verbose = YES;
                break;
            case 'h':
                usage();
            case ':':
                fprintf(stderr, "ERROR: \"-%c\" requires a value!\n", optopt);
                usage();
            case '?':
                fprintf(stderr, "ERROR: Unknown argument \"-%c\"\n", optopt);
                usage();
        }
    }
    @autoreleasepool {
        __blocklist = [NSMutableDictionary new];
        if (!configPath) {
#define LOCATIONS          \
    X("~/.stayawake.conf") \
    X("./.stayawake.conf") \
    X(".stayawake.conf")
#define X(PATH)                    \
            if (LoadConfig(PATH))  \
                goto FOUND;
            LOCATIONS
#undef X
        } else
            LoadConfig(configPath);
    FOUND:
        if (![__blocklist count]) {
            LOG(" * NOTHING IN BLOCKLIST");
            return 1;
        }
        assert(atexit(AllowSleep));
        for (;;) {
            if (CheckWindows())
                BlockSleep();
            else
                AllowSleep();
            sleep(sleepInterval);
        }
    }
    return 0;
}
