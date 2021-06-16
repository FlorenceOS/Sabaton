#!/bin/env python3

# Examples:
#   Dump TCON0 gamma table:
#     ./dump_reg_range.py /dev/ttyUSB0 1C0C400 400

import serial
import os
import sys

def read_addr(ser, addr):
  ser.write(b"devmem " + hex(addr).encode('utf-8') + b'\r\n')
  ser.readline()
  result = ser.readline().strip().decode('utf-8')
  ser.readline()
  return result

def dump_addr_range(ser, base, end, step_size):
  offset = 0

  while base + offset < end:
    print(f"  {read_addr(ser, base + offset)}, // offset: 0x{offset:04X}")
    offset += step_size


def main():
  ser = serial.Serial(sys.argv[1], 115200)
  base_addr = int(sys.argv[2], 16)
  size = int(sys.argv[3], 16)
  dump_addr_range(ser, base_addr, base_addr + size, 4)

if __name__ ==  '__main__':
  main()
