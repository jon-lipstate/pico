package pico
import "core:os"
import "core:strings"
import "core:fmt"
import "core:mem"
import "core:unicode/utf8"
import "./ansi_codes"
import "./gap_buffer"

STATUS_LINE :: 1
Terminal :: struct {
	dims:          [2]int,
	render_cursor: [2]int,
	line_offset:   int,
	buffer:        TextBuffer,
	screen_buffer: strings.Builder,
	status_line:   [dynamic]u8,
}
make_terminal :: proc(n_bytes: int = 4) -> Terminal {
	t := Terminal{}
	t.dims = _get_window_size()
	t.screen_buffer = strings.builder_make_len_cap(0, t.dims.x * t.dims.y)
	t.status_line = make([dynamic]u8, t.dims.y)
	clear_status_line(&t)
	t.dims.x -= STATUS_LINE
	t.buffer = make_text_buffer(n_bytes)
	t.render_cursor = {1, 1}
	t.buffer.cursor = 0
	return t
}

update_render_cursor :: proc(t: ^Terminal) {
	abs_row := 0
	end_of_buffer := gap_buffer.length_of(&t.buffer.gb)
	// TODO: Binary Search
	for starts_at, i in t.buffer.lines {
		past_start_of_row := t.buffer.cursor >= starts_at
		on_last_row := i == len(t.buffer.lines) - 1
		// Are we in this row?
		if past_start_of_row && (on_last_row || t.buffer.cursor < t.buffer.lines[i + 1]) {
			t.render_cursor.y = t.buffer.cursor - starts_at + 1 // term is 1-space
			abs_row = i
			break
		}
	}

	need_to_move := abs_row - t.line_offset - (t.render_cursor.x - 1)
	if need_to_move < 0 {
		balance := min(abs(need_to_move), t.render_cursor.x - 1) // mutate in zero-space, dont need to xform back
		t.render_cursor.x -= balance
		t.line_offset -= abs(need_to_move) - balance
	} else if need_to_move > 0 {
		balance := min(need_to_move, t.dims.x - t.render_cursor.x)
		t.render_cursor.x += balance
		t.line_offset += need_to_move - balance
	}
	return
}
move_cursor_by_pages :: proc(t: ^Terminal, n: int) {
	if len(t.buffer.lines) == 0 {return}

	move_by := n * t.dims.x
	requested_offset := move_by + t.line_offset
	actual_offset := clamp(requested_offset, 0, len(t.buffer.lines) - t.dims.x)

	overstep := abs(actual_offset - requested_offset) // todo:remove abs, not really needed
	overstep *= n < 0 ? -1 : 1
	t.line_offset = actual_offset

	t.render_cursor.x = clamp(t.render_cursor.x + overstep, 1, t.dims.x)

	abs_line := t.line_offset + t.render_cursor.x - 1
	starts_at := t.buffer.lines[abs_line]
	col := min(t.render_cursor.y - 1, line_length(&t.buffer, abs_line))
	t.buffer.cursor = starts_at + col
}
move_cursor_by_lines :: proc(t: ^Terminal, n: int) {
	if len(t.buffer.lines) == 0 {return}
	row := (t.render_cursor.x - 1) + n
	need_to_move := 0
	if row < 0 {
		need_to_move = row
		row = 0
	} else if row > t.dims.x {
		need_to_move = row - t.dims.x
		row = t.dims.x
	}
	t.line_offset = clamp(t.line_offset + need_to_move, 0, len(t.buffer.lines) - 1)
	abs_line := clamp(t.line_offset + row, 0, len(t.buffer.lines) - 1)
	starts_at := t.buffer.lines[abs_line]
	col := min(t.render_cursor.y - 1, line_length(&t.buffer, abs_line) - 1)

	t.buffer.cursor = starts_at + col
}
// TODO: maybe move into textbuffer?
move_cursor_by_runes :: proc(t: ^Terminal, n: int) {
	buffer := t.buffer.gb.buf
	cursor := t.buffer.cursor
	if n > 0 {
		for i := 0; i < n; i += 1 {
			if cursor >= len(buffer) {break}
			r, rune_size := utf8.decode_rune_in_bytes(buffer[cursor:])
			cursor += rune_size
		}
	} else {
		for i := 0; i > n; i -= 1 {
			if cursor <= 0 {break}
			r, rune_size := utf8.decode_last_rune_in_bytes(buffer[:cursor])
			cursor -= rune_size
		}
	}
	t.buffer.cursor = clamp(cursor, 0, length_of(&t.buffer))
}

