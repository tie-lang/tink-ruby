# test_tink.rb —— unit tests for tink.rb. Run: ruby test_tink.rb
require_relative 'tink'

failures = 0

def check(cond, name)
  if cond
    puts "[PASS] #{name}"
  else
    $failures += 1
    puts "[FAIL] #{name}"
  end
end

$failures = 0

# crc32 check vector
check(Tink.crc32('123456789'.b) == 0xCBF43926, 'crc32 vector')

# frame roundtrip
p = "\x01\x02\x03".b
frame = Tink.frame_encode(p)
check(frame.bytesize == p.bytesize + 8, 'frame length')
got = Tink.frame_next(frame, 0)
check(!got.nil?, 'frame present')
if got
  payload, nxt = got
  check(nxt == frame.bytesize, 'frame next == length')
  check(payload == p, 'frame payload roundtrip')
end

# empty frame roundtrip
fe = Tink.frame_encode(''.b)
ge = Tink.frame_next(fe, 0)
check(!ge.nil? && ge[1] == fe.bytesize && ge[0].empty?, 'empty frame roundtrip')

# CRC tamper rejected
ft = Tink.frame_encode(p)
ft.setbyte(4, ft.getbyte(4) + 1) # tamper payload[0]
check(Tink.frame_next(ft, 0).nil?, 'crc tamper rejected')

# frame_skip matches length
fs = Tink.frame_encode(p)
check(Tink.frame_skip(fs, 0) == fs.bytesize, 'frame_skip matches length')

# out of bounds
check(Tink.frame_next(frame, frame.bytesize).nil?, 'frame_next out of bounds')
check(Tink.frame_skip(frame, frame.bytesize).nil?, 'frame_skip out of bounds')
check(Tink.frame_next(''.b, 0).nil?, 'frame_next empty input')

if $failures.positive?
  puts "#{$failures} checks FAILED"
  exit 1
end
puts 'all tests passed'