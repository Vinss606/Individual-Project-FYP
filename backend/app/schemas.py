from datetime import date as date_type
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

OFFICIAL_PJRM_URL = "https://pjrm.kpdn.gov.my/"
OFFICIAL_MYKASIH_URL = "https://www.mykasih.com.my/ms/about-us/merchant-partners/"


# ---- Auth -----------------------------------------------------------------

class LoginRequest(BaseModel):
    ic_number: str = Field(..., examples=["901231045678"])
    pin: str = Field(..., min_length=4, max_length=6)


class RegisterRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    ic_number: str = Field(..., min_length=12, max_length=12, examples=["950101071234"])
    phone: str = Field(..., min_length=8, max_length=20, examples=["+60123456789"])
    pin: str = Field(..., min_length=6, max_length=6, examples=["123456"])
    monthly_salary: float = Field(default=2500.0, ge=0, examples=[3000.0])
    monthly_commitments: float = Field(default=0.0, ge=0, examples=[800.0])
    commitments_list: Optional[List[Dict[str, Any]]] = None
    expenses_list: Optional[List[Dict[str, Any]]] = None


class ForgotPasswordRequest(BaseModel):
    ic_number: str = Field(..., min_length=12, max_length=12)
    new_pin: str = Field(..., min_length=6, max_length=6)


class LoginResponse(BaseModel):
    user_id: str
    name: str
    ic_number: str
    role: str = "user" # "user" | "admin"
    token: str


class ActionMessageResponse(BaseModel):
    success: bool
    message: str



# ---- Verification & Resource Badges ---------------------------------------

class VerificationReportOut(BaseModel):
    status: str # "VERIFIED" | "PENDING_REVIEW" | "NOT_VERIFIED" | "EXPIRED"
    score: float
    source: str
    source_url: Optional[str] = None
    last_verified: str
    details: str
    breakdown: Dict[str, Any] = {}
    rescheduled: bool = False
    official_date: Optional[str] = None


# ---- MyKasih locations / merchants ----------------------------------------

class MyKasihLocationOut(BaseModel):
    id: str
    name: str
    address: str
    state: str = "Pulau Pinang"
    district: str = "Seberang Perai"
    latitude: float
    longitude: float
    distance_km: Optional[float] = None
    date: date_type
    start_time: str
    end_time: str
    quota_total: int
    quota_remaining: int
    items: List[str]
    verification_status: str = "VERIFIED" # "VERIFIED" | "PENDING_REVIEW" | "NOT_VERIFIED" | "EXPIRED"
    source_name: str = "Yayasan MyKasih / Rakan Niaga SARA"
    source_url: str = OFFICIAL_MYKASIH_URL
    last_verified: str = "2026-09-10"


# ---- Jualan Rahmah listings --------------------------------------------------

class PriceItemOut(BaseModel):
    name: str
    controlled_price: float
    market_price: float


class JualanRahmahListingOut(BaseModel):
    id: str
    name: str
    organiser: str
    address: str
    state: str = "Pulau Pinang"
    district: str = "Seberang Perai"
    latitude: float
    longitude: float
    distance_km: Optional[float] = None
    date: date_type
    start_time: str
    end_time: str
    target_families: int
    price_list: List[PriceItemOut]
    verification_status: str = "VERIFIED" # "VERIFIED" | "PENDING_REVIEW" | "NOT_VERIFIED" | "EXPIRED"
    source_name: str = "Portal Rasmi PJRM (KPDN)"
    source_url: str = OFFICIAL_PJRM_URL
    last_verified: str = "2026-09-10"
    match_score: Optional[float] = 100.0
    rescheduled: bool = False
    official_date: Optional[str] = None


# ---- Budget planner & Income Tracking ----------------------------------------

class IncomeItemOut(BaseModel):
    id: str
    source: str
    amount: float
    date: str = ""
    is_recurring: bool = True


class AddIncomeRequest(BaseModel):
    source: str
    amount: float
    date: Optional[str] = None
    is_recurring: bool = True


class ExpenseItemOut(BaseModel):
    id: str
    name: str
    amount: float
    category: Optional[str] = None


class CategoryBudgetOut(BaseModel):
    category: str
    budget_amount: float
    spent_amount: float
    utilization_percent: float


class SetCategoryBudgetRequest(BaseModel):
    category: str
    budget_amount: float


class BudgetPlanOut(BaseModel):
    monthly_salary: float
    incomes: List[IncomeItemOut] = []
    total_income: float = 0.0
    commitments: List[ExpenseItemOut] = []
    total_commitments: float = 0.0
    disposable_income: float = 0.0
    monthly_expenses: List[ExpenseItemOut] = []
    total_expenses: float = 0.0
    balance: float = 0.0
    category_budgets: List[CategoryBudgetOut] = []
    suggestions: List[str] = []


class UpdateSalaryRequest(BaseModel):
    monthly_salary: float


class AddCommitmentRequest(BaseModel):
    name: str
    amount: float


class UpdateIncomeRequest(BaseModel):
    source: Optional[str] = None
    amount: Optional[float] = None
    date: Optional[str] = None
    is_recurring: Optional[bool] = None


class UpdateCommitmentRequest(BaseModel):
    name: Optional[str] = None
    amount: Optional[float] = None


class UpdateExpenseRequest(BaseModel):
    name: Optional[str] = None
    amount: Optional[float] = None
    category: Optional[str] = None
    date: Optional[str] = None


class AddExpenseRequest(BaseModel):
    name: str
    amount: float
    category: str


# ---- In-App Notifications ---------------------------------------------------

class NotificationOut(BaseModel):
    id: str
    user_id: str
    title: str
    message: str
    type: str # "BUDGET_WARNING" | "SCHEDULE_UPDATE" | "RESOURCE_ALERT" | "INFO"
    created_at: str
    is_read: bool = False
    action_route: Optional[str] = None


# ---- Admin Management -------------------------------------------------------

class CreateEventRequest(BaseModel):
    name: str
    organiser: str
    address: str
    state: str = "Pulau Pinang"
    district: str = "Seberang Perai"
    latitude: float
    longitude: float
    date: date_type
    start_time: str
    end_time: str
    target_families: int
    price_list: List[PriceItemOut] = []
    run_verification: bool = True


class CreateMerchantRequest(BaseModel):
    name: str
    address: str
    state: str = "Pulau Pinang"
    district: str = "Seberang Perai"
    latitude: float
    longitude: float
    date: date_type
    start_time: str
    end_time: str
    quota_total: int
    quota_remaining: int
    items: List[str] = []
    run_verification: bool = True


class UpdateStatusRequest(BaseModel):
    status: str # "VERIFIED" | "PENDING_REVIEW" | "NOT_VERIFIED" | "EXPIRED"
    notes: Optional[str] = None
