const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const Io = std.Io;

const serial = @import("serial");

const ADDR = 1;
const MESSAGE = "OK, ready, let's do it.  ";

pub const Version = enum { @"3.1", @"4" };

pub fn Tally(comptime version: Version) type {
    return struct {
        const Self = @This();

        pub const DataLen = 16;

        pub const MsgLen = @sizeOf(Header) +
            @sizeOf(Control) +
            DataLen +
            @sizeOf(ChkSum) +
            @sizeOf(VBC) +
            @sizeOf(XData) * 2;

        pub const Header = packed struct {
            addr: u7,
            res7: u1 = 1,
        };

        pub const Control = packed struct {
            tally1: bool,
            tally2: bool,
            tally3: bool,
            tally4: bool,
            brightness: u2,
            mode: enum(u1) { display, command } = .display,
            res7: u1 = 0,
        };

        pub const VBC = switch (version) {
            .@"3.1" => void,
            .@"4" => packed struct {
                xdata_len: u4 = 2,
                version_minor: u2 = 0,
                res7: u1 = 0,
            },
        };

        pub const ChkSum = switch (version) {
            .@"3.1" => void,
            .@"4" => packed struct { sum: u7, res7: u1 = 0 },
        };

        pub const Colour = enum(u2) {
            off,
            red,
            green,
            amber,
        };

        pub const XData = switch (version) {
            .@"3.1" => void,
            .@"4" => packed struct {
                rh: Colour = .off,
                txt: Colour = .off,
                lh: Colour = .off,
                res6: u1 = 0,
                res7: u1 = 0,
            },
        };

        pub const Message = struct {
            addr: u7,
            data: []const u8,
            tally: [4]bool = @splat(false),
            brightness: u2 = 3,

            pub fn render(self: @This()) [MsgLen]u8 {
                var msg: [MsgLen]u8 = @splat(' ');
                msg[0] = @bitCast(Header{ .addr = self.addr });
                msg[1] = @bitCast(Control{
                    .tally1 = self.tally[0],
                    .tally2 = self.tally[1],
                    .tally3 = self.tally[2],
                    .tally4 = self.tally[3],
                    .brightness = self.brightness,
                });
                const len = @min(MsgLen, self.data.len);
                @memcpy(msg[2..][0..len], self.data);
                return msg;
            }
        };

        dev: Io.File,

        pub fn init(
            dev: Io.File,
        ) !Self {
            try serial.configureSerialPort(dev, serial.SerialConfig{
                .baud_rate = 38400,
                .word_size = .eight,
                .parity = .even,
                .stop_bits = .one,
                .handshake = .none,
            });

            return .{ .dev = dev };
        }

        pub fn send(self: Self, io: Io, message: Message) !void {
            var w_buf: [MsgLen]u8 = undefined;
            var msg = message.render();
            var w = self.dev.writer(io, &w_buf);
            _ = try w.interface.write(@ptrCast(&msg));
            try w.interface.flush();
        }
    };
}

test Tally {
    const io = std.testing.io;
    var dev = try Io.Dir.cwd().openFile(io, "/dev/tty.debug-console", .{ .mode = .read_write });
    defer dev.close(io);
    const Three = Tally(.@"3.1");
    assert(@sizeOf(Three.Control) == 1);
    // assert(Three.MsgLen == 18);
    // _ = try Tally(.@"3.1").init(dev, 1);
}

pub fn main(init: std.process.Init) !void {
    var dev = try Io.Dir.cwd().openFile(init.io, "/dev/ttyUSB0", .{ .mode = .read_write });
    defer dev.close(init.io);
    if (false) {
        var w_buf: [32]u8 = undefined;
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
                try init.io.sleep(.fromMilliseconds(200), .awake);
            }
        }
    } else {
        const UMD = Tally(.@"3.1");
        const tally = try UMD.init(dev);
        try tally.send(init.io, .{
            .addr = 1,
            .data = "0123456789abcdef",
        });
    }
}
