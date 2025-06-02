package websocket

import "core:bufio"
import "core:bytes"
import "core:fmt"
import "core:io"
import "core:log"
import "core:net"
import "core:strconv"
import "core:strings"

HTTPS :: "https"
HTTP :: "http"

Headers :: map[string]string

Method :: enum {
	Get,
	Post,
}

Status_Code :: enum (int) {
	Continue            = 100,
	Switching_Protocols = 101,
	Success             = 200,
	Bad_Request         = 400,
	Unauthorized        = 401,
	Forbidden           = 403,
	Not_Found           = 404,
}

URL :: struct {
	protocol: string,
	host:     string,
	port:     string,
	path:     string,
	query:    string,
}


Request :: struct {
	method:  Method,
	headers: Headers,
	url:     URL,
}

Response :: struct {
	status:  Status_Code,
	headers: Headers,
	body:    string, //TODO(devon): Determine if thias project actually needs to use the body
}

method_to_string :: proc(method: Method) -> string {
	switch method {
	case .Get:
		{
			return "GET"
		}
	case .Post:
		{
			return "POST"
		}
	}

	return "N/A"
}

request_init :: proc(allocator := context.allocator) -> ^Request {
	req := new(Request, allocator)

	req.headers = make(Headers, allocator)

	return req
}

request_destory :: proc(req: ^Request, allocator := context.allocator) {
	delete(req.headers)

	free(req, allocator)
}

request_method :: proc(req: ^Request, method: Method) {
	req.method = method
}

request_url :: proc(req: ^Request, full_url: string, allocator := context.allocator) {
	url, err := parse_url(full_url, allocator)
	if err {
		log.errorf("ERROR - Failed to parse URL")
	}
	req.url = url
}

request_add_header :: proc(req: ^Request, key: string, value: string, overwrite := false) {
	if key in req.headers && !overwrite {
		log.warnf(
			"Attempted to add header(%v) of value(%v) to HTTP request, but the header already exists and overwrite flag not set..",
		)
		return
	}

	log.debug("Header(%v) of value(%v) added to HTTP request..")
	req.headers[key] = value
}

response_destroy :: proc(resp: ^Response, allocator := context.allocator) {
	delete(resp.headers)

	free(resp, allocator)
}

/*
NOTE(devon) This is crap, replace in the future. Just a quick and dirty to get to the real problem at hand

__Does not handle malformed urls__! The caller of this function will either need to create their own parser,
 or will need to be responsible validating the urls prior to passing it into the function
*/
parse_url :: proc(raw_url: string, allocator := context.allocator) -> (url: URL, err: bool) {
	log.debug("Parsing url: %v\n", raw_url)

	start_index: int = 7 // http://

	if strings.starts_with(raw_url, "https://") {
		url.protocol = HTTPS
		start_index = 8
	} else if strings.starts_with(raw_url, "http://") {
		url.protocol = HTTP
	} else {
		// some.unsecure.com/ will be resolved to http
		// localhost:3000 will be resolved to http 
		// 127.0.0.1:3000 will be resolved to http 
		url.protocol = HTTP
		start_index = 0
	}

	reader: strings.Reader
	strings.reader_init(&reader, raw_url)
	strings.reader_seek(&reader, i64(start_index), .Start)

	has_port := false

	// Extract host
	for {
		r, _, r_err := strings.reader_read_rune(&reader)
		if r_err == .EOF {
			url.host = strings.cut(raw_url, start_index, int(reader.i) - start_index)
			// log.errorf("ERROR - Invalid URL: %v\n", raw_url)
			// err = true
			return
		}

		// Start of the port
		if r == ':' {
			url.host = strings.cut(raw_url, start_index, int(reader.i) - 1 - start_index)
			start_index = int(reader.i)
			has_port = true
			break
		}

		// No port
		if r == '/' {
			url.host = strings.cut(raw_url, start_index, int(reader.i) - 1 - start_index)
			start_index = int(reader.i)
			break
		}
	}

	// Extract port, if it exists
	if has_port {
		for {
			r, _, r_err := strings.reader_read_rune(&reader)

			// Start of the path
			if r == '/' {
				url.port = strings.cut(raw_url, start_index, int(reader.i) - 1 - start_index)
				start_index = int(reader.i)
				break
			}

			if r_err == .EOF {
				url.port = strings.cut(raw_url, start_index, int(reader.i) - start_index)
				return
			}

		}
	}

	// Extract path
	for {
		r, _, r_err := strings.reader_read_rune(&reader)

		// Start of the path
		if r == '?' {
			url.path = strings.cut(raw_url, start_index, int(reader.i) - 1 - start_index)
			start_index = int(reader.i)
			break
		}

		if r_err == .EOF {
			url.path = strings.cut(raw_url, start_index, int(reader.i) - start_index)

			return
		}
	}

	// TODO(devon): Query support

	return
}

