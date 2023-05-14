package pico
import "core:strings"
import "core:fmt"
import "core:os"
import "./gap_buffer"

TextBuffer :: struct {
	using gb: gap_buffer.GapBuffer,
	cursor:   int, // sb terminal?
	lines:    [dynamic]int, //starts_at
}
make_text_buffer :: proc(n_bytes: int = 64) -> TextBuffer {
	b := TextBuffer{}
	b.gb = gap_buffer.make_gap_buffer(max(64, n_bytes))
	return b
}
destroy_text_buffer :: proc(b: ^TextBuffer) {
	gap_buffer.destroy_gap_buffer(&b.gb)
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
		if right[i] == '\n' {append(&b.lines, len(left) + i + 1)}
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
// TODO: File Cursors(?)
insert_file_at :: proc(b: ^TextBuffer, cursor: int, handle: os.Handle) -> (ok: bool) {
	if handle == os.INVALID_HANDLE {return false}
	fs, err := os.file_size(handle)
	if err < 0 {return false}
	gap_buffer.check_gap_size(&b.gb, int(fs))
	gap_buffer.shift_gap_to(&b.gb, cursor)
	gb_slice := b.buf[b.gap_start:b.gap_end]
	n, rerr := os.read(handle, gb_slice)
	fmt.assertf(rerr > -1, "read err 0x%x", -rerr)
	assert(n == int(fs), "mismatched os.read")
	b.gap_start += n
	calculate_lines(b)
	return true
}
// TODO: Buffer/File Cursors (?)
// NOTE: Seeks to Start of File
flush_to_file :: proc(b: ^TextBuffer, handle: os.Handle) -> (ok: bool) {
	if handle == os.INVALID_HANDLE {return false}
	os.seek(handle, 0, os.SEEK_SET)
	left, right := gap_buffer.get_strings(&b.gb)
	os.write_string(handle, left)
	os.write_string(handle, right)
	return true
}
remove_at :: proc(b: ^TextBuffer, cursor: int, count: int) {
	eff_cursor := cursor
	if count < 0 {eff_cursor -= 2} 	// Backspace
	gap_buffer.remove(&b.gb, cursor, count)
	if count < 0 {b.cursor = max(0, b.cursor + count)}
	calculate_lines(b)
}
// TODO: actual UTF8 support
rune_at :: proc(b: ^TextBuffer, cursor: int) -> rune {
	cursor := clamp(cursor, 0, length_of(b) - 1)
	left, right := gap_buffer.get_strings(&b.gb)
	if cursor < len(left) {
		return rune(left[cursor])
	} else {
		return rune(right[cursor - len(left)])
	}
}
print_range :: proc(b: ^TextBuffer, buf: ^strings.Builder, start_cursor, end_cursor: int) {
	left, right := gap_buffer.get_strings(&b.gb)
	assert(start_cursor >= 0, "invalid start")
	assert(end_cursor <= length_of(b), "invalid end")

	left_len := len(left)
	if end_cursor <= left_len {
		strings.write_string(buf, left[start_cursor:end_cursor])
	} else if start_cursor >= left_len {
		strings.write_string(buf, right[start_cursor - left_len:end_cursor - left_len])
	} else {
		strings.write_string(buf, left[start_cursor:])
		strings.write_string(buf, right[0:end_cursor - left_len])
	}
}
