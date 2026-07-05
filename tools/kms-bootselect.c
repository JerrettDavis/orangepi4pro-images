#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#include <drm/drm.h>
#include <drm/drm_mode.h>

#ifndef DRM_MODE_CONNECTED
#define DRM_MODE_CONNECTED 1
#endif

#define EXIT_NVME 0
#define EXIT_SD 10
#define EXIT_REBOOT 20
#define EXIT_KMS_UNAVAILABLE 111

struct kms {
    int fd;
    uint32_t connector_id;
    uint32_t crtc_id;
    uint32_t fb_id;
    uint32_t handle;
    uint32_t pitch;
    uint32_t width;
    uint32_t height;
    size_t size;
    uint32_t *pixels;
    struct drm_mode_modeinfo mode;
};

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

static void fill_rect(struct kms *k, unsigned int x, unsigned int y,
                      unsigned int w, unsigned int h, uint32_t color)
{
    unsigned int yy, xx;
    unsigned int stride = k->pitch / 4;

    for (yy = y; yy < y + h && yy < k->height; yy++) {
        for (xx = x; xx < x + w && xx < k->width; xx++) {
            k->pixels[yy * stride + xx] = color;
        }
    }
}

static void draw_char(struct kms *k, unsigned int x, unsigned int y, char c,
                      unsigned int scale, uint32_t color)
{
    const char *g = glyph(c);
    unsigned int row, col;

    for (row = 0; row < 7; row++) {
        for (col = 0; col < 5; col++) {
            if (g[row * 5 + col] == '1') {
                fill_rect(k, x + col * scale, y + row * scale, scale, scale, color);
            }
        }
    }
}

static void draw_text(struct kms *k, unsigned int x, unsigned int y,
                      const char *s, unsigned int scale, uint32_t color)
{
    while (*s) {
        if (*s != ' ') {
            draw_char(k, x, y, *s, scale, color);
        }
        x += 6 * scale;
        s++;
    }
}

static void draw_menu(struct kms *k, int selected, int remaining)
{
    char seconds[16];
    struct drm_mode_fb_dirty_cmd dirty;
    struct drm_clip_rect clip;
    uint32_t white = 0x00ffffff;
    uint32_t black = 0x00000000;
    uint32_t blue = 0x00005fdb;
    uint32_t yellow = 0x00ffd44a;
    uint32_t gray = 0x00e8e8e8;

    fill_rect(k, 0, 0, k->width, k->height, white);
    fill_rect(k, 0, 0, k->width, 34, black);
    fill_rect(k, 0, k->height > 34 ? k->height - 34 : 0, k->width, 34, black);
    fill_rect(k, 0, 0, 34, k->height, black);
    fill_rect(k, k->width > 34 ? k->width - 34 : 0, 0, 34, k->height, black);
    fill_rect(k, 58, 52, k->width > 116 ? k->width - 116 : k->width, 112, gray);

    draw_text(k, 82, 82, "BOOT SELECT", 10, black);

    fill_rect(k, 82, 218, 620, 72, selected == 0 ? blue : white);
    fill_rect(k, 82, 326, 620, 72, selected == 1 ? blue : white);
    fill_rect(k, 82, 434, 620, 72, selected == 2 ? blue : white);

    draw_text(k, 112, 234, "N NVME UBUNTU", 7, selected == 0 ? white : black);
    draw_text(k, 112, 342, "S SD UBUNTU", 7, selected == 1 ? white : black);
    draw_text(k, 112, 450, "R REBOOT", 7, selected == 2 ? white : black);

    snprintf(seconds, sizeof(seconds), "%02d", remaining);
    draw_text(k, 82, k->height > 86 ? k->height - 86 : 520, "ENTER SELECTS", 5, black);
    draw_text(k, 620, k->height > 86 ? k->height - 86 : 520, "TIME", 5, black);
    draw_text(k, 802, k->height > 86 ? k->height - 86 : 520, seconds, 5, yellow);
    msync(k->pixels, k->size, MS_SYNC);

    memset(&clip, 0, sizeof(clip));
    clip.x2 = k->width;
    clip.y2 = k->height;
    memset(&dirty, 0, sizeof(dirty));
    dirty.fb_id = k->fb_id;
    dirty.num_clips = 1;
    dirty.clips_ptr = (uintptr_t)&clip;
    ioctl(k->fd, DRM_IOCTL_MODE_DIRTYFB, &dirty);
}

