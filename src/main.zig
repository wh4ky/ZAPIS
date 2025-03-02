const std = @import("std");
const http = @import("./http.zig");

// TODO:
// respect keep-alive
// support more requests
// event-driven programming
// async I/O
// config
// websockets

var mimeTypeMap = std.hash_map.StringHashMap([]const u8);

pub fn main() !void {
    std.log.info("Server started!", .{});

    const allocator = std.heap.PageAllocator;
    mimeTypeMap.init(allocator);

    mimeTypeMap.put(".txt", "text/plain");
    mimeTypeMap.put(".html", "text/html");
    mimeTypeMap.put(".css", "text/css");
    mimeTypeMap.put(".js", "text/javascript");
    mimeTypeMap.put(".json", "application/json");
    mimeTypeMap.put(".php", "application/x-httpd-php");
    mimeTypeMap.put(".ico", "image/vnd.microsoft.icon");
    mimeTypeMap.put(".png", "image/png");
    mimeTypeMap.put(".jpg", "image/jpeg");
    mimeTypeMap.put(".gif", "image/gif");

    const address: std.net.Address = try std.net.Address.resolveIp("0.0.0.0", 4206);
    var server: std.net.Server = try address.listen(.{ .reuse_address = true });

    std.log.info("Listening on {}", .{address});

    while (server.accept()) |connection| {
        std.log.info("Accepted connection from: {}", .{connection.address});
        var recieve_buf: [4096]u8 = undefined;
        var recieve_total: usize = 0;

        while (connection.stream.read(recieve_buf[recieve_total..])) |recieve_len| {
            if (recieve_len == 0) break;
            recieve_total += recieve_len;
            if (std.mem.containsAtLeast(u8, recieve_buf[0..recieve_total], 1, "\r\n\r\n")) break;
        } else |err| return err;

        const recieve_data = recieve_buf[0..recieve_total];
        if (recieve_data.len == 0) {
            std.log.warn("Connection made, but no header recieved", .{});
            continue;
        }
        const header = try http.parseHeaders(recieve_data);
        header.print();

        if (header.method == std.http.Method.GET) {
            const path = try http.parsePath(header.resource);
            const file = http.openLocalFile(path) catch |err| {
                if (err == error.FileNotFound) {
                    _ = try connection.stream.writer().write(http404());
                    continue;
                } else {
                    return err;
                }
            };

            const response = "HTTP/1.1 200 OK\r\n" ++
                "Connection: close\r\n" ++
                "Content-Type: {s}\r\n" ++
                "Content-Length: {d}\r\n" ++
                "\r\n" ++
                "{s}";

            _ = try connection.stream.writer().print(response, .{ http.mimeForPath(path), file.len, file });
        } else {
            const response = "HTTP/1.1 200 OK\r\nConnection: close\r\n";
            _ = try connection.stream.writer().write(response);
        }

        connection.stream.close();
        std.log.info("Closed connection on {}", .{address});
    } else |err| return err;
}

fn http404() []const u8 {
    return "HTTP/1.1 404 NOT FOUND \r\n" ++
        "Connection: close\r\n" ++
        "Content-Type: text/html; charset=utf8\r\n" ++
        "Content-Length: 9\r\n" ++
        "\r\n" ++
        "NOT FOUND";
}

pub fn mimeFromPath(path: []const u8) []const u8 {
    if (mimeTypeMap.get(std.fs.path.extension(path))) |mime|
        return mime;
    return "application/octet-stream";
}
