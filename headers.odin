package websocket

import "core:encoding/base64"

import "core:/log"
import http "shared:odin-http"

WebSocketHeaders :: http.Headers
WEBSOCKET_VERSION :: "13"

apply_websocket_headers :: proc(
	headers: ^WebSocketHeaders,
	request_headers: ^http.Headers,
) -> WebSocketError {
	if headers == nil {return .Headers_Nil}

	challenge, challenge_err := challenge_key()

	if challenge_err != .None {
		log.errorf(
			"[odin-websocket] Failed to generate Challenge Key: %v\n",
			challenge_err,
		)
		return .Challenge_Key_Nil
	}

	http.headers_set(headers, "Upgrade", "websocket")
	http.headers_set(headers, "Connection", "Upgrade")
	http.headers_set(headers, "Sec-WebSocket-Key", challenge)
	http.headers_set(headers, "Sec-WebSocket-Version", WEBSOCKET_VERSION)

	// TODO(devon): Protocols
	// TODO(devon): Extensions

	return nil
}

/**
See [Secition 4.1, Bullet 7 of RFC 6455](https://datatracker.ietf.org/doc/html/rfc6455#autoid-15)
*/
challenge_key :: proc(
	allocator := context.allocator,
) -> (
	challenge: string,
	challenge_err: WebSocketError,
) {
	b, alloc_err := make([]u8, 16, allocator)
	if alloc_err != nil {
		log.errorf(
			"[odin-websocket] Allocator error occurred attempting to generate challenge key: %v\n",
			alloc_err,
		)
		return "", .Allocator_Failure
	}

	key := base64.encode(b[:], base64.ENC_TABLE, allocator)
	return key, .None
}
