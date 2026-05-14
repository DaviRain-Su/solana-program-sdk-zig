//! `solana_client` — host-side Solana JSON-RPC codec helpers.
//!
//! v0.1 keeps the wire codec allocation-light while also exposing a small
//! transport boundary. Applications own the actual HTTP/WebSocket socket
//! implementation and can plug it into `Transport`.

const std = @import("std");
const sol = @import("solana_program_sdk");
const alt = @import("solana_address_lookup_table");

pub const Pubkey = sol.Pubkey;
pub const LookupTableAccount = alt.LookupTableAccount;
pub const RpcId = u64;
pub const SubscriptionId = u64;

pub const Error = error{
    OutputTooSmall,
    InvalidJsonStringInput,
    InvalidAccountData,
    AccountNotFound,
    InvalidAccountOwner,
    InvalidEndpointUrl,
    NoEndpoints,
    ResponseTooLarge,
};

pub const TransportError = error{
    Timeout,
    ConnectionFailed,
    ResponseTooLarge,
    InvalidResponse,
    RateLimited,
    ServerUnavailable,
    UnsupportedProtocol,
};

pub const Commitment = enum {
    processed,
    confirmed,
    finalized,

    pub fn jsonName(self: Commitment) []const u8 {
        return switch (self) {
            .processed => "processed",
            .confirmed => "confirmed",
            .finalized => "finalized",
        };
    }
};

pub const AccountEncoding = enum {
    base64,
    base64_zstd,

    pub fn jsonName(self: AccountEncoding) []const u8 {
        return switch (self) {
            .base64 => "base64",
            .base64_zstd => "base64+zstd",
        };
    }
};

pub const RpcError = struct {
    code: i64,
    message: []const u8,
};

pub const RpcErrorKind = enum {
    parse_error,
    invalid_request,
    method_not_found,
    invalid_params,
    internal_error,
    blockhash_not_found,
    node_unhealthy,
    preflight_failure,
    rate_limited,
    server_error,
    unknown,
};

pub const NormalizedRpcError = struct {
    code: i64,
    message: []const u8,
    kind: RpcErrorKind,
    retryable: bool,
};

pub const HttpMethod = enum {
    post,

    pub fn jsonName(self: HttpMethod) []const u8 {
        return switch (self) {
            .post => "POST",
        };
    }
};

pub const TransportKind = enum {
    http_json_rpc,
    websocket_json_rpc,
};

pub const Endpoint = struct {
    url: []const u8,
    websocket_url: ?[]const u8 = null,
    default_commitment: ?Commitment = null,

    pub fn validate(self: Endpoint) Error!void {
        if (!isHttpUrl(self.url)) return error.InvalidEndpointUrl;
        if (self.websocket_url) |ws_url| {
            if (!isWebsocketUrl(ws_url)) return error.InvalidEndpointUrl;
        }
    }
};

pub const EndpointPool = struct {
    endpoints: []const Endpoint,
    next_index: usize = 0,

    pub fn next(self: *EndpointPool) Error!Endpoint {
        if (self.endpoints.len == 0) return error.NoEndpoints;
        const endpoint = self.endpoints[self.next_index % self.endpoints.len];
        self.next_index = (self.next_index + 1) % self.endpoints.len;
        try endpoint.validate();
        return endpoint;
    }
};

pub const RetryPolicy = struct {
    max_attempts: u8 = 3,
    initial_delay_ms: u32 = 100,
    max_delay_ms: u32 = 2_000,

    pub fn attempts(self: RetryPolicy) u8 {
        return @max(self.max_attempts, 1);
    }

    pub fn shouldRetryTransport(_: RetryPolicy, err: TransportError) bool {
        return switch (err) {
            error.Timeout,
            error.ConnectionFailed,
            error.RateLimited,
            error.ServerUnavailable,
            => true,
            error.ResponseTooLarge,
            error.InvalidResponse,
            error.UnsupportedProtocol,
            => false,
        };
    }

    pub fn delayMs(self: RetryPolicy, attempt_index: u8) u32 {
        var delay = self.initial_delay_ms;
        var i: u8 = 0;
        while (i < attempt_index) : (i += 1) {
            delay = std.math.mul(u32, delay, 2) catch self.max_delay_ms;
            if (delay >= self.max_delay_ms) return self.max_delay_ms;
        }
        return @min(delay, self.max_delay_ms);
    }
};

pub const TransportRequest = struct {
    kind: TransportKind = .http_json_rpc,
    method: HttpMethod = .post,
    endpoint_url: []const u8,
    body: []const u8,
    timeout_ms: u32,
};

pub const Transport = struct {
    context: *anyopaque,
    sendFn: *const fn (context: *anyopaque, request: TransportRequest, response_out: []u8) TransportError![]const u8,

    pub fn send(self: Transport, request: TransportRequest, response_out: []u8) TransportError![]const u8 {
        return self.sendFn(self.context, request, response_out);
    }
};

pub const StdHttpTransport = struct {
    client: *std.http.Client,
    keep_alive: bool = true,
    redirect_buffer: ?[]u8 = null,
    decompress_buffer: ?[]u8 = null,
    extra_headers: []const std.http.Header = &.{},
    privileged_headers: []const std.http.Header = &.{},

    pub fn transport(self: *StdHttpTransport) Transport {
        return .{
            .context = self,
            .sendFn = send,
        };
    }

    fn send(
        context: *anyopaque,
        request: TransportRequest,
        response_out: []u8,
    ) TransportError![]const u8 {
        const self: *StdHttpTransport = @ptrCast(@alignCast(context));
        if (request.kind != .http_json_rpc or request.method != .post) return error.UnsupportedProtocol;
        if (!isHttpUrl(request.endpoint_url)) return error.UnsupportedProtocol;

        var response_writer = std.Io.Writer.fixed(response_out);
        const result = self.client.fetch(.{
            .location = .{ .url = request.endpoint_url },
            .method = .POST,
            .payload = request.body,
            .response_writer = &response_writer,
            .redirect_buffer = self.redirect_buffer,
            .decompress_buffer = self.decompress_buffer,
            .redirect_behavior = .unhandled,
            .keep_alive = self.keep_alive,
            .headers = .{
                .content_type = .{ .override = "application/json" },
                .accept_encoding = .default,
            },
            .extra_headers = self.extra_headers,
            .privileged_headers = self.privileged_headers,
        }) catch |err| return mapFetchError(err);

        if (transportErrorForHttpStatus(result.status)) |err| return err;
        return response_writer.buffered();
    }
};

pub const ClientConfig = struct {
    default_commitment: Commitment = .finalized,
    request_timeout_ms: u32 = 10_000,
    subscription_timeout_ms: u32 = 30_000,
    retry_policy: RetryPolicy = .{},

    pub fn timeoutMs(self: ClientConfig, kind: TransportKind) u32 {
        return switch (kind) {
            .http_json_rpc => self.request_timeout_ms,
            .websocket_json_rpc => self.subscription_timeout_ms,
        };
    }
};

