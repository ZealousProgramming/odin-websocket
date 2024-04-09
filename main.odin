package websocket

import "core:fmt"
import "core:net"

ADDRESS: net.IP4_Address : net.IP4_Address{127, 0, 0, 1}
PORT :: 8573
ENDPOINT :: "127.0.0.1:3000"

INITIAL_MESSAGE :: "Hellolove"

main :: proc() {
	fmt.println("[odin-websocket] Hello from the otherside")

	endpoint, endpoint_err := net.parse_endpoint(ENDPOINT)
	if endpoint_err {
		fmt.eprintln("NETWORK ERROR: Failed to parse endpoints")
	}

	tcp_socket, listen_err := net.listen_tcp(endpoint)
	if listen_err != nil {
		fmt.eprintf("NETWORK ERROR: Failed to listen - %s\n", listen_err)
	}

	buffer: [len(INITIAL_MESSAGE)]u8
	copy(buffer[:], INITIAL_MESSAGE)

	for {
		connection, _, accept_err := net.accept_tcp(tcp_socket)
		if accept_err != nil {
			fmt.eprintf(
				"NETWORK ERROR: Failed to accept incoming connection - %s\n",
				accept_err,
			)
		} else {
			fmt.println("Incoming Connection: %v", connection)
		}

		bytes_written, send_err := net.send_tcp(tcp_socket, buffer[:])
		if send_err != nil {
			fmt.eprintf(
				"NETWORK ERROR: Failed to send message - %s\n",
				accept_err,
			)

			return
		} else {
			fmt.println("Incoming Connection: %v", connection)
		}
	}

}

