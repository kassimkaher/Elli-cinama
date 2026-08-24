"""Codec verification gate. Must pass before any network request.

Run: python3 test_codec.py   (exit 0 = PASS, exit 1 = FAIL)
"""
import sys

from abk_codec import KEY, xor_bytes, encode_payload, decode_body

failures = []


def check(name, cond):
    print(f"  [{'PASS' if cond else 'FAIL'}] {name}")
    if not cond:
        failures.append(name)


print("ABK codec verification gate")
print(f"  key length = {len(KEY)} (expected 15)")
check("key is the recovered 15-byte constant",
      KEY == b"r+3e>@y](7wEEM[" and len(KEY) == 15)

# 1. empty string
check("empty string round-trips",
      decode_body(encode_payload("")) == "")
check("empty string encodes to empty",
      encode_payload("") == b"")

# 2. ASCII payload
ascii_in = "abcdefghijklmnopqrstuvwxyz0123456789"
check("ASCII payload round-trips",
      decode_body(encode_payload(ascii_in)) == ascii_in)

# 3. JSON payload (representative login envelope shape, no real creds)
json_in = ('{"code":"00000000","user":"USER","pass":"PASS",'
           '"mac":"02:00:00:00:00:00","sn":"02:00:00:00:00:00",'
           '"model":"generic","group":0,"mode":"login"}')
check("JSON payload round-trips",
      decode_body(encode_payload(json_in)) == json_in)

# 4. key wraparound: input longer than the 15-byte key must cycle the key
long_in = "A" * 47  # 47 = 3*15 + 2, forces wraparound past the key boundary
enc = encode_payload(long_in)
# byte i of ciphertext must equal ('A' XOR KEY[i % 15])
expected = bytes(ord("A") ^ KEY[i % len(KEY)] for i in range(47))
check("key wraparound matches manual computation", enc == expected)
check("key wraparound round-trips", decode_body(enc) == long_in)

# 5. XOR is symmetric (encode == decode transform on bytes)
sample = b"the quick brown fox 0123456789 {}[]"
check("xor_bytes is an involution (symmetric)",
      xor_bytes(xor_bytes(sample)) == sample)

# 6. ciphertext of ASCII input stays in single-byte range (why it travels
#    as a percent-encoded form field, per Phase 1)
check("ASCII input -> all cipher bytes < 0x80",
      all(b < 0x80 for b in encode_payload(json_in)))

print()
if failures:
    print(f"CODEC GATE: FAIL ({len(failures)} failing) -> {failures}")
    sys.exit(1)
print("CODEC GATE: PASS")
sys.exit(0)
