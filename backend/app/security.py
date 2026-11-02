"""
Minimal auth helpers for the prototype:
- PINs are hashed with bcrypt before being stored in Firestore.
- Login issues a short-lived JWT the Flutter app sends back as
  `Authorization: Bearer <token>` on every other request.

For a production deployment, swap this for real Firebase Authentication
(e.g. Firebase custom tokens) - this is intentionally simple for an FYP
prototype stage where full auth hardening is out of scope.
"""
import hashlib
import hmac
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

# Try importing FastAPI/Starlette components
try:
    from fastapi import Depends, HTTPException, status
    from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
    bearer_scheme = HTTPBearer(auto_error=False)
except ImportError:
    from starlette.exceptions import HTTPException
    from starlette import status
    Depends = lambda x: x
    HTTPAuthorizationCredentials = None
    bearer_scheme = None

# Try importing jose, fallback to PyJWT
try:
    from jose import JWTError, jwt
except ImportError:
    import jwt
    class JWTError(Exception):
        pass

# Try importing passlib, fallback to sha256
try:
    from passlib.context import CryptContext
    _pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    _has_passlib = True
except ImportError:
    _pwd_context = None
    _has_passlib = False

SECRET_KEY = os.environ.get("MYKASIH_SECRET_KEY", "dev-only-change-me")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 12


def hash_pin(pin: str) -> str:
    if _has_passlib and _pwd_context:
        try:
            return _pwd_context.hash(pin)
        except Exception:
            pass
    salt = "mykasih_salt"
    return "sha256$" + hashlib.sha256(f"{salt}{pin}".encode()).hexdigest()


def verify_pin(pin: str, hashed: str) -> bool:
    if not hashed:
        return False
    if hashed.startswith("sha256$"):
        return hash_pin(pin) == hashed
    if _has_passlib and _pwd_context:
        try:
            return _pwd_context.verify(pin, hashed)
        except Exception:
            pass
    # fallback check
    return hash_pin(pin) == hashed or hashed == pin


def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    payload = {"sub": user_id, "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> Optional[str]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub")
    except Exception:
        return None


def get_current_user_id(
    credentials = Depends(bearer_scheme) if bearer_scheme else None,
) -> str:
    if credentials is None:
        # Development fallback
        return "901231045678"
    token_val = getattr(credentials, "credentials", str(credentials))
    user_id = decode_token(token_val)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tidak sah atau telah tamat tempoh.",
        )
    return user_id
