// +build linux
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

/* c_cc characters */
VINTR :: 0
VQUIT :: 1
VERASE :: 2
VKILL :: 3
VEOF :: 4
VTIME :: 5
VMIN :: 6
VSWTC :: 7
VSTART :: 8
VSTOP :: 9
VSUSP :: 10
VEOL :: 11
VREPRINT :: 12
VDISCARD :: 13
VWERASE :: 14
VLNEXT :: 15
VEOL2 :: 16

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
CBAUD :: 0o010017
B0 :: 0o000000 /* hang up */
B50 :: 0o000001
B75 :: 0o000002
B110 :: 0o000003
B134 :: 0o000004
B150 :: 0o000005
B200 :: 0o000006
B300 :: 0o000007
B600 :: 0o000010
B1200 :: 0o000011
B1800 :: 0o000012
B2400 :: 0o000013
B4800 :: 0o000014
B9600 :: 0o000015
B19200 :: 0o000016
B38400 :: 0o000017
EXTA :: "B19200"
EXTB :: "B38400"
CSIZE :: 0o000060
CS5 :: 0o000000
CS6 :: 0o000020
CS7 :: 0o000040
CS8 :: 0o000060
CSTOPB :: 0o000100
CREAD :: 0o000200
PARENB :: 0o000400
PARODD :: 0o001000
HUPCL :: 0o002000
CLOCAL :: 0o004000
CBAUDEX :: 0o010000
BOTHER :: 0o010000
B57600 :: 0o010001
B115200 :: 0o010002
B230400 :: 0o010003
B460800 :: 0o010004
B500000 :: 0o010005
B576000 :: 0o010006
B921600 :: 0o010007
B1000000 :: 0o010010
B1152000 :: 0o010011
B1500000 :: 0o010012
B2000000 :: 0o010013
B2500000 :: 0o010014
B3000000 :: 0o010015
B3500000 :: 0o010016
B4000000 :: 0o010017
CIBAUD :: 0o02003600000 /* input baud rate */
CMSPAR :: 0o10000000000 /* mark or space (stick) parity */
CRTSCTS :: 0o20000000000 /* flow control */

IBSHIFT :: 16 /* Shift from CBAUD to CIBAUD */

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

/* tcflow() and TCXONC use these */
TCOOFF :: 0
TCOON :: 1
TCIOFF :: 2
TCION :: 3

/* tcflush() and TCFLSH use these */
TCIFLUSH :: 0
TCOFLUSH :: 1
TCIOFLUSH :: 2

/* tcsetattr uses these */
TCSANOW :: 0
TCSADRAIN :: 1
TCSAFLUSH :: 2
