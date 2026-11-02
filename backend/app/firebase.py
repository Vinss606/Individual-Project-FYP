"""
Firebase Admin SDK bootstrap.

Setup:
1. Go to https://console.firebase.google.com -> create a project.
2. Enable "Firestore Database" (in Native mode).
3. Project settings -> Service accounts -> Generate new private key.
   This downloads a JSON file - save it as `serviceAccountKey.json`
   inside the `backend/` folder (same level as this `app/` package).
   DO NOT commit this file to git - it grants full admin access.
4. That's it - no separate Firebase Auth needed here, since this app
   uses a simple MyKad/IC + PIN login stored in Firestore directly
   (see routers/auth.py). You can swap in real Firebase Auth later.
"""
import datetime as dt
import os
import uuid
from typing import Any, Dict, List, Optional

_SERVICE_ACCOUNT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "serviceAccountKey.json",
)

_app = None
_db = None


class MockDocSnapshot:
    def __init__(self, doc_id: str, data: Optional[Dict[str, Any]]):
        self.id = doc_id
        self._data = dict(data) if data is not None else None

    @property
    def exists(self) -> bool:
        return self._data is not None

    def to_dict(self) -> Dict[str, Any]:
        return dict(self._data) if self._data is not None else {}


class MockDocumentRef:
    def __init__(self, collection: "MockCollectionRef", doc_id: str):
        self.collection = collection
        self.id = doc_id

    def get(self) -> MockDocSnapshot:
        data = self.collection._data.get(self.id)
        return MockDocSnapshot(self.id, data)

    def set(self, data: Dict[str, Any], merge: bool = False):
        if merge and self.id in self.collection._data:
            self.collection._data[self.id].update(data)
        else:
            self.collection._data[self.id] = dict(data)

    def update(self, data: Dict[str, Any]):
        if self.id in self.collection._data:
            self.collection._data[self.id].update(data)
        else:
            self.collection._data[self.id] = dict(data)

    def delete(self):
        self.collection._data.pop(self.id, None)


class MockQuery:
    def __init__(self, collection: "MockCollectionRef", filters: Optional[List] = None, limit_n: Optional[int] = None):
        self.collection = collection
        self.filters = filters or []
        self.limit_n = limit_n

    def where(self, field: str, op: str, value: Any) -> "MockQuery":
        new_filters = list(self.filters)
        new_filters.append((field, op, value))
        return MockQuery(self.collection, new_filters, self.limit_n)

    def limit(self, n: int) -> "MockQuery":
        return MockQuery(self.collection, self.filters, n)

    def stream(self):
        results = []
        for doc_id, data in list(self.collection._data.items()):
            match = True
            for field, op, val in self.filters:
                doc_val = data.get(field)
                if op == "==" and doc_val != val:
                    match = False
                    break
            if match:
                results.append(MockDocSnapshot(doc_id, data))
                if self.limit_n and len(results) >= self.limit_n:
                    break
        return iter(results)


class MockCollectionRef:
    def __init__(self, name: str):
        self.name = name
        self._data: Dict[str, Dict[str, Any]] = {}

    def document(self, doc_id: Optional[str] = None) -> MockDocumentRef:
        if not doc_id:
            doc_id = str(uuid.uuid4())
        return MockDocumentRef(self, doc_id)

    def add(self, data: Dict[str, Any]):
        doc_id = str(uuid.uuid4())
        self._data[doc_id] = dict(data)
        return None, MockDocumentRef(self, doc_id)

    def stream(self):
        return [MockDocSnapshot(k, v) for k, v in list(self._data.items())]

    def where(self, field: str, op: str, value: Any) -> MockQuery:
        return MockQuery(self, [(field, op, value)])

    def limit(self, n: int) -> MockQuery:
        return MockQuery(self, [], n)