pub const Client = struct {
    endpoint: Endpoint,
    transport: Transport,
    config: ClientConfig = .{},

    pub fn request(
        self: Client,
        body: []const u8,
        response_out: []u8,
    ) (Error || TransportError)![]const u8 {
        try self.endpoint.validate();
        return sendWithRetry(self.transport, .{
            .kind = .http_json_rpc,
            .method = .post,
            .endpoint_url = self.endpoint.url,
            .body = body,
            .timeout_ms = self.config.request_timeout_ms,
        }, response_out, self.config.retry_policy);
    }

    pub fn websocketRequest(
        self: Client,
        body: []const u8,
        websocket_url_out: []u8,
        response_out: []u8,
    ) (Error || TransportError)![]const u8 {
        try self.endpoint.validate();
        const websocket_url = try writeWebsocketUrl(self.endpoint, websocket_url_out);
        return sendWithRetry(self.transport, .{
            .kind = .websocket_json_rpc,
            .method = .post,
            .endpoint_url = websocket_url,
            .body = body,
            .timeout_ms = self.config.timeoutMs(.websocket_json_rpc),
        }, response_out, self.config.retry_policy);
    }

    pub fn getLatestBlockhash(
        self: Client,
        id: RpcId,
        request_out: []u8,
        response_out: []u8,
    ) (Error || TransportError)![]const u8 {
        const commitment = self.endpoint.default_commitment orelse self.config.default_commitment;
        const body = try buildGetLatestBlockhashRequest(id, commitment, request_out);
        return self.request(body, response_out);
    }

    pub fn getBalance(
        self: Client,
        id: RpcId,
        pubkey_base58: []const u8,
        request_out: []u8,
        response_out: []u8,
    ) (Error || TransportError)![]const u8 {
        const commitment = self.endpoint.default_commitment orelse self.config.default_commitment;
        const body = try buildGetBalanceRequest(id, pubkey_base58, commitment, request_out);
        return self.request(body, response_out);
    }

    pub fn getAccountInfo(
        self: Client,
        id: RpcId,
        pubkey_base58: []const u8,
        request_out: []u8,
        response_out: []u8,
    ) (Error || TransportError)![]const u8 {
        const commitment = self.endpoint.default_commitment orelse self.config.default_commitment;
        const body = try buildGetAccountInfoRequest(id, pubkey_base58, commitment, .base64, request_out);
        return self.request(body, response_out);
    }

    pub fn fetchAddressLookupTable(
        self: Client,
        allocator: std.mem.Allocator,
        id: RpcId,
        lookup_table_base58: []const u8,
        request_out: []u8,
        response_out: []u8,
        account_data_out: []u8,
    ) (Error || TransportError || alt.Error || anyerror)!LookupTableAccount {
        const response_json = try self.getAccountInfo(id, lookup_table_base58, request_out, response_out);
        const parsed = try parseGetAccountInfoResponse(allocator, response_json);
        defer parsed.deinit();
        const account = parsed.value.result.?.value orelse return error.AccountNotFound;
        return parseAddressLookupTableAccountInfo(account, account_data_out);
    }

    pub fn accountSubscribe(
        self: Client,
        id: RpcId,
        pubkey_base58: []const u8,
        request_out: []u8,
        websocket_url_out: []u8,
        response_out: []u8,
    ) (Error || TransportError)![]const u8 {
        const commitment = self.endpoint.default_commitment orelse self.config.default_commitment;
        const body = try buildAccountSubscribeRequest(id, pubkey_base58, commitment, .base64, request_out);
        return self.websocketRequest(body, websocket_url_out, response_out);
    }

    pub fn accountUnsubscribe(
        self: Client,
        id: RpcId,
        subscription_id: SubscriptionId,
        request_out: []u8,
        websocket_url_out: []u8,
        response_out: []u8,
    ) (Error || TransportError)![]const u8 {
        const body = try buildUnsubscribeRequest(id, .account, subscription_id, request_out);
        return self.websocketRequest(body, websocket_url_out, response_out);
    }
};

pub const RpcContext = struct {
    slot: u64,
};

pub const GetLatestBlockhashResult = struct {
    context: RpcContext,
    value: struct {
        blockhash: []const u8,
        lastValidBlockHeight: u64,
    },
};

pub const GetLatestBlockhashResponse = struct {
    jsonrpc: []const u8,
    id: RpcId,
    result: ?GetLatestBlockhashResult = null,
    @"error": ?RpcError = null,
};

pub const GetBalanceResult = struct {
    context: RpcContext,
    value: u64,
};

pub const GetBalanceResponse = struct {
    jsonrpc: []const u8,
    id: RpcId,
    result: ?GetBalanceResult = null,
    @"error": ?RpcError = null,
};

pub const AccountInfo = struct {
    lamports: u64,
    owner: []const u8,
    executable: bool,
    rentEpoch: u64,
    data: std.json.Value,
    space: ?u64 = null,
};

pub const AccountData = struct {
    bytes_base64: []const u8,
    encoding: AccountEncoding,
};

pub const GetAccountInfoResult = struct {
    context: RpcContext,
    value: ?AccountInfo,
};

pub const GetAccountInfoResponse = struct {
    jsonrpc: []const u8,
    id: RpcId,
    result: ?GetAccountInfoResult = null,
    @"error": ?RpcError = null,
};

pub const SendTransactionResponse = struct {
    jsonrpc: []const u8,
    id: RpcId,
    result: ?[]const u8 = null,
    @"error": ?RpcError = null,
};

pub const SimulateTransactionResult = struct {
    context: RpcContext,
    value: struct {
        err: ?std.json.Value = null,
        logs: ?[][]const u8 = null,
        unitsConsumed: ?u64 = null,
    },
};

pub const SimulateTransactionResponse = struct {
    jsonrpc: []const u8,
    id: RpcId,
    result: ?SimulateTransactionResult = null,
    @"error": ?RpcError = null,
};

pub const SubscriptionKind = enum {
    account,
    program,
    logs,
    signature,
    slot,
    root,

    pub fn subscribeMethod(self: SubscriptionKind) []const u8 {
        return switch (self) {
            .account => "accountSubscribe",
            .program => "programSubscribe",
            .logs => "logsSubscribe",
            .signature => "signatureSubscribe",
            .slot => "slotSubscribe",
            .root => "rootSubscribe",
        };
    }

    pub fn unsubscribeMethod(self: SubscriptionKind) []const u8 {
        return switch (self) {
            .account => "accountUnsubscribe",
            .program => "programUnsubscribe",
            .logs => "logsUnsubscribe",
            .signature => "signatureUnsubscribe",
            .slot => "slotUnsubscribe",
            .root => "rootUnsubscribe",
        };
    }
};