static int get_resources(int fd, struct drm_mode_card_res *res,
                         uint32_t **crtcs, uint32_t **connectors, uint32_t **encoders)
{
    memset(res, 0, sizeof(*res));
    if (ioctl(fd, DRM_IOCTL_MODE_GETRESOURCES, res) < 0) {
        return -1;
    }

    *crtcs = calloc(res->count_crtcs ? res->count_crtcs : 1, sizeof(uint32_t));
    *connectors = calloc(res->count_connectors ? res->count_connectors : 1, sizeof(uint32_t));
    *encoders = calloc(res->count_encoders ? res->count_encoders : 1, sizeof(uint32_t));
    if (!*crtcs || !*connectors || !*encoders) {
        return -1;
    }

    res->crtc_id_ptr = (uintptr_t)*crtcs;
    res->connector_id_ptr = (uintptr_t)*connectors;
    res->encoder_id_ptr = (uintptr_t)*encoders;
    if (ioctl(fd, DRM_IOCTL_MODE_GETRESOURCES, res) < 0) {
        return -1;
    }
    return 0;
}

static int fail_stage(const char *stage)
{
    fprintf(stderr, "stage=%s errno=%d %s\n", stage, errno, strerror(errno));
    return -1;
}

static int get_connector(int fd, uint32_t id, struct drm_mode_get_connector *conn,
                         struct drm_mode_modeinfo **modes, uint32_t **encoders)
{
    uint32_t *props;
    uint64_t *prop_values;
    int ret;

    memset(conn, 0, sizeof(*conn));
    conn->connector_id = id;
    if (ioctl(fd, DRM_IOCTL_MODE_GETCONNECTOR, conn) < 0) {
        return -1;
    }

    *modes = calloc(conn->count_modes ? conn->count_modes : 1, sizeof(**modes));
    *encoders = calloc(conn->count_encoders ? conn->count_encoders : 1, sizeof(**encoders));
    props = calloc(conn->count_props ? conn->count_props : 1, sizeof(*props));
    prop_values = calloc(conn->count_props ? conn->count_props : 1, sizeof(*prop_values));
    if (!*modes || !*encoders || !props || !prop_values) {
        free(props);
        free(prop_values);
        return -1;
    }

    conn->modes_ptr = (uintptr_t)*modes;
    conn->encoders_ptr = (uintptr_t)*encoders;
    conn->props_ptr = (uintptr_t)props;
    conn->prop_values_ptr = (uintptr_t)prop_values;
    ret = ioctl(fd, DRM_IOCTL_MODE_GETCONNECTOR, conn);
    free(props);
    free(prop_values);
    return ret < 0 ? -1 : 0;
}

static int pick_crtc(int fd, const struct drm_mode_card_res *res,
                     const uint32_t *crtcs, const uint32_t *conn_encoders,
                     uint32_t count_encoders, uint32_t current_encoder)
{
    struct drm_mode_get_encoder enc;
    uint32_t i, j;

    if (current_encoder) {
        memset(&enc, 0, sizeof(enc));
        enc.encoder_id = current_encoder;
        if (ioctl(fd, DRM_IOCTL_MODE_GETENCODER, &enc) == 0 && enc.crtc_id) {
            return (int)enc.crtc_id;
        }
    }

    for (i = 0; i < count_encoders; i++) {
        memset(&enc, 0, sizeof(enc));
        enc.encoder_id = conn_encoders[i];
        if (ioctl(fd, DRM_IOCTL_MODE_GETENCODER, &enc) < 0) {
            continue;
        }
        if (enc.crtc_id) {
            return (int)enc.crtc_id;
        }
        for (j = 0; j < res->count_crtcs; j++) {
            if (enc.possible_crtcs & (1u << j)) {
                return (int)crtcs[j];
            }
        }
    }
    return res->count_crtcs ? (int)crtcs[0] : -1;
}

