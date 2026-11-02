from datetime import date, datetime
import uuid
from typing import List, Optional
from ..compat import APIRouter, Depends, HTTPException, status

from ..firebase import get_db
from ..schemas import (
    CreateEventRequest,
    CreateMerchantRequest,
    PriceItemOut,
    UpdateStatusRequest,
    VerificationReportOut,
)
from ..security import get_current_user_id
from ..verification import VerificationEngine

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/verify/event", response_model=VerificationReportOut)
def verify_event_data(payload: dict, user_id: str = Depends(get_current_user_id)):
    """Runs the 3-level verification algorithm against the official KPDN PJRM registry."""
    report = VerificationEngine.verify_jualan_rahmah(payload)
    return VerificationReportOut(**report)


@router.post("/verify/merchant", response_model=VerificationReportOut)
def verify_merchant_data(payload: dict, user_id: str = Depends(get_current_user_id)):
    """Runs verification against official MyKasih / SARA merchant database."""
    report = VerificationEngine.verify_mykasih_merchant(payload)
    return VerificationReportOut(**report)


@router.post("/events")
def create_event(payload: CreateEventRequest, user_id: str = Depends(get_current_user_id)):
    db = get_db()
    data = payload.model_dump() if hasattr(payload, "model_dump") else payload.dict()
    # Stringify date
    data["date"] = str(data["date"])
    
    # Run verification if requested
    if payload.run_verification:
        ver_result = VerificationEngine.verify_jualan_rahmah(data)
        data["verification_status"] = ver_result["status"]
        data["match_score"] = ver_result["score"]
        data["source_name"] = ver_result["source"]
        data["source_url"] = ver_result["source_url"]
        data["last_verified"] = ver_result["last_verified"]
        data["rescheduled"] = ver_result.get("rescheduled", False)
        data["official_date"] = ver_result.get("official_date")
    else:
        data["verification_status"] = "PENDING_REVIEW"
        data["match_score"] = 50.0
        data["source_name"] = "Entri Manual Pentadbir"
        data["source_url"] = "https://pjrm.kpdn.gov.my/"
        data["last_verified"] = date.today().strftime("%Y-%m-%d")

    # Add to Firestore
    doc_ref = db.collection("jualan_rahmah_listings").document()
    doc_ref.set(data)
    return {"id": doc_ref.id, "message": "Acara berjaya ditambah.", "verification": data["verification_status"]}


@router.patch("/events/{event_id}/status")
def update_event_status(
    event_id: str, payload: UpdateStatusRequest, user_id: str = Depends(get_current_user_id)
):
    db = get_db()
    ref = db.collection("jualan_rahmah_listings").document(event_id)
    snap = ref.get()
    if not snap.exists:
        raise HTTPException(status_code=404, detail="Acara tidak dijumpai.")
    
    ref.update({
        "verification_status": payload.status,
        "last_verified": date.today().strftime("%Y-%m-%d"),
        "admin_notes": payload.notes or "Dikemaskini oleh pentadbir."
    })
    return {"message": f"Status berjaya dikemaskini kepada {payload.status}."}


@router.delete("/events/{event_id}")
def delete_event(event_id: str, user_id: str = Depends(get_current_user_id)):
    db = get_db()
    db.collection("jualan_rahmah_listings").document(event_id).delete()
    return {"message": "Acara berjaya dipadam."}


@router.post("/merchants")
def create_merchant(payload: CreateMerchantRequest, user_id: str = Depends(get_current_user_id)):
    db = get_db()
    data = payload.model_dump() if hasattr(payload, "model_dump") else payload.dict()
    data["date"] = str(data["date"])

    if payload.run_verification:
        ver_result = VerificationEngine.verify_mykasih_merchant(data)
        data["verification_status"] = ver_result["status"]
        data["source_name"] = ver_result["source"]
        data["source_url"] = ver_result["source_url"]
        data["last_verified"] = ver_result["last_verified"]
    else:
        data["verification_status"] = "PENDING_REVIEW"
        data["source_name"] = "Entri Manual Pentadbir"
        data["source_url"] = "https://www.mykasih.com.my/ms/about-us/merchant-partners/"
        data["last_verified"] = date.today().strftime("%Y-%m-%d")

    doc_ref = db.collection("mykasih_locations").document()
    doc_ref.set(data)
    return {"id": doc_ref.id, "message": "Pusat agihan / peniaga berjaya ditambah.", "verification": data["verification_status"]}


