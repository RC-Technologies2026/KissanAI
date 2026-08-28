"""
Shared rate limiter for FastAPI using slowapi.

Import `limiter` from this module and apply @limiter.limit() decorators to routes.
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
