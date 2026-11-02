import calendar
import uuid
from datetime import date, datetime
from typing import List, Dict, Any

from ..compat import APIRouter, Depends, HTTPException, status
from ..firebase import get_db
from ..schemas import (
    AddCommitmentRequest,
    AddExpenseRequest,
    AddIncomeRequest,
    BudgetPlanOut,
    CategoryBudgetOut,
    ExpenseItemOut,
    IncomeItemOut,
    SetCategoryBudgetRequest,
    UpdateSalaryRequest,
    UpdateIncomeRequest,
    UpdateCommitmentRequest,
    UpdateExpenseRequest,
)
from ..security import get_current_user_id

router = APIRouter(prefix="/budget", tags=["budget"])


def _ensure_own_data(path_user_id: str, token_user_id: str):
    if path_user_id != token_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Anda hanya dibenarkan mengakses maklumat belanjawan sendiri.",
        )


def _budget_ref(db, user_id: str) -> Any:
    return db.collection("budgets").document(user_id)


def _default_budget() -> dict:
    return {
        "monthly_salary": 2500.0,
        "incomes": [
            {
                "id": str(uuid.uuid4()),
                "source": "Gaji Pokok",
                "amount": 2500.0,
                "date": date.today().strftime("%Y-%m-%d"),
                "is_recurring": True,
            }
        ],
        "commitments": [
            {"id": str(uuid.uuid4()), "name": "Sewa Rumah", "amount": 600.0},
            {"id": str(uuid.uuid4()), "name": "Ansuran Motosikal", "amount": 250.0},
        ],
        "category_budgets": {
            "Makanan & Minuman": 600.0,
            "Pengangkutan": 200.0,
            "Perumahan": 400.0,
            "Utiliti": 150.0,
            "Lain-lain": 150.0,
        },
        "monthly_expenses": [
            {
                "id": str(uuid.uuid4()),
                "name": "Barang Dapur Awal Bulan",
                "amount": 420.0,
                "category": "Makanan & Minuman",
            },
            {
                "id": str(uuid.uuid4()),
                "name": "Petrol Mingguan",
                "amount": 60.0,
                "category": "Pengangkutan",
            },
            {
                "id": str(uuid.uuid4()),
                "name": "Bil Air & Elektrik",
                "amount": 110.0,
                "category": "Utiliti",
            },
        ],
    }


def _days_left_in_month() -> int:
    now = datetime.now()
    _, num_days = calendar.monthrange(now.year, now.month)
    days_left = num_days - now.day
    return max(days_left, 1)


def _generate_suggestions(
    total_income: float,
    commitments_total: float,
    disposable_income: float,
    expenses_total: float,
    category_budgets: Dict[str, float],
    expenses_by_cat: Dict[str, float],
) -> List[str]:
    """
    Intelligent Rule-based Recommendation Engine according to DPP specifications:
    1. Disposable income check
    2. Food budget > 80% & days remaining > 7
    3. Total spending > Total income
    4. Savings allocation reminder
    """
    suggestions = []
    days_left = _days_left_in_month()

    if total_income <= 0:
        return suggestions

    # Rule 1: High fixed commitments (> 40% income)
    if (commitments_total / total_income) > 0.4:
        suggestions.append(
            "💳 Komitmen tetap anda melebihi 40% pendapatan. Pertimbangkan untuk "
            "menyusun semula pinjaman atau kurangkan perbelanjaan tetap."
        )

    # Rule 2: Food spending approaching limit (> 80% of food budget with > 7 days remaining)
    food_budget = category_budgets.get("Makanan & Minuman", 0)
    food_spent = expenses_by_cat.get("Makanan & Minuman", 0)
    if food_budget > 0:
        food_util = (food_spent / food_budget) * 100
        if food_util >= 80 and days_left > 7:
            suggestions.append(
                f"🍲 Perbelanjaan makanan anda telah mencapai {food_util:.0f}% daripada bajet (baki {days_left} hari). "
                "Sila manfaatkan Jualan Rahmah Madani atau kedai MyKasih berdekatan untuk barangan asas lebih murah."
            )

    # Rule 3: Total spending > Total income (Deficit alert)
    total_spent = commitments_total + expenses_total
    if total_spent > total_income:
        suggestions.append(
            "⚠️ Perbelanjaan semasa anda melebihi jumlah pendapatan bulanan! "
            "Sila semak semula dan tangguhkan perbelanjaan bukan penting."
        )
    elif total_spent / total_income > 0.85:
        suggestions.append(
            f"📊 Anda telah menggunakan {(total_spent/total_income)*100:.0f}% daripada pendapatan bulan ini. "
            f"Kekalkan baki RM{(total_income - total_spent):.0f} untuk simpanan kecemasan."
        )

    # Rule 4: Savings allocation recommendation
    balance = total_income - total_spent
    if balance >= 50:
        suggestions.append(
            f"💰 Anda mempunyai baki pendapatan boleh guna RM{disposable_income - expenses_total:.0f}. "
            "Cadangan: Peruntukkan sekurang-kurangnya RM50 ke dalam simpanan kecemasan bulan ini."
        )

    return suggestions


