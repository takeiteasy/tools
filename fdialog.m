/* fdialog (https://github.com/takeiteasy/tools) (Mac only)
 Description: Create simple file dialog from command line
              Open, directory and save dialogs are support with optional filters
              See -h/--help for more information on usage.
              After selecting a file to open or save to path(s) will be printed to stdout
 Build: clang fdialog.m -framework AppKit -o fdialog
 
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


#include <AppKit/AppKit.h>
#include <Availability.h>
#include <getopt.h>

typedef enum {
    DIALOG_OPEN,
    DIALOG_OPEN_DIR,
    DIALOG_SAVE,
    DIALOG_NOT_SET
} DIALOG_ACTION;

static struct option long_options[] = {
    {"open", no_argument, NULL, 'o'},
    {"dir", no_argument, NULL, 'd'},
    {"save", no_argument, NULL, 's'},
    {"multiple", no_argument, NULL, 'm'},
    {"filter", required_argument, NULL, 'f'},
    {"path", required_argument, NULL, 'p'},
    {"filename", required_argument, NULL, 'n'},
    {NULL, 0, NULL, 0}
};

static void usage(void) {
    puts("usage: fdialog [options]\n");
    puts("\t-o/--open\tOpen file dialog\t\t[required*]");
    puts("\t-d/--dir\tOpen directory dialog\t\t[required*]");
    puts("\t-s/--save\tSave file dialog\t\t[required*]");
    puts("\t-m/--multiple\tAllow selecting multiple files\t[disabled by default]");
    puts("\t-f/--filter\tAllowed file extension pattern\t[comma delimeter]");
    puts("\t-p/--path\tInitial directory for dialog to show");
    puts("\t-n/--filename\tDefault filename for dialog to use");
    puts("\t-h/--help\tDisplay this message");
    puts("\n\t[*] Only one of these is required");
}

int main(int argc, char** argv) {
    @autoreleasepool {
        NSSavePanel* panel;
        NSOpenPanel* open_panel;
        int opt;
        BOOL allowed_multiple = NO;
        char *pattern = NULL, *path = NULL, *filename = NULL;
        extern char* optarg;
        extern int optopt;
        DIALOG_ACTION action = DIALOG_NOT_SET;
        
        while ((opt = getopt_long(argc, argv, ":odhsmf:p:n:", long_options, NULL)) != -1) {
            switch(opt) {
                case 'o':
                    action = DIALOG_OPEN;
                    break;
                case 'd':
                    action = DIALOG_OPEN_DIR;
                    break;
                case 's':
                    action = DIALOG_SAVE;
                    break;
                case 'm':
                    allowed_multiple = YES;
                    break;
                case 'f':
                    pattern = optarg;
                    break;
                case 'p':
                    path = optarg;
                    break;
                case 'n':
                    filename = optarg;
                    break;
                case 'h':
                    usage();
                    return EXIT_SUCCESS;
                case ':':
                    printf("ERROR: \"-%c\" requires an value!\n", optopt);
                    usage();
                    return EXIT_FAILURE;
                case '?':
                    printf("ERROR: Unknown argument \"-%c\"\n", optopt);
                    usage();
                    return EXIT_FAILURE;
            }
        }
        
        switch (action) {
            case DIALOG_OPEN:
            case DIALOG_OPEN_DIR:
                open_panel = [NSOpenPanel openPanel];
                panel = open_panel;
                break;
            case DIALOG_SAVE:
                panel = [NSSavePanel savePanel];
                break;
            case DIALOG_NOT_SET:
            default:
                fprintf(stderr, "ERROR! No flag set\n");
                usage();
                return EXIT_FAILURE;
        }
        [panel setLevel:CGShieldingWindowLevel()];
        
        if (!pattern || action == DIALOG_SAVE)
            goto SKIP_FILTERS;
        
        NSMutableArray* file_types = [[NSMutableArray alloc] init];
        char *token = strtok(pattern, ",");
        while (token) {
            [file_types addObject:[NSString stringWithUTF8String:token]];
            token = strtok(NULL, ",");
        }
        [panel setAllowedFileTypes:file_types];
        
    SKIP_FILTERS:
        if (path) {
            NSString *path_str = [NSString stringWithUTF8String:path];
            NSURL *path_url = [NSURL fileURLWithPath:path_str];
            panel.directoryURL = path_url;
        }
        
        if (filename) {
            NSString *filenameString = [NSString stringWithUTF8String:filename];
            panel.nameFieldStringValue = filenameString;
        }
        
        switch (action) {
            case DIALOG_OPEN:
                open_panel.allowsMultipleSelection = allowed_multiple;
                open_panel.canChooseDirectories = NO;
                open_panel.canChooseFiles = YES;
                break;
            case DIALOG_OPEN_DIR:
                open_panel.allowsMultipleSelection = allowed_multiple;
                open_panel.canCreateDirectories = YES;
                open_panel.canChooseDirectories = YES;
                open_panel.canChooseFiles = NO;
                break;
            case DIALOG_SAVE:
                break;
            case DIALOG_NOT_SET:
            default:
                fprintf(stderr, "ERROR! Dialog type not set or invalid!\n");
                usage();
                return EXIT_FAILURE;
        }
        
        // Mute stderr to silence annoying warning by OSX
        int old_stderr = dup(2);
        freopen("/dev/null", "w", stderr);
        fclose(stderr);
        
        if ([panel runModal] == NSModalResponseOK) {
            // Restore stderr
            stderr = fdopen(old_stderr, "w");
            
            if (action == DIALOG_SAVE || !allowed_multiple) {
                const char* url = [[[panel URL] path] UTF8String];
                if (!url)
                    return EXIT_FAILURE;
                
                printf("%s\n", url);
            } else {
                NSArray* urls = [open_panel URLs];
                if (!urls)
                    return EXIT_FAILURE;
                
                for (NSURL* url in urls)
                    printf("%s\n", [[url path] UTF8String]);
            }
        } else
            return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
