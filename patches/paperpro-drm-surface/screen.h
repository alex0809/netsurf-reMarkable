/*
 * Paper Pro DRM/KMS surface backend for libnsfb-reMarkable.
 *
 * Replaces the original screen.h which targeted /dev/fb0 + MXC EPDC ioctl.
 * The reMarkable Paper Pro exposes its e-ink panel through the standard
 * Linux DRM/KMS subsystem (imx-drm driver, /dev/dri/card0) — there is no
 * /dev/fb0 device at all.
 *
 * Field names match the original struct so remarkable.c (which only reads
 * scrinfo.{width,height,bpp,linelen} and mapped_fb) compiles unchanged.
 */

#ifndef RM_SCREEN_H
#define RM_SCREEN_H

#include <stdbool.h>
#include <stdint.h>

#include "libnsfb.h"

typedef struct fb_info_s {
	int height;
	int width;
	int bpp;
	int linelen;
} fb_info_t;

typedef struct fb_state_s {
	/* DRM master / mode-setting state */
	int drm_fd;
	uint32_t fb_id;
	uint32_t crtc_id;
	uint32_t conn_id;

	/* Dumb buffer state */
	uint32_t buf_handle;
	uint64_t size;
	void *mapped_fb;

	/* Restored at finalize so xochitl can resume cleanly */
	void *saved_crtc; /* drmModeCrtc * (opaque to avoid including drmModeMode here) */

	/* Geometry for nsfb */
	fb_info_t scrinfo;
} fb_state_t;

int fb_initialize(fb_state_t *state);
int fb_finalize(fb_state_t *state);
int fb_update_region(fb_state_t *state, nsfb_bbox_t *box);
int fb_claim_region(fb_state_t *state, nsfb_bbox_t *box);

#endif
