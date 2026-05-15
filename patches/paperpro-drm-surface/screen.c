/*
 * Paper Pro DRM/KMS surface backend for libnsfb-reMarkable.
 *
 * Drops the rM1/rM2 mxcfb path entirely and uses standard Linux DRM
 * dumb buffers + drmModeSetCrtc + drmModeDirtyFB. The imx-drm driver
 * the Paper Pro ships should handle the e-ink refresh internally on
 * dirty-fb (or via an auto-update mode). Refinement of waveform-mode
 * selection via DRM properties can come later if needed.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/ioctl.h>
#include <sys/mman.h>

#include <xf86drm.h>
#include <xf86drmMode.h>

#include "libnsfb.h"
#include "libnsfb_plot.h"

#include "screen.h"
#include "log.h"

#define DRM_DEVICE "/dev/dri/card0"

static int try_become_master(int fd)
{
	if (drmSetMaster(fd) == 0)
		return 0;
	ERROR_LOG("drmSetMaster failed: %s — another process holds the display.\n"
		  "    Run 'systemctl stop xochitl' before launching nsfb.",
		  strerror(errno));
	return -1;
}

static drmModeConnector *find_connected_connector(int fd, drmModeRes *res)
{
	for (int i = 0; i < res->count_connectors; i++) {
		drmModeConnector *c = drmModeGetConnector(fd, res->connectors[i]);
		if (!c)
			continue;
		if (c->connection == DRM_MODE_CONNECTED && c->count_modes > 0)
			return c;
		drmModeFreeConnector(c);
	}
	return NULL;
}

static uint32_t pick_crtc(int fd, drmModeRes *res, drmModeConnector *conn)
{
	if (conn->encoder_id) {
		drmModeEncoder *e = drmModeGetEncoder(fd, conn->encoder_id);
		if (e) {
			uint32_t crtc = e->crtc_id;
			drmModeFreeEncoder(e);
			if (crtc)
				return crtc;
		}
	}
	for (int i = 0; i < conn->count_encoders; i++) {
		drmModeEncoder *e = drmModeGetEncoder(fd, conn->encoders[i]);
		if (!e)
			continue;
		for (int j = 0; j < res->count_crtcs; j++) {
			if (e->possible_crtcs & (1 << j)) {
				uint32_t crtc = res->crtcs[j];
				drmModeFreeEncoder(e);
				return crtc;
			}
		}
		drmModeFreeEncoder(e);
	}
	return 0;
}

int fb_initialize(fb_state_t *state)
{
	memset(state, 0, sizeof(*state));
	state->drm_fd = -1;

	state->drm_fd = open(DRM_DEVICE, O_RDWR | O_CLOEXEC);
	if (state->drm_fd < 0) {
		ERROR_LOG("open(%s) failed: %s", DRM_DEVICE, strerror(errno));
		return -1;
	}

	if (try_become_master(state->drm_fd) < 0)
		goto fail;

	drmModeRes *res = drmModeGetResources(state->drm_fd);
	if (!res) {
		ERROR_LOG("drmModeGetResources: %s", strerror(errno));
		goto fail;
	}

	drmModeConnector *conn = find_connected_connector(state->drm_fd, res);
	if (!conn) {
		ERROR_LOG("no DRM connector in CONNECTED state");
		drmModeFreeResources(res);
		goto fail;
	}

	state->conn_id = conn->connector_id;
	drmModeModeInfo mode = conn->modes[0];
	int width = mode.hdisplay;
	int height = mode.vdisplay;

	state->crtc_id = pick_crtc(state->drm_fd, res, conn);
	if (!state->crtc_id) {
		ERROR_LOG("no usable CRTC for connector %u", conn->connector_id);
		drmModeFreeConnector(conn);
		drmModeFreeResources(res);
		goto fail;
	}

	DEBUG_LOG("connector=%u crtc=%u mode=%dx%d@%dHz",
		  conn->connector_id, state->crtc_id,
		  width, height, mode.vrefresh);

	state->saved_crtc = drmModeGetCrtc(state->drm_fd, state->crtc_id);

	struct drm_mode_create_dumb create = {
		.width = width,
		.height = height,
		.bpp = 32,
	};
	if (drmIoctl(state->drm_fd, DRM_IOCTL_MODE_CREATE_DUMB, &create) < 0) {
		ERROR_LOG("DRM_IOCTL_MODE_CREATE_DUMB: %s", strerror(errno));
		drmModeFreeConnector(conn);
		drmModeFreeResources(res);
		goto fail;
	}
	state->buf_handle = create.handle;
	state->size = create.size;

	if (drmModeAddFB(state->drm_fd, width, height, 24, 32,
			 create.pitch, state->buf_handle, &state->fb_id) < 0) {
		ERROR_LOG("drmModeAddFB: %s", strerror(errno));
		drmModeFreeConnector(conn);
		drmModeFreeResources(res);
		goto fail;
	}

	struct drm_mode_map_dumb map = { .handle = state->buf_handle };
	if (drmIoctl(state->drm_fd, DRM_IOCTL_MODE_MAP_DUMB, &map) < 0) {
		ERROR_LOG("DRM_IOCTL_MODE_MAP_DUMB: %s", strerror(errno));
		drmModeFreeConnector(conn);
		drmModeFreeResources(res);
		goto fail;
	}

	state->mapped_fb = mmap(NULL, create.size, PROT_READ | PROT_WRITE,
				MAP_SHARED, state->drm_fd, map.offset);
	if (state->mapped_fb == MAP_FAILED) {
		ERROR_LOG("mmap: %s", strerror(errno));
		state->mapped_fb = NULL;
		drmModeFreeConnector(conn);
		drmModeFreeResources(res);
		goto fail;
	}

	/* Start with a white screen */
	memset(state->mapped_fb, 0xff, create.size);

	if (drmModeSetCrtc(state->drm_fd, state->crtc_id, state->fb_id,
			   0, 0, &state->conn_id, 1, &mode) < 0) {
		ERROR_LOG("drmModeSetCrtc: %s", strerror(errno));
		drmModeFreeConnector(conn);
		drmModeFreeResources(res);
		goto fail;
	}

	state->scrinfo.width = width;
	state->scrinfo.height = height;
	state->scrinfo.bpp = 32;
	state->scrinfo.linelen = (int)create.pitch;

	drmModeFreeConnector(conn);
	drmModeFreeResources(res);

	DEBUG_LOG("fb ready: %dx%d bpp=32 pitch=%d size=%llu",
		  state->scrinfo.width, state->scrinfo.height,
		  state->scrinfo.linelen, (unsigned long long)state->size);

	return 0;

