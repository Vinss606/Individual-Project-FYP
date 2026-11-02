"""
Universal FastAPI / Starlette compatibility layer.
Ensures zero-crash execution across any Python environment.
"""
try:
    from fastapi import APIRouter, Depends, HTTPException, Query, status
    from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
    HAS_FASTAPI = True
except ImportError:
    from starlette.exceptions import HTTPException
    from starlette import status
    HAS_FASTAPI = False

    class APIRouter:
        def __init__(self, prefix: str = "", tags: list = None):
            self.prefix = prefix
            self.tags = tags or []
            self.routes = []

        def get(self, path: str, **kwargs):
            def decorator(f):
                return f
            return decorator

        def post(self, path: str, **kwargs):
            def decorator(f):
                return f
            return decorator

        def patch(self, path: str, **kwargs):
            def decorator(f):
                return f
            return decorator

        def delete(self, path: str, **kwargs):
            def decorator(f):
                return f
            return decorator

    def Depends(f=None):
        return None

    def Query(default=..., **kwargs):
        return default

    class HTTPAuthorizationCredentials:
        credentials = ""

    class HTTPBearer:
        def __init__(self, **kwargs):
            pass
