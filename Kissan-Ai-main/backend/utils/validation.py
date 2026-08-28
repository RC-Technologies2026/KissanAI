"""Shared file validation helpers used by image upload and detection endpoints."""

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}

IMAGE_MAGIC_BYTES = {
    b"\xff\xd8\xff": "jpeg",
    b"\x89PNG": "png",
    b"GIF87a": "gif",
    b"GIF89a": "gif",
    b"RIFF": "webp",
    b"BM": "bmp",
}


def check_magic_bytes(header: bytes) -> bool:
    """Check if file header matches a known image format signature."""
    for magic in IMAGE_MAGIC_BYTES:
        if header.startswith(magic):
            return True
    return False


def validate_extension(filename: str) -> bool:
    """Check if the file extension is in the allowed image list."""
    filename = filename.lower()
    ext = "." + filename.rsplit(".", 1)[-1] if "." in filename else ""
    return ext in ALLOWED_EXTENSIONS
