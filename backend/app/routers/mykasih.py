from datetime import date, datetime
from typing import Optional
from ..compat import APIRouter, Depends, Query

from ..firebase import get_db
from ..schemas import MyKasihLocationOut
from ..security import get_current_user_id
from ..utils import haversine_km

router = APIRouter(prefix="/mykasih", tags=["mykasih"])


@router.get("/locations", response_model=list[MyKasihLocationOut])
def list_locations(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(30, ge=0),
    search: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None),
    user_id: str = Depends(get_current_user_id),
):
    db = get_db()
    docs = db.collection("mykasih_locations").stream()

    results = []
    for doc in docs:
        data = doc.to_dict()
        distance = haversine_km(lat, lng, data["latitude"], data["longitude"])
        if distance > radius_km:
            continue
        if search:
            haystack = f"{data.get('name', '')} {data.get('address', '')}".lower()
            if search.lower() not in haystack:
                continue

        ver_status = data.get("verification_status", "VERIFIED")
        if status_filter and status_filter.upper() != "ALL" and ver_status != status_filter.upper():
            continue

        event_date_val = data.get("date")
        if isinstance(event_date_val, str):
            try:
                event_date = datetime.strptime(event_date_val, "%Y-%m-%d").date()
            except Exception:
                event_date = date.today()
        else:
            event_date = event_date_val or date.today()

        results.append(
            MyKasihLocationOut(
                id=doc.id,
                name=data["name"],
                address=data["address"],
                state=data.get("state", "Pulau Pinang"),
                district=data.get("district", "Seberang Perai"),
                latitude=data["latitude"],
                longitude=data["longitude"],
                distance_km=round(distance, 1),
                date=event_date,
                start_time=data["start_time"],
                end_time=data["end_time"],
                quota_total=data["quota_total"],
                quota_remaining=data["quota_remaining"],
                items=data.get("items", []),
                verification_status=ver_status,
                source_name=data.get("source_name", "Yayasan MyKasih / Rakan Niaga SARA"),
                source_url=data.get("source_url", "https://www.mykasih.com.my/ms/about-us/merchant-partners/"),
                last_verified=data.get("last_verified", date.today().strftime("%Y-%m-%d")),
            )
        )

    results.sort(key=lambda r: r.distance_km or 0)
    return results