def _to_out(data: dict) -> BudgetPlanOut:
    incomes_data = data.get("incomes", [])
    commitments_data = data.get("commitments", [])
    expenses_data = data.get("monthly_expenses", [])
    cat_budgets_data = data.get("category_budgets", {
        "Makanan & Minuman": 600.0,
        "Pengangkutan": 200.0,
        "Perumahan": 400.0,
        "Utiliti": 150.0,
        "Lain-lain": 150.0,
    })

    # Calculate Incomes
    incomes_list = []
    for inc in incomes_data:
        if isinstance(inc, dict):
            incomes_list.append(
                IncomeItemOut(
                    id=str(inc.get("id", uuid.uuid4())),
                    source=str(inc.get("source", "Pendapatan")),
                    amount=float(inc.get("amount", 0.0)),
                    date=str(inc.get("date", date.today().strftime("%Y-%m-%d"))),
                    is_recurring=bool(inc.get("is_recurring", True)),
                )
            )
    total_income = sum(inc.amount for inc in incomes_list)
    if total_income == 0 and data.get("monthly_salary", 0) > 0:
        total_income = float(data.get("monthly_salary", 0))

    # Calculate Commitments & Disposable Income
    commitments_list = []
    for c in commitments_data:
        if isinstance(c, dict):
            commitments_list.append(
                ExpenseItemOut(
                    id=str(c.get("id", uuid.uuid4())),
                    name=str(c.get("name", "Komitmen")),
                    amount=float(c.get("amount", 0.0)),
                    category=c.get("category"),
                )
            )
    total_commitments = sum(c.amount for c in commitments_list)
    disposable_income = max(0.0, total_income - total_commitments)

    # Calculate Expenses
    expenses_list = []
    for e in expenses_data:
        if isinstance(e, dict):
            expenses_list.append(
                ExpenseItemOut(
                    id=str(e.get("id", uuid.uuid4())),
                    name=str(e.get("name", "Perbelanjaan")),
                    amount=float(e.get("amount", 0.0)),
                    category=e.get("category"),
                )
            )
    total_expenses = sum(e.amount for e in expenses_list)
    balance = total_income - (total_commitments + total_expenses)

    # Category breakdown & Budgets
    expenses_by_cat: Dict[str, float] = {}
    for e in expenses_list:
        cat = e.category or "Lain-lain"
        expenses_by_cat[cat] = expenses_by_cat.get(cat, 0.0) + e.amount

    # Dynamically scale category budgets with disposable income
    base_disposable = max(300.0, disposable_income)
    alloc_pcts = {
        "Makanan & Minuman": 0.35,
        "Pengangkutan": 0.20,
        "Perumahan": 0.20,
        "Utiliti": 0.15,
        "Lain-lain": 0.10,
    }

    category_budgets_out: List[CategoryBudgetOut] = []
    for cat in ["Makanan & Minuman", "Pengangkutan", "Perumahan", "Utiliti", "Lain-lain"]:
        b_amount = round(base_disposable * alloc_pcts.get(cat, 0.2), 2)
        spent = expenses_by_cat.get(cat, 0.0)
        util = (spent / b_amount * 100) if b_amount > 0 else 0.0
        category_budgets_out.append(
            CategoryBudgetOut(
                category=cat,
                budget_amount=float(b_amount),
                spent_amount=spent,
                utilization_percent=round(util, 1),
            )
        )

    # Ensure any categories that were spent on but had no explicit budget are included
    for cat, spent in expenses_by_cat.items():
        if cat not in cat_budgets_data:
            category_budgets_out.append(
                CategoryBudgetOut(
                    category=cat,
                    budget_amount=0.0,
                    spent_amount=spent,
                    utilization_percent=100.0,
                )
            )

    suggestions = _generate_suggestions(
        total_income=total_income,
        commitments_total=total_commitments,
        disposable_income=disposable_income,
        expenses_total=total_expenses,
        category_budgets=cat_budgets_data,
        expenses_by_cat=expenses_by_cat,
    )

    return BudgetPlanOut(
        monthly_salary=total_income,
        incomes=incomes_list,
        total_income=total_income,
        commitments=commitments_list,
        total_commitments=total_commitments,
        disposable_income=disposable_income,
        monthly_expenses=expenses_list,
        total_expenses=total_expenses,
        balance=balance,
        category_budgets=category_budgets_out,
        suggestions=suggestions,
    )