pub const SubscriptionResponse = struct {
    jsonrpc: []const u8,
    id: RpcId,
    result: ?SubscriptionId = null,
    @"error": ?RpcError = null,
};

pub const UnsubscribeResponse = struct {
    jsonrpc: []const u8,
    id: RpcId,
    result: ?bool = null,
    @"error": ?RpcError = null,
};

pub const AccountNotificationParams = struct {
    result: GetAccountInfoResult,
    subscription: SubscriptionId,
};

pub const AccountNotification = struct {
    jsonrpc: []const u8,
    method: []const u8,
    params: AccountNotificationParams,
};

pub fn buildAccountSubscribeRequest(
    id: RpcId,
    pubkey_base58: []const u8,
    commitment: ?Commitment,
    encoding: AccountEncoding,
    out: []u8,
) Error![]u8 {
    try validateJsonStringInput(pubkey_base58);

    if (commitment) |level| {
        return bufPrint(out,
            \\{{"jsonrpc":"2.0","id":{},"method":"accountSubscribe","params":["{s}",{{"encoding":"{s}","commitment":"{s}"}}]}}
        , .{ id, pubkey_base58, encoding.jsonName(), level.jsonName() });
    }

    return bufPrint(out,
        \\{{"jsonrpc":"2.0","id":{},"method":"accountSubscribe","params":["{s}",{{"encoding":"{s}"}}]}}
    , .{ id, pubkey_base58, encoding.jsonName() });
}

pub fn buildProgramSubscribeRequest(
    id: RpcId,
    program_base58: []const u8,
    commitment: ?Commitment,
    encoding: AccountEncoding,
    out: []u8,
) Error![]u8 {
    try validateJsonStringInput(program_base58);

    if (commitment) |level| {
        return bufPrint(out,
            \\{{"jsonrpc":"2.0","id":{},"method":"programSubscribe","params":["{s}",{{"encoding":"{s}","commitment":"{s}"}}]}}
        , .{ id, program_base58, encoding.jsonName(), level.jsonName() });
    }

    return bufPrint(out,
        \\{{"jsonrpc":"2.0","id":{},"method":"programSubscribe","params":["{s}",{{"encoding":"{s}"}}]}}
    , .{ id, program_base58, encoding.jsonName() });
}

pub fn buildLogsSubscribeMentionsRequest(
    id: RpcId,
    pubkey_base58: []const u8,
    commitment: ?Commitment,
    out: []u8,
) Error![]u8 {
    try validateJsonStringInput(pubkey_base58);

    if (commitment) |level| {
        return bufPrint(out,
            \\{{"jsonrpc":"2.0","id":{},"method":"logsSubscribe","params":[{{"mentions":["{s}"]}},{{"commitment":"{s}"}}]}}
        , .{ id, pubkey_base58, level.jsonName() });
    }

    return bufPrint(out,
        \\{{"jsonrpc":"2.0","id":{},"method":"logsSubscribe","params":[{{"mentions":["{s}"]}}]}}
    , .{ id, pubkey_base58 });
}

pub fn buildSignatureSubscribeRequest(
    id: RpcId,
    signature_base58: []const u8,
    commitment: ?Commitment,
    enable_received_notification: bool,
    out: []u8,
) Error![]u8 {
    try validateJsonStringInput(signature_base58);

    if (commitment) |level| {
        return bufPrint(out,
            \\{{"jsonrpc":"2.0","id":{},"method":"signatureSubscribe","params":["{s}",{{"commitment":"{s}","enableReceivedNotification":{}}}]}}
        , .{ id, signature_base58, level.jsonName(), enable_received_notification });
    }

    return bufPrint(out,
        \\{{"jsonrpc":"2.0","id":{},"method":"signatureSubscribe","params":["{s}",{{"enableReceivedNotification":{}}}]}}
    , .{ id, signature_base58, enable_received_notification });
}

pub fn buildSimpleSubscribeRequest(
    id: RpcId,
    kind: SubscriptionKind,
    out: []u8,
) Error![]u8 {
    return switch (kind) {
        .slot,
        .root,
        => bufPrint(out,
            \\{{"jsonrpc":"2.0","id":{},"method":"{s}"}}
        , .{ id, kind.subscribeMethod() }),
        .account,
        .program,
        .logs,
        .signature,
        => error.InvalidJsonStringInput,
    };
}

pub fn buildUnsubscribeRequest(
    id: RpcId,
    kind: SubscriptionKind,
    subscription_id: SubscriptionId,
    out: []u8,
) Error![]u8 {
    return bufPrint(out,
        \\{{"jsonrpc":"2.0","id":{},"method":"{s}","params":[{}]}}
    , .{ id, kind.unsubscribeMethod(), subscription_id });
}

pub fn buildGetLatestBlockhashRequest(
    id: RpcId,
    commitment: ?Commitment,
    out: []u8,
) Error![]u8 {
    if (commitment) |level| {
        return bufPrint(out,
            \\{{"jsonrpc":"2.0","id":{},"method":"getLatestBlockhash","params":[{{"commitment":"{s}"}}]}}
        , .{ id, level.jsonName() });
    }

    return bufPrint(out,
        \\{{"jsonrpc":"2.0","id":{},"method":"getLatestBlockhash"}}
    , .{id});
}

pub fn buildGetBalanceRequest(
    id: RpcId,
    pubkey_base58: []const u8,
    commitment: ?Commitment,
    out: []u8,
) Error![]u8 {
    try validateJsonStringInput(pubkey_base58);

    if (commitment) |level| {
        return bufPrint(out,
            \\{{"jsonrpc":"2.0","id":{},"method":"getBalance","params":["{s}",{{"commitment":"{s}"}}]}}
        , .{ id, pubkey_base58, level.jsonName() });
    }

    return bufPrint(out,
        \\{{"jsonrpc":"2.0","id":{},"method":"getBalance","params":["{s}"]}}
    , .{ id, pubkey_base58 });
}

pub fn buildGetAccountInfoRequest(
    id: RpcId,
    pubkey_base58: []const u8,
    commitment: ?Commitment,
    encoding: AccountEncoding,
    out: []u8,
) Error![]u8 {
    try validateJsonStringInput(pubkey_base58);

    if (commitment) |level| {
        return bufPrint(out,
            \\{{"jsonrpc":"2.0","id":{},"method":"getAccountInfo","params":["{s}",{{"encoding":"{s}","commitment":"{s}"}}]}}
        , .{ id, pubkey_base58, encoding.jsonName(), level.jsonName() });
    }

    return bufPrint(out,
        \\{{"jsonrpc":"2.0","id":{},"method":"getAccountInfo","params":["{s}",{{"encoding":"{s}"}}]}}
    , .{ id, pubkey_base58, encoding.jsonName() });
}

