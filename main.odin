package main

//import "core:encoding/base64"
import "core:fmt"
import "core:net"
import "core:strings"

ADDRESS: net.IP4_Address : net.IP4_Address{127, 0, 0, 1}
PORT :: 8573
ENDPOINT :: "127.0.0.1:3000"

INITIAL_MESSAGE :: "ping"

main :: proc() {
	fmt.println("[odin-websocket] Setting up server")

	endpoint, endpoint_err := net.parse_endpoint(ENDPOINT)
	if !endpoint_err {
		fmt.eprintln("NETWORK ERROR: Failed to parse endpoint")
	}

	socket, listen_err := net.listen_tcp(endpoint)
	if listen_err != nil {
		fmt.eprintf("NETWORK ERROR: Failed to listen - %s\n", listen_err)
	}

	buffer: [len(INITIAL_MESSAGE)]u8
	copy(buffer[:], INITIAL_MESSAGE)

	for {
		connection, _, accept_err := net.accept_tcp(socket)
		if accept_err != nil {
			fmt.eprintf(
				"NETWORK ERROR: Failed to accept incoming connection - %s\n",
				accept_err,
			)
		} else {
			fmt.printf("Incoming Connection: %v\n", connection)
		}

		bytes_written, send_err := net.send_tcp(connection, buffer[:])
		if send_err != nil {
			fmt.eprintf(
				"NETWORK ERROR: Failed to send message - %s\n",
				accept_err,
			)
			return
		} else {
			fmt.println("Incoming Connection: %v", connection)
		}

		received, rerr := net.recv(connection, buffer[:])
		if rerr != nil {
			fmt.printf("recv error %v\n", rerr)
			return
		}

		if (received > 0) {
			fmt.println("Received message of length:", received)

			message, alloc_err := strings.clone_from_bytes(
				buffer[:],
				context.temp_allocator,
			)
			if alloc_err != nil {
				fmt.eprintf(
					"Failed to convert bytes to string: %v\n",
					alloc_err,
				)
				return
			} else {
				fmt.println("Received message with content:", message)
			}

			return
		}
	}

}