static struct drm_mode_modeinfo fixed_1024x600_mode(void)
{
    struct drm_mode_modeinfo mode;

    memset(&mode, 0, sizeof(mode));
    mode.clock = 49000;
    mode.hdisplay = 1024;
    mode.hsync_start = 1029;
    mode.hsync_end = 1042;
    mode.htotal = 1312;
    mode.vdisplay = 600;
    mode.vsync_start = 602;
    mode.vsync_end = 605;
    mode.vtotal = 622;
    mode.vrefresh = 60;
    mode.flags = DRM_MODE_FLAG_NHSYNC | DRM_MODE_FLAG_PVSYNC;
    mode.type = DRM_MODE_TYPE_USERDEF;
    snprintf(mode.name, sizeof(mode.name), "1024x600");
    return mode;
}

static int setup_kms(struct kms *k)
{
    struct drm_mode_card_res res;
    struct drm_mode_create_dumb create;
    struct drm_mode_fb_cmd fb;
    struct drm_mode_map_dumb map;
    struct drm_mode_crtc crtc;
    uint32_t *crtcs = NULL, *connectors = NULL, *encoders = NULL;
    uint32_t *conn_encoders = NULL;
    struct drm_mode_modeinfo *modes = NULL;
    unsigned int i, m;
    int found = 0;

    memset(k, 0, sizeof(*k));
    k->fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (k->fd < 0) {
        return fail_stage("open-card0");
    }
    ioctl(k->fd, DRM_IOCTL_SET_MASTER, 0);

    if (get_resources(k->fd, &res, &crtcs, &connectors, &encoders) < 0) {
        return fail_stage("get-resources");
    }

    for (i = 0; i < res.count_connectors && !found; i++) {
        struct drm_mode_get_connector conn;

        free(modes);
        free(conn_encoders);
        modes = NULL;
        conn_encoders = NULL;
        if (get_connector(k->fd, connectors[i], &conn, &modes, &conn_encoders) < 0) {
            continue;
        }
        if (conn.connector_type != DRM_MODE_CONNECTOR_HDMIA) {
            continue;
        }

        k->connector_id = conn.connector_id;
        if (conn.count_modes == 0) {
            k->mode = fixed_1024x600_mode();
        } else {
            k->mode = modes[0];
            for (m = 0; m < conn.count_modes; m++) {
                if (strcmp(modes[m].name, "1024x600") == 0) {
                    k->mode = modes[m];
                    break;
                }
            }
        }
        k->crtc_id = (uint32_t)pick_crtc(k->fd, &res, crtcs, conn_encoders,
                                         conn.count_encoders, conn.encoder_id);
        found = k->crtc_id != 0;
    }

    free(crtcs);
    free(connectors);
    free(encoders);
    free(modes);
    free(conn_encoders);

    if (!found) {
        return fail_stage("no-usable-hdmi");
    }

    k->width = k->mode.hdisplay;
    k->height = k->mode.vdisplay;
    memset(&create, 0, sizeof(create));
    create.width = k->width;
    create.height = k->height;
    create.bpp = 32;
    if (ioctl(k->fd, DRM_IOCTL_MODE_CREATE_DUMB, &create) < 0) {
        return fail_stage("create-dumb");
    }
    k->handle = create.handle;
    k->pitch = create.pitch;
    k->size = create.size;

    memset(&fb, 0, sizeof(fb));
    fb.width = k->width;
    fb.height = k->height;
    fb.pitch = k->pitch;
    fb.bpp = 32;
    fb.depth = 24;
    fb.handle = k->handle;
    if (ioctl(k->fd, DRM_IOCTL_MODE_ADDFB, &fb) < 0) {
        return fail_stage("addfb");
    }
    k->fb_id = fb.fb_id;

    memset(&map, 0, sizeof(map));
    map.handle = k->handle;
    if (ioctl(k->fd, DRM_IOCTL_MODE_MAP_DUMB, &map) < 0) {
        return fail_stage("map-dumb");
    }
    k->pixels = mmap(NULL, k->size, PROT_READ | PROT_WRITE, MAP_SHARED, k->fd, map.offset);
    if (k->pixels == MAP_FAILED) {
        return fail_stage("mmap-dumb");
    }

    memset(&crtc, 0, sizeof(crtc));
    crtc.crtc_id = k->crtc_id;
    crtc.fb_id = k->fb_id;
    crtc.set_connectors_ptr = (uintptr_t)&k->connector_id;
    crtc.count_connectors = 1;
    crtc.mode = k->mode;
    crtc.mode_valid = 1;
    if (ioctl(k->fd, DRM_IOCTL_MODE_SETCRTC, &crtc) < 0) {
        return fail_stage("setcrtc");
    }
    fprintf(stderr, "stage=ready connector=%u crtc=%u fb=%u mode=%ux%u pitch=%u\n",
            k->connector_id, k->crtc_id, k->fb_id, k->width, k->height, k->pitch);
    return 0;
}

