/* glsl2header.c -- https://github.com/takeiteasy/tools
 
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

#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <string.h>
#if defined(_WIN32) || defined(_WIN64)
#include <io.h>
#define F_OK 0
#define access _access
#else
#include <unistd.h>
#endif

#define BAIL(X, MSG, ...)                                     \
    do {                                                      \
        if (!(X)) {                                           \
            fprintf(stderr, "ERROR: " MSG "\n", __VA_ARGS__); \
            usage();                                          \
        }                                                     \
        assert((X));                                          \
    } while(0)

static char* FileExt(const char *path) {
    const char *dot = strrchr(path, '.');
    return !dot || dot == path ? NULL : dot + 1;
}

static char* RemoveExt(const char* path) {
    char *lastExt = strrchr(path, '.');
    if (lastExt != NULL)
        *lastExt = '\0';
    return lastExt ? path : NULL;
}

static char* FileName(const char *path) {
    int l = 0;
    char *tmp = strstr(path, "/");
    do {
        l = strlen(tmp) + 1;
        path = &path[strlen(path) - l + 2];
        tmp = strstr(path, "/");
    } while(tmp);
    return RemoveExt(path);
}

#if defined(_WIN32) || defined(_WIN64)
#define NEWLINE "\r\n"
#else
#define NEWLINE "\n"
#endif

static char* ReadFile(const char* path, size_t *size) {
    FILE *file = fopen(path, "rb");
    if (!file) {
        fprintf(stderr, "fopen \"%s\" failed: %d %s\n", path, errno, strerror(errno));
        return NULL;
    }
    
    fseek(file, 0, SEEK_END);
    size_t length = ftell(file);
    rewind(file);
    
    char *data = calloc(length + 1, sizeof(char));
    fread(data, 1, length, file);
    fclose(file);
    
    if (size)
        *size = length;
    return data;
}

#define usage() printf("usage: glsl2header <in>.glsl <out:optional>\n")

int main(int argc, const char *argv[]) {
    BAIL(argc == 2 || argc == 3, "Incorrect arguments: %d, expected 1 or 2", argc - 1);
    const char *ext = FileExt(argv[1]);
    BAIL(ext, "Incorrect file extension: \"%s\", expected \"glsl\"", ext ? ext : "NULL");
    BAIL(!strncmp(ext, "glsl", 4), "Incorrect file extension: \"%s\", expected \"glsl\"", ext);
    BAIL(!access(argv[1], F_OK), "File doesn't exist at: \"%s\"", argv[1]);
    
    char *data = ReadFile(argv[1], NULL);
    BAIL(data, "Failed to load shader at: \"%s\"", argv[1]);
    
    char outPath[512];
    char *outName = (char*)FileName(argv[1]);
    switch (argc) {
        case 2:
            outPath[0] = '\0';
            break;
        case 3: {
            int pathLength = strlen(argv[2]);
            memcpy(outPath, argv[2], sizeof(char) * pathLength);
            outPath[pathLength] = '\0';
            break;
        }
        default:
            usage();
            return 1;
    }
    for (int i = 0; i < strlen(outName); i++)
        if (outName[i] == '.')
            outName[i] = '_';
    
    FILE *out = outPath[0] == '\0' ? stdout : fopen(outPath, "w");
    fprintf(out, "// Generated by glsl2header.c -- https://github.com/takeiteasy/\n"
                 "\n"
                 "#ifndef __GLSL__%s__H__\n"
                 "#define __GLSL__%s__H__\n",
                 outName, outName);
    fprintf(out, "static const char* shdr_%s_data =\n", outName);
    char *token = strtok(data, NEWLINE);
    int firstLine = 1;
    while (token) {
        int ok = 0;
        for (int i = 0; i < strlen(token); i++)
            if (token[i] != ' ') {
                ok = 1;
                break;
            }
        if (!ok)
            goto NEXT;
        fprintf(out, "\"%s%s\"", token, firstLine ? "\\n" : "");
        if (firstLine) {
            firstLine = 0;
            assert(token[0] == '#');
        }
    NEXT:
        token = strtok(NULL, NEWLINE);
        if (ok)
            fprintf(out, "%s", token ? "\n" : ";\n");
    }
    fprintf(out, "#endif // __GLSL__%s__H__\n", outName);
    
    if (outPath[0] != '\0')
        fclose(out);
    free(data);
    return 0;
}
