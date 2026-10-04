//! Internal reflection shared by the Zig 0.16 and 0.17 implementations.
const std = @import("std");
const Type = std.builtin.Type;

pub const StructField = if (@hasDecl(Type, "StructField")) Type.StructField else struct {
    name: [:0]const u8,
    type: type,
    default_value_ptr: ?*const anyopaque,
    is_comptime: bool,
    alignment: ?usize,

    pub inline fn defaultValue(comptime field: @This()) ?field.type {
        const ptr: *const field.type = @ptrCast(@alignCast(field.default_value_ptr orelse return null));
        return ptr.*;
    }
};

pub const UnionField = if (@hasDecl(Type, "UnionField")) Type.UnionField else struct {
    name: [:0]const u8,
    type: type,
    alignment: ?usize,
};

pub const EnumField = if (@hasDecl(Type, "EnumField")) Type.EnumField else struct {
    name: [:0]const u8,
    value: comptime_int,
};

fn Field(comptime Info: type) type {
    return switch (Info) {
        Type.Struct => StructField,
        Type.Union => UnionField,
        Type.Enum => EnumField,
        else => @compileError("expected struct, union, or enum reflection"),
    };
}

/// Retains field order, explicit alignment, and default/comptime field metadata.
pub inline fn fields(comptime info: anytype) []const Field(@TypeOf(info)) {
    if (@hasField(@TypeOf(info), "fields")) return info.fields;
    const result = comptime blk: {
        var result: [info.field_names.len]Field(@TypeOf(info)) = undefined;
        for (info.field_names, 0..) |name, i| {
            result[i] = switch (@TypeOf(info)) {
                Type.Struct => .{
                    .name = name,
                    .type = info.field_types[i],
                    .default_value_ptr = info.field_attrs[i].default_value_ptr,
                    .is_comptime = info.field_attrs[i].@"comptime",
                    .alignment = info.field_attrs[i].@"align",
                },
                Type.Union => .{
                    .name = name,
                    .type = info.field_types[i],
                    .alignment = info.field_attrs[i].@"align",
                },
                Type.Enum => .{ .name = name, .value = info.field_values[i] },
                else => unreachable,
            };
        }
        break :blk result;
    };
    return &result;
}

pub inline fn paramTypes(comptime info: Type.Fn) []const ?type {
    if (@hasField(Type.Fn, "param_types")) return info.param_types;
    const result = comptime blk: {
        var result: [info.params.len]?type = undefined;
        for (info.params, 0..) |param, i| result[i] = param.type;
        break :blk result;
    };
    return &result;
}
