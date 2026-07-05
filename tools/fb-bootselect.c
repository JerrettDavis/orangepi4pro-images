#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

static uint8_t *fb;
static struct fb_var_screeninfo var;
static struct fb_fix_screeninfo fix;

static uint32_t make_color(uint8_t r, uint8_t g, uint8_t b)
{
    if (var.bits_per_pixel == 16) {
        return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
    }
    return ((uint32_t)r << var.red.offset) |
           ((uint32_t)g << var.green.offset) |
           ((uint32_t)b << var.blue.offset);
}

static void put_pixel(unsigned int x, unsigned int y, uint32_t color)
{
    unsigned int bytes = var.bits_per_pixel / 8;
    uint8_t *p;

    if (x >= var.xres || y >= var.yres || bytes == 0) {
        return;
    }
    p = fb + (y + var.yoffset) * fix.line_length + (x + var.xoffset) * bytes;
    if (bytes == 2) {
        *(uint16_t *)p = (uint16_t)color;
    } else {
        *(uint32_t *)p = color;
    }
}

static void fill_rect(unsigned int x, unsigned int y, unsigned int w, unsigned int h, uint32_t color)
{
    unsigned int yy, xx;
    for (yy = y; yy < y + h && yy < var.yres; yy++) {
        for (xx = x; xx < x + w && xx < var.xres; xx++) {
            put_pixel(xx, yy, color);
        }
    }
}

static const char *glyph(char c)
{
    switch (c) {
    case 'A': return "01110" "10001" "10001" "11111" "10001" "10001" "10001";
    case 'B': return "11110" "10001" "10001" "11110" "10001" "10001" "11110";
    case 'C': return "01111" "10000" "10000" "10000" "10000" "10000" "01111";
    case 'D': return "11110" "10001" "10001" "10001" "10001" "10001" "11110";
    case 'E': return "11111" "10000" "10000" "11110" "10000" "10000" "11111";
    case 'F': return "11111" "10000" "10000" "11110" "10000" "10000" "10000";
    case 'G': return "01111" "10000" "10000" "10111" "10001" "10001" "01111";
    case 'H': return "10001" "10001" "10001" "11111" "10001" "10001" "10001";
    case 'I': return "11111" "00100" "00100" "00100" "00100" "00100" "11111";
    case 'K': return "10001" "10010" "10100" "11000" "10100" "10010" "10001";
    case 'L': return "10000" "10000" "10000" "10000" "10000" "10000" "11111";
    case 'M': return "10001" "11011" "10101" "10101" "10001" "10001" "10001";
    case 'N': return "10001" "11001" "10101" "10011" "10001" "10001" "10001";
    case 'O': return "01110" "10001" "10001" "10001" "10001" "10001" "01110";
    case 'P': return "11110" "10001" "10001" "11110" "10000" "10000" "10000";
    case 'R': return "11110" "10001" "10001" "11110" "10100" "10010" "10001";
    case 'S': return "01111" "10000" "10000" "01110" "00001" "00001" "11110";
    case 'T': return "11111" "00100" "00100" "00100" "00100" "00100" "00100";
    case 'U': return "10001" "10001" "10001" "10001" "10001" "10001" "01110";
    case 'V': return "10001" "10001" "10001" "10001" "10001" "01010" "00100";
    case 'Y': return "10001" "10001" "01010" "00100" "00100" "00100" "00100";
    case '0': return "01110" "10001" "10011" "10101" "11001" "10001" "01110";
    case '1': return "00100" "01100" "00100" "00100" "00100" "00100" "01110";
    case '2': return "01110" "10001" "00001" "00010" "00100" "01000" "11111";
    case '3': return "11110" "00001" "00001" "01110" "00001" "00001" "11110";
    case '4': return "00010" "00110" "01010" "10010" "11111" "00010" "00010";
    case '5': return "11111" "10000" "10000" "11110" "00001" "00001" "11110";
    case '6': return "01110" "10000" "10000" "11110" "10001" "10001" "01110";
    case '7': return "11111" "00001" "00010" "00100" "01000" "01000" "01000";
    case '8': return "01110" "10001" "10001" "01110" "10001" "10001" "01110";
    case '9': return "01110" "10001" "10001" "01111" "00001" "00001" "01110";
    case ':': return "00000" "00100" "00100" "00000" "00100" "00100" "00000";
    case '-': return "00000" "00000" "00000" "11111" "00000" "00000" "00000";
    default: return "00000" "00000" "00000" "00000" "00000" "00000" "00000";
    }
}

static void draw_char(unsigned int x, unsigned int y, char c, unsigned int scale, uint32_t color)
{
    const char *g = glyph(c);
    unsigned int row, col;
    for (row = 0; row < 7; row++) {
        for (col = 0; col < 5; col++) {
            if (g[row * 5 + col] == '1') {
                fill_rect(x + col * scale, y + row * scale, scale, scale, color);
            }
        }
    }
}

static void draw_text(unsigned int x, unsigned int y, const char *s, unsigned int scale, uint32_t color)
{
    while (*s) {
        if (*s != ' ') {
            draw_char(x, y, *s, scale, color);
        }
        x += 6 * scale;
        s++;
    }
}

int main(int argc, char **argv)
{
    int fd;
    size_t fb_size;
    uint32_t white, black, gray;
    char seconds[16];

    fd = open("/dev/fb0", O_RDWR);
    if (fd < 0) {
        return 0;
    }
    if (ioctl(fd, FBIOGET_VSCREENINFO, &var) < 0 ||
        ioctl(fd, FBIOGET_FSCREENINFO, &fix) < 0) {
        close(fd);
        return 0;
    }
    fb_size = fix.smem_len;
    fb = mmap(NULL, fb_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (fb == MAP_FAILED) {
        close(fd);
        return 0;
    }

    white = make_color(255, 255, 255);
    black = make_color(0, 0, 0);
    gray = make_color(220, 220, 220);

    fill_rect(0, 0, var.xres, var.yres, white);
    fill_rect(0, 0, var.xres, 24, black);
    fill_rect(0, var.yres > 24 ? var.yres - 24 : 0, var.xres, 24, black);
    fill_rect(0, 0, 24, var.yres, black);
    fill_rect(var.xres > 24 ? var.xres - 24 : 0, 0, 24, var.yres, black);
    fill_rect(48, 48, var.xres > 96 ? var.xres - 96 : var.xres, 110, gray);

    draw_text(72, 72, "BOOT SELECT", 10, black);
    draw_text(72, 220, "N NVME", 8, black);
    draw_text(72, 330, "S SD", 8, black);
    draw_text(72, 440, "R REBOOT", 8, black);
    draw_text(72, 560, "TIME", 7, black);
    snprintf(seconds, sizeof(seconds), "%s", argc > 1 ? argv[1] : "0");
    draw_text(420, 560, seconds, 7, black);

    msync(fb, fb_size, MS_SYNC);
    munmap(fb, fb_size);
    close(fd);
    return 0;
}