fail:
	fb_finalize(state);
	return -1;
}

int fb_finalize(fb_state_t *state)
{
	if (state->drm_fd < 0)
		return 0;

	if (state->mapped_fb) {
		munmap(state->mapped_fb, state->size);
		state->mapped_fb = NULL;
	}

	if (state->saved_crtc) {
		drmModeCrtc *c = (drmModeCrtc *)state->saved_crtc;
		drmModeSetCrtc(state->drm_fd, c->crtc_id, c->buffer_id,
			       c->x, c->y, &state->conn_id, 1, &c->mode);
		drmModeFreeCrtc(c);
		state->saved_crtc = NULL;
	}

	if (state->fb_id) {
		drmModeRmFB(state->drm_fd, state->fb_id);
		state->fb_id = 0;
	}

	if (state->buf_handle) {
		struct drm_mode_destroy_dumb destroy = { .handle = state->buf_handle };
		drmIoctl(state->drm_fd, DRM_IOCTL_MODE_DESTROY_DUMB, &destroy);
		state->buf_handle = 0;
	}

	drmDropMaster(state->drm_fd);
	close(state->drm_fd);
	state->drm_fd = -1;
	return 0;
}

int fb_update_region(fb_state_t *state, nsfb_bbox_t *box)
{
	if (!box || state->drm_fd < 0)
		return 0;

	int w = state->scrinfo.width;
	int h = state->scrinfo.height;

	drmModeClip clip = {
		.x1 = (uint16_t)(box->x0 < 0 ? 0 : (box->x0 > w ? w : box->x0)),
		.y1 = (uint16_t)(box->y0 < 0 ? 0 : (box->y0 > h ? h : box->y0)),
		.x2 = (uint16_t)(box->x1 < 0 ? 0 : (box->x1 > w ? w : box->x1)),
		.y2 = (uint16_t)(box->y1 < 0 ? 0 : (box->y1 > h ? h : box->y1)),
	};

	if (clip.x2 <= clip.x1 || clip.y2 <= clip.y1)
		return 0;

	int rc = drmModeDirtyFB(state->drm_fd, state->fb_id, &clip, 1);
	if (rc < 0 && rc != -ENOSYS) {
		/* -ENOSYS just means the driver doesn't implement dirty-fb,
		   not a fatal error — the next vblank will pick up our writes. */
		TRACE_LOG("drmModeDirtyFB: %d (%s)", rc, strerror(-rc));
	}
	return 0;
}

int fb_claim_region(fb_state_t *state, nsfb_bbox_t *box)
{
	(void)state;
	(void)box;
	return 0;
}