static int open_inputs(struct pollfd *pfds, int max)
{
    char path[64];
    int count = 0;

    for (int i = 0; i < 32 && count < max; i++) {
        snprintf(path, sizeof(path), "/dev/input/event%d", i);
        int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd >= 0) {
            pfds[count].fd = fd;
            pfds[count].events = POLLIN;
            count++;
        }
    }
    return count;
}

static int read_choice(int timeout)
{
    struct pollfd pfds[32];
    int count = open_inputs(pfds, 32);
    int selected = 0;
    time_t end = time(NULL) + timeout;
    int last_remaining = -1;
    extern struct kms global_kms;

    while (time(NULL) < end) {
        int remaining = (int)(end - time(NULL));
        if (remaining != last_remaining) {
            draw_menu(&global_kms, selected, remaining);
            last_remaining = remaining;
        }
        if (poll(pfds, count, 100) <= 0) {
            continue;
        }
        for (int i = 0; i < count; i++) {
            struct input_event ev;
            if (!(pfds[i].revents & POLLIN)) {
                continue;
            }
            while (read(pfds[i].fd, &ev, sizeof(ev)) == sizeof(ev)) {
                if (ev.type != EV_KEY || ev.value == 0) {
                    continue;
                }
                if (ev.code == KEY_N) {
                    return EXIT_NVME;
                }
                if (ev.code == KEY_S) {
                    return EXIT_SD;
                }
                if (ev.code == KEY_R) {
                    return EXIT_REBOOT;
                }
                if (ev.code == KEY_DOWN) {
                    selected = (selected + 1) % 3;
                    draw_menu(&global_kms, selected, remaining);
                }
                if (ev.code == KEY_UP) {
                    selected = (selected + 2) % 3;
                    draw_menu(&global_kms, selected, remaining);
                }
                if (ev.code == KEY_ENTER || ev.code == KEY_KPENTER) {
                    return selected == 0 ? EXIT_NVME : selected == 1 ? EXIT_SD : EXIT_REBOOT;
                }
            }
        }
    }

    for (int i = 0; i < count; i++) {
        close(pfds[i].fd);
    }
    return EXIT_NVME;
}

struct kms global_kms;

int main(int argc, char **argv)
{
    int timeout = 30;

    if (argc > 1) {
        timeout = atoi(argv[1]);
        if (timeout < 5) {
            timeout = 5;
        }
    }

    if (setup_kms(&global_kms) < 0) {
        return EXIT_KMS_UNAVAILABLE;
    }

    sleep(3);
    draw_menu(&global_kms, 0, timeout);
    return read_choice(timeout);
}
