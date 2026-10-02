class InfinityFreeChallenge {
  InfinityFreeChallenge._();

  static String? solveCookie(String html) {
    final match = RegExp(
      r'var a=toNumbers\("([0-9a-fA-F]+)"\),b=toNumbers\("([0-9a-fA-F]+)"\),c=toNumbers\("([0-9a-fA-F]+)"\)',
    ).firstMatch(html);

    if (match == null) {
      return null;
    }

    final key = _toNumbers(match.group(1)!);
    final iv = _toNumbers(match.group(2)!);
    final cipher = _toNumbers(match.group(3)!);
    final decrypted = _SlowAes.decryptCbc(cipher, key, iv);
    return _toHex(decrypted);
  }

  static bool isChallenge(String body) {
    return body.contains('/aes.js') &&
        body.contains('slowAES.decrypt') &&
        body.contains('document.cookie="__test="');
  }

  static List<int> _toNumbers(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  static String _toHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

class _SlowAes {
  static const _sbox = [
    99,
    124,
    119,
    123,
    242,
    107,
    111,
    197,
    48,
    1,
    103,
    43,
    254,
    215,
    171,
    118,
    202,
    130,
    201,
    125,
    250,
    89,
    71,
    240,
    173,
    212,
    162,
    175,
    156,
    164,
    114,
    192,
    183,
    253,
    147,
    38,
    54,
    63,
    247,
    204,
    52,
    165,
    229,
    241,
    113,
    216,
    49,
    21,
    4,
    199,
    35,
    195,
    24,
    150,
    5,
    154,
    7,
    18,
    128,
    226,
    235,
    39,
    178,
    117,
    9,
    131,
    44,
    26,
    27,
    110,
    90,
    160,
    82,
    59,
    214,
    179,
    41,
    227,
    47,
    132,
    83,
    209,
    0,
    237,
    32,
    252,
    177,
    91,
    106,
    203,
    190,
    57,
    74,
    76,
    88,
    207,
    208,
    239,
    170,
    251,
    67,
    77,
    51,
    133,
    69,
    249,
    2,
    127,
    80,
    60,
    159,
    168,
    81,
    163,
    64,
    143,
    146,
    157,
    56,
    245,
    188,
    182,
    218,
    33,
    16,
    255,
    243,
    210,
    205,
    12,
    19,
    236,
    95,
    151,
    68,
    23,
    196,
    167,
    126,
    61,
    100,
    93,
    25,
    115,
    96,
    129,
    79,
    220,
    34,
    42,
    144,
    136,
    70,
    238,
    184,
    20,
    222,
    94,
    11,
    219,
    224,
    50,
    58,
    10,
    73,
    6,
    36,
    92,
    194,
    211,
    172,
    98,
    145,
    149,
    228,
    121,
    231,
    200,
    55,
    109,
    141,
    213,
    78,
    169,
    108,
    86,
    244,
    234,
    101,
    122,
    174,
    8,
    186,
    120,
    37,
    46,
    28,
    166,
    180,
    198,
    232,
    221,
    116,
    31,
    75,
    189,
    139,
    138,
    112,
    62,
    181,
    102,
    72,
    3,
    246,
    14,
    97,
    53,
    87,
    185,
    134,
    193,
    29,
    158,
    225,
    248,
    152,
    17,
    105,
    217,
    142,
    148,
    155,
    30,
    135,
    233,
    206,
    85,
    40,
    223,
    140,
    161,
    137,
    13,
    191,
    230,
    66,
    104,
    65,
    153,
    45,
    15,
    176,
    84,
    187,
    22,
  ];

  static const _rsbox = [
    82,
    9,
    106,
    213,
    48,
    54,
    165,
    56,
    191,
    64,
    163,
    158,
    129,
    243,
    215,
    251,
    124,
    227,
    57,
    130,
    155,
    47,
    255,
    135,
    52,
    142,
    67,
    68,
    196,
    222,
    233,
    203,
    84,
    123,
    148,
    50,
    166,
    194,
    35,
    61,
    238,
    76,
    149,
    11,
    66,
    250,
    195,
    78,
    8,
    46,
    161,
    102,
    40,
    217,
    36,
    178,
    118,
    91,
    162,
    73,
    109,
    139,
    209,
    37,
    114,
    248,
    246,
    100,
    134,
    104,
    152,
    22,
    212,
    164,
    92,
    204,
    93,
    101,
    182,
    146,
    108,
    112,
    72,
    80,
    253,
    237,
    185,
    218,
    94,
    21,
    70,
    87,
    167,
    141,
    157,
    132,
    144,
    216,
    171,
    0,
    140,
    188,
    211,
    10,
    247,
    228,
    88,
    5,
    184,
    179,
    69,
    6,
    208,
    44,
    30,
    143,
    202,
    63,
    15,
    2,
    193,
    175,
    189,
    3,
    1,
    19,
    138,
    107,
    58,
    145,
    17,
    65,
    79,
    103,
    220,
    234,
    151,
    242,
    207,
    206,
    240,
    180,
    230,
    115,
    150,
    172,
    116,
    34,
    231,
    173,
    53,
    133,
    226,
    249,
    55,
    232,
    28,
    117,
    223,
    110,
    71,
    241,
    26,
    113,
    29,
    41,
    197,
    137,
    111,
    183,
    98,
    14,
    170,
    24,
    190,
    27,
    252,
    86,
    62,
    75,
    198,
    210,
    121,
    32,
    154,
    219,
    192,
    254,
    120,
    205,
    90,
    244,
    31,
    221,
    168,
    51,
    136,
    7,
    199,
    49,
    177,
    18,
    16,
    89,
    39,
    128,
    236,
    95,
    96,
    81,
    127,
    169,
    25,
    181,
    74,
    13,
    45,
    229,
    122,
    159,
    147,
    201,
    156,
    239,
    160,
    224,
    59,
    77,
    174,
    42,
    245,
    176,
    200,
    235,
    187,
    60,
    131,
    83,
    153,
    97,
    23,
    43,
    4,
    126,
    186,
    119,
    214,
    38,
    225,
    105,
    20,
    99,
    85,
    33,
    12,
    125,
  ];

  static const _rcon = [
    141,
    1,
    2,
    4,
    8,
    16,
    32,
    64,
    128,
    27,
    54,
    108,
    216,
    171,
    77,
    154,
    47,
    94,
    188,
    99,
    198,
    151,
    53,
    106,
    212,
    179,
    125,
    250,
    239,
    197,
    145,
    57,
  ];

  static List<int> decryptCbc(List<int> input, List<int> key, List<int> iv) {
    final output = <int>[];
    var previous = List<int>.from(iv);
    final expandedKey = _expandKey(key);

    for (var offset = 0; offset < input.length; offset += 16) {
      final block = input.sublist(offset, offset + 16);
      final decrypted = _decryptBlock(block, expandedKey);
      for (var i = 0; i < 16; i++) {
        output.add(decrypted[i] ^ previous[i]);
      }
      previous = block;
    }

    _unpad(output);
    return output;
  }

  static List<int> _decryptBlock(List<int> input, List<int> expandedKey) {
    final state = List<int>.filled(16, 0);
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 4; column++) {
        state[row + 4 * column] = input[4 * row + column];
      }
    }

    var current = _addRoundKey(state, _roundKey(expandedKey, 160));
    for (var round = 9; round > 0; round--) {
      current = _invShiftRows(current);
      current = _subBytes(current, inverse: true);
      current = _addRoundKey(current, _roundKey(expandedKey, 16 * round));
      current = _invMixColumns(current);
    }
    current = _invShiftRows(current);
    current = _subBytes(current, inverse: true);
    current = _addRoundKey(current, _roundKey(expandedKey, 0));

    final output = List<int>.filled(16, 0);
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 4; column++) {
        output[4 * row + column] = current[row + 4 * column];
      }
    }
    return output;
  }

  static List<int> _expandKey(List<int> key) {
    const size = 16;
    const expandedSize = 176;
    final expanded = List<int>.filled(expandedSize, 0);
    for (var i = 0; i < size; i++) {
      expanded[i] = key[i];
    }

    var bytesGenerated = size;
    var rconIteration = 1;
    final temp = List<int>.filled(4, 0);

    while (bytesGenerated < expandedSize) {
      for (var i = 0; i < 4; i++) {
        temp[i] = expanded[bytesGenerated - 4 + i];
      }

      if (bytesGenerated % size == 0) {
        final first = temp[0];
        temp[0] = temp[1];
        temp[1] = temp[2];
        temp[2] = temp[3];
        temp[3] = first;
        for (var i = 0; i < 4; i++) {
          temp[i] = _sbox[temp[i]];
        }
        temp[0] ^= _rcon[rconIteration++];
      }

      for (var i = 0; i < 4; i++) {
        expanded[bytesGenerated] = expanded[bytesGenerated - size] ^ temp[i];
        bytesGenerated++;
      }
    }

    return expanded;
  }

  static List<int> _roundKey(List<int> expandedKey, int offset) {
    final key = List<int>.filled(16, 0);
    for (var column = 0; column < 4; column++) {
      for (var row = 0; row < 4; row++) {
        key[4 * row + column] = expandedKey[offset + 4 * column + row];
      }
    }
    return key;
  }

  static List<int> _addRoundKey(List<int> state, List<int> key) {
    return List<int>.generate(16, (index) => state[index] ^ key[index]);
  }

  static List<int> _subBytes(List<int> state, {required bool inverse}) {
    final box = inverse ? _rsbox : _sbox;
    return List<int>.generate(16, (index) => box[state[index]]);
  }

  static List<int> _invShiftRows(List<int> state) {
    final output = List<int>.from(state);
    for (var row = 0; row < 4; row++) {
      final offset = 4 * row;
      for (var shift = 0; shift < row; shift++) {
        final last = output[offset + 3];
        output[offset + 3] = output[offset + 2];
        output[offset + 2] = output[offset + 1];
        output[offset + 1] = output[offset];
        output[offset] = last;
      }
    }
    return output;
  }

  static List<int> _invMixColumns(List<int> state) {
    final output = List<int>.from(state);
    for (var column = 0; column < 4; column++) {
      final a0 = state[column];
      final a1 = state[4 + column];
      final a2 = state[8 + column];
      final a3 = state[12 + column];
      output[column] = _mul(a0, 14) ^ _mul(a3, 9) ^ _mul(a2, 13) ^ _mul(a1, 11);
      output[4 + column] =
          _mul(a1, 14) ^ _mul(a0, 9) ^ _mul(a3, 13) ^ _mul(a2, 11);
      output[8 + column] =
          _mul(a2, 14) ^ _mul(a1, 9) ^ _mul(a0, 13) ^ _mul(a3, 11);
      output[12 + column] =
          _mul(a3, 14) ^ _mul(a2, 9) ^ _mul(a1, 13) ^ _mul(a0, 11);
    }
    return output;
  }

  static int _mul(int value, int factor) {
    var result = 0;
    var a = value;
    var b = factor;

    for (var i = 0; i < 8; i++) {
      if ((b & 1) == 1) {
        result ^= a;
      }
      final highBit = a & 0x80;
      a = (a << 1) & 0xff;
      if (highBit == 0x80) {
        a ^= 0x1b;
      }
      b >>= 1;
    }

    return result;
  }

  static void _unpad(List<int> bytes) {
    if (bytes.length <= 16) {
      return;
    }

    final pad = bytes.last;
    if (pad < 1 || pad > 16 || pad > bytes.length) {
      return;
    }

    for (var i = bytes.length - pad; i < bytes.length; i++) {
      if (bytes[i] != pad) {
        return;
      }
    }
    bytes.removeRange(bytes.length - pad, bytes.length);
  }
}
