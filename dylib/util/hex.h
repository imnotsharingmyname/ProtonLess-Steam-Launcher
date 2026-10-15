// Hex helpers
#ifndef NOTPROTON_UTIL_HEX_H
#define NOTPROTON_UTIL_HEX_H

static inline int np_hex_val(int ch) {
    if (ch >= '0' && ch <= '9')
        return ch - '0';
    ch |= 0x20; // fold A-F onto a-f
    if (ch >= 'a' && ch <= 'f')
        return ch - 'a' + 10;
    return -1;
}

#endif // NOTPROTON_UTIL_HEX_H
