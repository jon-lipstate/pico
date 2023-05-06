// +build windows
// +private
package pico
import win "core:sys/windows"
import "core:os"
import "./ansi_codes"

prev_in_mode: win.DWORD
prev_out_mode: win.DWORD
_set_terminal :: proc() {
	using win
	GetConsoleMode(HANDLE(os.stdin), &prev_in_mode)
	in_mode := prev_in_mode
	in_mode &= ~(ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT | ENABLE_PROCESSED_INPUT)
	in_mode |= ENABLE_WINDOW_INPUT | ENABLE_VIRTUAL_TERMINAL_INPUT
	SetConsoleMode(HANDLE(os.stdin), in_mode)

	GetConsoleMode(HANDLE(os.stdout), &prev_out_mode)
	out_mode := prev_out_mode
	out_mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING
	out_mode &= ~ENABLE_WRAP_AT_EOL_OUTPUT
	SetConsoleMode(HANDLE(os.stdout), out_mode)
}
_restore_terminal :: proc() {
	using win
	ansi_codes.reset()
	SetConsoleMode(HANDLE(os.stdin), prev_in_mode)
	SetConsoleMode(HANDLE(os.stdout), prev_out_mode)
}

_get_window_size :: proc() -> [2]int {
	using win
	sbi: CONSOLE_SCREEN_BUFFER_INFO
	ok := GetConsoleScreenBufferInfo(HANDLE(os.stdout), &sbi)
	if !ok {panic("failed to get screen info")}

	dims := [2]int{
		int(sbi.srWindow.Bottom - sbi.srWindow.Top) + 1,
		int(sbi.srWindow.Right - sbi.srWindow.Left) + 1,
	}
	return dims
}
