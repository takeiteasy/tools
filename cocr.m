/* cocr.m -- General purpose on-screen OCR for Mac [https://github.com/takeiteasy/cocr]
 
 clang cocr.m -framework Carbon -framework Cocoa -framework Vision -o cocr
 
 The MIT License (MIT)

 Copyright (c) 2023 George Watson

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

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <Carbon/Carbon.h>
#include <getopt.h>
#import <Cocoa/Cocoa.h>
#import <Vision/Vision.h>
#import <CoreImage/CoreImage.h>
#import <CommonCrypto/CommonDigest.h>

#define LOGF(MSG, ...)              \
do {                                \
    if (settings.enableVerboseMode) \
        NSLog((MSG), __VA_ARGS__);  \
} while(0)
#define LOG(MSG) LOGF(@"%@", (MSG))

@interface DashedBorderView : NSView
@end

@interface SelectWindow : NSWindow
@property (nonatomic, strong) DashedBorderView *dashedBorderView;
-(id)initWithPositionX:(NSInteger)x andY:(NSInteger)y;
-(void)resizeWithMousePositionX:(NSInteger)x andY:(NSInteger)y;
@end

@interface ScreenReader : NSObject
@property NSRect frame;

-(id)initWithFrame:(NSRect)frame;
-(BOOL)readText:(void(^)(NSString*))completion;
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) NSStatusItem *statusBar;
@property (nonatomic, strong) SelectWindow *captureWindow;
@property (nonatomic, strong) ScreenReader *screenReader;
- (id)init;
- (void)newWindowAtX:(NSInteger)x andY:(NSInteger)y;
- (void)createStatusBar;
@end

typedef struct {
    CFMachPortRef tap;
    CFRunLoopSourceRef tapLoop;
    AppDelegate *delegate;
    NSPoint mousePosition;
    BOOL dragging;
} State;

typedef struct {
    BOOL enableVerboseMode;
    BOOL disableOverlay;
    BOOL disableBorder;
    BOOL disableStatusBar;
    BOOL disableMD5Check;
    BOOL outputToClipboard;
    BOOL keepAlive;
    NSTimeInterval refreshInterval;
    NSColor *backgroundColor;
    NSRect frame;
    BOOL frameSet;
    NSString *languageCode;
} Settings;

static State state;
static Settings settings;

@implementation DashedBorderView
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    // dash customization parameters
    CGFloat dashPattern[] = {10, 6}; // 10 units on, 6 units off, for example
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    // Set the line color
    CGContextSetStrokeColorWithColor(context, [NSColor colorWithRed:0.f
                                                              green:0.f
                                                               blue:0.f
                                                              alpha:.5f].CGColor);
    // Set the line width
    CGContextSetLineWidth(context, 2.0); // Set this to the width you desire
    // Set the line dash pattern
    CGContextSetLineDash(context, 0, dashPattern, 2); // 2 is the number of elements in the dashPattern
    // Create a path for the rectangle
    CGContextBeginPath(context);
    CGContextAddRect(context, NSInsetRect(self.bounds, 1, 1)); // Inset the rect so the border is fully visible
    // Stroke the path
    CGContextStrokePath(context);
}
@end

@implementation SelectWindow {
    NSInteger originX;
    NSInteger originY;
    NSInteger width;
    NSInteger height;
}

- (id)initWithPositionX:(NSInteger)x andY:(NSInteger)y {
    originX = x;
    originY = y;
    width = 0;
    height = 0;
    if (self = [super initWithContentRect:NSMakeRect(originX, originY, 0, 0)
                                styleMask:NSWindowStyleMaskBorderless
                                  backing:NSBackingStoreBuffered
                                    defer:NO]) {
        [self setTitle:NSProcessInfo.processInfo.processName];
        [self setOpaque:NO];
        [self setExcludedFromWindowsMenu:NO];
        [self setBackgroundColor:[NSColor colorWithDeviceRed:0.f
                                                       green:0.f
                                                        blue:1.f
                                                       alpha:.1f]];
        [self setIgnoresMouseEvents:YES];
        [self makeKeyAndOrderFront:self];
        [self setLevel:NSFloatingWindowLevel];
        [self setCanHide:NO];
        [self setReleasedWhenClosed:NO];
        
        if (!settings.disableBorder) {
            _dashedBorderView = [[DashedBorderView alloc] initWithFrame:[self frame]];
            [self setContentView:_dashedBorderView];
        }
    }
    return self;
}

- (void)resizeWithMousePositionX:(NSInteger)x andY:(NSInteger)y {
    width = x - originX;
    height = y - originY;
    NSInteger offsetX = 0;
    NSInteger offsetY = 0;
    if (width < 0)
        offsetX = labs(width);
    if (height < 0)
        offsetY = labs(height);
    [self setFrame:NSMakeRect(originX - offsetX,
                              originY - offsetY,
                              labs(width),
                              labs(height))
           display:NO];
}
@end

@interface NSData (MyAdditions)
- (NSString *)MD5Hash;
@end

@implementation NSData (MyAdditions)
- (NSString *)MD5Hash {
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(self.bytes, (CC_LONG)self.length, result); // This is the md5 call
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", result[i]];
    return output;
}
@end

@implementation ScreenReader {
    NSString *lastHash;
}

-(id)initWithFrame:(NSRect)frame {
    if (self = [super init]) {
        _frame = frame;
        lastHash = @"";
    }
    return self;
}

- (BOOL)readText:(void(^)(NSString *finished))completion {
    NSString *outPath = [NSString stringWithFormat:@"/tmp/cocr_%@.png", [[NSUUID UUID] UUIDString]];
    
    NSTask *task = [NSTask new];
    [task setLaunchPath:@"/usr/sbin/screencapture"];
    int y = [[[NSScreen screens] objectAtIndex:0] frame].size.height - _frame.size.height - (int)_frame.origin.y;
    if (_frame.size.width == 0 || _frame.size.height == 0)
        [NSApp terminate:nil];
    [task setArguments:@[@"-r", @"-x", @"-R", [NSString stringWithFormat:@"%d,%d,%d,%d", (int)_frame.origin.x, y, (int)_frame.size.width, (int)_frame.size.height], outPath]];
    [task launch];
    [task waitUntilExit];
    
    if (!settings.disableMD5Check) {
        NSString *hash = [[NSData dataWithContentsOfFile:outPath] MD5Hash];
        if ([lastHash isEqualTo:hash])
            return false;
        lastHash = hash;
    }
    
    NSImage* nsImg = [[NSImage alloc] initWithContentsOfFile:outPath];
    if (!nsImg) {
        NSLog(@"ERROR: Failed to load image at \"%@\"", outPath);
        return NO;
    }
    NSRect imageRect = NSMakeRect(0, 0, nsImg.size.width, nsImg.size.height);
    CGImageRef img = [nsImg CGImageForProposedRect:&imageRect
                                           context:NULL
                                             hints:nil];
    if (!img) {
        NSLog(@"ERROR: Failed to load image at \"%@\"", outPath);
        return NO;
    }
    VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc] initWithCGImage:img options:@{}];
    
    NSArray<NSString*> *languages = @[settings.languageCode];
    VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        if (error) {
            NSLog(@"ERROR: %@", error.localizedDescription);
            return;
        }
        
        NSArray *observations = [request results];
        NSMutableArray<NSString*> *recognizedStrings = [[NSMutableArray alloc] init];
        
        for (VNRecognizedTextObservation *observation in observations) {
            VNRecognizedText *topCandidate = [[observation topCandidates:1] firstObject];
            if (topCandidate)
                [recognizedStrings addObject:topCandidate.string];
        }
        
        for (NSString *string in recognizedStrings)
            completion(string);
    }];
    request.recognitionLanguages = languages;
    
    NSError *error = nil;
    [requestHandler performRequests:@[request]
                              error:&error];
    if (error) {
        NSLog(@"Unable to perform the requests: %@", error.localizedDescription);
        return NO;
    }
    [[NSFileManager defaultManager] removeItemAtPath:outPath
                                               error:&error];
    if (error) {
        NSLog(@"Unable to delete file: %@", error.localizedDescription);
        return NO;
    }
    return YES;
}
@end

@implementation AppDelegate {
    NSTimer *refreshTimer;
}

- (id)init {
    if (self = [super init]) {
        state.mousePosition = [NSEvent mouseLocation];
        _screenReader = nil;
        refreshTimer = nil;
        
        if (settings.frameSet) {
            [self initScreenReader:settings.frame];
            if (!settings.disableStatusBar && settings.keepAlive)
                [state.delegate createStatusBar];
        }
    }
    return self;
}

- (void)timerRefresh {
    [_screenReader readText:^(NSString *result) {
        if (settings.outputToClipboard) {
            [[NSPasteboard generalPasteboard] clearContents];
            [[NSPasteboard generalPasteboard] setString:result
                                                forType:NSPasteboardTypeString];
        } else {
            printf("%s\n", [result UTF8String]);
        }
        if (!settings.keepAlive)
            [NSApp terminate:nil];
    }];
}

- (void)newWindowAtX:(NSInteger)x andY:(NSInteger)y {
    _captureWindow = [[SelectWindow alloc] initWithPositionX:x
                                                        andY:y];
}

- (void)initScreenReader:(NSRect)frame {
    LOGF(@"* CAPTURING AT: x:%f, y:%f, w:%f, h:%f", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
    _screenReader = [[ScreenReader alloc] initWithFrame:frame];
    if (!settings.keepAlive)
        [self timerRefresh];
    else
        refreshTimer = [NSTimer scheduledTimerWithTimeInterval:settings.refreshInterval
                                                        target:self
                                                      selector:@selector(timerRefresh)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(terminate:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];
}

- (void)createStatusBar {
    _statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusBar.button.image = [NSImage imageWithSystemSymbolName:@"sparkles"
                                        accessibilityDescription:nil];
#if __MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4
    statusBar.highlightMode = YES;
#endif
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItemWithTitle:@"Quit"
                    action:@selector(terminate:)
             keyEquivalent:@"q"];
    _statusBar.menu = menu;
}
@end

static CGEventRef EventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *ref) {
    state.mousePosition = [NSEvent mouseLocation];
    bool lastDraggingState = state.dragging;
    switch (type) {
        case kCGEventKeyDown:
            if (CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == kVK_Escape)
                [NSApp terminate:nil];
            break;
        case kCGEventLeftMouseDragged:
            state.dragging = YES;
            LOG(@"* DRAGGING STARTED");
            [[state.delegate captureWindow] resizeWithMousePositionX:state.mousePosition.x
                                                                andY:state.mousePosition.y];
            if (!lastDraggingState) {
                [state.delegate newWindowAtX:state.mousePosition.x
                                        andY:state.mousePosition.y];
                return NULL;
            }
            break;
        case kCGEventLeftMouseUp:
            if (state.dragging) {
                LOG(@"* DRAGGING FINISHED");
                [[state.delegate captureWindow] resizeWithMousePositionX:state.mousePosition.x
                                                                    andY:state.mousePosition.y];
                [state.delegate initScreenReader:[[state.delegate captureWindow] frame]];
                if (!settings.keepAlive || settings.disableOverlay)
                    [[state.delegate captureWindow] close];
                else {
                    if (!settings.disableBorder) {
                        NSRect frame = [[state.delegate captureWindow] frame];
                        frame.size.width += 4;
                        frame.size.height += 4;
                        frame.origin.x -= 2;
                        frame.origin.y -= 2;
                        [[state.delegate captureWindow] setFrame:frame
                                                         display:YES
                                                         animate:YES];
                    }
                    
                    if (!settings.disableStatusBar && settings.keepAlive)
                        [state.delegate createStatusBar];
                }
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), state.tapLoop, kCFRunLoopCommonModes);
                CGEventTapEnable(state.tap, 0);
                state.tap = nil;
                return NULL;
            } else
                [NSApp terminate:nil];
            break;
        case kCGEventTapDisabledByTimeout:
        case kCGEventTapDisabledByUserInput:
            CGEventTapEnable(state.tap, 1);
        default:
            break;
    }
    return event;
}

static struct option long_options[] = {
    {"disable-overlay", no_argument, NULL, 'o'},
    {"color", required_argument, NULL, 'c'},
    {"disable-border", no_argument, NULL, 'b'},
    {"frame", required_argument, NULL, 'f'},
    {"keep-alive", no_argument, NULL, 'k'},
    {"interval", required_argument, NULL, 'i'},
    {"fullscreen", no_argument, NULL, 'F'},
    {"disable-statusbar", no_argument, NULL, 's'},
    {"disable-md5check", no_argument, NULL, 'm'},
    {"clipboard", no_argument, NULL, 'p'},
    {"language", required_argument, NULL, 'l'},
    {"verbose", no_argument, NULL, 'v'},
    {"help", no_argument, NULL, 'h'},
    {NULL, 0, NULL, 0}
};

static void usage(void) {
    puts("usage: cocr [options]");
    puts("");
    puts("  Description:");
    puts("    A general purpose CLI on-screen OCR for Mac");
    puts("");
    puts("  Arguments:");
    puts("    * --disable-overlay/-o -- Disable capture overlay");
    puts("    * --color/-c -- Background color for capture overlay (Hex or RGBA)");
    puts("    * --disable-border/-b -- Disable border on capture overlay");
    puts("    * --frame/-f -- Capture frame (x,y,w,h)");
    puts("    * --keep-alive/-k -- Capture periodically, see -i");
    puts("    * --interval/-i -- Capture timer interval (default: 1 second)");
    puts("    * --fullscreen/-F -- Set capture frame to screen size");
    puts("    * --disable-statusbar/-s -- Disable status bar icon to quit app");
    puts("    * --disable-md5check/-m -- Disable MD5 duplicate check");
    puts("    * --clipboard/-p -- Output OCR result to clipboard instead of STDOUT");
    puts("    * --language/-l -- Set the target language, default \"en-US\"");
    puts("    * --verbose/-v -- Enable logging");
    puts("    * --help/-h -- Display this message");
}

int main(int argc, char *argv[]) {
    memset((void*)&state, 0, sizeof(State));
    memset((void*)&settings, 0, sizeof(Settings));
    settings.refreshInterval = 1.f;
    settings.backgroundColor = [NSColor colorWithRed:0.f
                                               green:0.f
                                                blue:1.f
                                               alpha:.1f];
    settings.frame = NSMakeRect(0.f, 0.f, 0.f, 0.f);
    settings.languageCode = @"en-US";
    
    int opt;
    extern int optind;
    extern char* optarg;
    extern int optopt;
    while ((opt = getopt_long(argc, argv, "hvobkFsmpc:f:i:l:", long_options, NULL)) != -1) {
        switch (opt) {
            case 'o':
                settings.disableOverlay = YES;
                break;
            case 'c':
#define SetWindowColor(R, G, B, A)                                          \
        settings.backgroundColor = [NSColor colorWithRed:(float)(R) / 255.f \
                                                   green:(float)(G) / 255.f \
                                                    blue:(float)(B) / 255.f \
                                                   alpha:(float)(A) / 255.f];
                if (optarg[0] == '#') {
                    int _r, _g, _b, _a;
                    sscanf(optarg, "%02x%02x%02x%02x", &_r, &_g, &_b, &_a);
                    SetWindowColor(_r, _g, _b, _a);
                } else if (!strncmp(optarg, "rgb", 3)) {
                    int _r, _g, _b, _a;
                    sscanf(optarg, "rgb(%d,%d,%d,%d)", &_r, &_g, &_b, &_a);
                    SetWindowColor(_r, _g, _b, _a);
                } else {
                    NSLog(@"ERROR: Invalid color format\n");
                    usage();
                    return 6;
                }
                break;
            case 'b':
                settings.disableBorder = YES;
                break;
            case 'f': {
                int _x, _y, _w, _h;
                sscanf(optarg, "%02x,%02x,%02x,%02x", &_x, &_y, &_w, &_h);
                settings.frame = NSMakeRect((float)_x, (float)_y, (float)_w, (float)_h);
                settings.frameSet = YES;
                break;
            }
            case 'k':
                settings.keepAlive = YES;
                break;
            case 'i':
                if (!(settings.refreshInterval = atoi(optarg)))
                    settings.refreshInterval = 1.f;
                break;
            case 'F':
                settings.frame = [[NSScreen mainScreen] frame];
                break;
            case 's':
                settings.disableStatusBar = YES;
                break;
            case 'm':
                settings.disableMD5Check = YES;
                break;
            case 'p':
                settings.outputToClipboard = YES;
                break;
            case 'l':
                settings.languageCode = [NSString stringWithUTF8String:optarg];
                break;
            case 'v':
                settings.enableVerboseMode = YES;
                break;
            case 'h':
                usage();
                return 0;
            case '?':
                fprintf(stderr, "ERROR: Unknown argument \"-%c\"\n", optopt);
                usage();
                return 3;
        }
    }
    
    if (!settings.frameSet) {
        assert((state.tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, kCGEventMaskForAllEvents, EventCallback, NULL)));
        state.tapLoop = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, state.tap, 0);
        CGEventTapEnable(state.tap, 1);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), state.tapLoop, kCFRunLoopCommonModes);
    }
    
    @autoreleasepool {
        state.delegate = [AppDelegate new];
        LOG(@"* APP DELEGATE CREATED");
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [NSApp setDelegate:state.delegate];
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }
    return 0;
}
