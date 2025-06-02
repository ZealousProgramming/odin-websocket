package websocket

import "core:encoding/base64"
import "core:fmt"
import "core:io"
import "core:log"
import "core:math/rand"
import "core:net"


client_connect :: proc(url: string, allocator := context.allocator) -> (status: WebSocket_Error) {
	/* Example of the handshake request
	GET http://localhost:8080/echo HTTP/1.1
	Host: example.com:8000
	Upgrade: websocket
	Connection: Upgrade
	Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
	Sec-WebSocket-Version: 13
	*/

	// Handle Request
	// -----------
	// See [Section 4.1, Page 17 of RFC 6455](https://datatracker.ietf.org/doc/html/rfc6455)

	// 1.   The handshake MUST be a valid HTTP request as specified by
	//     [RFC2616](https://datatracker.ietf.org/doc/html/rfc2616).

	// 2.   The method of the request MUST be GET, and the HTTP version MUST
	//     be at least 1.1.

	//     For example, if the WebSocket URI is "ws://example.com/chat",
	//     the first line sent should be "GET /chat HTTP/1.1".

	// 3.   The "Request-URI" part of the request MUST match the /resource
	//     name/ defined in Section 3 (a relative URI) or be an absolute
	//     http/https URI that, when parsed, has a /resource name/, /host/,
	//     and /port/ that match the corresponding ws/wss URI.

	// 4.   The request MUST contain a |Host| header field whose value
	//     contains /host/ plus optionally ":" followed by /port/ (when not
	//     using the default port).

	// 5.   The request MUST contain an |Upgrade| header field whose value
	//     MUST include the "websocket" keyword.

	// 6.   The request MUST contain a |Connection| header field whose value
	//     MUST include the "Upgrade" token.

	// 7.   The request MUST include a header field with the name
	//     |Sec-WebSocket-Key|.  The value of this header field MUST be a
	//     nonce consisting of a randomly selected 16-byte value that has
	//     been base64-encoded (see Section 4 of [RFC4648]).  The nonce
	//     MUST be selected randomly for each connection.

	//     NOTE: As an example, if the randomly selected value was the
	//     sequence of bytes 0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09
	//     0x0a 0x0b 0x0c 0x0d 0x0e 0x0f 0x10, the value of the header
	//     field would be "AQIDBAUGBwgJCgsMDQ4PEC=="

	// 8.   The request MUST include a header field with the name |Origin|
	//     [RFC6454] if the request is coming from a browser client.  If
	//     the connection is from a non-browser client, the request MAY
	//     include this header field if the semantics of that client match
	//     the use-case described here for browser clients.  The value of
	//     this header field is the ASCII serialization of origin of the
	//     context in which the code establishing the connection is
	//     running.  See [RFC6454] for the details of how this header field
	//     value is constructed.

	//     As an example, if code downloaded from www.example.com attempts
	//     to establish a connection to ww2.example.com, the value of the
	//     header field would be "http://www.example.com".

	// 9.   The request MUST include a header field with the name
	//     |Sec-WebSocket-Version|.  The value of this header field MUST be
	//     13.

	//     NOTE: Although draft versions of this document (-09, -10, -11,
	//     and -12) were posted (they were mostly comprised of editorial
	//     changes and clarifications and not changes to the wire
	//     protocol), values 9, 10, 11, and 12 were not used as valid
	//     values for Sec-WebSocket-Version.  These values were reserved in
	//     the IANA registry but were not and will not be used.

	// 10.  The request MAY include a header field with the name
	//     |Sec-WebSocket-Protocol|.  If present, this value indicates one
	//     or more comma-separated subprotocol the client wishes to speak,
	//     ordered by preference.  The elements that comprise this value
	//     MUST be non-empty strings with characters in the range U+0021 to
	//     U+007E not including separator characters as defined in
	//     [RFC2616] and MUST all be unique strings.  The ABNF for the
	//     value of this header field is 1#token, where the definitions of
	//     constructs and rules are as given in [RFC2616].

	// 11.  The request MAY include a header field with the name
	//     |Sec-WebSocket-Extensions|.  If present, this value indicates
	//     the protocol-level extension(s) the client wishes to speak.  The
	//     interpretation and format of this header field is described in
	//     Section 9.1.

	// 12.  The request MAY include any other header fields, for example,
	//     cookies [RFC6265] and/or authentication-related header fields
	//     such as the |Authorization| header field [RFC2616], which are
	//     processed according to documents that define them.

	challenge_key := generate_challenge_key()
	defer delete(challenge_key)

	converted_url, conversion_ok := convert_scheme(url, context.temp_allocator)
	if !conversion_ok {
		log.errorf("FAILED - Failed to convert ws url: %v\n", url)
		status = .Handshake_Failure

		return
	}

	req := request_init(context.temp_allocator)
	request_url(req, converted_url)
	request_method(req, .Get)
	host: string = req.url.host

	if len(req.url.port) > 0 {
		host = fmt.tprintf("%v:%v", host, req.url.port)
	}

	request_add_header(req, "Host", host)

	// REQUIRED - The WebSocket server will return an 400 Bad Request if the following are not present in the handshake
	request_add_header(req, "Upgrade", "websocket")
	request_add_header(req, "Connection", "Upgrade")
	request_add_header(req, "Sec-WebSocket-Key", challenge_key)
	request_add_header(req, "Sec-WebSocket-Version", WEBSOCKET_VERSION)

	socket, err := net.dial_tcp(host)

	if err != nil {
		log.errorf("FAILED - Failed to create socket to %v: %v\n", host, err)
		status = .Handshake_Failure

		return
	} else {
		log.info("Socket successfully created")
	}

	// Send the handshake
	_, ok := send(&socket, req)
	if !ok {
		log.error("ERROR - Failed to send handshake request..")
		status = .Handshake_Failure

		return
	}

	// Handle Reponse
	// -----------
	// See [Section 4.1, Page 19 of RFC 6455](https://datatracker.ietf.org/doc/html/rfc6455)

	// 1.  If the status code received from the server is not 101, the
	//     client handles the response per HTTP [RFC2616] procedures.  In
	//     particular, the client might perform authentication if it
	//     receives a 401 status code; the server might redirect the client
	//     using a 3xx status code (but clients are not required to follow
	//     them), etc.  Otherwise, proceed as follows.

	// 2.  If the response lacks an |Upgrade| header field or the |Upgrade|
	//     header field contains a value that is not an ASCII case-
	//     insensitive match for the value "websocket", the client MUST
	//     _Fail the WebSocket Connection_.

	// 3.  If the response lacks a |Connection| header field or the
	//     |Connection| header field doesn't contain a token that is an
	//     ASCII case-insensitive match for the value "Upgrade", the client
	//     MUST _Fail the WebSocket Connection_.

	// 4.  If the response lacks a |Sec-WebSocket-Accept| header field or
	//     the |Sec-WebSocket-Accept| contains a value other than the
	//     base64-encoded SHA-1 of the concatenation of the |Sec-WebSocket-
	//     Key| (as a string, not base64-decoded) with the string "258EAFA5-
	//     E914-47DA-95CA-C5AB0DC85B11" but ignoring any leading and
	//     trailing whitespace, the client MUST _Fail the WebSocket
	//     Connection_.

	// 5.  If the response includes a |Sec-WebSocket-Extensions| header
	//     field and this header field indicates the use of an extension
	//     that was not present in the client's handshake (the server has
	//     indicated an extension not requested by the client), the client
	//     MUST _Fail the WebSocket Connection_.  (The parsing of this
	//     header field to determine which extensions are requested is
	//     discussed in Section 9.1.)

	// 6.  If the response includes a |Sec-WebSocket-Protocol| header field
	//     and this header field indicates the use of a subprotocol that was
	//     not present in the client's handshake (the server has indicated a
	//     subprotocol not requested by the client), the client MUST _Fail
	//     the WebSocket Connection_.

	resp, resp_ok := recv(socket, allocator)
	if !resp_ok {
		log.errorf("ERROR - Failed to read response\n")
		status = .Handshake_Failure
		return
	}
	defer response_destroy(resp, allocator)

	// HTTP/1.1 400 Bad Request
	// HTTP/1.1 101 Switching Protocols
	if resp.status != .Switching_Protocols {
		log.errorf(
			"ERROR - Handshake response HTTP code, expected: '101' actual: '%v'\n",
			resp.status,
		)
		status = .Handshake_Failure
		return
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
		case .Not_Connected,
		     .Connection_Closed,
		     .Network_Unreachable,
		     .Timeout,
		     .Invalid_Argument,
		     .Insufficient_Resources:
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

/*
Generates a 16-byte nonce challenge key 

__WARNING__: The calling party is responsible for de-allocating the returned string

See [Section 4.1, Bullet 7 of RFC 6455](https://datatracker.ietf.org/doc/html/rfc6455#autoid-15)
*/
generate_challenge_key :: proc(allocator := context.allocator) -> string {
	data: [16]byte
	bytes_read := rand.read(data[:])
	log.debugf("Read {} bytes\n", bytes_read)

	return base64.encode(data[:], base64.ENC_TABLE, allocator)
}
