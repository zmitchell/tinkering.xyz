+++
title = "Bit mask tables"
date = 2022-09-27
draft = false
[extra]
show_date = true
+++

At `$WORK` I have a need to create some bitmasks over a 64-bit field. I've never done this before. I figured that *surely* tables exist for grabbing a certain number of bits from a certain position, but I never found those tables. So, to scratch my own itch I wrote a very simple Python program to generate the tables and used a CSV to Markdown converter to create the tables. Here you go, now we both have a quick reference.

## Program
```python
bit_sizes = [1, 8, 16, 32]
total_bits = 64

for bit_size in bit_sizes:
    positions = int(total_bits / bit_size)
    n = 0
    for _ in range(bit_size):
        n = n << 1
        n += 1
    print(f"# {bit_size} bits")
    for pos in range(positions):
        print(f"{pos}, {n}")
        n = n << bit_size
```

## Table format
Each table has a "position" column and a "decimal value" column. The "position" refers to which `n` bits you're setting to 1. For a single bit the position is which individual bit is 1. For 8 bits the position is which 8 bits you're setting to 1. The decimal value is the decimal value when the bits at the given position are set to 1. For example, 8 bits in position 1 (the second byte) corresponds to the binary number `0b000....01111111100000000` and the decimal value 65280.

To get the mask for an odd number of bits you can just add the decimal values in the table since the positions don't overlap for a given number of bits.

## 1 bit
|Position|Decimal Value       |
|--------|--------------------|
|0       | 1                  |
|1       | 2                  |
|2       | 4                  |
|3       | 8                  |
|4       | 16                 |
|5       | 32                 |
|6       | 64                 |
|7       | 128                |
|8       | 256                |
|9       | 512                |
|10      | 1024               |
|11      | 2048               |
|12      | 4096               |
|13      | 8192               |
|14      | 16384              |
|15      | 32768              |
|16      | 65536              |
|17      | 131072             |
|18      | 262144             |
|19      | 524288             |
|20      | 1048576            |
|21      | 2097152            |
|22      | 4194304            |
|23      | 8388608            |
|24      | 16777216           |
|25      | 33554432           |
|26      | 67108864           |
|27      | 134217728          |
|28      | 268435456          |
|29      | 536870912          |
|30      | 1073741824         |
|31      | 2147483648         |
|32      | 4294967296         |
|33      | 8589934592         |
|34      | 17179869184        |
|35      | 34359738368        |
|36      | 68719476736        |
|37      | 137438953472       |
|38      | 274877906944       |
|39      | 549755813888       |
|40      | 1099511627776      |
|41      | 2199023255552      |
|42      | 4398046511104      |
|43      | 8796093022208      |
|44      | 17592186044416     |
|45      | 35184372088832     |
|46      | 70368744177664     |
|47      | 140737488355328    |
|48      | 281474976710656    |
|49      | 562949953421312    |
|50      | 1125899906842624   |
|51      | 2251799813685248   |
|52      | 4503599627370496   |
|53      | 9007199254740992   |
|54      | 18014398509481984  |
|55      | 36028797018963968  |
|56      | 72057594037927936  |
|57      | 144115188075855872 |
|58      | 288230376151711744 |
|59      | 576460752303423488 |
|60      | 1152921504606846976|
|61      | 2305843009213693952|
|62      | 4611686018427387904|
|63      | 9223372036854775808|

## 8 Bits
|Position|Decimal Value       |
|--------|--------------------|
|0       | 255                |
|1       | 65280              |
|2       | 16711680           |
|3       | 4278190080         |
|4       | 1095216660480      |
|5       | 280375465082880    |
|6       | 71776119061217280  |
|7       | 18374686479671623680|

## 16 bits
|Position|Decimal Value       |
|--------|--------------------|
|0       | 65535              |
|1       | 4294901760         |
|2       | 281470681743360    |
|3       | 18446462598732840960|

## 32 bits
|Position|Decimal Value       |
|--------|--------------------|
|0       | 4294967295         |
|1       | 18446744069414584320|
