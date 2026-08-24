"""ABK / Eliaa Pro payload codec.

Recovered in Phase 1 from libnative-lib.so (DecInterceptor.getKeyValue()):
a repeating-key XOR over the bytes of the payload.

Key : "r+3e>@y](7wEEM[" -> 72 2b 33 65 3e 40 79 5d 28 37 77 45 45 4d 5b  (15 bytes)

The original client XORs char-by-char over a Java String, then FormBody
UTF-8 encodes it. For the pure-ASCII payloads this app sends (numeric
credentials + ASCII field names) and for PHP's json_encode responses (which
escape all non-ASCII to \\uXXXX, i.e. ASCII), byte-wise XOR is identical to
the recovered char-wise XOR. We therefore operate at the byte level, which
matches a byte-wise PHP server implementation exactly.

This module reuses NOTHING from libnative-lib.so; the key is the recovered
constant only.
"""

KEY = b"r+3e>@y](7wEEM["


def xor_bytes(data: bytes) -> bytes:
    klen = len(KEY)
    return bytes(b ^ KEY[i % klen] for i, b in enumerate(data))


def encode_payload(text: str) -> bytes:
    """Plaintext JSON string -> obfuscated bytes for the `json` form field."""
    return xor_bytes(text.encode("utf-8"))


def decode_body(raw: bytes) -> str:
    """Obfuscated response bytes -> plaintext string (caller should .strip())."""
    return xor_bytes(raw).decode("utf-8", errors="replace")