pub fn buildSendTransactionRequest(
    id: RpcId,
    transaction_base64: []const u8,
    out: []u8,
) Error![]u8 {
    try validateJsonStringInput(transaction_base64);

    return bufPrint(out,
        \\{{"jsonrpc":"2.0","id":{},"method":"sendTransaction","params":["{s}",{{"encoding":"base64"}}]}}
    , .{ id, transaction_base64 });
}

pub fn buildSimulateTransactionRequest(
    id: RpcId,
    transaction_base64: []const u8,
    out: []u8,
) Error![]u8 {
    try validateJsonStringInput(transaction_base64);

    return bufPrint(out,
        \\{{"jsonrpc":"2.0","id":{},"method":"simulateTransaction","params":["{s}",{{"encoding":"base64","sigVerify":false}}]}}
    , .{ id, transaction_base64 });
}

pub fn parseGetLatestBlockhashResponse(
    allocator: std.mem.Allocator,
    response_json: []const u8,
) !std.json.Parsed(GetLatestBlockhashResponse) {
    return parseResponse(GetLatestBlockhashResponse, allocator, response_json);
}

pub fn parseGetBalanceResponse(
    allocator: std.mem.Allocator,
    response_json: []const u8,
) !std.json.Parsed(GetBalanceResponse) {
    return parseResponse(GetBalanceResponse, allocator, response_json);
}

pub fn parseGetAccountInfoResponse(
    allocator: std.mem.Allocator,
    response_json: []const u8,
) !std.json.Parsed(GetAccountInfoResponse) {
    return parseResponse(GetAccountInfoResponse, allocator, response_json);
}

pub fn accountInfoData(account: AccountInfo) Error!AccountData {
    const array = switch (account.data) {
        .array => |array| array,
        else => return error.InvalidAccountData,
    };
    if (array.items.len != 2) return error.InvalidAccountData;
    const bytes_base64 = switch (array.items[0]) {
        .string => |value| value,
        else => return error.InvalidAccountData,
    };
    const encoding_name = switch (array.items[1]) {
        .string => |value| value,
        else => return error.InvalidAccountData,
    };
    const encoding: AccountEncoding = if (std.mem.eql(u8, encoding_name, AccountEncoding.base64.jsonName()))
        .base64
    else if (std.mem.eql(u8, encoding_name, AccountEncoding.base64_zstd.jsonName()))
        .base64_zstd
    else
        return error.InvalidAccountData;
    return .{
        .bytes_base64 = bytes_base64,
        .encoding = encoding,
    };
}

pub fn decodeAccountInfoBase64Data(account: AccountInfo, out: []u8) Error![]const u8 {
    const data = try accountInfoData(account);
    if (data.encoding != .base64) return error.InvalidAccountData;
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(data.bytes_base64) catch return error.InvalidAccountData;
    if (out.len < decoded_len) return error.OutputTooSmall;
    std.base64.standard.Decoder.decode(out[0..decoded_len], data.bytes_base64) catch return error.InvalidAccountData;
    return out[0..decoded_len];
}

pub fn parseAddressLookupTableAccountInfo(
    account: AccountInfo,
    account_data_out: []u8,
) (Error || alt.Error)!LookupTableAccount {
    var owner_buf: [44]u8 = undefined;
    const owner_len = sol.pubkey.encodeBase58(&alt.PROGRAM_ID, &owner_buf);
    if (!std.mem.eql(u8, account.owner, owner_buf[0..owner_len])) return error.InvalidAccountOwner;
    if (account.executable) return error.InvalidAccountData;

    const account_data = try decodeAccountInfoBase64Data(account, account_data_out);
    return alt.parse(account_data);
}

pub fn parseSendTransactionResponse(
    allocator: std.mem.Allocator,
    response_json: []const u8,
) !std.json.Parsed(SendTransactionResponse) {
    return parseResponse(SendTransactionResponse, allocator, response_json);
}

pub fn parseSimulateTransactionResponse(
    allocator: std.mem.Allocator,
    response_json: []const u8,
) !std.json.Parsed(SimulateTransactionResponse) {
    return parseResponse(SimulateTransactionResponse, allocator, response_json);
}

pub fn parseSubscriptionResponse(
    allocator: std.mem.Allocator,
    response_json: []const u8,
) !std.json.Parsed(SubscriptionResponse) {
    return parseResponse(SubscriptionResponse, allocator, response_json);
}

pub fn parseUnsubscribeResponse(
    allocator: std.mem.Allocator,
    response_json: []const u8,
) !std.json.Parsed(UnsubscribeResponse) {
    return parseResponse(UnsubscribeResponse, allocator, response_json);
}

pub fn parseAccountNotification(
    allocator: std.mem.Allocator,
    notification_json: []const u8,
) !std.json.Parsed(AccountNotification) {
    return parseResponse(AccountNotification, allocator, notification_json);
}

pub fn normalizeRpcError(err: RpcError) NormalizedRpcError {
    const kind: RpcErrorKind = switch (err.code) {
        -32700 => .parse_error,
        -32600 => .invalid_request,
        -32601 => .method_not_found,
        -32602 => .invalid_params,
        -32603 => .internal_error,
        -32005 => .node_unhealthy,
        -32002 => .preflight_failure,
        -32004 => .blockhash_not_found,
        -32016 => .rate_limited,
        else => if (err.code >= -32099 and err.code <= -32000) .server_error else .unknown,
    };
    return .{
        .code = err.code,
        .message = err.message,
        .kind = kind,
        .retryable = switch (kind) {
            .node_unhealthy,
            .rate_limited,
            .server_error,
            .internal_error,
            => true,
            .parse_error,
            .invalid_request,
            .method_not_found,
            .invalid_params,
            .blockhash_not_found,
            .preflight_failure,
            .unknown,
            => false,
        },
    };
}

pub fn websocketUrlLen(endpoint: Endpoint) Error!usize {
    if (endpoint.websocket_url) |ws_url| {
        if (!isWebsocketUrl(ws_url)) return error.InvalidEndpointUrl;
        return ws_url.len;
    }
    if (!isHttpUrl(endpoint.url)) return error.InvalidEndpointUrl;
    return endpoint.url.len - "http".len + "ws".len;
}

pub fn writeWebsocketUrl(endpoint: Endpoint, out: []u8) Error![]const u8 {
    if (endpoint.websocket_url) |ws_url| {
        if (!isWebsocketUrl(ws_url)) return error.InvalidEndpointUrl;
        if (out.len < ws_url.len) return error.OutputTooSmall;
        @memcpy(out[0..ws_url.len], ws_url);
        return out[0..ws_url.len];
    }
    if (!isHttpUrl(endpoint.url)) return error.InvalidEndpointUrl;
    const prefix_len: usize = if (std.mem.startsWith(u8, endpoint.url, "https://")) "https".len else "http".len;
    const ws_prefix = if (prefix_len == "https".len) "wss" else "ws";
    const needed = endpoint.url.len - prefix_len + ws_prefix.len;
    if (out.len < needed) return error.OutputTooSmall;
    @memcpy(out[0..ws_prefix.len], ws_prefix);
    @memcpy(out[ws_prefix.len..needed], endpoint.url[prefix_len..]);
    return out[0..needed];
}

