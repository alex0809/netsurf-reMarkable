/*
 * Paper Pro raw evdev input backend for libnsfb-reMarkable.
 *
 * Replaces the libevdev + libudev implementation with direct evdev
 * reads. libevdev.so.2 isn't present on the rMPP rootfs anyway, and
 * libudev's device enumeration is overkill for our use — we hard-code
 * the Elan touch device.
 *
 * Currently handles single-touch + tap-to-click only. Stylus and
 * multitouch can be added once the basics are confirmed working.
 */

#ifndef RM_INPUT_H
#define RM_INPUT_H

#include <stdbool.h>
#include <stdint.h>

#include "libnsfb.h"
#include "libnsfb_event.h"

typedef struct input_state_s {
	int touch_fd;

	/* Last reported pen-down absolute position, in screen coords */
	int last_x;
	int last_y;

	/* Reported by the touch device's ABS axis ranges (EVIOCGABS) so we
	 * can scale device coordinates into screen coordinates. */
	int touch_min_x, touch_max_x;
	int touch_min_y, touch_max_y;

	/* Screen size (copied at init from nsfb) so the scaler stays
	 * decoupled from fb_state. */
	int screen_w, screen_h;

	bool touching;
	bool pending_down;
	bool pending_up;
	bool pending_move;
} input_state_t;

int input_initialize(input_state_t *state, nsfb_t *nsfb);
int input_finalize(input_state_t *state);
bool input_get_next_event(input_state_t *state, nsfb_event_t *event, int timeout);

#endif