@router.patch("/merchants/{merchant_id}/status")
def update_merchant_status(
    merchant_id: str, payload: UpdateStatusRequest, user_id: str = Depends(get_current_user_id)
):
    db = get_db()
    ref = db.collection("mykasih_locations").document(merchant_id)
    snap = ref.get()
    if not snap.exists:
        raise HTTPException(status_code=404, detail="Pusat agihan tidak dijumpai.")
    
    ref.update({
        "verification_status": payload.status,
        "last_verified": date.today().strftime("%Y-%m-%d"),
        "admin_notes": payload.notes or "Dikemaskini oleh pentadbir."
    })
    return {"message": f"Status berjaya dikemaskini kepada {payload.status}."}


@router.delete("/merchants/{merchant_id}")
def delete_merchant(merchant_id: str, user_id: str = Depends(get_current_user_id)):
    db = get_db()
    db.collection("mykasih_locations").document(merchant_id).delete()
    return {"message": "Pusat agihan berjaya dipadam."}


@router.post("/simulate-reschedule/{event_id}")
def simulate_schedule_change(
    event_id: str, new_date: str, user_id: str = Depends(get_current_user_id)
):
    """
    Demonstrates Level 3 Reschedule detection:
    Updates stored date, detects change from official source, and broadcasts a notification to users.
    """
    db = get_db()
    ref = db.collection("jualan_rahmah_listings").document(event_id)
    snap = ref.get()
    if not snap.exists:
        raise HTTPException(status_code=404, detail="Acara tidak dijumpai.")
    
    old_data = snap.to_dict()
    old_date = old_data.get("date", "2026-09-15")

    # Update event with rescheduled status
    ref.update({
        "date": new_date,
        "rescheduled": True,
        "official_date": new_date,
        "last_verified": date.today().strftime("%Y-%m-%d"),
    })

    # Broadcast notification to users
    notif_ref = db.collection("notifications").document()
    notif_payload = {
        "user_id": "ALL",
        "title": "⚠️ Penjadualan Semula Acara",
        "message": f"Jualan Rahmah di {old_data.get('name', 'Dewan')} telah dijadualkan semula dari {old_date} kepada {new_date}.",
        "type": "SCHEDULE_UPDATE",
        "created_at": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "is_read": False,
        "action_route": "/jualan-rahmah",
    }
    notif_ref.set(notif_payload)

    return {
        "message": "Penjadualan semula berjaya dikemaskini dan notifikasi telah dihantar kepada pengguna.",
        "old_date": old_date,
        "new_date": new_date,
        "notification_id": notif_ref.id
    }


@router.get("/users")
def get_all_users(user_id: str = Depends(get_current_user_id)):
    db = get_db()
    users_ref = db.collection("users")
    docs = users_ref.stream()
    result = []
    for doc in docs:
        u = doc.to_dict()
        ic = u.get("ic_number", doc.id)
        b_doc = db.collection("budgets").document(ic).get()
        b_data = b_doc.to_dict() if b_doc.exists else {}
        salary = float(b_data.get("monthly_salary", u.get("monthly_salary", 2500.0)))
        commitments = float(b_data.get("total_commitments", u.get("monthly_commitments", 0.0)))
        result.append({
            "ic_number": ic,
            "name": u.get("name", "Pengguna"),
            "phone": u.get("phone", "-"),
            "role": u.get("role", "user"),
            "salary": salary,
            "commitments": commitments,
            "disposable": salary - commitments,
            "created_at": u.get("created_at", "2026-10-01")
        })
    return result


@router.delete("/users/{ic_number}")
def delete_user_account(ic_number: str, user_id: str = Depends(get_current_user_id)):
    if ic_number == "800101075555":
        raise HTTPException(status_code=400, detail="Akaun Pentadbir Utama tidak boleh dipadam.")
    db = get_db()
    db.collection("users").document(ic_number).delete()
    db.collection("budgets").document(ic_number).delete()
    return {"message": "Akaun pengguna berjaya dipadam."}

