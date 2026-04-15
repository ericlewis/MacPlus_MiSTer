#!/usr/bin/env python3
"""
Reverse bitstream for Analogue Pocket.

The Pocket requires bit-reversed RBF files (RBF_R format).
For each byte in the input file, the bit order is reversed:
  bit 7 ↔ bit 0, bit 6 ↔ bit 1, etc.

Usage:
    python3 reverse_bitstream.py input.rbf output.rbf_r
"""

import sys

def reverse_bits(byte):
    """Reverse the bit order of a single byte."""
    result = 0
    for i in range(8):
        result |= ((byte >> i) & 1) << (7 - i)
    return result

# Pre-compute lookup table for speed
REVERSE_TABLE = bytes(reverse_bits(i) for i in range(256))

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.rbf> <output.rbf_r>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    with open(input_path, 'rb') as f:
        data = f.read()

    reversed_data = data.translate(REVERSE_TABLE)

    with open(output_path, 'wb') as f:
        f.write(reversed_data)

    print(f"Reversed {len(data)} bytes: {input_path} → {output_path}")

if __name__ == '__main__':
    main()
