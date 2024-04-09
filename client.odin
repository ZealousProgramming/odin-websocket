package websocket

import "core:net"
import http "shared:odin-http"

WebsocketClient :: struct {
	connection: Maybe(net.Socket),
}

client_init :: proc(
	request: ^http.Request,
	allocator := context.allocator,
) -> ^WebsocketClient {
	client := new(WebsocketClient, allocator)
	return client
}

client_free :: proc(client: ^WebsocketClient, allocator := context.allocator) {
	free(client)
}