clear_status_line :: proc(t: ^Terminal) {
	mem.set(&t.status_line[0], ' ', len(t.status_line))
}
write_status_line :: proc(t: ^Terminal) {
	fmt.bprintf(
		t.status_line[:],
		"[%v,%v] | Offset: %v | Cursor: %v/%v | nLines: %v | CTRL+X: Save & Exit | CTRL+Q: Quit, No Save",
		t.render_cursor.x,
		t.render_cursor.y,
		t.line_offset,
		t.buffer.cursor,
		length_of(&t.buffer),
		len(t.buffer.lines),
	)
}
get_visible_cursors :: proc(t: ^Terminal) -> (start, end: int) {
	if len(t.buffer.lines) == 0 {
		end = length_of(&t.buffer)
		return
	}
	start = t.buffer.lines[t.line_offset]
	last_line := min(len(t.buffer.lines) - 1, t.line_offset + t.dims.x)
	if last_line == len(t.buffer.lines) - 1 {
		end = length_of(&t.buffer)
	} else {
		end = t.buffer.lines[last_line]
	}
	return
}

RUNNING := true
SHOULD_SAVE := false
main :: proc() {
	args := os.args
	if len(args) != 2 {
		fmt.println("Invalid args - expected 'pico file_name.ext'")
		os.exit(1)
	}
	f, e := os.open(args[1], os.O_CREATE | os.O_RDWR, 0o644)
	if os.INVALID_HANDLE == f {fmt.println("Bad Handle");os.exit(1)}
	if e < 0 {fmt.printf("File open error 0x%x", -e);os.exit(1)}

	using ansi_codes
	_set_terminal();defer _restore_terminal()
	alt_buffer_mode(true);defer alt_buffer_mode(false)

	fs, err := os.file_size(f);assert(err > -1)
	t := make_terminal(int(fs))
	if fs > 0 {
		ok := insert_file_at(&t.buffer, 0, f)
		if !ok {
			alt_buffer_mode(false)
			_restore_terminal()
			fmt.println("failed to read input file. aborting.")
			os.exit(1)
		}
	}

	// First Paint
	t.buffer.cursor = 0
	render(&t)
	move_to(t.render_cursor.x, t.render_cursor.y)

	for RUNNING {
		if update(&t) {
			update_render_cursor(&t)
			render(&t)
		}
		move_to(t.render_cursor.x, t.render_cursor.y)
	}
	if SHOULD_SAVE {
		os.close(f)
		f, e = os.open(args[1], os.O_TRUNC | os.O_WRONLY, 0o644)
		assert(e > -1, "Error")
		assert(f != os.INVALID_HANDLE, "Bad Handle")
		flush_to_file(&t.buffer, f)
	}
}

render :: proc(t: ^Terminal) {
	using ansi_codes
	erase(.All) // TODO: repaint only touched?
	// Status Line:
	write_status_line(t)
	move_to(t.dims.x + STATUS_LINE, 0)
	set_graphic_rendition(.Bright_Cyan_Background)
	color_ansi(.Black)
	fmt.print(string(t.status_line[:]))
	move_to(t.dims.x + STATUS_LINE, 0)
	reset()

	// Screen Render
	move_to(1, 1)
	start, end := get_visible_cursors(t)
	print_range(&t.buffer, &t.screen_buffer, start, end)
	set_graphic_rendition(.Bright_Black_Background)
	str := strings.to_string(t.screen_buffer)
	when ODIN_OS == .Windows {
		fmt.print(str)
	} else {
		// Posix really wants \r on the screen, and we dont in our buffer
		prev := 0
		for c, i in str {
			if c == '\n' {
				fmt.print(string(str[prev:i]))
				fmt.print("\r\n")
				prev = i + 1
			}
		}
		fmt.print(string(str[prev:len(str)]))
	}
	reset()
	clear(&t.screen_buffer.buf)
	clear_status_line(t)
}