pub fn sendWithRetry(
    transport: Transport,
    request: TransportRequest,
    response_out: []u8,
    policy: RetryPolicy,
) TransportError![]const u8 {
    const max_attempts = policy.attempts();
    var attempt: u8 = 0;
    while (attempt < max_attempts) : (attempt += 1) {
        return transport.send(request, response_out) catch |err| {
            if (attempt + 1 >= max_attempts or !policy.shouldRetryTransport(err)) return err;
            continue;
        };
    }
    unreachable;
}

fn parseResponse(
    comptime T: type,
    allocator: std.mem.Allocator,
    response_json: []const u8,
) !std.json.Parsed(T) {
    return std.json.parseFromSlice(T, allocator, response_json, .{
        .ignore_unknown_fields = true,
    });
}

fn validateJsonStringInput(value: []const u8) Error!void {
    for (value) |byte| {
        if (byte < 0x20 or byte == '"' or byte == '\\') {
            return error.InvalidJsonStringInput;
        }
    }
}

fn isHttpUrl(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://");
}

fn isWebsocketUrl(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "ws://") or std.mem.startsWith(u8, url, "wss://");
}

fn transportErrorForHttpStatus(status: std.http.Status) ?TransportError {
    const code = @intFromEnum(status);
    if (code >= 200 and code < 300) return null;
    return switch (status) {
        .too_many_requests => error.RateLimited,
        .bad_gateway,
        .service_unavailable,
        .gateway_timeout,
        => error.ServerUnavailable,
        else => if (code >= 500) error.ServerUnavailable else error.InvalidResponse,
    };
}

fn mapFetchError(err: anyerror) TransportError {
    return switch (err) {
        error.WriteFailed,
        error.StreamTooLong,
        => error.ResponseTooLarge,
        error.UnsupportedUriScheme => error.UnsupportedProtocol,
        error.ConnectionRefused,
        error.ConnectionTimedOut,
        error.ConnectionResetByPeer,
        error.ConnectionReadTimedOut,
        error.ConnectionWriteTimedOut,
        error.NetworkUnreachable,
        error.TemporaryNameServerFailure,
        error.NameServerFailure,
        error.UnknownHostName,
        => error.ConnectionFailed,
        else => error.InvalidResponse,
    };
}

fn bufPrint(out: []u8, comptime fmt: []const u8, args: anytype) Error![]u8 {
    return std.fmt.bufPrint(out, fmt, args) catch |err| switch (err) {
        error.NoSpaceLeft => error.OutputTooSmall,
    };
}

test "builds getLatestBlockhash request with commitment" {
    var buf: [128]u8 = undefined;
    const request = try buildGetLatestBlockhashRequest(1, .finalized, &buf);
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getLatestBlockhash\",\"params\":[{\"commitment\":\"finalized\"}]}",
        request,
    );
}

test "builds getBalance request and rejects non-JSON-safe pubkey strings" {
    var buf: [160]u8 = undefined;
    const request = try buildGetBalanceRequest(2, "11111111111111111111111111111111", .confirmed, &buf);
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"getBalance\",\"params\":[\"11111111111111111111111111111111\",{\"commitment\":\"confirmed\"}]}",
        request,
    );
    try std.testing.expectError(
        error.InvalidJsonStringInput,
        buildGetBalanceRequest(2, "bad\"pubkey", null, &buf),
    );
}

test "builds getAccountInfo request with encoding" {
    var buf: [192]u8 = undefined;
    const request = try buildGetAccountInfoRequest(
        8,
        "11111111111111111111111111111111",
        .finalized,
        .base64,
        &buf,
    );
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"getAccountInfo\",\"params\":[\"11111111111111111111111111111111\",{\"encoding\":\"base64\",\"commitment\":\"finalized\"}]}",
        request,
    );
    const zstd_request = try buildGetAccountInfoRequest(
        9,
        "11111111111111111111111111111111",
        null,
        .base64_zstd,
        &buf,
    );
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"getAccountInfo\",\"params\":[\"11111111111111111111111111111111\",{\"encoding\":\"base64+zstd\"}]}",
        zstd_request,
    );
}

test "builds transaction submission and simulation requests" {
    var send_buf: [160]u8 = undefined;
    const send = try buildSendTransactionRequest(3, "AQIDBA==", &send_buf);
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"sendTransaction\",\"params\":[\"AQIDBA==\",{\"encoding\":\"base64\"}]}",
        send,
    );

    var simulate_buf: [192]u8 = undefined;
    const simulate = try buildSimulateTransactionRequest(4, "AQIDBA==", &simulate_buf);
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"simulateTransaction\",\"params\":[\"AQIDBA==\",{\"encoding\":\"base64\",\"sigVerify\":false}]}",
        simulate,
    );
}

test "builds websocket subscription and unsubscribe requests" {
    var account_buf: [192]u8 = undefined;
    const account = try buildAccountSubscribeRequest(
        10,
        "11111111111111111111111111111111",
        .finalized,
        .base64,
        &account_buf,
    );
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"accountSubscribe\",\"params\":[\"11111111111111111111111111111111\",{\"encoding\":\"base64\",\"commitment\":\"finalized\"}]}",
        account,
    );

    var program_buf: [192]u8 = undefined;
    const program = try buildProgramSubscribeRequest(
        11,
        "11111111111111111111111111111111",
        null,
        .base64_zstd,
        &program_buf,
    );
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":11,\"method\":\"programSubscribe\",\"params\":[\"11111111111111111111111111111111\",{\"encoding\":\"base64+zstd\"}]}",
        program,
    );

    var logs_buf: [192]u8 = undefined;
    const logs = try buildLogsSubscribeMentionsRequest(
        12,
        "11111111111111111111111111111111",
        .confirmed,
        &logs_buf,
    );
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":12,\"method\":\"logsSubscribe\",\"params\":[{\"mentions\":[\"11111111111111111111111111111111\"]},{\"commitment\":\"confirmed\"}]}",
        logs,
    );

    var signature_buf: [224]u8 = undefined;
    const signature = try buildSignatureSubscribeRequest(
        13,
        "5wHu1qwBqqyqSutnXrTxiJdqWwJdP6sM2uH3a9xFJxHg",
        .processed,
        true,
        &signature_buf,
    );
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":13,\"method\":\"signatureSubscribe\",\"params\":[\"5wHu1qwBqqyqSutnXrTxiJdqWwJdP6sM2uH3a9xFJxHg\",{\"commitment\":\"processed\",\"enableReceivedNotification\":true}]}",
        signature,
    );

    var slot_buf: [80]u8 = undefined;
    const slot = try buildSimpleSubscribeRequest(14, .slot, &slot_buf);
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":14,\"method\":\"slotSubscribe\"}",
        slot,
    );

    var unsubscribe_buf: [96]u8 = undefined;
    const unsubscribe = try buildUnsubscribeRequest(15, .account, 99, &unsubscribe_buf);
    try std.testing.expectEqualStrings(
        "{\"jsonrpc\":\"2.0\",\"id\":15,\"method\":\"accountUnsubscribe\",\"params\":[99]}",
        unsubscribe,
    );
}

