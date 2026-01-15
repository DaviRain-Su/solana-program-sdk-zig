//! Example: SysvarData wrappers.

const anchor = @import("sol_anchor_zig");

const Accounts = struct {
    clock: anchor.ClockData,
    rent: anchor.RentData,
    epoch_schedule: anchor.EpochScheduleData,
};

pub fn readSysvars(ctx: anchor.Context(Accounts)) !void {
    _ = ctx.accounts.clock.data;
    _ = ctx.accounts.rent.data;
    _ = ctx.accounts.epoch_schedule.data;
}
