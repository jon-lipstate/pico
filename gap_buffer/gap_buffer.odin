package gap_buffer
import "core:unicode/utf8"
import "core:mem"
import "core:runtime"

BufferPosition :: int
GapBuffer :: struct {
	buf:       []u8, // Should be dynamic?
	gap_start: BufferPosition,
	gap_end:   BufferPosition,
	allocator: runtime.Allocator,
}
length_of :: proc(b: ^GapBuffer) -> int {
	gap := b.gap_end - b.gap_start
	return len(b.buf) - gap
}
// Gets strings that point into the left and right sides of the gap. Note that this is neither thread, or even operation safe.
// Strings need to be immediately cloned or operated on prior to editing the buffer again.
get_strings :: proc(b: ^GapBuffer) -> (left: string, right: string) {
	left = string(b.buf[:b.gap_start])
	right = string(b.buf[b.gap_end:])
	return
}
// Allocates the Gap Buffer, stores the provided allocator for all future reallocations
make_gap_buffer :: proc(n_bytes: int, allocator := context.allocator) -> GapBuffer {
	b := GapBuffer {
		buf       = make([]u8, n_bytes, allocator),
		gap_end   = n_bytes,
		allocator = allocator,
	}
	return b
}
// Deletes the internal buffer
destroy_gap_buffer :: proc(b: ^GapBuffer) {
	delete(b.buf)
}
// Moves the Gap to the cursor position. Cursors are clamped [0,n) where n is the filled count of the buffer.
shift_gap_to :: proc(b: ^GapBuffer, cursor: BufferPosition) {
	gap_len := b.gap_end - b.gap_start
	cursor := clamp(cursor, 0, len(b.buf) - gap_len)
	if cursor == b.gap_start {return}

	if b.gap_start < cursor {
		// Gap is before the cursor:
		//   v~~~~v
		//[12]           [3456789abc]
		//--------|------------------ Gap is BEFORE Cursor
		//[123456]           [789abc]
		delta := cursor - b.gap_start
		mem.copy(&b.buf[b.gap_start], &b.buf[b.gap_end], delta)
		b.gap_start += delta
		b.gap_end += delta
	} else if b.gap_start > cursor {
		// Gap is after the cursor
		//   v~~~v
		//[123456]           [789abc]
		//---|----------------------- Gap is AFTER Cursor
		//[12]           [3456789abc]
		delta := b.gap_start - cursor
		mem.copy(&b.buf[b.gap_end - delta], &b.buf[b.gap_start - delta], delta)
		b.gap_start -= delta
		b.gap_end -= delta
	}
}
// Verifies the buffer can hold the needed write. Resizes the array if not. By default doubles array size.
check_gap_size :: proc(b: ^GapBuffer, n_required: int) {
	gap_len := b.gap_end - b.gap_start
	if gap_len < n_required {
		shift_gap_to(b, len(b.buf) - gap_len)
		req_buf_size := n_required + len(b.buf) - gap_len
		new_buf := make([]u8, 2 * req_buf_size, b.allocator)
		copy_slice(new_buf, b.buf[:b.gap_end])
		delete(b.buf)
		b.buf = new_buf
		b.gap_end = len(b.buf)
	}
}
// Moves the gap to the cursor, then moves the gap pointer beyond count, effectively deleting it.  
// Note: Do not rely on the gap being 0, remove will leave as-is values behind in the gap  
// WARNING: Does not protect for unicode at present, simply deletes bytes  
remove :: proc(b: ^GapBuffer, cursor: BufferPosition, count: int) {
	n_del := abs(count)
	eff_cursor := cursor
	if count < 0 {eff_cursor = max(0, eff_cursor - n_del)}
	shift_gap_to(b, eff_cursor)
	b.gap_end = min(b.gap_end + n_del, len(b.buf))
}
// Inserts into the gap buffer, note that rune and char collide, so they need wrapped in a cast to inform the compiler which you're calling
insert :: proc {
	insert_char,
	insert_rune,
	insert_slice,
	insert_string,
}

insert_char :: proc(b: ^GapBuffer, cursor: BufferPosition, char: u8) {
	check_gap_size(b, 1)
	shift_gap_to(b, cursor)
	b.buf[b.gap_start] = char
	b.gap_start += 1
}
insert_rune :: proc(b: ^GapBuffer, cursor: BufferPosition, r: rune) {
	bytes, length := utf8.encode_rune(r)
	insert_slice(b, cursor, bytes[:length])
}
insert_slice :: proc(b: ^GapBuffer, cursor: BufferPosition, slice: []u8) {
	check_gap_size(b, len(slice))
	shift_gap_to(b, cursor)
	copy_slice(b.buf[b.gap_start:], slice)
	b.gap_start += len(slice)
}
insert_string :: proc(b: ^GapBuffer, cursor: BufferPosition, str: string) {
	insert_slice(b, cursor, transmute([]u8)str)
}
