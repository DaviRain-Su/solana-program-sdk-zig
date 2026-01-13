# sol-anchor-zig

Anchor-like framework for Solana program development in Zig.

This package is extracted from `solana_program_sdk` and lives as a subpackage in the same repository. It depends on `solana_program_sdk` via a path dependency.

## Usage

```zig
const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const CounterData = struct {
    count: u64,
    authority: sol.PublicKey,
};

const Counter = anchor.Account(CounterData, .{
    .discriminator = anchor.accountDiscriminator("Counter"),
});
```

## IDL + Zig Client

```zig
const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const MyProgram = struct {
    pub const id = sol.PublicKey.comptimeFromBase58("11111111111111111111111111111111");

    pub const instructions = struct {
        pub const initialize = anchor.Instruction(.{
            .Accounts = InitializeAccounts,
            .Args = InitializeArgs,
        });
    };
};

const idl_json = try anchor.generateIdlJson(allocator, MyProgram, .{});
const client_src = try anchor.generateZigClient(allocator, MyProgram, .{});
```

## Program Entry (Typed Dispatch)

```zig
const anchor = @import("sol_anchor_zig");
const sol = anchor.sdk;

const Program = struct {
    pub const id = sol.PublicKey.comptimeFromBase58("11111111111111111111111111111111");

    pub const instructions = struct {
        pub const initialize = anchor.Instruction(.{
            .Accounts = InitializeAccounts,
            .Args = InitializeArgs,
        });
    };

    pub fn initialize(ctx: anchor.Context(InitializeAccounts), args: InitializeArgs) !void {
        _ = ctx;
        _ = args;
    }

    pub fn fallback(ctx: anchor.FallbackContext) !void {
        _ = ctx;
    }
};

pub fn processInstruction(
    program_id: *const sol.PublicKey,
    accounts: []const sol.account.Account.Info,
    data: []const u8,
) !void {
    try anchor.ProgramEntry(Program).dispatchWithConfig(program_id, accounts, data, .{
        .fallback = Program.fallback,
    });
}
```

## IDL Output (Build Step)

```bash
cd anchor
../solana-zig/zig build idl \
  -Didl-program=../path/to/program.zig \
  -Didl-output=idl/my_program.json
```

`idl-program` must export `pub const Program`.

## Program Client

```zig
const client = @import("solana_client");
var rpc = client.RpcClient.init(allocator, "http://localhost:8899");
var program = ProgramClient.init(allocator, &rpc);

const sig = try program.sendInitialize(authority, payer, counter, args, &.{ &payer_kp, &authority_kp });
```

## Comptime Derives

```zig
const Accounts = anchor.Accounts(struct {
    authority: anchor.Signer,
    counter: anchor.Account(CounterData, .{
        .discriminator = anchor.accountDiscriminator("Counter"),
        .attrs = &.{
            anchor.attr.seeds(&.{ anchor.seed("counter"), anchor.seedAccount("authority") }),
            anchor.attr.bump(),
            anchor.attr.constraint("authority.key() == counter.authority"),
        },
    }),
});

const CounterLoader = anchor.AccountLoader(CounterData, .{
    .discriminator = anchor.accountDiscriminator("Counter"),
});

const CounterLazy = anchor.LazyAccount(CounterData, .{
    .discriminator = anchor.accountDiscriminator("Counter"),
});

const AccountsSugar = anchor.Accounts(struct {
    authority: anchor.Signer,
    counter: anchor.Account(CounterData, .{
        .discriminator = anchor.accountDiscriminator("Counter"),
        .attrs = anchor.attr.account(.{
            .seeds = &.{ anchor.seed("counter"), anchor.seedAccount("authority") },
            .seeds_program = anchor.seedAccount("authority"),
            .bump_field = "bump",
            .constraint = "authority.key() == counter.authority",
        }),
    }),
});

const AccountsTyped = anchor.Accounts(struct {
    authority: anchor.Signer,
    counter: anchor.Account(CounterData, .{
        .discriminator = anchor.accountDiscriminator("Counter"),
        .attrs = anchor.attr.account(.{
            .mut = true,
            .signer = true,
            .seeds = &.{ anchor.seed("counter"), anchor.seedAccount("authority") },
            .bump_field = "bump",
            .owner_expr = "authority.key()",
            .space_expr = "8 + INIT_SPACE",
            .constraint = "authority.key() == counter.authority",
        }),
    }),
});

const CounterTyped = anchor.Account(CounterData, .{
    .discriminator = anchor.accountDiscriminator("Counter"),
    .bump_field = anchor.dataField(CounterData, .bump),
    .seeds = &.{
        anchor.seed("counter"),
        anchor.seedDataField(CounterData, .authority),
    },
});

const FieldAccounts = anchor.AccountsWith(struct {
    authority: anchor.Signer,
    counter: CounterTyped,
}, .{
    .counter = anchor.attr.account(.{
        .mut = true,
        .signer = true,
    }),
});

const FieldAccountsDerive = anchor.AccountsDerive(struct {
    authority: anchor.Signer,
    counter: CounterTyped,
    pub const attrs = .{
        .counter = anchor.attr.account(.{
            .mut = true,
            .signer = true,
        }),
    };
});

const CounterEvent = anchor.Event(struct {
    amount: anchor.eventField(u64, .{ .index = true }),
    owner: sol.PublicKey,
});
```

