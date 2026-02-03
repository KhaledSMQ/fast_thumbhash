import 'dart:typed_data';

import 'models.dart';

/// Ultra-fast PNG encoder optimized for ThumbHash images.
///
/// Features:
/// - Pre-allocated buffer (no dynamic growth)
/// - 256-entry CRC table (1 lookup per byte)
/// - Batched Adler-32 calculation (modulo every NMAX bytes, not every byte)
/// - Zero intermediate allocations
///
/// This encoder produces valid PNG files but does not compress the data
/// (uses uncompressed DEFLATE blocks) for maximum speed.

/// Maximum bytes to process before Adler-32 modulo to prevent overflow.
/// With NMAX=5552: a1 max = 1 + 255*5552 = 1,415,761 (fits in 32 bits)
/// a2 max ≈ 3.9 billion (fits in 32-bit unsigned)
const _adlerNmax = 5552;

/// Pre-computed CRC-32 table for fast checksum calculation (256 entries).
/// Standard PNG/zlib polynomial 0xEDB88320 with bit-reversal.
/// 1 table lookup per byte instead of 2 with the 4-bit table.
const _crc32Table = <int>[
  0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA,
  0x076DC419, 0x706AF48F, 0xE963A535, 0x9E6495A3,
  0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988,
  0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91,
  0x1DB71064, 0x6AB020F2, 0xF3B97148, 0x84BE41DE,
  0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
  0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC,
  0x14015C4F, 0x63066CD9, 0xFA0F3D63, 0x8D080DF5,
  0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172,
  0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B,
  0x35B5A8FA, 0x42B2986C, 0xDBBBC9D6, 0xACBCF940,
  0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
  0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116,
  0x21B4F4B5, 0x56B3C423, 0xCFBA9599, 0xB8BDA50F,
  0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924,
  0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D,
  0x76DC4190, 0x01DB7106, 0x98D220BC, 0xEFD5102A,
  0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
  0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818,
  0x7F6A0DBB, 0x086D3D2D, 0x91646C97, 0xE6635C01,
  0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E,
  0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457,
  0x65B0D9C6, 0x12B7E950, 0x8BBEB8EA, 0xFCB9887C,
  0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
  0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2,
  0x4ADFA541, 0x3DD895D7, 0xA4D1C46D, 0xD3D6F4FB,
  0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0,
  0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9,
  0x5005713C, 0x270241AA, 0xBE0B1010, 0xC90C2086,
  0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
  0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4,
  0x59B33D17, 0x2EB40D81, 0xB7BD5C3B, 0xC0BA6CAD,
  0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A,
  0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683,
  0xE3630B12, 0x94643B84, 0x0D6D6A3E, 0x7A6A5AA8,
  0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
  0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE,
  0xF762575D, 0x806567CB, 0x196C3671, 0x6E6B06E7,
  0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC,
  0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5,
  0xD6D6A3E8, 0xA1D1937E, 0x38D8C2C4, 0x4FDFF252,
  0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
  0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60,
  0xDF60EFC3, 0xA867DF55, 0x316E8EEF, 0x4669BE79,
  0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236,
  0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F,
  0xC5BA3BBE, 0xB2BD0B28, 0x2BB45A92, 0x5CB36A04,
  0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
  0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A,
  0x9C0906A9, 0xEB0E363F, 0x72076785, 0x05005713,
  0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38,
  0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21,
  0x86D3D2D4, 0xF1D4E242, 0x68DDB3F8, 0x1FDA836E,
  0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
  0x88085AE6, 0xFF0F6A70, 0x660E39CA, 0x110F095C,
  0x8F659EFF, 0xF862AE69, 0x616BFFD3, 0x166CCF45,
  0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2,
  0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB,
  0xAED16A4A, 0xD9D65ADC, 0x40DF0B66, 0x37D83BF0,
  0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
  0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6,
  0xBAD03605, 0xCDD70693, 0x54DE5729, 0x23D967BF,
  0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94,
  0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D,
];

