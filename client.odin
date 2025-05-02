package websocket

import "core:fmt"
import "core:log"
import "core:net"
import "core:strings"
import "core:bytes"
import "core:io"
import "core:bufio"


// Websocket_Client :: struct {
// 	// connection: ^net.Socket,
// }

// client_init :: proc(
// 	request: ^http.Request,
// 	allocator := context.allocator,
// ) -> ^Websocket_Client {
// 	client := new(Websocket_Client, allocator)
// 	return client
// }


// client_free :: proc(client: ^Websocket_Client, allocator := context.allocator) {
// 	free(client)
// }

// ws_client_connect :: proc(client: ^Websocket_Client, allocator := context.allocator) {
ws_client_connect :: proc(allocator := context.allocator) -> (status: WebSocket_Error) {
	/* Example of the handshake request
	GET http://localhost:8080/echo HTTP/1.1
	Host: example.com:8000
	Upgrade: websocket
	Connection: Upgrade
	Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
	Sec-WebSocket-Version: 13
	*/

	endpoint := "localhost:8080"
	headers: map[string]string
	defer delete(headers)

	headers["Host"] = "localhost:8080"
	// REQUIRED - The WebSocket server will return an 400 Bad Request if the following are not present in the handshake
	headers["Upgrade"] = "websocket"
	headers["Connection"] = "Upgrade"
	headers["Sec-WebSocket-Key"] = "dGhlIHNhbXBsZSBub25jZQ=="
	headers["Sec-WebSocket-Version"] = "13"

	headers["Content-Length"] = "0"
	headers["Accept"] = "*/*"
	headers["User-Agent"] = "odin"

	buffer: bytes.Buffer
	defer bytes.buffer_destroy(&buffer)

	bytes.buffer_write_string(&buffer, "GET http://localhost:8080/echo HTTP/1.1\r\n")

	for k, v in headers {
		bytes.buffer_write_string(&buffer, fmt.tprintf("%v: %v\r\n", k, v))
	}

	bytes.buffer_write_string(&buffer, "\r\n")


	socket, err := net.dial_tcp(endpoint)

	if err != nil {
		log.errorf("FAILED - Failed to create socket: %v\n", err)
		status = .Handshake_Failure
		
		return 
	} else {
		log.info("Socket successfully created")
	}

	da_stuff := bytes.buffer_to_bytes(&buffer)

	log.info("\n[PAYLOAD]:\n")
	log.info(string(da_stuff))
	log.info("\n")

	// No SSL for now
	n, send_err := net.send_tcp(socket, da_stuff)

	if send_err != nil {
		log.errorf("FAILED - Failed to send packet: %v\n", send_err)

		status = .Handshake_Failure
		return
	} else {
		log.info("Handshake sent, awaiting reponse..\n")
	}

	log.info("\n[RESPONSE]:\n")
	// Reponse
	stream: io.Stream
	stream.data = rawptr(uintptr(socket))
	stream.procedure = socket_stream

	stream_reader := io.to_reader(stream)
	scanner: bufio.Scanner

	bufio.scanner_init(&scanner, stream_reader, allocator)
	defer bufio.scanner_destroy(&scanner)

	for {
		if !bufio.scanner_scan(&scanner) {
			scan_err := bufio.scanner_error(&scanner)

			log.errorf("ERROR - Scanner encountered an error: %v\n", scan_err)

			status = .Handshake_Failure
			return
		}

		line := bufio.scanner_text(&scanner)
		log.info(line)

		if len(transmute([]u8)line) <= 0 {
			status = .Nil
			break
		}

		// HTTP/1.1 400 Bad Request
		// HTTP/1.1 101 Switching Protocols
		if strings.contains(line, "HTTP/1.1") {
			chunks, _ :=  strings.split(line, " ", context.temp_allocator)
			if len(chunks) < 2 {
				status = .Invalid_HTTP_Request

				return
			}

			http_code := chunks[1]

			if http_code != "101" {
				log.errorf("ERROR - Handshake response HTTP code, expected: '101' actual: '%v'\n", http_code)
				status = .Handshake_Failure

				return
			}
		}
	}

	return
}


socket_stream :: proc(
	stream_data: rawptr,
	mode: io.Stream_Mode,
	p: []byte,
	offset: i64,
	whence: io.Seek_From,
) -> (
	n: i64,
	err: io.Error,
) {
	#partial switch mode {
	case .Query:
		return io.query_utility(io.Stream_Mode_Set{.Query, .Read})
	case .Read:
		sock := net.TCP_Socket(uintptr(stream_data))
		received, recv_err := net.recv_tcp(sock, p)
		n = i64(received)

		#partial switch recv_err {
		case .None:
			err = .None
		case .Not_Connected, .Connection_Closed, .Network_Unreachable, .Timeout, .Invalid_Argument, .Insufficient_Resources:
			log.errorf("unexpected error reading tcp: %s", recv_err)
			err = .Unexpected_EOF
		case:
			log.errorf("unexpected error reading tcp: %s", recv_err)
			err = .Unknown
		}
	case:
		err = .Empty
	}

	return
}
