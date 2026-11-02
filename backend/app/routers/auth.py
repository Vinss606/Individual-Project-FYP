import re
from ..compat import APIRouter, HTTPException, status

from ..firebase import get_db
from ..schemas import LoginRequest, LoginResponse, RegisterRequest, ForgotPasswordRequest, ActionMessageResponse
from ..security import verify_pin, hash_pin, create_access_token

router = APIRouter(prefix="/auth", tags=["auth"])


def is_valid_malaysian_phone(phone: str) -> bool:
    if not phone or not isinstance(phone, str):
        return False
    cleaned = re.sub(r'[\s\-\(\)\.]', '', phone.strip())
    if cleaned.startswith('+60'):
        cleaned = '0' + cleaned[3:]
    elif cleaned.startswith('60'):
        cleaned = '0' + cleaned[2:]
    if not cleaned.isdigit():
        return False
    # Mobile 010-019 (10-11 digits)
    if re.match(r'^01[0-9]{8,9}$', cleaned):
        return True
    # Landline 03-09 (9-10 digits)
    if re.match(r'^0[3-9][0-9]{7,8}$', cleaned):
        return True
    return False


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest):
    db = get_db()
    users_ref = db.collection("users")
    query = users_ref.where("ic_number", "==", payload.ic_number).limit(1).stream()
    user_doc = next(query, None)

    if user_doc is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Nombor MyKad/IC atau PIN tidak sah.",
        )

    user_data = user_doc.to_dict()
    if not verify_pin(payload.pin, user_data.get("pin_hash", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Nombor MyKad/IC atau PIN tidak sah.",
        )

    token = create_access_token(user_doc.id)
    return LoginResponse(
        user_id=user_doc.id,
        name=user_data.get("name", ""),
        ic_number=payload.ic_number,
        role=user_data.get("role", "user"),
        token=token,
    )


@router.post("/register", response_model=LoginResponse)
def register(payload: RegisterRequest):
    db = get_db()
    users_ref = db.collection("users")
    
    # Check if IC already exists
    existing = next(users_ref.where("ic_number", "==", payload.ic_number).limit(1).stream(), None)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nombor MyKad/IC ini telah berdaftar dalam sistem.",
        )

    # Validate Malaysian phone format (Requirement 4)
    if payload.phone and not is_valid_malaysian_phone(payload.phone):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nombor telefon tidak sah. Sila gunakan format nombor telefon Malaysia (Contoh: 012-3456789 atau 011-12345678).",
        )

    # Initialize budget with user-provided salary, commitments and expenses
    salary = float(payload.monthly_salary or 2500.0)
    
    init_comms = payload.commitments_list if payload.commitments_list else (
        [{"id": "com-1", "name": "Komitmen Tetap Bulanan (Sewa/Pinjaman)", "amount": float(payload.monthly_commitments or 0.0)}]
        if float(payload.monthly_commitments or 0.0) > 0 else []
    )
    commitments = sum(float(c.get("amount", 0.0)) for c in init_comms)
    
    init_exps = payload.expenses_list if payload.expenses_list else []
    total_expenses = sum(float(e.get("amount", 0.0)) for e in init_exps)
    disposable = max(0.0, salary - commitments)
    balance = disposable - total_expenses

    # Hash PIN and create user with salary and commitments
    pin_hash = hash_pin(payload.pin)
    new_user_data = {
        "name": payload.name,
        "ic_number": payload.ic_number,
        "phone": payload.phone,
        "pin_hash": pin_hash,
        "role": "user",
        "salary": salary,
        "commitments": commitments,
        "commitments_list": init_comms,
        "expenses_list": init_exps,
        "created_at": "2026-10-06T00:00:00Z"
    }

    user_ref = users_ref.document(payload.ic_number)
    user_ref.set(new_user_data)

    budget_ref = db.collection("budgets").document(payload.ic_number)
    budget_ref.set({
        "monthly_salary": salary,
        "total_income": salary,
        "incomes": [
            {"id": "inc-1", "source": f"Gaji Pokok ({payload.name})", "amount": salary, "is_recurring": True}
        ],
        "commitments": init_comms,
        "total_commitments": commitments,
        "monthly_expenses": init_exps,
        "total_expenses": total_expenses,
        "balance": balance,
        "category_budgets": {
            "Makanan & Minuman": round(max(300.0, disposable) * 0.35, 2),
            "Pengangkutan": round(max(300.0, disposable) * 0.20, 2),
            "Perumahan": round(max(300.0, disposable) * 0.20, 2),
            "Utiliti": round(max(300.0, disposable) * 0.15, 2),
            "Lain-lain": round(max(300.0, disposable) * 0.10, 2),
        },
        "sara_monthly_subsidy": 100.0,
        "jualan_rahmah_savings": 80.0
    })

    token = create_access_token(payload.ic_number)
    return LoginResponse(
        user_id=payload.ic_number,
        name=payload.name,
        ic_number=payload.ic_number,
        role="user",
        token=token,
    )


@router.post("/forgot-password", response_model=ActionMessageResponse)
def forgot_password(payload: ForgotPasswordRequest):
    db = get_db()
    users_ref = db.collection("users")
    user_doc = next(users_ref.where("ic_number", "==", payload.ic_number).limit(1).stream(), None)

    if user_doc is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nombor MyKad/IC tidak ditemui dalam pangkalan data.",
        )

    # Update PIN
    new_pin_hash = hash_pin(payload.new_pin)
    users_ref.document(user_doc.id).update({"pin_hash": new_pin_hash})

    return ActionMessageResponse(
        success=True,
        message="PIN keselamatan anda telah berjaya dikemaskini. Sila log masuk dengan PIN baharu.",
    )


@router.get("/profile")
def get_user_profile(user_id: str = Depends(get_current_user_id)):
    db = get_db()
    user_doc = db.collection("users").document(user_id).get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="Pengguna tidak ditemui.")
    u = user_doc.to_dict()
    b_doc = db.collection("budgets").document(user_id).get()
    b_data = b_doc.to_dict() if b_doc.exists else {}
    salary = float(b_data.get("monthly_salary", 2500.0))
    commitments = float(b_data.get("total_commitments", 0.0))
    return {
        "name": u.get("name", ""),
        "ic_number": u.get("ic_number", user_id),
        "phone": u.get("phone", ""),
        "role": u.get("role", "user"),
        "salary": salary,
        "commitments": commitments,
        "disposable": salary - commitments
    }


@router.patch("/profile")
def update_user_profile(payload: dict, user_id: str = Depends(get_current_user_id)):
    db = get_db()
    user_ref = db.collection("users").document(user_id)
    budget_ref = db.collection("budgets").document(user_id)

    updates = {}
    if "name" in payload and payload["name"]:
        updates["name"] = payload["name"]
    if "phone" in payload and payload["phone"]:
        updates["phone"] = payload["phone"]
    if "pin" in payload and len(str(payload["pin"])) == 6:
        updates["pin_hash"] = hash_pin(str(payload["pin"]))
    
    if updates:
        user_ref.update(updates)

    budget_updates = {}
    if "salary" in payload and payload["salary"] is not None:
        salary = float(payload["salary"])
        budget_updates["monthly_salary"] = salary
        budget_updates["total_income"] = salary
    if "commitments" in payload and payload["commitments"] is not None:
        commitments = float(payload["commitments"])
        budget_updates["total_commitments"] = commitments
    
    if budget_updates:
        budget_ref.update(budget_updates)

    return {"success": True, "message": "Profil dan tetapan kewangan berjaya dikemaskini."}