/// Encodes a ThumbHash image to PNG format.
///
/// This is a fast, uncompressed PNG encoder optimized for small images.
/// The output is a valid PNG file with proper alpha channel support.
///
/// [image] is a [ThumbHashImage] with RGBA pixel data.
///
/// Returns a [Uint8List] containing the PNG file data.
///
/// Example:
/// ```dart
/// final image = thumbHashToRGBA(hash);
/// final pngBytes = thumbHashImageToPng(image);
/// // Use pngBytes with Image.memory() or save to file
/// ```
Uint8List thumbHashImageToPng(ThumbHashImage image) {
  final w = image.width;
  final h = image.height;
  final rgba = image.rgba;

  // Calculate exact buffer size upfront for pre-allocation
  // PNG structure:
  // - Signature: 8 bytes
  // - IHDR chunk: 4 (len) + 4 (type) + 13 (data) + 4 (crc) = 25 bytes
  // - IDAT chunk: 4 (len) + 4 (type) + data + 4 (crc)
  //   - data: 2 (zlib header) + h * (5 (block) + 1 (filter) + w*4 (pixels)) + 4 (adler)
  // - IEND chunk: 4 + 4 + 0 + 4 = 12 bytes
  final row = w * 4 + 1; // pixels + filter byte
  final idatData = 2 + h * (5 + row) + 4; // zlib header + blocks + adler
  final totalSize = 8 + 25 + 8 + idatData + 4 + 12;

  final out = Uint8List(totalSize);
  var pos = 0;

  // PNG signature (8 bytes)
  out[pos++] = 0x89;
  out[pos++] = 0x50; // P
  out[pos++] = 0x4E; // N
  out[pos++] = 0x47; // G
  out[pos++] = 0x0D; // CR
  out[pos++] = 0x0A; // LF
  out[pos++] = 0x1A; // SUB
  out[pos++] = 0x0A; // LF

  // IHDR chunk
  final ihdrStart = pos;
  // Length (13 bytes)
  out[pos++] = 0;
  out[pos++] = 0;
  out[pos++] = 0;
  out[pos++] = 13;
  // Type "IHDR"
  out[pos++] = 0x49;
  out[pos++] = 0x48;
  out[pos++] = 0x44;
  out[pos++] = 0x52;
  // Width (4 bytes big-endian)
  out[pos++] = 0;
  out[pos++] = 0;
  out[pos++] = w >> 8;
  out[pos++] = w & 0xFF;
  // Height (4 bytes big-endian)
  out[pos++] = 0;
  out[pos++] = 0;
  out[pos++] = h >> 8;
  out[pos++] = h & 0xFF;
  // Bit depth (8), Color type (6 = RGBA)
  out[pos++] = 8;
  out[pos++] = 6;
  // Compression, Filter, Interlace (all 0)
  out[pos++] = 0;
  out[pos++] = 0;
  out[pos++] = 0;

  // IHDR CRC (covers type + data, 17 bytes starting at ihdrStart + 4)
  final ihdrCrc = _crc32(out, ihdrStart + 4, 17);
  out[pos++] = (ihdrCrc >> 24) & 0xFF;
  out[pos++] = (ihdrCrc >> 16) & 0xFF;
  out[pos++] = (ihdrCrc >> 8) & 0xFF;
  out[pos++] = ihdrCrc & 0xFF;

  // IDAT chunk
  final idatStart = pos;
  // Length
  out[pos++] = (idatData >> 24) & 0xFF;
  out[pos++] = (idatData >> 16) & 0xFF;
  out[pos++] = (idatData >> 8) & 0xFF;
  out[pos++] = idatData & 0xFF;
  // Type "IDAT"
  out[pos++] = 0x49;
  out[pos++] = 0x44;
  out[pos++] = 0x41;
  out[pos++] = 0x54;

  // zlib header (no compression)
  out[pos++] = 0x78;
  out[pos++] = 0x01;

  // Adler-32 accumulators - using batched modulo for speed
  var a1 = 1;
  var a2 = 0;
  var adlerCount = 0; // Bytes since last modulo

  // Write image data as uncompressed DEFLATE blocks
  var rgbaIdx = 0;
  for (var y = 0; y < h; y++) {
    final isLast = y == h - 1;

    // DEFLATE block header (5 bytes)
    out[pos++] = isLast ? 1 : 0; // BFINAL flag
    out[pos++] = row & 0xFF; // LEN low byte
    out[pos++] = row >> 8; // LEN high byte
    out[pos++] = ~row & 0xFF; // NLEN low byte
    out[pos++] = (row >> 8) ^ 0xFF; // NLEN high byte

    // Filter byte (0 = None)
    out[pos++] = 0;
    a1 += 0; // Filter byte is 0, no change to a1
    a2 += a1;
    adlerCount++;

    // Pixel data for this row - batched Adler-32 (modulo only when needed)
    final rowEnd = rgbaIdx + w * 4;
    while (rgbaIdx < rowEnd) {
      final b = rgba[rgbaIdx++];
      out[pos++] = b;
      a1 += b;
      a2 += a1;
      adlerCount++;

      // Apply modulo when approaching overflow limit
      if (adlerCount >= _adlerNmax) {
        a1 %= 65521;
        a2 %= 65521;
        adlerCount = 0;
      }
    }
  }

  // Final modulo to get correct checksum
  a1 %= 65521;
  a2 %= 65521;

  // Adler-32 checksum (big-endian)
  out[pos++] = (a2 >> 8) & 0xFF;
  out[pos++] = a2 & 0xFF;
  out[pos++] = (a1 >> 8) & 0xFF;
  out[pos++] = a1 & 0xFF;

  // IDAT CRC
  final idatCrc = _crc32(out, idatStart + 4, idatData + 4);
  out[pos++] = (idatCrc >> 24) & 0xFF;
  out[pos++] = (idatCrc >> 16) & 0xFF;
  out[pos++] = (idatCrc >> 8) & 0xFF;
  out[pos++] = idatCrc & 0xFF;

  // IEND chunk (empty)
  // Length = 0
  out[pos++] = 0;
  out[pos++] = 0;
  out[pos++] = 0;
  out[pos++] = 0;
  // Type "IEND"
  out[pos++] = 0x49;
  out[pos++] = 0x45;
  out[pos++] = 0x4E;
  out[pos++] = 0x44;
  // IEND CRC (pre-computed for "IEND" with empty data)
  out[pos++] = 0xAE;
  out[pos++] = 0x42;
  out[pos++] = 0x60;
  out[pos++] = 0x82;

  return out;
}

/// Computes CRC-32 using a 256-entry table for speed.
///
/// Uses the PNG/zlib polynomial with bit-reversal.
/// 1 table lookup per byte (vs 2 with 4-bit table).
@pragma('vm:prefer-inline')
int _crc32(Uint8List data, int start, int length) {
  var crc = 0xFFFFFFFF;
  final end = start + length;
  for (var i = start; i < end; i++) {
    crc = (crc >>> 8) ^ _crc32Table[(crc ^ data[i]) & 0xFF];
  }
  return crc ^ 0xFFFFFFFF;
}
