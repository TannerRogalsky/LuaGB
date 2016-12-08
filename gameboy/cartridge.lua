local memory = require("gameboy/memory")
local rom_header = require("gameboy/rom_header")

local cartridge = {}

local mbc_none = require("gameboy/mbc/none")
local mbc1 = require("gameboy/mbc/mbc1")
local mbc3 = require("gameboy/mbc/mbc3")

local external_ram = memory.generate_block(32 * 1024)

local mbc_mappings = {}
mbc_mappings[0x00] = mbc_none
mbc_mappings[0x01] = mbc1
mbc_mappings[0x02] = mbc1
mbc_mappings[0x03] = mbc1

mbc_mappings[0x11] = mbc3
mbc_mappings[0x12] = mbc3
mbc_mappings[0x13] = mbc3

cartridge.load = function(file_data, size)
  print("Reading cartridge into memory...")
  cartridge.raw_data = {}
  for i = 0, size - 1 do
    cartridge.raw_data[i] = file_data:byte(i + 1)
  end
  print("Read " .. math.ceil(#cartridge.raw_data / 1024) .. " kB")
  cartridge.header = rom_header.parse_cartridge_header(cartridge.raw_data)
  rom_header.print_cartridge_header(cartridge.header)

  if mbc_mappings[cartridge.header.mbc_type] then
    print("Using mapper: ", cartridge.header.mbc_name)
    mbc_mappings[cartridge.header.mbc_type].raw_data = cartridge.raw_data
    mbc_mappings[cartridge.header.mbc_type].external_ram = external_ram
    -- Cart ROM
    memory.map_block(0x00, 0x7F, mbc_mappings[cartridge.header.mbc_type])
    -- External RAM
    memory.map_block(0xA0, 0xBF, mbc_mappings[cartridge.header.mbc_type], 0x0000)
  else
    print("Unsupported MBC type! Defaulting to ROM ONLY, game will probably not boot.")
    mbc_mappings[0x00].raw_data = cartridge.raw_data
    mbc_mappings[0x00].external_ram = external_ram
    memory.map_block(0x00, 0x7F, mbc_mappings[0x00])
    memory.map_block(0xA0, 0xBF, mbc_mappings[0x00], 0x0000)
  end

  -- Add a guard to cartridge.raw_data, such that any out-of-bounds reads return 0x00
  cartridge.raw_data.mt = {}
  cartridge.raw_data.mt.__index = function(table, address)
    -- Data doesn't exist? Tough luck; return 0x00
    return 0x00
  end
  setmetatable(cartridge.raw_data, cartridge.raw_data.mt)

end

return cartridge