test "parses getLatestBlockhash and getBalance responses" {
    const allocator = std.testing.allocator;

    const blockhash_json =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":2792},"value":{"blockhash":"EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N","lastValidBlockHeight":3090}},"id":1}
    ;
    const parsed_blockhash = try parseGetLatestBlockhashResponse(allocator, blockhash_json);
    defer parsed_blockhash.deinit();
    try std.testing.expectEqual(@as(RpcId, 1), parsed_blockhash.value.id);
    try std.testing.expect(parsed_blockhash.value.result != null);
    try std.testing.expectEqual(@as(u64, 2792), parsed_blockhash.value.result.?.context.slot);
    try std.testing.expectEqualStrings(
        "EkSnNWid2cvwEVnVx9aBqawnmiCNiDgp3gUdkDPTKN1N",
        parsed_blockhash.value.result.?.value.blockhash,
    );
    try std.testing.expectEqual(@as(u64, 3090), parsed_blockhash.value.result.?.value.lastValidBlockHeight);

    const balance_json =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":1},"value":5000000000},"id":2}
    ;
    const parsed_balance = try parseGetBalanceResponse(allocator, balance_json);
    defer parsed_balance.deinit();
    try std.testing.expectEqual(@as(u64, 5000000000), parsed_balance.value.result.?.value);
}

test "parses getAccountInfo base64 response" {
    const allocator = std.testing.allocator;

    const account_json =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":12},"value":{"lamports":123,"owner":"AddressLookupTab1e1111111111111111111111111","executable":false,"rentEpoch":42,"data":["AQIDBA==","base64"],"space":4}},"id":8}
    ;
    const parsed = try parseGetAccountInfoResponse(allocator, account_json);
    defer parsed.deinit();

    const account = parsed.value.result.?.value.?;
    try std.testing.expectEqual(@as(u64, 12), parsed.value.result.?.context.slot);
    try std.testing.expectEqual(@as(u64, 123), account.lamports);
    try std.testing.expectEqualStrings("AddressLookupTab1e1111111111111111111111111", account.owner);
    try std.testing.expect(!account.executable);
    try std.testing.expectEqual(@as(u64, 42), account.rentEpoch);
    try std.testing.expectEqual(@as(u64, 4), account.space.?);
    switch (account.data) {
        .array => |array| try std.testing.expectEqualStrings("AQIDBA==", array.items[0].string),
        else => return error.InvalidResponse,
    }
    const data = try accountInfoData(account);
    try std.testing.expectEqual(AccountEncoding.base64, data.encoding);
    try std.testing.expectEqualStrings("AQIDBA==", data.bytes_base64);
    var decoded: [4]u8 = undefined;
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, try decodeAccountInfoBase64Data(account, &decoded));

    const missing_json =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":13},"value":null},"id":9}
    ;
    const missing = try parseGetAccountInfoResponse(allocator, missing_json);
    defer missing.deinit();
    try std.testing.expect(missing.value.result.?.value == null);

    var too_small: [3]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeAccountInfoBase64Data(account, &too_small));
}

fn writeLookupTableFixture(
    out: []u8,
    authority: ?*const Pubkey,
    addresses: []const Pubkey,
) []const u8 {
    std.debug.assert(out.len >= alt.LOOKUP_TABLE_META_SIZE + addresses.len * sol.PUBKEY_BYTES);
    @memset(out[0..alt.LOOKUP_TABLE_META_SIZE], 0);
    std.mem.writeInt(u32, out[0..4], @intFromEnum(alt.ProgramState.lookup_table), .little);
    std.mem.writeInt(u64, out[4..12], std.math.maxInt(u64), .little);
    std.mem.writeInt(u64, out[12..20], 88, .little);
    out[20] = 1;
    if (authority) |key| {
        out[21] = 1;
        @memcpy(out[22..54], key);
    } else {
        out[21] = 0;
    }
    var cursor: usize = alt.LOOKUP_TABLE_META_SIZE;
    for (addresses) |*address| {
        @memcpy(out[cursor..][0..sol.PUBKEY_BYTES], address);
        cursor += sol.PUBKEY_BYTES;
    }
    return out[0..cursor];
}

test "parses address lookup table account info from RPC account data" {
    const allocator = std.testing.allocator;
    const authority: Pubkey = .{9} ** sol.PUBKEY_BYTES;
    const addresses = [_]Pubkey{
        .{1} ** sol.PUBKEY_BYTES,
        .{2} ** sol.PUBKEY_BYTES,
    };
    var raw: [alt.LOOKUP_TABLE_META_SIZE + addresses.len * sol.PUBKEY_BYTES]u8 = undefined;
    const raw_data = writeLookupTableFixture(&raw, &authority, &addresses);
    var encoded_buf: [std.base64.standard.Encoder.calcSize(raw.len)]u8 = undefined;
    const encoded = std.base64.standard.Encoder.encode(&encoded_buf, raw_data);

    var json_buf: [512]u8 = undefined;
    const account_json = try std.fmt.bufPrint(
        &json_buf,
        "{{\"jsonrpc\":\"2.0\",\"result\":{{\"context\":{{\"slot\":12}},\"value\":{{\"lamports\":123,\"owner\":\"AddressLookupTab1e1111111111111111111111111\",\"executable\":false,\"rentEpoch\":42,\"data\":[\"{s}\",\"base64\"],\"space\":{}}}}},\"id\":8}}",
        .{ encoded, raw_data.len },
    );
    const parsed = try parseGetAccountInfoResponse(allocator, account_json);
    defer parsed.deinit();
    var decoded: [raw.len]u8 = undefined;

    const table = try parseAddressLookupTableAccountInfo(parsed.value.result.?.value.?, &decoded);
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u64)), table.meta.deactivation_slot);
    try std.testing.expectEqual(@as(u64, 88), table.meta.last_extended_slot);
    try std.testing.expectEqualSlices(u8, &authority, &table.meta.authority.?);
    try std.testing.expectEqual(@as(usize, addresses.len), table.addresses.len);
    try std.testing.expectEqualSlices(u8, &addresses[1], &table.addresses[1]);
}

