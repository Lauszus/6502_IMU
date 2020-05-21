#!/usr/bin/python
#
# Kristian Sloth Lauszus, 2020.
# The code is released under the MIT License.
#
# Contact information
# -------------------
# Kristian Lauszus
# Web      :  http://www.lauszus.com
# e-mail   :  lauszus@gmail.com

from math import atan2, pi, ceil


def chunks(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


# Create a 6-bit lookup table
ratio = 7. / 63.  # 0.11
atan2_lut = []
for yx in range(0, 63 + 1):
    # Top 3-bits is the y-value and the lower 3-bits is the x-value
    # by dividing by pi we normalize the value and then it's multiplied by 180 deg
    atan2_lut.append(round(atan2((yx >> 3) + ratio, (yx & 7) + ratio) / pi * 0x20))
print('.atan2_lut:')
for lut in chunks(atan2_lut, 16):
    print('  .byte %s' % ','.join('${:02X}'.format(x) for x in lut))
# The offsets are simply a list of 0, 90, 270, 180 degrees
atan2_offsets = []
for i in range(0, 4):
    atan2_offsets.append(0x10 * i)
# Swap the last two value, as the function uses a unconventional quadrant system internally
atan2_offsets[2], atan2_offsets[3] = atan2_offsets[3], atan2_offsets[2]
print('.atan2_offsets:')
print('  .byte %s' % ','.join('${:02X}'.format(x) for x in atan2_offsets))
print()

# Create a 8-bit lookup table
ratio = 15. / 255.  # 0.059
atan2_lut = []
for yx in range(0, 255 + 1):
    # Top 4-bits is the y-value and the lower 4-bits is the x-value
    # by dividing by pi we normalize the value and then it's multiplied by 180 deg
    atan2_lut.append(round(atan2((yx >> 4) + ratio, (yx & 15) + ratio) / pi * 0x80))
print('.atan2_lut:')
for lut in chunks(atan2_lut, 16):
    print('  .byte %s' % ','.join('${:02X}'.format(x) for x in lut))
# The offsets are simply a list of 0, 90, 270, 180 degrees
atan2_offsets = []
for i in range(0, 4):
    atan2_offsets.append(0x40 * i)
# Swap the last two value, as the function uses a unconventional quadrant system internally
atan2_offsets[2], atan2_offsets[3] = atan2_offsets[3], atan2_offsets[2]
print('.atan2_offsets:')
print('  .byte %s' % ','.join('${:02X}'.format(x) for x in atan2_offsets))
print()


# A general function for generating the lookup table
def gen_atan2_lut(bits):
    deg_360 = 2 ** bits
    deg_180, deg_90 = deg_360 >> 1, deg_360 >> 2
    bit_mask = 2 ** (bits >> 1) - 1
    ratio = bit_mask / (deg_360 - 1)
    atan2_lut = []
    for yx in range(0, deg_360):
        # Top bits is the y-value and the lower bits is the x-value
        # by dividing by pi we normalize the value and then it's multiplied by 180 deg
        atan2_lut.append(round(atan2((yx >> (bits >> 1)) + ratio, (yx & bit_mask) + ratio) / pi * deg_180))
    print('.atan2_lut:')
    for lut in chunks(atan2_lut, 16):
        print('  %s %s' % ('.byte' if bits <= 8 else '.word', ','.join('${number:0{width}X}'.format(width=ceil(bits / 4), number=x) for x in lut)))
    # The offsets are simply a list of 0, 90, 270, 180 degrees
    atan2_offsets = []
    for i in range(0, 4):
        atan2_offsets.append(deg_90 * i)
    # Swap the last two value, as the function uses a unconventional quadrant system internally
    atan2_offsets[2], atan2_offsets[3] = atan2_offsets[3], atan2_offsets[2]
    print('.atan2_offsets:')
    print('  %s %s' % ('.byte' if bits <= 8 else '.word', ','.join('${number:0{width}X}'.format(width=ceil(bits / 4), number=x) for x in atan2_offsets)))
    print()


gen_atan2_lut(6)
gen_atan2_lut(8)
# gen_atan2_lut(12)
