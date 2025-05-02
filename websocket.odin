package websocket

WebSocket_Error :: enum {
	Nil = 0,
	Allocator_Failure,
	Challenge_Key_Nil,
	Headers_Nil,
	Handshake_Failure,
	Invalid_HTTP_Request,
}