class MockFirestore:
    def __init__(self):
        self._collections: Dict[str, MockCollectionRef] = {}
        self._seed_default_data()

    def collection(self, name: str) -> MockCollectionRef:
        if name not in self._collections:
            self._collections[name] = MockCollectionRef(name)
        return self._collections[name]

    def _seed_default_data(self):
        from .security import hash_pin
        from .verification import OFFICIAL_PJRM_URL, OFFICIAL_MYKASIH_URL

        today = dt.date.today()

        # Users
        u_ref = self.collection("users")
        u_ref.document("901231045678").set({
            "ic_number": "901231045678",
            "pin_hash": hash_pin("123456"),
            "name": "Sharvin",
            "role": "user",
        })
        u_ref.document("800101075555").set({
            "ic_number": "800101075555",
            "pin_hash": hash_pin("654321"),
            "name": "Admin KPDN / MyKasih",
            "role": "admin",
        })

        # MyKasih Locations
        m_ref = self.collection("mykasih_locations")
        m_ref.add({
            "name": "99 Speedmart Butterworth (Rakan Niaga Rasmi)",
            "address": "Jalan Bagan Luar, 10350 Butterworth, Seberang Perai",
            "state": "Pulau Pinang",
            "district": "Seberang Perai Utara",
            "latitude": 5.3991,
            "longitude": 100.3638,
            "date": str(today + dt.timedelta(days=11)),
            "start_time": "08:00",
            "end_time": "22:00",
            "quota_total": 250,
            "quota_remaining": 160,
            "items": ["Beras 5kg", "Minyak 2L", "Gula 1kg", "Susu", "Telur Gred B"],
            "verification_status": "VERIFIED",
            "source_name": "Yayasan MyKasih / Rakan Niaga SARA",
            "source_url": OFFICIAL_MYKASIH_URL,
            "last_verified": str(today - dt.timedelta(days=1)),
        })
        m_ref.add({
            "name": "Mydin Mall Bukit Mertajam",
            "address": "Jalan Baru, Bandar Perda, 14000 Bukit Mertajam",
            "state": "Pulau Pinang",
            "district": "Seberang Perai Tengah",
            "latitude": 5.3644,
            "longitude": 100.4661,
            "date": str(today + dt.timedelta(days=5)),
            "start_time": "09:00",
            "end_time": "22:00",
            "quota_total": 400,
            "quota_remaining": 220,
            "items": ["Beras 5kg", "Tepung 1kg", "Telur", "Minyak Masak 2L", "Barangan Dapur SARA"],
            "verification_status": "VERIFIED",
            "source_name": "Yayasan MyKasih / Rakan Niaga SARA",
            "source_url": OFFICIAL_MYKASIH_URL,
            "last_verified": str(today),
        })
        m_ref.add({
            "name": "Lotus's Seberang Jaya",
            "address": "Jalan Todak 2, Pusat Bandar Seberang Jaya, 13700 Perai",
            "state": "Pulau Pinang",
            "district": "Seberang Perai Tengah",
            "latitude": 5.3930,
            "longitude": 100.4000,
            "date": str(today + dt.timedelta(days=8)),
            "start_time": "08:30",
            "end_time": "22:30",
            "quota_total": 300,
            "quota_remaining": 180,
            "items": ["Beras 5kg", "Minyak 2L", "Susu Tepung", "Mi segera"],
            "verification_status": "VERIFIED",
            "source_name": "Yayasan MyKasih / Rakan Niaga SARA",
            "source_url": OFFICIAL_MYKASIH_URL,
            "last_verified": str(today - dt.timedelta(days=2)),
        })

        # Jualan Rahmah listings
        j_ref = self.collection("jualan_rahmah_listings")
        j_ref.add({
            "name": "Jualan Rahmah Madani Butterworth",
            "organiser": "KPDN Pulau Pinang & MBSP",
            "address": "Dataran Butterworth, Jalan Bagan Luar, 10350 Butterworth",
            "state": "Pulau Pinang",
            "district": "Seberang Perai Utara",
            "latitude": 5.3995,
            "longitude": 100.3642,
            "date": str(today + dt.timedelta(days=13)),
            "start_time": "08:00",
            "end_time": "13:00",
            "target_families": 500,
            "price_list": [
                {"name": "Beras Super Tempatan 5kg", "controlled_price": 12.00, "market_price": 18.50},
                {"name": "Minyak Masak 2L", "controlled_price": 6.50, "market_price": 9.80},
                {"name": "Gula Pasir 1kg", "controlled_price": 2.50, "market_price": 3.20},
            ],
            "verification_status": "VERIFIED",
            "source_name": "Portal Rasmi PJRM (KPDN)",
            "source_url": OFFICIAL_PJRM_URL,
            "last_verified": str(today),
            "match_score": 100.0,
            "rescheduled": False,
        })
        j_ref.add({
            "name": "Jualan Rahmah Pasar Malam Nibong Tebal",
            "organiser": "Persatuan Peniaga Kecil Nibong Tebal",
            "address": "Tapak Pasar Malam Nibong Tebal, 14300 Nibong Tebal",
            "state": "Pulau Pinang",
            "district": "Seberang Perai Selatan",
            "latitude": 5.1667,
            "longitude": 100.4833,
            "date": str(today + dt.timedelta(days=9)),
            "start_time": "17:00",
            "end_time": "21:00",
            "target_families": 200,
            "price_list": [
                {"name": "Bawang Besar 1kg", "controlled_price": 3.00, "market_price": 4.50},
                {"name": "Kentang 1kg", "controlled_price": 2.80, "market_price": 4.00},
            ],
            "verification_status": "PENDING_REVIEW",
            "source_name": "Bukan Rasmi / Permohonan Komuniti",
            "source_url": OFFICIAL_PJRM_URL,
            "last_verified": str(today),
            "match_score": 74.0,
            "rescheduled": False,
        })
        j_ref.add({
            "name": "Jualan Rahmah Madani Bayan Lepas (Tamat)",
            "organiser": "KPDN Daerah Barat Daya",
            "address": "Dewan Komuniti Bayan Lepas, 11900 Bayan Lepas",
            "state": "Pulau Pinang",
            "district": "Barat Daya",
            "latitude": 5.2950,
            "longitude": 100.2590,
            "date": str(today - dt.timedelta(days=4)),
            "start_time": "09:00",
            "end_time": "13:00",
            "target_families": 300,
            "price_list": [
                {"name": "Beras Super Tempatan 5kg", "controlled_price": 12.00, "market_price": 18.50}
            ],
            "verification_status": "EXPIRED",
            "source_name": "Portal Rasmi PJRM (KPDN)",
            "source_url": OFFICIAL_PJRM_URL,
            "last_verified": str(today - dt.timedelta(days=4)),
            "match_score": 92.0,
            "rescheduled": False,
        })

        # Budget for Sharvin
        b_ref = self.collection("budgets")
        b_ref.document("901231045678").set({
            "monthly_salary": 2900.0,
            "incomes": [
                {
                    "id": str(uuid.uuid4()),
                    "source": "Gaji Pokok (Kerani Logistik)",
                    "amount": 2500.0,
                    "date": str(today.replace(day=1)),
                    "is_recurring": True,
                },
                {
                    "id": str(uuid.uuid4()),
                    "source": "Pendapatan Sampingan (Pemandu e-Hailing)",
                    "amount": 400.0,
                    "date": str(today.replace(day=10)),
                    "is_recurring": False,
                }
            ],
            "commitments": [
                {"id": str(uuid.uuid4()), "name": "Sewa Rumah Flat", "amount": 550.0},
                {"id": str(uuid.uuid4()), "name": "Ansuran Motosikal Honda", "amount": 220.0},
                {"id": str(uuid.uuid4()), "name": "Pelan Internet Rumah & Telco", "amount": 110.0},
            ],
            "category_budgets": {
                "Makanan & Minuman": 650.0,
                "Pengangkutan": 250.0,
                "Perumahan": 450.0,
                "Utiliti": 150.0,
                "Lain-lain": 150.0,
            },
            "monthly_expenses": [
                {
                    "id": str(uuid.uuid4()),
                    "name": "Barang Dapur & Pasar Basah (Minggu 1-2)",
                    "amount": 530.0,
                    "category": "Makanan & Minuman",
                },
                {
                    "id": str(uuid.uuid4()),
                    "name": "Makan Tengah Hari Tempat Kerja",
                    "amount": 95.0,
                    "category": "Makanan & Minuman",
                },
                {
                    "id": str(uuid.uuid4()),
                    "name": "Petrol Motosikal",
                    "amount": 75.0,
                    "category": "Pengangkutan",
                },
                {
                    "id": str(uuid.uuid4()),
                    "name": "Bil Elektrik TNB & Air PBA",
                    "amount": 130.0,
                    "category": "Utiliti",
                },
            ]
        })

        # Auto-ingest live data from official PJRM & MyKasih Foundation portals
        try:
            from .live_scraper import populate_database_with_live_data
            populate_database_with_live_data(self)
        except Exception as e:
            print(f"[Firebase] Note on live sync: {e}")



def get_db():
    """Returns a cached Firestore client or fallback in-memory MockFirestore."""
    global _app, _db
    if _db is not None:
        return _db

    try:
        import firebase_admin
        from firebase_admin import credentials, firestore

        if os.path.exists(_SERVICE_ACCOUNT_PATH):
            try:
                cred = credentials.Certificate(_SERVICE_ACCOUNT_PATH)
                _app = firebase_admin.initialize_app(cred)
                _db = firestore.client()
                return _db
            except Exception:
                pass
    except ImportError:
        pass

    # Use in-memory MockFirestore
    _db = MockFirestore()
    return _db
