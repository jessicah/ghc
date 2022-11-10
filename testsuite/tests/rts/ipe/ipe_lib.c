#include "Rts.h"
#include "rts/IPE.h"
#include <string.h>
#include "ipe_lib.h"

void init_string_table(StringTable *st) {
    st->size = 128;
    st->n = 0;
    st->buffer = malloc(st->size);
}

uint32_t add_string(StringTable *st, const char *s) {
    const size_t len = strlen(s);
    const uint32_t n = st->n;
    if (st->n + len + 1 > st->size) {
        const size_t new_size = 2*st->size + len;
        st->buffer = realloc(st->buffer, new_size);
        st->size = new_size;
    }

    memcpy(&st->buffer[st->n], s, len);
    st->n += len;
    st->buffer[st->n] = '\0';
    st->n += 1;
    return n;
}

IpeBufferEntry makeAnyProvEntry(Capability *cap, StringTable *st, HaskellObj closure, int i) {
    IpeBufferEntry provEnt;
    provEnt.info = get_itbl(closure);

    unsigned int tableNameLength = strlen("table_name_") + 3 /* digits */ + 1 /* null character */;
    char *tableName = malloc(sizeof(char) * tableNameLength);
    snprintf(tableName, tableNameLength, "table_name_%03i", i);
    provEnt.table_name = add_string(st, tableName);

    unsigned int closureDescLength = strlen("closure_desc_") + 3 /* digits */ + 1 /* null character */;
    char *closureDesc = malloc(sizeof(char) * closureDescLength);
    snprintf(closureDesc, closureDescLength, "closure_desc_%03i", i);
    provEnt.closure_desc = add_string(st, closureDesc);

    unsigned int tyDescLength = strlen("ty_desc_") + 3 /* digits */ + 1 /* null character */;
    char *tyDesc = malloc(sizeof(char) * tyDescLength);
    snprintf(tyDesc, tyDescLength, "ty_desc_%03i", i);
    provEnt.ty_desc = add_string(st, tyDesc);

    unsigned int labelLength = strlen("label_") + 3 /* digits */ + 1 /* null character */;
    char *label = malloc(sizeof(char) * labelLength);
    snprintf(label, labelLength, "label_%03i", i);
    provEnt.label = add_string(st, label);

    unsigned int moduleLength = strlen("module_") + 3 /* digits */ + 1 /* null character */;
    char *module = malloc(sizeof(char) * moduleLength);
    snprintf(module, moduleLength, "module_%03i", i);
    provEnt.module_name = add_string(st, module);

    unsigned int srcLocLength = strlen("srcloc_") + 3 /* digits */ + 1 /* null character */;
    char *srcLoc = malloc(sizeof(char) * srcLocLength);
    snprintf(srcLoc, srcLocLength, "srcloc_%03i", i);
    provEnt.srcloc = add_string(st, srcLoc);

    return provEnt;
}

IpeBufferListNode *makeAnyProvEntries(Capability *cap, int start, int end) {
    const int n = end - start;
    IpeBufferListNode *node = malloc(sizeof(IpeBufferListNode) + n * sizeof(IpeBufferEntry));
    StringTable st;
    init_string_table(&st);
    for (int i=start; i < end; i++) {
        HaskellObj closure = rts_mkInt(cap, 42);
        node->entries[i] = makeAnyProvEntry(cap, &st, closure, i);
    }
    node->next = NULL;
    node->count = n;
    node->string_table = st.buffer;
    return node;
}