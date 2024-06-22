/* cdialog (https://github.com/takeiteasy/dialog-tools) (Mac only)
 Description: Create simple color picker dialog from command line
              See -h/--help for more information on usage.
 Build: clang cdialog.m -framework AppKit -o cdialog
 
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


#include <AppKit/AppKit.h>
#include <Availability.h>
#include <getopt.h>

static struct option long_options[] = {
    {"opacity", no_argument, NULL, 'o'},
    {"help", no_argument, NULL, 'h'},
    {NULL, 0, NULL, 0}
};

enum {
    FORMAT_RGB = 0,
    FORMAT_HEX,
    FORMAT_FLOAT
};

static void usage(void) {
    puts("usage: cdialog [options]\n");
    puts("  https://github.com/takeiteasy/dialog-tools\n");
    puts("  -f/--format  Specify the color output format [default: RGB]");
    puts("  -o/--opacity Enable opacity");
    puts("  -h/--help    Display this message");
    puts("formats:");
    puts("  rgb = 0-255, hex = 00-FF, float = 0.0-1.0\n");
}

static void PrintChannel(int format, float value) {
    switch (format) {
        default:
        case FORMAT_RGB:
            fprintf(stdout, "%d", (int)(value * 255.f));
            break;
        case FORMAT_HEX:
            fprintf(stdout, "%02X", (int)(value * 255.f));
            break;
        case FORMAT_FLOAT:
            fprintf(stdout, "%.2f", value);
            break;
    }
}

int main(int argc, char** argv) {
    @autoreleasepool {
        int outFormat = FORMAT_RGB;
        BOOL enableOpacity = NO;
        int opt;
        extern char* optarg;
        while ((opt = getopt_long(argc, argv, "hof:", long_options, NULL)) != -1) {
            switch (opt) {
                case 'f':
                    if (!strncmp(optarg, "rgb", 3)) {
                        outFormat = FORMAT_RGB;
                    } else if (!strncmp(optarg, "hex", 3)) {
                        outFormat = FORMAT_HEX;
                    } else if (!strncmp(optarg, "float", 5)) {
                        outFormat = FORMAT_FLOAT;
                    } else {
                        fprintf(stderr, "ERROR: unknown format \"-%c\"\n", optopt);
                        usage();
                        return EXIT_FAILURE;
                    }
                    break;
                case 'o':
                    enableOpacity = YES;
                    break;
                case 'h':
                    usage();
                    return EXIT_SUCCESS;
                case ':':
                    fprintf(stderr, "ERROR: \"-%c\" requires a value!\n", optopt);
                    usage();
                    return EXIT_FAILURE;
                case '?':
                    fprintf(stderr, "ERROR: Unknown argument \"-%c\"\n", optopt);
                    usage();
                    return EXIT_FAILURE;
            }
        }
        
        // Set up the panel
        NSWindow* window = [[NSApplication sharedApplication] keyWindow];
        NSColorPanel* panel = [NSColorPanel sharedColorPanel];
        NSColor* tmp = [NSColor colorWithCalibratedRed:255.f
                                                 green:255.f
                                                  blue:255.f
                                                 alpha:255.f];
        [panel setColor:tmp];
        [panel setShowsAlpha:enableOpacity];
        
        // Create the modal window + wait for it to close
        NSModalSession modal = [NSApp beginModalSessionForWindow:panel];
        for (;;) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            if ([NSApp runModalSession:modal] != NSModalResponseContinue)
                break;
            if (![panel isVisible])
                break;
        }
        [NSApp endModalSession:modal];
        
        // Get the color from the modal window and print
        tmp = [panel color];
        NSColor* color = [tmp colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
        CGFloat r, g, b, a;
        [color getRed:&r green:&g blue:&b alpha:&a];
        PrintChannel(outFormat, r);
        if (outFormat != FORMAT_HEX)
            fprintf(stdout, ",");
        PrintChannel(outFormat, g);
        if (outFormat != FORMAT_HEX)
            fprintf(stdout, ",");
        PrintChannel(outFormat, b);
        if (enableOpacity) {
            if (outFormat != FORMAT_HEX)
                fprintf(stdout, ",");
            PrintChannel(outFormat, a);
        }
        
        [window makeKeyAndOrderFront:nil];
    }
    return EXIT_SUCCESS;
}
