from datetime import date, datetime
from typing import Optional
from ..compat import APIRouter, Depends, Query

from ..firebase import get_db
from ..schemas import JualanRahmahListingOut, PriceItemOut
from ..security import get_current_user_id
from ..utils import haversine_km

router = APIRouter(prefix="/jualan-rahmah", tags=["jualan-rahmah"])


@router.get("/listings", response_model=list[JualanRahmahListingOut])
def list_listings(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(30, ge=0),
    search: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None),
    user_id: str = Depends(get_current_user_id),
):
    db = get_db()
    docs = db.collection("jualan_rahmah_listings").stream()
    today = date.today()

    results = []
    for doc in docs:
        data = doc.to_dict()
        distance = haversine_km(lat, lng, data["latitude"], data["longitude"])
        if distance > radius_km:
            continue
        if search:
            haystack = f"{data.get('name', '')} {data.get('address', '')} {data.get('organiser', '')}".lower()
            if search.lower() not in haystack:
                continue

        event_date_val = data["date"]
        # Handle string or date type
        if isinstance(event_date_val, str):
            try:
                event_date = datetime.strptime(event_date_val, "%Y-%m-%d").date()
            except Exception:
                event_date = today
        else:
            event_date = event_date_val

        # Level 3: Auto-detect expiry
        stored_status = data.get("verification_status", "VERIFIED")
        if event_date < today:
            ver_status = "EXPIRED"
        else:
            ver_status = stored_status

        if status_filter and status_filter.upper() != "ALL" and ver_status != status_filter.upper():
            continue

        results.append(
            JualanRahmahListingOut(
                id=doc.id,
                name=data["name"],
                organiser=data["organiser"],
                address=data["address"],
                state=data.get("state", "Pulau Pinang"),
                district=data.get("district", "Seberang Perai"),
                latitude=data["latitude"],
                longitude=data["longitude"],
                distance_km=round(distance, 1),
                date=event_date,
                start_time=data["start_time"],
                end_time=data["end_time"],
                target_families=data["target_families"],
                price_list=[
                    PriceItemOut(**item) for item in data.get("price_list", [])
                ],
                verification_status=ver_status,
                source_name=data.get("source_name", "Portal Rasmi PJRM (KPDN)"),
                source_url=data.get("source_url", "https://pjrm.kpdn.gov.my/"),
                last_verified=data.get("last_verified", today.strftime("%Y-%m-%d")),
                match_score=data.get("match_score", 95.0),
                rescheduled=data.get("rescheduled", False),
                official_date=data.get("official_date", None),
            )
        )

    results.sort(key=lambda r: r.distance_km or 0)
    return results