update :: proc(t: ^Terminal) -> bool {
	@(static)
	buf: [1024]u8
	buf[1] = 0 // Guard for ESC todo: is this really needed?
	n_read, err := os.read(os.stdin, buf[:])
	//Status Print:
	free_all(context.temp_allocator)
	print_buf := fmt.tprintf("%x", buf[:n_read])
	fmt.bprint(t.status_line[t.dims.y - len(print_buf):], print_buf)

	for i := 0; i < n_read; i += 1 {
		char := buf[i]
		if char == CTRL_Q {
			RUNNING = false
			break
		} else if char == CTRL_X {
			RUNNING = false
			SHOULD_SAVE = true
			break
		}
		if char == ESC {
			// Arrows - TODO: Guard for `i > n`
			if buf[i + 1] == 0x5b {
				// ESC [ 0x5B ARROW_CODE
				i += 2
				switch buf[i] {
				case ARROW_UP:
					move_cursor_by_lines(t, -1)
				case ARROW_DOWN:
					move_cursor_by_lines(t, 1)
				case ARROW_LEFT:
					move_cursor_by_runes(t, -1)
				case ARROW_RIGHT:
					move_cursor_by_runes(t, 1)
				case HOME:
					n := t.render_cursor.y - 1
					move_cursor_by_runes(t, -n)
				case END:
					current_line := t.line_offset + t.render_cursor.x - 1
					ll := line_length(&t.buffer, current_line)
					n := ll - t.render_cursor.y
					move_cursor_by_runes(t, n)
					// bandaid - sometimes end does not actually land on the end..?
					r := rune_at(&t.buffer, t.buffer.cursor)
					if r != '\n' {move_cursor_by_runes(t, 1)}
				case PAGE_UP:
					move_cursor_by_pages(t, -1)
				case PAGE_DOWN:
					move_cursor_by_pages(t, 1)
				case 0x33:
					if buf[i + 1] == DEL {
						remove_at(&t.buffer, t.buffer.cursor, 1)
					} else if buf[i + 1] == BKSP {
						remove_at(&t.buffer, t.buffer.cursor, -1)
					}
				}
			}
			break
		} else if buf[i] == DEL {
			// posix
			remove_at(&t.buffer, t.buffer.cursor, 1)
		} else if buf[i] == BKSP {
			// posix
			remove_at(&t.buffer, t.buffer.cursor, -1)
		} else {
			s := [1]u8{char} // TODO: process more than one char at a time
			if char == '\r' || char == '\n' {
				insert_at(&t.buffer, t.buffer.cursor, "\n")
			} else {
				// TODO: prune non-ascii chars?
				insert_at(&t.buffer, t.buffer.cursor, string(s[:]))
			}
		}
	}
	return n_read > 0
}

//ctrl+letter = ascii - 64 (0x40)
ESC :: 0x1b

CTRL_C :: 0x03
CTRL_X :: 0x18
CTRL_Q :: 0x11

DEL :: 0x7e
BKSP :: 0x7f

HOME :: 0x48 // CTRL+ [1b, 5b, 31, 3b, 35, 48],
END :: 0x46
PAGE_UP :: 0x35 //[1b, 5b, 35, 7e]
PAGE_DOWN :: 0x36 // [1b, 5b, 36, 7e]

ARROW_UP :: 0x41 // A
ARROW_DOWN :: 0x42 // B
ARROW_RIGHT :: 0x43 // C
ARROW_LEFT :: 0x44 // D
