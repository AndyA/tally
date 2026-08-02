const std = @import("std");
const print = std.debug.print;
const Io = std.Io;

const serial = @import("serial");

pub fn main(init: std.process.Init) !void {
    var w_buf: [32]u8 = undefined;
    var dev = try Io.Dir.cwd().openFile(init.io, "/dev/serial0", .{ .mode = .read_write });
    defer dev.close(init.io);
    var w = dev.writer(init.io, &w_buf);

    try serial.configureSerialPort(dev, serial.SerialConfig{
        .baud_rate = 38400,
        .word_size = .eight,
        .parity = .even,
        .stop_bits = .one,
        .handshake = .none,
    });

    _ = try w.interface.write("\x81\x300123456789abcdef");
    try w.interface.flush();
}
