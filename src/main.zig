const std = @import("std");
const print = std.debug.print;
const Io = std.Io;

const serial = @import("serial");

const ADDR = 1;
const MESSAGE = "OK, ready, let's do it.  ";

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

    const msg = MESSAGE ++ MESSAGE;
    while (true) {
        for (0..MESSAGE.len) |pos| {
            _ = try w.interface.writeByte(0x80 | ADDR);
            _ = try w.interface.writeByte(0x30 | (@as(u8, @intCast(pos)) & 0x0f));
            _ = try w.interface.write(msg[pos..][0..16]);
            try w.interface.flush();
            print("{s}\n", .{msg[pos..][0..16]});
            try init.io.sleep(.fromMilliseconds(250), .awake);
        }
    }
}
