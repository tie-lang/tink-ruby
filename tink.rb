# frozen_string_literal: true

# tink.rb —— tink data-flow node frame protocol (universal, language-agnostic).
#
# Frame = [len u32 BE][payload][crc u32 BE]; crc = CRC32-IEEE (0xEDB88320).
# Mirrors std/tink.tie (tie standard library) and the other-language tink
# libraries; pure functions over String (binary, byte vector), IO (stdin/stdout)
# left to the caller. Ruby, no dependencies.
#
#   frame = Tink.frame_encode("hi".b)
#   payload, next_pos = Tink.frame_next(frame, 0)

module Tink
  # CRC32-IEEE over a binary string (bit-loop, no table; matches Zlib.crc32).
  # Check vector: Tink.crc32("123456789") == 0xCBF43926.
  def self.crc32(data)
    crc = 0xFFFFFFFF
    data.each_byte do |b|
      crc ^= b
      8.times do
        crc = (crc & 1).zero? ? crc >> 1 : (crc >> 1) ^ 0xEDB88320
      end
    end
    (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF
  end

  # Encode a payload into a full frame: [len u32 BE][payload][crc u32 BE].
  # Returns a binary String of payload.bytesize + 8 bytes.
  def self.frame_encode(payload)
    n = payload.bytesize
    out = +"".b
    out << [(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF].pack('C4')
    out << payload
    c = crc32(payload)
    out << [(c >> 24) & 0xFF, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF].pack('C4')
    out
  end

  # Parse one frame at pos (verifies CRC). Returns [payload, next_pos] (0-based
  # byte offsets) or nil on out-of-bounds / CRC mismatch. Payload is a copy.
  def self.frame_next(bytes, pos)
    return nil if pos.negative? || bytes.bytesize < pos + 8

    n = be32(bytes, pos)
    end_pos = pos + 8 + n
    return nil if bytes.bytesize < end_pos

    payload = bytes.byteslice(pos + 4, n)
    want = be32(bytes, end_pos - 4)
    return nil unless crc32(payload) == want

    [payload, end_pos]
  end

  # Skip one frame at pos without copying or verifying (zero-copy).
  # Returns next_pos, or nil on out-of-bounds.
  def self.frame_skip(bytes, pos)
    return nil if pos.negative? || bytes.bytesize < pos + 8

    n = be32(bytes, pos)
    end_pos = pos + 8 + n
    return nil if bytes.bytesize < end_pos

    end_pos
  end

  # Read a big-endian u32 at byte offset off.
  def self.be32(b, off)
    ((b.getbyte(off) << 24) | (b.getbyte(off + 1) << 16) |
      (b.getbyte(off + 2) << 8) | b.getbyte(off + 3)) & 0xFFFFFFFF
  end
  private_class_method :be32
end