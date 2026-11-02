from datetime import datetime
from typing import List
from ..compat import APIRouter, Depends

from ..firebase import get_db
from ..schemas import NotificationOut
from ..security import get_current_user_id

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=List[NotificationOut])
def get_user_notifications(user_id: str = Depends(get_current_user_id)):
    db = get_db()
    results = []
    
    # Fetch notifications for this user and broadcasted "ALL" notifications
    docs = db.collection("notifications").stream()
    for doc in docs:
        data = doc.to_dict()
        doc_user = data.get("user_id", "")
        if doc_user in (user_id, "ALL"):
            results.append(
                NotificationOut(
                    id=doc.id,
                    user_id=doc_user,
                    title=data.get("title", "Notifikasi"),
                    message=data.get("message", ""),
                    type=data.get("type", "INFO"),
                    created_at=data.get("created_at", datetime.now().strftime("%Y-%m-%d %H:%M")),
                    is_read=data.get("is_read", False),
                    action_route=data.get("action_route", None),
                )
            )
            
    # Sort newest first
    results.sort(key=lambda x: x.created_at, reverse=True)
    return results


@router.patch("/{notif_id}/read")
def mark_as_read(notif_id: str, user_id: str = Depends(get_current_user_id)):
    db = get_db()
    ref = db.collection("notifications").document(notif_id)
    snap = ref.get()
    if snap.exists:
        ref.update({"is_read": True})
    return {"status": "ok"}
