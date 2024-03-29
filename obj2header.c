/* obj2header.c -- https://github.com/takeiteasy/tools
 
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

#define FAST_OBJ_IMPLEMENTATION
#include "fast_obj.h"
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

static const char* FileExt(const char *path) {
    const char *dot = strrchr(path, '.');
    return !dot || dot == path ? NULL : dot + 1;
}

static const char* RemoveExt(const char* path) {
    char *lastExt = strrchr(path, '.');
    if (lastExt != NULL)
        *lastExt = '\0';
    return lastExt ? path : NULL;
}

static const char* FileName(const char *path) {
    int l = 0;
    char *tmp = strstr(path, "/");
    do {
        l = strlen(tmp) + 1;
        path = &path[strlen(path) - l + 2];
        tmp = strstr(path, "/");
    } while(tmp);
    return RemoveExt(path);
}

#define usage() printf("usage: obj2header <in>.obj <out:optional>\n")

int main(int argc, const char *argv[]) {
    BAIL(argc == 3 || argc == 2, "Incorrect arguments: %d, expected 1 or 2", argc - 1);
    const char *ext = FileExt(argv[1]);
    BAIL(ext, "Incorrect file extension: \"%s\", expected \"obj\"", ext ? ext : "NULL");
    BAIL(!strncmp(ext, "obj", 3), "Incorrect file extension: \"%s\", expected \"obj\"", ext);
    BAIL(!access(argv[1], F_OK), "File doesn't exist at: \"%s\"", argv[1]);
    
    fastObjMesh* mesh = fast_obj_read(argv[1]);
    BAIL(mesh, "Failed to load obj at \"%s\"", argv[1]);
    
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
    BAIL(out, "Failed to save to \"%s\"", outPath);
    fprintf(out, "// Generated by obj2header.c -- https://github.com/takeiteasy/\n"
                 "\n"
                 "#ifndef __OBJ__%s__H__\n"
                 "#define __OBJ__%s__H__\n\n",
                 outName, outName);
    size_t sizeOfBuffer = mesh->face_count * 3 * 8;
    fprintf(out, "static float obj_%s_data[%zu] = {", outName, sizeOfBuffer);
    float buffer[sizeOfBuffer];
    for (int i = 0; i < mesh->face_count * 3; i++) {
        fastObjIndex vertex = mesh->indices[i];
        unsigned int pos = i * 8;
        unsigned int v_pos = vertex.p * 3;
        unsigned int n_pos = vertex.n * 3;
        unsigned int t_pos = vertex.t * 2;
        memcpy(buffer + pos, mesh->positions + v_pos, 3 * sizeof(float));
        memcpy(buffer + pos + 3, mesh->normals + n_pos, 3 * sizeof(float));
        memcpy(buffer + pos + 6, mesh->texcoords + t_pos, 2 * sizeof(float));
    }
    for (int i = 0; i < sizeOfBuffer; i+=8)
        fprintf(out, "\n\t%f, %f, %f,\t%f, %f, %f,\t%f, %f,", buffer[i], buffer[i+1], buffer[i+2], buffer[i+3], buffer[i+4], buffer[i+5], buffer[i+6], buffer[i+7]);
    fprintf(out, "\n};\nstatic unsigned int obj_%s_data_size = %zu;\n", outName, sizeOfBuffer);
    fprintf(out, "static unsigned int obj_%s_face_count = %d;\n", outName, mesh->face_count * 3);
    fprintf(out, "\n#endif // __OBJ__%s__H__\n", outName);
            
    if (outPath[0] != '\0')
            fclose(out);
    fast_obj_destroy(mesh);
    return 0;
}