test "address lookup table account info rejects wrong owner" {
    const allocator = std.testing.allocator;
    const account_json =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":12},"value":{"lamports":123,"owner":"11111111111111111111111111111111","executable":false,"rentEpoch":42,"data":["AQIDBA==","base64"],"space":4}},"id":8}
    ;
    const parsed = try parseGetAccountInfoResponse(allocator, account_json);
    defer parsed.deinit();
    var decoded: [4]u8 = undefined;
    try std.testing.expectError(
        error.InvalidAccountOwner,
        parseAddressLookupTableAccountInfo(parsed.value.result.?.value.?, &decoded),
    );
}

test "parses sendTransaction, simulateTransaction, and RPC error responses" {
    const allocator = std.testing.allocator;

    const send_json =
        \\{"jsonrpc":"2.0","result":"5wHu1qwBqqyqSutnXrTxiJdqWwJdP6sM2uH3a9xFJxHg","id":3}
    ;
    const parsed_send = try parseSendTransactionResponse(allocator, send_json);
    defer parsed_send.deinit();
    try std.testing.expectEqualStrings(
        "5wHu1qwBqqyqSutnXrTxiJdqWwJdP6sM2uH3a9xFJxHg",
        parsed_send.value.result.?,
    );

    const simulate_json =
        \\{"jsonrpc":"2.0","result":{"context":{"slot":11},"value":{"err":null,"logs":["Program log: ok"],"unitsConsumed":42}},"id":4}
    ;
    const parsed_simulate = try parseSimulateTransactionResponse(allocator, simulate_json);
    defer parsed_simulate.deinit();
    try std.testing.expectEqual(@as(u64, 11), parsed_simulate.value.result.?.context.slot);
    try std.testing.expectEqual(@as(u64, 42), parsed_simulate.value.result.?.value.unitsConsumed.?);
    try std.testing.expectEqualStrings("Program log: ok", parsed_simulate.value.result.?.value.logs.?[0]);

    const err_json =
        \\{"jsonrpc":"2.0","error":{"code":-32002,"message":"Transaction simulation failed"},"id":4}
    ;
    const parsed_error = try parseSimulateTransactionResponse(allocator, err_json);
    defer parsed_error.deinit();
    try std.testing.expect(parsed_error.value.result == null);
    try std.testing.expectEqual(@as(i64, -32002), parsed_error.value.@"error".?.code);
    try std.testing.expectEqualStrings(
        "Transaction simulation failed",
        parsed_error.value.@"error".?.message,
    );
}

test "parses subscription responses and account notifications" {
    const allocator = std.testing.allocator;

    const subscription_json =
        \\{"jsonrpc":"2.0","result":42,"id":10}
    ;
    const subscription = try parseSubscriptionResponse(allocator, subscription_json);
    defer subscription.deinit();
    try std.testing.expectEqual(@as(SubscriptionId, 42), subscription.value.result.?);

    const unsubscribe_json =
        \\{"jsonrpc":"2.0","result":true,"id":11}
    ;
    const unsubscribe = try parseUnsubscribeResponse(allocator, unsubscribe_json);
    defer unsubscribe.deinit();
    try std.testing.expect(unsubscribe.value.result.?);

    const notification_json =
        \\{"jsonrpc":"2.0","method":"accountNotification","params":{"result":{"context":{"slot":12},"value":{"lamports":123,"owner":"11111111111111111111111111111111","executable":false,"rentEpoch":42,"data":["AQIDBA==","base64"],"space":4}},"subscription":42}}
    ;
    const notification = try parseAccountNotification(allocator, notification_json);
    defer notification.deinit();
    try std.testing.expectEqualStrings("accountNotification", notification.value.method);
    try std.testing.expectEqual(@as(SubscriptionId, 42), notification.value.params.subscription);
    try std.testing.expectEqual(@as(u64, 12), notification.value.params.result.context.slot);
    try std.testing.expectEqual(@as(u64, 123), notification.value.params.result.value.?.lamports);
}

test "normalizes rpc errors and retry policy" {
    const unhealthy = normalizeRpcError(.{ .code = -32005, .message = "Node is unhealthy" });
    try std.testing.expectEqual(RpcErrorKind.node_unhealthy, unhealthy.kind);
    try std.testing.expect(unhealthy.retryable);

    const preflight = normalizeRpcError(.{ .code = -32002, .message = "Transaction simulation failed" });
    try std.testing.expectEqual(RpcErrorKind.preflight_failure, preflight.kind);
    try std.testing.expect(!preflight.retryable);

    const policy: RetryPolicy = .{ .initial_delay_ms = 50, .max_delay_ms = 120 };
    try std.testing.expect(policy.shouldRetryTransport(error.Timeout));
    try std.testing.expect(!policy.shouldRetryTransport(error.InvalidResponse));
    try std.testing.expectEqual(@as(u32, 50), policy.delayMs(0));
    try std.testing.expectEqual(@as(u32, 100), policy.delayMs(1));
    try std.testing.expectEqual(@as(u32, 120), policy.delayMs(2));
}

test "endpoint pool validates and derives websocket urls" {
    const endpoints = [_]Endpoint{
        .{ .url = "https://api.mainnet-beta.solana.com", .default_commitment = .confirmed },
        .{ .url = "http://127.0.0.1:8899", .websocket_url = "ws://127.0.0.1:8900" },
    };
    var pool: EndpointPool = .{ .endpoints = &endpoints };

    const first = try pool.next();
    try std.testing.expectEqualStrings("https://api.mainnet-beta.solana.com", first.url);
    var ws_buf: [64]u8 = undefined;
    const first_ws = try writeWebsocketUrl(first, &ws_buf);
    try std.testing.expectEqualStrings("wss://api.mainnet-beta.solana.com", first_ws);

    const second = try pool.next();
    const second_ws = try writeWebsocketUrl(second, &ws_buf);
    try std.testing.expectEqualStrings("ws://127.0.0.1:8900", second_ws);
    try std.testing.expectError(error.InvalidEndpointUrl, (Endpoint{ .url = "ftp://bad" }).validate());
}

const FakeTransport = struct {
    calls: u8 = 0,
    fail_first: bool = false,
    expected_body: []const u8,
    response: []const u8,

    fn transport(self: *FakeTransport) Transport {
        return .{ .context = self, .sendFn = send };
    }

    fn send(context: *anyopaque, request: TransportRequest, response_out: []u8) TransportError![]const u8 {
        const self: *FakeTransport = @ptrCast(@alignCast(context));
        self.calls += 1;
        if (request.kind != .http_json_rpc) return error.InvalidResponse;
        if (request.method != .post) return error.InvalidResponse;
        if (!std.mem.eql(u8, "https://rpc.example", request.endpoint_url)) return error.InvalidResponse;
        if (!std.mem.eql(u8, self.expected_body, request.body)) return error.InvalidResponse;
        if (self.fail_first and self.calls == 1) return error.Timeout;
        if (response_out.len < self.response.len) return error.ResponseTooLarge;
        @memcpy(response_out[0..self.response.len], self.response);
        return response_out[0..self.response.len];
    }
};

