/* largetext (Mac only)
 Description: Pipe text to display in large text. Similar to what an old app used to
              do many years ago. I can't remember which one it was though. (Mail maybe???)
              Anyway, simply pipe some text to the program and it will display in a big
              font in the centre of the screen for about 2 seconds.
 Build: clang largetext.m -framework Cocoa -o largetext
 
 The MIT License (MIT)
 
 Copyright (c) 2022 George Watson
 
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

#import <Cocoa/Cocoa.h>

static NSString* str = nil;
static BOOL start_fade = NO;
static double opacity = 1.;

#define PADDING 10
#define TIMEOUT 1.5
#define FADE_BY 50.

@interface AppView : NSView {}
@end

@implementation AppView
- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {}
    return self;
}

- (void)drawRect:(NSRect)frame {
    NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:frame
                                                         xRadius:6.0
                                                         yRadius:6.0];
    [[NSColor colorWithRed:0
                     green:0
                      blue:0
                     alpha:opacity - .25] set];
    [path fill];
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate> {
    NSWindow* window;
    AppView* view;
    NSTextField* label;
    NSTimer* timer;
    NSDate* start;
}
@end

@implementation AppDelegate : NSObject
- (id)init {
    if (self = [super init]) {
        window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 0, 0)
                                             styleMask:NSWindowStyleMaskBorderless
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
        label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        view = [[AppView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        timer = [NSTimer scheduledTimerWithTimeInterval:(1. / 60.)
                                                 target:self
                                               selector:@selector(update)
                                               userInfo:nil
                                                repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer
                                     forMode:NSModalPanelRunLoopMode];
        start = [NSDate date];
    }
    return self;
}

- (void)applicationWillFinishLaunching:(NSNotification*)notification {
    [label setStringValue:str];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setAlignment:NSTextAlignmentCenter];
    [label setFont:[NSFont systemFontOfSize:72.0]];
    [label setTextColor:[NSColor whiteColor]];
    [[label cell] setBackgroundStyle:NSBackgroundStyleRaised];
    [label sizeToFit];
    
    [window setTitle:NSProcessInfo.processInfo.processName];
    [window setOpaque:NO];
    [window setExcludedFromWindowsMenu:NO];
    [window setBackgroundColor:[NSColor clearColor]];
    [window setIgnoresMouseEvents:YES];
    [window makeKeyAndOrderFront:self];
    [window setLevel:NSFloatingWindowLevel];
    [window setCanHide:NO];
    
    [window setFrame:NSMakeRect(([[NSScreen mainScreen] visibleFrame].origin.x + [[NSScreen mainScreen] visibleFrame].size.width / 2) - ([label frame].size.width / 2),
                                ([[NSScreen mainScreen] visibleFrame].origin.y + [[NSScreen mainScreen] visibleFrame].size.height / 2) - ([label frame].size.height / 2),
                                [label frame].size.width + PADDING,
                                [label frame].size.height + PADDING)
             display:YES];
    [view setFrame:NSMakeRect(0, 0,
                              [window frame].size.width,
                              [window frame].size.height)];
    [label setFrame:NSMakeRect(0, 0,
                               [window frame].size.width,
                               [window frame].size.height)];
    [window setContentView:view];
    [view addSubview:label];
}

- (void)update {
    if (!start_fade) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
        if (elapsed >= TIMEOUT)
            start_fade = YES;
    } else {
        if (opacity <= 0.)
            [NSApp terminate:nil];
        opacity -= ([[NSDate date] timeIntervalSinceDate:[timer fireDate]] * FADE_BY);
        [label setTextColor:[[NSColor whiteColor] colorWithAlphaComponent:opacity]];
        [view setNeedsDisplay:YES];
    }
}
@end

int main(int argc, char** argv) {
    @autoreleasepool {
        if (isatty(fileno(stdin)))
            return EXIT_FAILURE;
        
        NSMutableString* pipe = [[NSMutableString alloc] init];
        char line[LINE_MAX];
        while (fgets(line, LINE_MAX, stdin) != NULL)
            [pipe appendString:@(line)];
        
        if (![pipe length])
            return EXIT_FAILURE;
        if ([pipe characterAtIndex:[pipe length] - 1] == '\n')
            [pipe deleteCharactersInRange:NSMakeRange([pipe length] - 1, 1)];
        
        str = [[NSString alloc] initWithString:pipe];
        if (!str)
            return EXIT_FAILURE;
        
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [NSApp setDelegate:[AppDelegate new]];
        [NSApp run];
    }
    return EXIT_SUCCESS;
}
