const std = @import("std");
const uefi = std.os.uefi;

const sabaton = @import("root").sabaton;

const root = @import("root");

pub fn init(page_root: *sabaton.paging.Root) callconv(.Inline) void {
    const graphicsProto = root.locateProtocol(uefi.protocols.GraphicsOutputProtocol) orelse {
        sabaton.puts("No graphics protocol found!\n");
        return;
    };

    sabaton.add_framebuffer(graphicsProto.mode.frame_buffer_base);

    const mode = graphicsProto.mode.info;

    switch (mode.pixel_format) {
        .PixelRedGreenBlueReserved8BitPerColor,
        .PixelBlueGreenRedReserved8BitPerColor,
        => {
            sabaton.fb.bpp = 32;
            sabaton.fb.red_mask_size = 8;
            sabaton.fb.blue_mask_size = 8;
            sabaton.fb.green_mask_size = 8;
        },
        .PixelBitMask => {
            const mask = mode.pixel_information;
            sabaton.fb.bpp = if (mask.reserved_mask == 0) 24 else 32;
        },
        else => unreachable,
    }

    switch (mode.pixel_format) {
        .PixelRedGreenBlueReserved8BitPerColor => {
            sabaton.fb.red_mask_shift = 0;
            sabaton.fb.green_mask_shift = 8;
            sabaton.fb.blue_mask_shift = 16;
        },
        .PixelBlueGreenRedReserved8BitPerColor => {
            sabaton.fb.blue_mask_shift = 0;
            sabaton.fb.green_mask_shift = 8;
            sabaton.fb.red_mask_shift = 16;
        },
        .PixelBitMask => {
            const mask = mode.pixel_information;
            sabaton.fb.red_mask_shift = @ctz(u32, mask.red_mask);
            sabaton.fb.red_mask_size = @popCount(u32, mask.red_mask);
            sabaton.fb.green_mask_shift = @ctz(u32, mask.green_mask);
            sabaton.fb.green_mask_size = @popCount(u32, mask.green_mask);
            sabaton.fb.blue_mask_shift = @ctz(u32, mask.blue_mask);
            sabaton.fb.blue_mask_size = @popCount(u32, mask.blue_mask);
        },
        else => unreachable,
    }

    sabaton.fb.width = @intCast(u16, mode.horizontal_resolution);
    sabaton.fb.height = @intCast(u16, mode.vertical_resolution);
    sabaton.fb.pitch = @intCast(u16, mode.pixels_per_scan_line * sabaton.fb.bpp / 8);

    if (!root.memmap.containsAddr(sabaton.fb.addr)) {
        // We need to map it ourselves
        const fbsz = @as(u64, sabaton.fb.pitch) * @as(u64, sabaton.fb.height);
        sabaton.paging.map(sabaton.fb.addr, sabaton.fb.addr, fbsz, .rw, .memory, page_root);
        sabaton.paging.map(sabaton.upper_half_phys_base + sabaton.fb.addr, sabaton.fb.addr, fbsz, .rw, .memory, page_root);
    }

    sabaton.puts("Mapped framebuffer!\n");
}