send :: proc(socket: ^net.TCP_Socket, req: ^Request) -> (n: int, ok: bool) {

	buffer: bytes.Buffer
	defer bytes.buffer_destroy(&buffer)

	// Request Start Line
	method: string = method_to_string(req.method)
	path: string = fmt.tprintf("%v /%v HTTP/1.1\r\n", method, req.url.path)
	bytes.buffer_write_string(&buffer, path)

	for k, v in req.headers {
		bytes.buffer_write_string(&buffer, fmt.tprintf("%v: %v\r\n", k, v))
	}

	// New line to separate the headers and the body (even if the body is empty)
	bytes.buffer_write_string(&buffer, "\r\n")

	data := bytes.buffer_to_bytes(&buffer)

	// Log Request
	request_log(data)

	// No SSL for now
	bytes_read, send_err := net.send_tcp(socket^, data)

	if send_err != nil {
		log.errorf("FAILED - Failed to send packet: %v\n", send_err)

		ok = false
		return
	} else {
		log.info("Handshake sent, awaiting reponse..\n")
	}

	n = bytes_read
	ok = true

	return
}

recv :: proc(
	socket: net.TCP_Socket,
	allocator := context.allocator,
) -> (
	resp: ^Response,
	ok: bool,
) {
	log.info("\n[RESPONSE]:\n")
	stream: io.Stream
	stream.data = rawptr(uintptr(socket))
	stream.procedure = socket_stream

	stream_reader := io.to_reader(stream)
	scanner: bufio.Scanner

	bufio.scanner_init(&scanner, stream_reader, allocator)
	defer bufio.scanner_destroy(&scanner)

	get_line :: proc(scanner: ^bufio.Scanner) -> (line: string, status: WebSocket_Error) {
		if !bufio.scanner_scan(scanner) {
			scan_err := bufio.scanner_error(scanner)

			log.errorf("ERROR - Scanner encountered an error: %v\n", scan_err)

			status = .Handshake_Failure
			return
		}

		line = bufio.scanner_text(scanner)
		log.debug(line)

		if len(transmute([]u8)line) <= 0 {
			status = .Nil
			return
		}

		return
	}

	// Get request start line
	start_line_raw, sl_err := get_line(&scanner)
	if sl_err != .Nil {
		ok = false
		return
	}

	sl_chunks, _ := strings.split(start_line_raw, " ", context.temp_allocator)

	resp = new(Response, allocator)

	// Get Headers
	response_headers: map[string]string

	for {
		next_line, err := get_line(&scanner)
		if err != .Nil {
			ok = false

			return
		}

		if next_line == "" {
			break
		}

		line_chunks, _ := strings.split(next_line, ":", context.temp_allocator)
		response_headers[line_chunks[0]] = line_chunks[1]
	}

	// Log the HTTP response
	builder: strings.Builder
	strings.builder_init(&builder, context.temp_allocator)

	strings.write_string(&builder, fmt.tprintf("\n\tStatus: %v\n", sl_chunks[1]))

	for k, v in response_headers {
		strings.write_string(&builder, fmt.tprintf("\t%v: %v\n", k, v))
	}


	log.info(strings.to_string(builder))
	status, _ := strconv.parse_i64(sl_chunks[1])
	resp.status = Status_Code(status)
	resp.headers = response_headers

	// Get Body
	strings.builder_reset(&builder)
	// response_body: [dynamic]string

	for {
		if scanner.done || scanner.start >= scanner.end {
			break
		}

		next_line, err := get_line(&scanner)

		if err != .Nil {
			ok = false
			return
		}

		if next_line == "" {
			break
		}
		log.info(next_line)

		strings.write_string(&builder, fmt.tprintf("\t%v\n", next_line))
	}

	log.info("\n[BODY]:\n")
	log.info(strings.to_string(builder))

	ok = true

	return
}

request_log :: proc(data: []byte) {
	log.debug("\n[REQUEST]:\n")
	log.debug(string(data))
}
