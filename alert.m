/* alert (Mac only)
 Description: Create simple alert notifications from command line
              See -h/--help for more information on usage.
              Return values are based on which button order (first button 0, second 1, etc)
 Build: clang alert.m -framework AppKit -o alert
 
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
    DIALOG_INFO,
    DIALOG_WARNING,
    DIALOG_ERROR,
    DIALOG_NOT_SET
} DIALOG_TYPE;

static struct option long_options[] = {
    {"info", no_argument, NULL, 'i'},
    {"warning", no_argument, NULL, 'w'},
    {"error", no_argument, NULL, 'e'},
    {"ok", no_argument, NULL, 'o'},
    {"cancel", no_argument, NULL, 'c'},
    {"yes", no_argument, NULL, 'y'},
    {"no", no_argument, NULL, 'n'},
    {"message", required_argument, NULL, 'm'},
    {"custom", required_argument, NULL, 'x'},
    {"help", no_argument, NULL, 'h'},
    {NULL, 0, NULL, 0}
};

static void usage(void) {
    puts("usage: alert [options] -m [message]\n");
    puts("\t-i/--info\tInfo style alert\t[required*]");
    puts("\t-w/--warning\tWarning style alert\t[required*]");
    puts("\t-e/--error\tError style dialog\t[required*]");
    puts("\t-o/--ok\t\tAdd OK button");
    puts("\t-c/--cancel\tAdd Cancel button");
    puts("\t-y/--yes\tAdd Yes button");
    puts("\t-n/--no\t\tAdd No button");
    puts("\t-x/--custom\tAdd button with custom text");
    puts("\t-m/--message\tDialog message\t\t[required]");
    puts("\t-h/--help\tDisplay this message");
    puts("\n\t[*] Only one of these is required");
}

int main(int argc, char** argv) {
    @autoreleasepool {
        NSAlert* alert = [[NSAlert alloc] init];
        int opt;
        char* msg = NULL;
        extern char* optarg;
        extern int optopt;
        DIALOG_TYPE type = DIALOG_NOT_SET;
        
        while ((opt = getopt_long(argc, argv, ":iweocyhnm:x:", long_options, NULL)) != -1) {
            switch (opt) {
                case 'i':
                    type = DIALOG_INFO;
                    break;
                case 'w':
                    type = DIALOG_WARNING;
                    break;
                case 'e':
                    type = DIALOG_ERROR;
                case 'o':
                    [alert addButtonWithTitle:@"OK"];
                    break;
                case 'c':
                    [alert addButtonWithTitle:@"Cancel"];
                    break;
                case 'y':
                    [alert addButtonWithTitle:@"Yes"];
                    break;
                case 'n':
                    [alert addButtonWithTitle:@"No"];
                    break;
                case 'm':
                    msg = optarg;
                    break;
                case 'x':
                    [alert addButtonWithTitle:@(optarg)];
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
        
        switch (type) {
            case DIALOG_INFO:
                [alert setAlertStyle:NSAlertStyleInformational];
                break;
            case DIALOG_WARNING:
                [alert setAlertStyle:NSAlertStyleWarning];
                break;
            case DIALOG_ERROR:
                [alert setAlertStyle:NSAlertStyleCritical];
                break;
            case DIALOG_NOT_SET:
            default:
                fprintf(stderr, "ERROR! Dialog type not set or invalid!\n");
                usage();
                return EXIT_FAILURE;
        }
        
        if (!msg) {
            fprintf(stderr, "ERROR! Message not set!\n");
            usage();
            return EXIT_FAILURE;
        }
        [alert setMessageText:@(msg)];
        
        long result = [alert runModal];
        printf("%ld\n", !result ? 0 : result - 1000);
    }
    return EXIT_SUCCESS;
}
