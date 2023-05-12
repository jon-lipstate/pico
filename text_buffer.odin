package pico
import "core:strings"
import "core:fmt"
import "./gap_buffer"

TextBuffer :: struct {
	using gb: gap_buffer.GapBuffer,
	cursor:   int, // sb terminal?
	lines:    [dynamic]int, //starts_at
}
// O(n)
calculate_lines :: proc(b: ^TextBuffer) {
	using gap_buffer
	clear(&b.lines)
	left, right := get_strings(&b.gb)
	append(&b.lines, 0) // start of file
	// TODO: AVX Scanning?
	// TODO: Only invalidate post-cursor
	// TODO: Handle Wrapping Screenwidth
	for i := 0; i < len(left); i += 1 {
		if left[i] == '\n' {append(&b.lines, i + 1)}
	}
	for i := 0; i < len(right); i += 1 {
		if left[i] == '\n' {append(&b.lines, len(left) + i + 1)}
	}
}

length_of :: proc(b: ^TextBuffer) -> int {
	return gap_buffer.length_of(&b.gb)
}

line_length :: proc(b: ^TextBuffer, the_line: int) -> int {
	fmt.assertf(the_line >= 0 && the_line <= len(b.lines), "invalid line %v", the_line)
	//Last Line:
	if the_line >= len(b.lines) - 1 {
		buf_len := length_of(b)
		return buf_len - b.lines[len(b.lines) - 1]
	} else {
		starts_at := b.lines[the_line]
		next_at := b.lines[the_line + 1]
		return next_at - starts_at
	}
}

insert_at :: proc(b: ^TextBuffer, cursor: int, s: string) {
	gap_buffer.insert(&b.gb, cursor, s)
	b.cursor += len(s)
	calculate_lines(b)
}

remove_at :: proc(b: ^TextBuffer, cursor: int, count: int) {
	eff_cursor := cursor
	if count < 0 {eff_cursor -= 2} 	// Backspace
	gap_buffer.remove(&b.gb, cursor, count)
	if count < 0 {b.cursor = max(0, b.cursor + count)}
	calculate_lines(b)
}
// TODO: actual UTF8 support
rune_at :: proc(b: ^TextBuffer) -> rune {
	cursor := clamp(b.cursor, 0, length_of(b) - 1)
	left, right := gap_buffer.get_strings(&b.gb)
	if cursor < len(left) {
		return rune(left[cursor])
	} else {
		return rune(right[cursor])
	}
}
print_range :: proc(b: ^TextBuffer, buf: ^strings.Builder, start_cursor, end_cursor: int) {
	left, right := gap_buffer.get_strings(&b.gb)
	assert(start_cursor >= 0, "invalid start")
	assert(end_cursor <= length_of(b), "invalid end")

	left_len := len(left)
	if end_cursor < left_len {
		strings.write_string(buf, left[start_cursor:end_cursor])
	} else if start_cursor >= left_len {
		strings.write_string(buf, right[start_cursor:end_cursor])
	} else {
		strings.write_string(buf, left[start_cursor:])
		strings.write_string(buf, right[:end_cursor])
	}
}
