const std = @import("std");

// TODO:
// - Learn:
// representation headers
// ContentEncoding
// TransferEncoding
// Websockets
// - Now:
// - Long time away:
// HTTP/2 HTTP/3 support

/// Struct for working with HTTP headers.
const HTTPHeader = struct {
    /// HTTP version.
    version: std.http.Version,
    /// The resource the client is requesting.
    resource: []const u8,
    /// HTTP method.
    method: std.http.Method,
    /// Host's IP adress.
    host: []const u8,
    /// User agent string.
    userAgent: []const u8,
    /// Connection type.
    connection: std.http.Connection,

    pub fn print(self: HTTPHeader) void {
        std.log.info("Recieved header:\n" ++
            "--\n" ++
            "{} {s} {}\r\n" ++
            "Host: {s}\r\n" ++
            "User-Agent: {s}\r\n" ++
            "Connection: {}\r\n " ++
            "--", .{ self.method, self.resource, self.version, self.host, self.userAgent, self.connection });
    }
};

/// Errors to throw.
pub const HTTPError = error{
    HeaderMalformed,
};

/// Accepted headers.
pub const HeaderNames = enum {
    Host,
    @"User-Agent",
};

/// Mime types.
const supportedMimeTypes = .{
    .{ ".txt", "text/plain" },
    .{ ".html", "text/html" },
    .{ ".css", "text/css" },
    .{ ".js", "text/javascript" },
    .{ ".json", "application/json" },
    .{ ".php", "application/x-httpd-php" },
    .{ ".ico", "image/vnd.microsoft.icon" },
    .{ ".png", "image/png" },
    .{ ".jpg", "image/jpeg" },
    .{ ".gif", "image/gif" },
};
/// Parse the given slice into easly readable http header data.
pub fn parseHeaders(header: []const u8) !HTTPHeader {
    var headerStruct = HTTPHeader{
        .version = undefined,
        .resource = undefined,
        .method = undefined,
        .host = undefined,
        .userAgent = undefined,
        .connection = undefined,
    };

    var headerLines = std.mem.splitSequence(u8, header, "\r\n");
    var headIter = std.mem.tokenizeSequence(u8, headerLines.first(), " ");

    if (headIter.next()) |method| {
        if (std.meta.stringToEnum(std.http.Method, method)) |methodName| {
            switch (methodName) {
                .GET => headerStruct.method = .GET,
                .HEAD => headerStruct.method = .HEAD,
                .POST => headerStruct.method = .POST,
                .PUT => headerStruct.method = .PUT,
                .DELETE => headerStruct.method = .DELETE,
                .CONNECT => headerStruct.method = .CONNECT,
                .OPTIONS => headerStruct.method = .OPTIONS,
                .TRACE => headerStruct.method = .TRACE,
                .PATCH => headerStruct.method = .PATCH,
                _ => headerStruct.method = undefined,
            }
        }
    } else {
        return HTTPError.HeaderMalformed;
    }

    if (headIter.next()) |resource| {
        headerStruct.resource = resource;
    } else {
        return HTTPError.HeaderMalformed;
    }

    if (headIter.next()) |version| {
        if (std.meta.stringToEnum(std.http.Version, version)) |versionName| {
            switch (versionName) {
                .@"HTTP/1.0" => headerStruct.version = .@"HTTP/1.0",
                .@"HTTP/1.1" => headerStruct.version = .@"HTTP/1.1",
            }
        }
    } else {
        return HTTPError.HeaderMalformed;
    }

    while (headerLines.next()) |line| {
        const nameSlice = std.mem.sliceTo(line, ':');
        const headerName = std.meta.stringToEnum(HeaderNames, nameSlice) orelse continue;
        const headerValue = std.mem.trimLeft(u8, line[nameSlice.len + 1 ..], " ");

        switch (headerName) {
            .Host => headerStruct.host = headerValue,
            .@"User-Agent" => headerStruct.userAgent = headerValue,
        }
    }

    return headerStruct;
}

pub fn parseHeadersKeepAlive(header: []const u8) !HTTPHeader {
    var headerStruct = HTTPHeader{
        .version = undefined,
        .resource = undefined,
        .method = undefined,
        .host = undefined,
        .userAgent = undefined,
        .connection = undefined,
    };

    var headerLines = std.mem.tokenizeSequence(u8, header, "\r\n");

    while (headerLines.next()) |line| {
        const nameSlice = std.mem.sliceTo(line, ':');
        const headerName = std.meta.stringToEnum(HeaderNames, nameSlice) orelse continue;
        const headerValue = std.mem.trimLeft(u8, line[nameSlice.len + 1 ..], " ");

        switch (headerName) {
            .Host => headerStruct.host = headerValue,
            .@"User-Agent" => headerStruct.userAgent = headerValue,
        }
    }

    return headerStruct;
}

pub fn parsePath(path: []const u8) ![]const u8 {
    if (std.mem.eql(u8, path, "/")) {
        return "/index.html";
    }
    return path;
}

pub fn mimeForPath(path: []const u8) []const u8 {
    const extension = std.fs.path.extension(path);
    inline for (supportedMimeTypes) |kv| {
        if (std.mem.eql(u8, extension, kv[0])) {
            return kv[1];
        }
    }
    return "application/octet-stream";
}

pub fn openLocalFile(path: []const u8) ![]u8 {
    const localPath = path[1..];
    const file = std.fs.cwd().openFile(localPath, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("File not found: {s}\n", .{localPath});
            return error.FileNotFound;
        },
        else => return err,
    };
    defer file.close();
    std.log.info("file: {}\n", .{file});
    const memory = std.heap.page_allocator;
    const maxSize = std.math.maxInt(usize);
    return try file.readToEndAlloc(memory, maxSize);
}