@router.get("/{user_id}", response_model=BudgetPlanOut)
def get_budget(user_id: str, token_user_id: str = Depends(get_current_user_id)):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    if not snap.exists:
        # Check if user document exists to reconstruct registered budget
        user_doc = db.collection("users").document(user_id).get()
        if user_doc.exists:
            u_data = user_doc.to_dict()
            u_name = u_data.get("name", "Pengguna")
            u_salary = float(u_data.get("salary", 2500.0))
            u_comms = u_data.get("commitments_list") or []
            if not u_comms and float(u_data.get("commitments", 0.0)) > 0:
                u_comms = [{"id": str(uuid.uuid4()), "name": "Komitmen Tetap Bulanan", "amount": float(u_data.get("commitments"))}]
            u_exps = u_data.get("expenses_list") or []
            total_com = sum(float(c.get("amount", 0.0)) for c in u_comms)
            total_exp = sum(float(e.get("amount", 0.0)) for e in u_exps)
            disposable = max(0.0, u_salary - total_com)
            balance = disposable - total_exp
            data = {
                "monthly_salary": u_salary,
                "total_income": u_salary,
                "incomes": [
                    {
                        "id": str(uuid.uuid4()),
                        "source": f"Gaji Pokok ({u_name})",
                        "amount": u_salary,
                        "date": date.today().strftime("%Y-%m-%d"),
                        "is_recurring": True,
                    }
                ],
                "commitments": u_comms,
                "total_commitments": total_com,
                "monthly_expenses": u_exps,
                "total_expenses": total_exp,
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
            }
        else:
            data = _default_budget()
        ref.set(data)
    else:
        data = snap.to_dict()
        # Migration check: if 'incomes' not in data, seed default
        if "incomes" not in data:
            data["incomes"] = [
                {
                    "id": str(uuid.uuid4()),
                    "source": "Gaji Pokok",
                    "amount": float(data.get("monthly_salary", 2500)),
                    "date": date.today().strftime("%Y-%m-%d"),
                    "is_recurring": True,
                }
            ]
            ref.set(data, merge=True)
    return _to_out(data)


