package websocket

import "core:log"

import builder "shared:odin-build"

main :: proc() {
	context.logger = log.create_console_logger(log.Level.Debug)
	defer log.destroy_console_logger(context.logger)

	builder.check_build_directory("./bin")

	// Build game
	builder.build("./examples/client", OUTPATH, "-debug -strict-style -vet -show-timings")

	// Formatting
	builder.execute_command("odinfmt -w .")
	builder.execute_command("odinfmt -w ./examples")
	builder.execute_command("odinfmt -w ./tests")

	// Run
	builder.run(OUTPATH)
}

//
EXE :: "./bin/odin-websocket"
OUTPATH :: EXE + ".exe" when ODIN_OS == .Windows else EXE
