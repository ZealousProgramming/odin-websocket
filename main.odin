package websocket

import "core:fmt"
import "core:log"
import "core:mem"

main :: proc() {
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	context.logger = log.create_console_logger(log.Level.Info)

	c_err := ws_client_connect()

	if c_err != .Nil {
		log.errorf("Failed to connect to server: %v\n", c_err)
	}

	log.destroy_console_logger(context.logger)
	for _, leak in track.allocation_map {
		fmt.eprintf("%v leaked %v bytes\n", leak.location, leak.size)
	}

	for bad_free in track.bad_free_array {
		fmt.eprintf(
			"%p allocation %p was freed incorrectly\n",
			bad_free.location,
			bad_free.memory,
		)
	}

}

track: mem.Tracking_Allocator
