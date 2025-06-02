package websocket_tests

// import "core:log"
import "core:testing"

import websocket "../"


URL_Test :: struct {
	full:     string,
	protocol: string,
	host:     string,
	port:     string,
	path:     string,
	query:    string,
}

url_tests :: []URL_Test {
	{
		full = "http://localhost:8080",
		protocol = websocket.HTTP,
		host = "localhost",
		port = "8080",
		path = "",
		query = "",
	},
	{
		full = "localhost:8080",
		protocol = websocket.HTTP,
		host = "localhost",
		port = "8080",
		path = "",
		query = "",
	},
	{
		full = "https://some.site.io",
		protocol = websocket.HTTPS,
		host = "some.site.io",
		port = "",
		path = "",
		query = "",
	},
	{
		full = "https://some.site.io/base_path",
		protocol = websocket.HTTPS,
		host = "some.site.io",
		port = "",
		path = "base_path",
		query = "",
	},
	{
		full = "https://some.site.io/base_path/nested_path",
		protocol = websocket.HTTPS,
		host = "some.site.io",
		port = "",
		path = "base_path/nested_path",
		query = "",
	},
	{
		full = "https://secure.com:443/raunchy/path",
		protocol = websocket.HTTPS,
		host = "secure.com",
		port = "443",
		path = "raunchy/path",
		query = "",
	},
}

@(test)
test_url :: proc(t: ^testing.T) {
	// context.logger = log.create_console_logger(log.Level.Info)
	// defer log.destroy_console_logger(context.logger)

	for ut in url_tests {
		url, err := websocket.parse_url(ut.full, context.temp_allocator)

		testing.expect_value(t, url.protocol, ut.protocol)

		testing.expectf(t, url.host == ut.host, EXPECTED_RESULT_TEMPLATE, ut.host, url.host)

		testing.expectf(t, url.port == ut.port, EXPECTED_RESULT_TEMPLATE, ut.port, url.port)

		testing.expectf(t, url.path == ut.path, EXPECTED_RESULT_TEMPLATE, ut.path, url.path)

		testing.expectf(t, url.query == ut.query, EXPECTED_RESULT_TEMPLATE, ut.query, url.query)

	}
}