const FakeWebSocketTransport = struct {
    calls: u8 = 0,
    expected_url: []const u8,
    expected_body: []const u8,
    expected_timeout_ms: u32,
    response: []const u8,

    fn transport(self: *FakeWebSocketTransport) Transport {
        return .{ .context = self, .sendFn = send };
    }

    fn send(context: *anyopaque, request: TransportRequest, response_out: []u8) TransportError![]const u8 {
        const self: *FakeWebSocketTransport = @ptrCast(@alignCast(context));
        self.calls += 1;
        if (request.kind != .websocket_json_rpc) return error.InvalidResponse;
        if (!std.mem.eql(u8, self.expected_url, request.endpoint_url)) return error.InvalidResponse;
        if (!std.mem.eql(u8, self.expected_body, request.body)) return error.InvalidResponse;
        if (request.timeout_ms != self.expected_timeout_ms) return error.Timeout;
        if (response_out.len < self.response.len) return error.ResponseTooLarge;
        @memcpy(response_out[0..self.response.len], self.response);
        return response_out[0..self.response.len];
    }
};

test "client sends through transport and retries retryable failures" {
    const expected_body =
        "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"getBalance\",\"params\":[\"11111111111111111111111111111111\",{\"commitment\":\"confirmed\"}]}";
    const response_json =
        "{\"jsonrpc\":\"2.0\",\"result\":{\"context\":{\"slot\":1},\"value\":2},\"id\":7}";
    var fake = FakeTransport{
        .fail_first = true,
        .expected_body = expected_body,
        .response = response_json,
    };
    const client: Client = .{
        .endpoint = .{ .url = "https://rpc.example", .default_commitment = .confirmed },
        .transport = fake.transport(),
        .config = .{ .retry_policy = .{ .max_attempts = 2 } },
    };
    var request_buf: [160]u8 = undefined;
    var response_buf: [160]u8 = undefined;
    const response = try client.getBalance(
        7,
        "11111111111111111111111111111111",
        &request_buf,
        &response_buf,
    );
    try std.testing.expectEqual(@as(u8, 2), fake.calls);
    try std.testing.expectEqualStrings(response_json, response);
}

test "client sends websocket subscription requests through websocket transport" {
    const expected_body =
        "{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"accountSubscribe\",\"params\":[\"11111111111111111111111111111111\",{\"encoding\":\"base64\",\"commitment\":\"confirmed\"}]}";
    const response_json =
        "{\"jsonrpc\":\"2.0\",\"result\":42,\"id\":10}";
    var fake = FakeWebSocketTransport{
        .expected_url = "wss://rpc.example",
        .expected_body = expected_body,
        .expected_timeout_ms = 12_345,
        .response = response_json,
    };
    const client: Client = .{
        .endpoint = .{ .url = "https://rpc.example", .default_commitment = .confirmed },
        .transport = fake.transport(),
        .config = .{ .subscription_timeout_ms = 12_345 },
    };
    var request_buf: [192]u8 = undefined;
    var websocket_url_buf: [64]u8 = undefined;
    var response_buf: [64]u8 = undefined;
    const response = try client.accountSubscribe(
        10,
        "11111111111111111111111111111111",
        &request_buf,
        &websocket_url_buf,
        &response_buf,
    );
    try std.testing.expectEqual(@as(u8, 1), fake.calls);
    try std.testing.expectEqualStrings(response_json, response);
}

test "std http transport maps unsupported protocols before network use" {
    var undefined_client: std.http.Client = undefined;
    var std_transport: StdHttpTransport = .{ .client = &undefined_client };
    const transport = std_transport.transport();
    var response_buf: [16]u8 = undefined;

    try std.testing.expectError(error.UnsupportedProtocol, transport.send(.{
        .kind = .websocket_json_rpc,
        .method = .post,
        .endpoint_url = "wss://rpc.example",
        .body = "{}",
        .timeout_ms = 1,
    }, &response_buf));
    try std.testing.expectError(error.UnsupportedProtocol, transport.send(.{
        .kind = .http_json_rpc,
        .method = .post,
        .endpoint_url = "ftp://rpc.example",
        .body = "{}",
        .timeout_ms = 1,
    }, &response_buf));
}

test "http status maps to transport errors" {
    try std.testing.expect(transportErrorForHttpStatus(.ok) == null);
    try std.testing.expectEqual(error.RateLimited, transportErrorForHttpStatus(.too_many_requests).?);
    try std.testing.expectEqual(error.ServerUnavailable, transportErrorForHttpStatus(.service_unavailable).?);
    try std.testing.expectEqual(error.ServerUnavailable, transportErrorForHttpStatus(.internal_server_error).?);
    try std.testing.expectEqual(error.InvalidResponse, transportErrorForHttpStatus(.bad_request).?);
}

test "public surface guards" {
    try std.testing.expectEqualStrings("processed", Commitment.processed.jsonName());
    try std.testing.expectEqualStrings("POST", HttpMethod.post.jsonName());
    try std.testing.expectEqualStrings("base64+zstd", AccountEncoding.base64_zstd.jsonName());
    try std.testing.expectEqual(@as(usize, sol.PUBKEY_BYTES), @sizeOf(Pubkey));
    try std.testing.expect(@hasDecl(@This(), "StdHttpTransport"));
    try std.testing.expect(@hasDecl(@This(), "buildGetAccountInfoRequest"));
    try std.testing.expect(@hasDecl(@This(), "parseGetAccountInfoResponse"));
    try std.testing.expect(@hasDecl(@This(), "decodeAccountInfoBase64Data"));
    try std.testing.expect(@hasDecl(Client, "fetchAddressLookupTable"));
    try std.testing.expect(@hasDecl(@This(), "parseAddressLookupTableAccountInfo"));
    try std.testing.expect(@hasDecl(@This(), "buildAccountSubscribeRequest"));
    try std.testing.expect(@hasDecl(@This(), "buildProgramSubscribeRequest"));
    try std.testing.expect(@hasDecl(@This(), "buildLogsSubscribeMentionsRequest"));
    try std.testing.expect(@hasDecl(@This(), "buildSignatureSubscribeRequest"));
    try std.testing.expect(@hasDecl(@This(), "parseSubscriptionResponse"));
    try std.testing.expect(@hasDecl(@This(), "parseAccountNotification"));
    try std.testing.expect(@hasDecl(Client, "accountSubscribe"));
}
