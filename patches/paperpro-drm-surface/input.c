/*
 * Paper Pro raw evdev input backend.
 *
 * Strategy: open the Elan touch device, read struct input_event objects
 * directly, accumulate ABS_MT_POSITION_X/Y + BTN_TOUCH into a tiny state
 * machine and emit NSFB events at SYN_REPORT boundaries.
 *
 * No libevdev. No libudev. ~150 lines instead of the original 712.
 */

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <linux/input.h>

#include "libnsfb.h"
#include "libnsfb_event.h"
#include "nsfb.h"

#include "input.h"
#include "log.h"

/* Hard-coded for the rMPP layout reported by /proc/bus/input/devices:
 *   event2 = Elan marker (stylus)
 *   event3 = Elan touch (capacitive)
 * Touch is enough for now. */
#define TOUCH_DEVICE "/dev/input/event3"

static int query_abs_range(int fd, int axis, int *min, int *max)
{
	struct input_absinfo info;
	if (ioctl(fd, EVIOCGABS(axis), &info) < 0)
		return -1;
	*min = info.minimum;
	*max = info.maximum;
	return 0;
}

int input_initialize(input_state_t *state, nsfb_t *nsfb)
{
	memset(state, 0, sizeof(*state));
	state->touch_fd = -1;

	state->screen_w = nsfb ? nsfb->width  : 0;
	state->screen_h = nsfb ? nsfb->height : 0;

	state->touch_fd = open(TOUCH_DEVICE, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
	if (state->touch_fd < 0) {
		ERROR_LOG("open(%s): %s", TOUCH_DEVICE, strerror(errno));
		return -1;
	}

	if (query_abs_range(state->touch_fd, ABS_MT_POSITION_X,
			    &state->touch_min_x, &state->touch_max_x) < 0) {
		state->touch_min_x = 0;
		state->touch_max_x = state->screen_w > 0 ? state->screen_w : 1;
	}
	if (query_abs_range(state->touch_fd, ABS_MT_POSITION_Y,
			    &state->touch_min_y, &state->touch_max_y) < 0) {
		state->touch_min_y = 0;
		state->touch_max_y = state->screen_h > 0 ? state->screen_h : 1;
	}

	DEBUG_LOG("touch device %s opened, axes x=[%d,%d] y=[%d,%d], screen %dx%d",
		  TOUCH_DEVICE,
		  state->touch_min_x, state->touch_max_x,
		  state->touch_min_y, state->touch_max_y,
		  state->screen_w, state->screen_h);
	return 0;
}

int input_finalize(input_state_t *state)
{
	if (state->touch_fd >= 0) {
		close(state->touch_fd);
		state->touch_fd = -1;
	}
	return 0;
}

static int scale_axis(int v, int dmin, int dmax, int screen)
{
	if (dmax <= dmin || screen <= 0)
		return v;
	int span = dmax - dmin;
	long s = (long)(v - dmin) * (long)screen / (long)span;
	if (s < 0) s = 0;
	if (s >= screen) s = screen - 1;
	return (int)s;
}

static bool emit_pending(input_state_t *s, nsfb_event_t *event)
{
	if (s->pending_down) {
		s->pending_down = false;
		event->type = NSFB_EVENT_KEY_DOWN;
		event->value.keycode = NSFB_KEY_MOUSE_1;
		return true;
	}
	if (s->pending_up) {
		s->pending_up = false;
		event->type = NSFB_EVENT_KEY_UP;
		event->value.keycode = NSFB_KEY_MOUSE_1;
		return true;
	}
	if (s->pending_move) {
		s->pending_move = false;
		event->type = NSFB_EVENT_MOVE_ABSOLUTE;
		event->value.vector.x = s->last_x;
		event->value.vector.y = s->last_y;
		return true;
	}
	return false;
}

bool input_get_next_event(input_state_t *state, nsfb_event_t *event, int timeout)
{
	if (state->touch_fd < 0)
		return false;

	if (emit_pending(state, event))
		return true;

	struct pollfd pfd = { .fd = state->touch_fd, .events = POLLIN };
	int rc = poll(&pfd, 1, timeout);
	if (rc <= 0)
		return false;

	int raw_x = -1, raw_y = -1;
	struct input_event ev;
	while (read(state->touch_fd, &ev, sizeof(ev)) == (ssize_t)sizeof(ev)) {
		switch (ev.type) {
		case EV_ABS:
			switch (ev.code) {
			case ABS_X:
			case ABS_MT_POSITION_X:
				raw_x = ev.value;
				break;
			case ABS_Y:
			case ABS_MT_POSITION_Y:
				raw_y = ev.value;
				break;
			case ABS_MT_TRACKING_ID:
				if (ev.value < 0) {
					if (state->touching) {
						state->touching = false;
						state->pending_up = true;
					}
				} else {
					if (!state->touching) {
						state->touching = true;
						state->pending_down = true;
					}
				}
				break;
			}
			break;
		case EV_KEY:
			if (ev.code == BTN_TOUCH) {
				if (ev.value) {
					if (!state->touching) {
						state->touching = true;
						state->pending_down = true;
					}
				} else {
					if (state->touching) {
						state->touching = false;
						state->pending_up = true;
					}
				}
			}
			break;
		case EV_SYN:
			if (ev.code == SYN_REPORT) {
				if (raw_x >= 0)
					state->last_x = scale_axis(raw_x,
								   state->touch_min_x,
								   state->touch_max_x,
								   state->screen_w);
				if (raw_y >= 0)
					state->last_y = scale_axis(raw_y,
								   state->touch_min_y,
								   state->touch_max_y,
								   state->screen_h);
				if ((raw_x >= 0 || raw_y >= 0) && state->touching)
					state->pending_move = true;

				if (emit_pending(state, event))
					return true;

				raw_x = -1;
				raw_y = -1;
			}
			break;
		}
	}

	return emit_pending(state, event);
}
