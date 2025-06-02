package websocket

import "core:fmt"
import "core:strings"

WEBSOCKET_VERSION :: "13"
WEBSOCKET_UNSECURE :: "ws"
WEBSOCKET_SECURE :: "wss"


WebSocket_Error :: enum {
	Nil = 0,
	Allocator_Failure,
	Challenge_Key_Nil,
	Headers_Nil,
	Handshake_Failure,
	Invalid_HTTP_Request,
}


/*
Changes the URL object's protocol/scheme from a websocket scheme to the corresponding HTTP protocol
*/
convert_scheme :: proc(
	url: string,
	allocator := context.allocator,
) -> (
	converted_url: string,
	ok: bool,
) {

	if strings.starts_with(url, "wss://") {
		converted_url = fmt.aprintf("%v%v", HTTPS, strings.cut(url, 3), allocator = allocator)

		ok = true
		return
	}

	if strings.starts_with(url, "ws://") {
		converted_url = fmt.aprintf("%v%v", HTTP, strings.cut(url, 2), allocator = allocator)

		ok = true
		return
	}

	return
}
