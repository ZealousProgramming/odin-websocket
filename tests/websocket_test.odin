package websocket_tests

import "core:testing"

import websocket "../"

EXPECTED_RESULT_TEMPLATE :: "Expected: %v, Actual: %v"


Convert_Scheme_Test :: struct {
	url:       string,
	converted: string,
	ok:        bool,
}

convert_scheme_tests :: []Convert_Scheme_Test {
	{url = "ws://localhost:8080", converted = "http://localhost:8080", ok = true},
	{url = "wss://wakkawakka.io", converted = "https://wakkawakka.io", ok = true},
	{url = "wsssss://radda.io", converted = "", ok = false},
	{url = "ps://facts.com", converted = "", ok = false},
	{url = "ps://wakkawakka.io", converted = "", ok = false},
	{url = "vvs://wakkawakka.io", converted = "", ok = false},
}

@(test)
test_convert_scheme :: proc(t: ^testing.T) {

	for cst in convert_scheme_tests {
		url, ok := websocket.convert_scheme(cst.url, context.temp_allocator)

		testing.expect_value(t, ok, cst.ok)

		testing.expectf(t, url == cst.converted, EXPECTED_RESULT_TEMPLATE, cst.converted, url)

		if !ok {
			delete(url)
		}
	}
}
