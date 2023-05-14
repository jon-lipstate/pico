package ansi_codes
import "core:fmt"
//https://en.wikipedia.org/wiki/ANSI_escape_code
print_ansi_sgr_table :: proc() {
	for i := 0; i < 11; i += 1 {
		for j := 0; j < 10; j += 1 {
			n := 10 * i + j
			if n > 108 {break}
			fmt.printf(" \x1b[%dm%3d\x1b[m", n, n)
		}
		fmt.println()
	}
}

title :: proc(str: string) {
	fmt.printf("\x1b]0;%s\a", str)
}

// `text:false` for background
color :: proc {
	color_ansi,
	color_rgb,
}
// `text:false` for background
color_rgb :: proc(r, g, b: int, text := true) {
	c := text ? '3' : '4'
	fmt.printf("\x1b[%v8;2;%d;%d;%dm", c, r, g, b)
}
Ansi_Color :: enum {
	Black = 0,
	Red,
	Green,
	Yellow,
	Blue,
	Magenta,
	Cyan,
	White,
	Gray,
	Default,
}
// `text:false` for background
color_ansi :: proc(color: Ansi_Color, text := true) {
	c := text ? '3' : '4'
	fmt.printf("\x1b[%v%dm", c, color)
}
SGR :: enum {
	Reset,
	Bold,
	Faint,
	Italic,
	Underline,
	Slow_Blink,
	Rapid_Blink,
	Invert_Colors,
	Conceal, // Poor Support
	Strike_Through, // Not supported by Terminal.app
	Primary_Font,
	Alt_Font_1,
	Alt_Font_2,
	Alt_Font_3,
	Alt_Font_4,
	Alt_Font_5,
	Alt_Font_6,
	Alt_Font_7,
	Alt_Font_8,
	Alt_Font_9,
	Alt_Font_Fraktur,
	Double_Underline,
	Normal_Intensity,
	Neither_Italic_nor_Blackletter,
	Not_Underlined,
	Not_Blinking,
	Porportional_Spacing,
	Not_Invert_Colors,
	Not_Conceal, // !Conceal
	Not_Strikethrough,
	Black_Text = 30,
	Red_Text = 31,
	Green_Text = 32,
	Yellow_Text = 33,
	Blue_Text = 34,
	Magenta_Text = 35,
	Cyan_Text = 36,
	White_Text = 37,
	// use color_rgb
	Default_Text = 39,
	Black_Background = 40,
	Red_Background = 41,
	Green_Background = 42,
	Yellow_Background = 43,
	Blue_Background = 44,
	Magenta_Background = 45,
	Cyan_Background = 46,
	White_Background = 47,
	// use color_rgb
	Default_Background = 49,
	Disable_Proportional_Spacing = 50,
	//
	Bright_Black_Text = 90,
	Bright_Red_Text = 91,
	Bright_Green_Text = 92,
	Bright_Yellow_Text = 93,
	Bright_Blue_Text = 94,
	Bright_Magenta_Text = 95,
	Bright_Cyan_Text = 96,
	Bright_White_Text = 97,
	//
	Bright_Black_Background = 100,
	Bright_Red_Background = 101,
	Bright_Green_Background = 102,
	Bright_Yellow_Background = 103,
	Bright_Blue_Background = 104,
	Bright_Magenta_Background = 105,
	Bright_Cyan_Background = 106,
	Bright_White_Background = 107,
}
set_graphic_rendition :: proc(sgr: SGR) {
	fmt.printf("\x1b[%dm", sgr)
}
color_bright :: proc(color: Ansi_Color, text := true) {
	c := text ? "9" : "10"
	fmt.printf("\x1b[%v%d;1m", c, color)
}
reset :: proc() {
	fmt.print("\x1b[m")
}

move_up :: proc(n: int = 1) {
	fmt.printf("\x1b[%dA", n)
}
move_down :: proc(n: int = 1) {
	fmt.printf("\x1b[%dB", n)
}
move_right :: proc(n: int = 1) {
	fmt.printf("\x1b[%dC", n)
}
move_left :: proc(n: int = 1) {
	fmt.printf("\x1b[%dD", n)
}
// Down & to Start
move_next_line :: proc(n: int = 1) {
	fmt.printf("\x1b[%dE", n)
}
move_prev_line :: proc(n: int = 1) {
	fmt.printf("\x1b[%dF", n)
}
move_horiz_abs :: proc(col: int = 1) {
	fmt.printf("\x1b[%dG", col)
}
move_to :: proc(r: int = 1, c: int = 1, hvp := false) {
	fmt.printf("\x1b[%d;%d%v", r, c, hvp ? 'f' : 'H')
}
Erase_Codes :: enum {
	FromCursorToEnd,
	FromCursorToBegin,
	All,
	Screen_And_Backbuffer, // not valid in `erase_line`
}
erase :: proc(code: Erase_Codes) {
	fmt.printf("\x1b[%dJ", code)
}
erase_line :: proc(code: Erase_Codes) {
	fmt.printf("\x1b[%dK", code)
}
scroll_up :: proc(n: int) {
	fmt.printf("\x1b[%dS", n)
}
scroll_down :: proc(n: int) {
	fmt.printf("\x1b[%dT", n)
}
store_cursor :: proc() {
	fmt.printf("\x1b[s")
}
restore_cursor :: proc() {
	fmt.printf("\x1b[u")
}
show_cursor :: proc(show := true) {
	fmt.printf("\x1b[?25%v", show ? 'h' : 'l')
}
report_focus :: proc(enable := true) {
	fmt.printf("\x1b[?1004%v", enable ? 'h' : 'l')
}
bracketed_paste :: proc(enable := true) {
	fmt.printf("\x1b[?2004%v", enable ? 'h' : 'l')
}
alt_buffer_mode :: proc(enable := true) {
	fmt.printf("\x1b[?1049%v", enable ? 'h' : 'l')
}
