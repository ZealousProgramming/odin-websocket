package client

//import "core:encoding/base64"
import "core:bytes"
import "core:fmt"
import "core:net"
import "core:strings"

SERVER_ENDPOINT :: "127.0.0.1:80"

INITIAL_MESSAGE :: "pong"

main :: proc() {
	fmt.printf("[odin-websocket] Connecting to %s..\n", SERVER_ENDPOINT)

	socket, err := net.dial_tcp(SERVER_ENDPOINT)
	fmt.assertf(err == nil, "dial error %v", err)
	defer net.close(socket)

	buff: [1024]byte
	for {
		received, rerr := net.recv(socket, buff[:])
		if rerr != nil {
			fmt.printf("recv error %v\n", rerr)
			return
		}

		if (received > 0) {
			fmt.println("Received message of length:", received)
			pong(&socket, buff[:], context.temp_allocator)

			return


		}
	}

}

pong :: proc(
	socket: ^net.TCP_Socket,
	buffer: []byte,
	allocator := context.allocator,
) {
	message, alloc_err := strings.clone_from_bytes(buffer, allocator)
	if alloc_err != nil {
		fmt.eprintf("Failed to convert bytes to string: %v\n", alloc_err)
		return
	} else {
		fmt.println("Received message with content:", message)
	}

	reply_buffer := bytes.Buffer{}
	buffer_bytes_written, bws_err := bytes.buffer_write_string(
		&reply_buffer,
		INITIAL_MESSAGE,
	)
	if bws_err != .None {
		fmt.eprintf("Failed to write to buffer from string: %v\n", bws_err)
		return
	}

	send_bytes_written, send_err := net.send_tcp(socket^, reply_buffer.buf[:])
	if send_err != nil {
		fmt.eprintf("Failed to send message to server: %v\n", send_err)

		return
	}

	fmt.printf("Bytes Sent: %v\n", send_bytes_written)
	fmt.printf("Content Sent: %v\n", INITIAL_MESSAGE)
}
