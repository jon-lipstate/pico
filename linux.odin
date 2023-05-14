// +build linux, darwin
package pico
import libc "core:c/libc"
import "core:c"
import nix "core:sys/unix"
import "core:os"

foreign import _libc "system:c"
@(default_calling_convention = "c")
foreign _libc {
	ioctl :: proc(fd: os.Handle, request: c.int, #c_vararg args: ..any) -> c.int ---
	tcgetattr :: proc(fd: os.Handle, termios_p: ^termios) -> c.int ---
	tcsetattr :: proc(fd: os.Handle, optional_actions: TCSetAttr_Optional_Actions, termios_p: ^termios) -> c.int ---
}

prev_term: termios

_set_terminal :: proc() {
	if tcgetattr(os.stdin, &prev_term) < 0 {
		panic("failed to GET terminal state")
	}
	term := prev_term
	term.c_iflag &= ~u32(BRKINT | ICRNL | INPCK | ISTRIP | IXON)
	term.c_oflag &= ~u32(OPOST)
	term.c_cflag |= u32(CS8) // ascii
	term.c_lflag &= ~u32(ECHO | ICANON | IEXTEN | ISIG)
	term.c_cc[VMIN] = 0
	term.c_cc[VTIME] = 0

	if tcsetattr(os.stdout, .FLUSH, &term) < 0 {
		panic("failed to SET terminal state")
	}
}

_restore_terminal :: proc() {
	tcsetattr(os.stdin, .FLUSH, &prev_term)
}

_get_window_size :: proc() -> [2]int {
	ws := winsize{}
	io_res := ioctl(os.stdout, TIOCGWINSZ, &ws)
	assert(io_res >= 0, "didnt get window size")
	dims := [2]int{int(ws.ws_row), int(ws.ws_col)}
	return dims
}

// from termios.h
TIOCGWINSZ :: 0x5413
winsize :: struct {
	ws_row:    u16, /* rows, in characters */
	ws_col:    u16, /* columns, in characters */
	ws_xpixel: u16, /* horizontal size, pixels */
	ws_ypixel: u16, /* vertical size, pixels */
}

// From /usr/include/asm-generic/termbits.h
termios :: struct {
	c_iflag:  c.uint,
	c_oflag:  c.uint,
	c_cflag:  c.uint,
	c_lflag:  c.uint,
	c_line:   u8,
	c_cc:     [32]u8, // [NCCS]::32
	c_ispeed: c.uint,
	c_ospeed: c.uint,
}

TCSetAttr_Optional_Actions :: enum c.int {
	NOW   = 0,
	DRAIN = 1,
	FLUSH = 2,
}

/* c_iflag bits */
IGNBRK :: 0o000001
BRKINT :: 0o000002
IGNPAR :: 0o000004
PARMRK :: 0o000010
INPCK :: 0o000020
ISTRIP :: 0o000040
INLCR :: 0o000100
IGNCR :: 0o000200
ICRNL :: 0o000400
IUCLC :: 0o001000
IXON :: 0o002000
IXANY :: 0o004000
IXOFF :: 0o010000
IMAXBEL :: 0o020000
IUTF8 :: 0o040000

/* c_oflag bits */
OPOST :: 0o000001
OLCUC :: 0o000002
ONLCR :: 0o000004
OCRNL :: 0o000010
ONOCR :: 0o000020
ONLRET :: 0o000040
OFILL :: 0o000100
OFDEL :: 0o000200
NLDLY :: 0o000400
NL0 :: 0o000000
NL1 :: 0o000400
CRDLY :: 0o003000
CR0 :: 0o000000
CR1 :: 0o001000
CR2 :: 0o002000
CR3 :: 0o003000
TABDLY :: 0o014000
TAB0 :: 0o000000
TAB1 :: 0o004000
TAB2 :: 0o010000
TAB3 :: 0o014000
XTABS :: 0o014000
BSDLY :: 0o020000
BS0 :: 0o000000
BS1 :: 0o020000
VTDLY :: 0o040000
VT0 :: 0o000000
VT1 :: 0o040000
FFDLY :: 0o100000
FF0 :: 0o000000
FF1 :: 0o100000

/* c_cflag bit meaning */
CS5 :: 0o000000
CS6 :: 0o000020
CS7 :: 0o000040
CS8 :: 0o000060
CSTOPB :: 0o000100
CREAD :: 0o000200
PARENB :: 0o000400
PARODD :: 0o001000
HUPCL :: 0o002000

/* c_lflag bits */
ISIG :: 0o000001
ICANON :: 0o000002
XCASE :: 0o000004
ECHO :: 0o000010
ECHOE :: 0o000020
ECHOK :: 0o000040
ECHONL :: 0o000100
NOFLSH :: 0o000200
TOSTOP :: 0o000400
ECHOCTL :: 0o001000
ECHOPRT :: 0o002000
ECHOKE :: 0o004000
FLUSHO :: 0o010000
PENDIN :: 0o040000
IEXTEN :: 0o100000
EXTPROC :: 0o200000

/* tcsetattr uses these */

TCSAFLUSH :: 2