@router.post("/{user_id}/incomes", response_model=BudgetPlanOut)
def add_income(
    user_id: str,
    payload: AddIncomeRequest,
    token_user_id: str = Depends(get_current_user_id),
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    incomes = data.setdefault("incomes", [])
    incomes.append(
        {
            "id": str(uuid.uuid4()),
            "source": payload.source,
            "amount": payload.amount,
            "date": payload.date or date.today().strftime("%Y-%m-%d"),
            "is_recurring": payload.is_recurring,
        }
    )
    # also update monthly_salary to sum of recurring
    data["monthly_salary"] = sum(i["amount"] for i in incomes)
    ref.set(data, merge=True)
    return _to_out(data)


@router.delete("/{user_id}/incomes/{item_id}", response_model=BudgetPlanOut)
def delete_income(
    user_id: str, item_id: str, token_user_id: str = Depends(get_current_user_id)
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    data["incomes"] = [i for i in data.get("incomes", []) if i["id"] != item_id]
    data["monthly_salary"] = sum(i["amount"] for i in data["incomes"])
    ref.set(data, merge=True)
    return _to_out(data)


@router.patch("/{user_id}/incomes/{item_id}", response_model=BudgetPlanOut)
def update_income(
    user_id: str,
    item_id: str,
    payload: UpdateIncomeRequest,
    token_user_id: str = Depends(get_current_user_id),
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    incomes = data.setdefault("incomes", [])
    for inc in incomes:
        if inc["id"] == item_id:
            if payload.source is not None:
                inc["source"] = payload.source
            if payload.amount is not None:
                inc["amount"] = payload.amount
            if payload.date is not None:
                inc["date"] = payload.date
            if payload.is_recurring is not None:
                inc["is_recurring"] = payload.is_recurring
            break
    data["monthly_salary"] = sum(i["amount"] for i in incomes)
    ref.set(data, merge=True)
    return _to_out(data)


@router.patch("/{user_id}/salary", response_model=BudgetPlanOut)
def update_salary(
    user_id: str,
    payload: UpdateSalaryRequest,
    token_user_id: str = Depends(get_current_user_id),
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    data["monthly_salary"] = payload.monthly_salary
    # Update or insert primary income
    incomes = data.setdefault("incomes", [])
    if incomes:
        incomes[0]["amount"] = payload.monthly_salary
    else:
        incomes.append(
            {
                "id": str(uuid.uuid4()),
                "source": "Gaji Pokok",
                "amount": payload.monthly_salary,
                "date": date.today().strftime("%Y-%m-%d"),
                "is_recurring": True,
            }
        )
    ref.set(data, merge=True)
    return _to_out(data)


@router.post("/{user_id}/commitments", response_model=BudgetPlanOut)
def add_commitment(
    user_id: str,
    payload: AddCommitmentRequest,
    token_user_id: str = Depends(get_current_user_id),
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    data.setdefault("commitments", []).append(
        {"id": str(uuid.uuid4()), "name": payload.name, "amount": payload.amount}
    )
    ref.set(data, merge=True)
    return _to_out(data)


@router.delete("/{user_id}/commitments/{item_id}", response_model=BudgetPlanOut)
def delete_commitment(
    user_id: str, item_id: str, token_user_id: str = Depends(get_current_user_id)
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    data["commitments"] = [
        c for c in data.get("commitments", []) if c["id"] != item_id
    ]
    ref.set(data, merge=True)
    return _to_out(data)


@router.patch("/{user_id}/commitments/{item_id}", response_model=BudgetPlanOut)
def update_commitment(
    user_id: str,
    item_id: str,
    payload: UpdateCommitmentRequest,
    token_user_id: str = Depends(get_current_user_id),
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    commitments = data.setdefault("commitments", [])
    for com in commitments:
        if com["id"] == item_id:
            if payload.name is not None:
                com["name"] = payload.name
            if payload.amount is not None:
                com["amount"] = payload.amount
            break
    ref.set(data, merge=True)
    return _to_out(data)


@router.post("/{user_id}/expenses", response_model=BudgetPlanOut)
def add_expense(
    user_id: str,
    payload: AddExpenseRequest,
    token_user_id: str = Depends(get_current_user_id),
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    data.setdefault("monthly_expenses", []).append(
        {
            "id": str(uuid.uuid4()),
            "name": payload.name,
            "amount": payload.amount,
            "category": payload.category,
        }
    )
    ref.set(data, merge=True)
    return _to_out(data)


@router.delete("/{user_id}/expenses/{item_id}", response_model=BudgetPlanOut)
def delete_expense(
    user_id: str, item_id: str, token_user_id: str = Depends(get_current_user_id)
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    data["monthly_expenses"] = [
        e for e in data.get("monthly_expenses", []) if e["id"] != item_id
    ]
    ref.set(data, merge=True)
    return _to_out(data)


@router.patch("/{user_id}/expenses/{item_id}", response_model=BudgetPlanOut)
def update_expense(
    user_id: str,
    item_id: str,
    payload: UpdateExpenseRequest,
    token_user_id: str = Depends(get_current_user_id),
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    expenses = data.setdefault("monthly_expenses", [])
    for exp in expenses:
        if exp["id"] == item_id:
            if payload.name is not None:
                exp["name"] = payload.name
            if payload.amount is not None:
                exp["amount"] = payload.amount
            if payload.category is not None:
                exp["category"] = payload.category
            break
    ref.set(data, merge=True)
    return _to_out(data)


@router.post("/{user_id}/category-budgets", response_model=BudgetPlanOut)
def set_category_budget(
    user_id: str,
    payload: SetCategoryBudgetRequest,
    token_user_id: str = Depends(get_current_user_id),
):
    _ensure_own_data(user_id, token_user_id)
    db = get_db()
    ref = _budget_ref(db, user_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else _default_budget()
    cat_budgets = data.setdefault("category_budgets", {})
    cat_budgets[payload.category] = payload.budget_amount
    ref.set(data, merge=True)
    return _to_out(data)