Indexed event fields must be `bool`, fixed-size integers (`u8/u16/u32/u64/u128/u256` and signed),
or `sol.PublicKey`. `usize/isize` are rejected to keep IDL stable across targets.

## AccountsDerive Auto Inference (Token/Mint/ATA)

AccountsDerive can auto-infer common token/mint/ata constraints when the
account data shape and field names match expected patterns.
It recognizes common aliases like `mint_account`, `token_mint_account`, and
`wallet`/`token_owner` for authority fields, and auto-wraps sysvars like `epoch_schedule`,
`recent_blockhashes`, and `fees` (including `sysvar_*` prefix), plus program aliases like `bpf_loader`,
`bpf_loader_upgradeable`, and `loader_v4`.
Associated token inference accepts either `owner` or `authority` fields in the
account data shape.
Associated token inference requires both `associated_token_program` and
`token_program` fields to be present in Accounts.
Cross-field constraints (token/mint/associated token refs) are validated at
comptime to ensure referenced Accounts fields exist and provide `key()`. Program
references (token_program/mint_token_program) are also checked to be Program or
UncheckedProgram fields.
The AccessFor owner reference must target a Program/UncheckedProgram field.
AccountsDerive also enforces that init/init_if_needed include a `system_program`
field, and token/mint/associated token constraints include the required
program fields (token_program/associated_token_program).
Payer/close/realloc targets are validated to ensure they expose `toAccountInfo()`
or are raw `AccountInfo` pointers.
Rent exemption is enforced at runtime when `rent_exempt` is set.
Common program aliases include `bpf_loader`, `bpf_loader_upgradeable`, `loader_v4`,
`compute_budget_program`, `address_lookup_table_program`, `ed25519_program`,
`secp256k1_program`, `secp256r1_program`, `vote_program`, and `feature_gate_program`.
Program auto binding applies to both `anchor.Program` and `anchor.UncheckedProgram` fields.

```zig
const TokenAccountData = struct {
    mint: sol.PublicKey,
    owner: sol.PublicKey,
};

const MintData = struct {
    mint_authority: sol.PublicKey,
    freeze_authority: sol.PublicKey,

    pub const DECIMALS: u8 = 6;
};

const TokenAccount = anchor.Account(TokenAccountData, .{
    .discriminator = anchor.accountDiscriminator("TokenAccount"),
});

const MintAccount = anchor.Account(MintData, .{
    .discriminator = anchor.accountDiscriminator("MintAccount"),
});

const AccountsAuto = anchor.AccountsDerive(struct {
    authority: anchor.Signer,
    token_mint: *const anchor.sdk.account.Account.Info,
    token_program: anchor.UncheckedProgram,
    ata_program: anchor.UncheckedProgram,
    token_account: TokenAccount,
    mint_account: MintAccount,
});
```

Supported aliases:

- token program: `token_program`, `spl_token_program`, `token_program_id`, `token_program_account`
- associated token program: `associated_token_program`, `associated_token_program_id`,
  `associated_token_program_account`, `ata_program`, `ata_program_id`
- token mint/authority: `mint` or `token_mint`, `authority` or `token_authority`
- token mint extended: `mint_pubkey`, `token_mint_pubkey`, `mint_key`, `token_mint_key`
- token mint extended: `mint_address`, `token_mint_address`, `mint_pk`, `token_mint_pk`
- token authority extended: `owner_pubkey`, `wallet_pubkey`, `authority_key`, `authority_address`,
  `owner_key`, `owner_address`, `wallet_address`

Constraint rules:

- `associated_token` cannot be combined with `token::*` or `mint::*` constraints.
- `token::*` constraints cannot be combined with `mint::*` constraints.
- `init`/`init_if_needed` validates account is writable and uninitialized; payer must be signer + writable.
- `executable` cannot be combined with `mut`, `signer`, `init`, `close`, or `realloc`.
- `zero` requires the discriminator bytes to be all zero.
- `space` enforces exact account data length when explicitly set.
- Duplicate mutable accounts are rejected unless the duplicated field uses `dup`.
- `token::mint/authority` validates the token account state and token program owner.
- `mint::authority/freeze_authority/decimals` validates the mint state and token program owner.
- `associated_token` validates the derived ATA address, token owner field, and token program owner.

## Build & Test

```bash
cd anchor
../solana-zig/zig build test --summary all
```
