"""
Populates Firestore with rich sample data showcasing official verification against:
- Jualan Rahmah Madani: https://pjrm.kpdn.gov.my/
- MyKasih Merchant Partners: https://www.mykasih.com.my/ms/about-us/merchant-partners/

Run this once after setting up serviceAccountKey.json:
    python seed_data.py
"""
import datetime as dt
import uuid

from app.firebase import get_db
from app.security import hash_pin

OFFICIAL_PJRM_URL = "https://pjrm.kpdn.gov.my/"
OFFICIAL_MYKASIH_URL = "https://www.mykasih.com.my/ms/about-us/merchant-partners/"


def seed_users(db):
    users_ref = db.collection("users")
    demo_users = [
        {"ic_number": "901231045678", "pin": "123456", "name": "Sharvin", "role": "user"},
        {"ic_number": "800101075555", "pin": "654321", "name": "Admin KPDN / MyKasih", "role": "admin"},
    ]
    for u in demo_users:
        doc_id = u["ic_number"]
        users_ref.document(doc_id).set(
            {
                "ic_number": u["ic_number"],
                "pin_hash": hash_pin(u["pin"]),
                "name": u["name"],
                "role": u["role"],
            }
        )
    print(f"Seeded {len(demo_users)} user(s).")
    print(" - Citizen Login: IC 901231045678, PIN: 123456")
    print(" - Admin Login:   IC 800101075555, PIN: 654321")


def seed_mykasih_locations(db):
    ref = db.collection("mykasih_locations")
    today = dt.date.today()
    locations = [
        {
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
        },
        {
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
        },
        {
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
        },
        {
            "name": "Econsave Raja Uda",
            "address": "Jalan Raja Uda, 12300 Butterworth",
            "state": "Pulau Pinang",
            "district": "Seberang Perai Utara",
            "latitude": 5.4300,
            "longitude": 100.3800,
            "date": str(today + dt.timedelta(days=3)),
            "start_time": "09:00",
            "end_time": "22:00",
            "quota_total": 200,
            "quota_remaining": 75,
            "items": ["Beras Super 5kg", "Gula Pasir", "Tepung Gandum"],
            "verification_status": "VERIFIED",
            "source_name": "Yayasan MyKasih / Rakan Niaga SARA",
            "source_url": OFFICIAL_MYKASIH_URL,
            "last_verified": str(today - dt.timedelta(days=1)),
        },
        {
            "name": "Kedai Komuniti Permatang Pauh (Cadangan Baharu)",
            "address": "Jalan Permatang Pauh, 13500 Seberang Perai",
            "state": "Pulau Pinang",
            "district": "Seberang Perai Tengah",
            "latitude": 5.4050,
            "longitude": 100.4120,
            "date": str(today + dt.timedelta(days=14)),
            "start_time": "09:00",
            "end_time": "12:00",
            "quota_total": 100,
            "quota_remaining": 100,
            "items": ["Beras 5kg", "Minyak 1kg"],
            "verification_status": "PENDING_REVIEW",
            "source_name": "Entri Peniaga Tempatan (Dalam Semakan)",
            "source_url": OFFICIAL_MYKASIH_URL,
            "last_verified": str(today),
        },
    ]
    for loc in locations:
        ref.add(loc)
    print(f"Seeded {len(locations)} MyKasih location(s).")


def seed_jualan_rahmah(db):
    ref = db.collection("jualan_rahmah_listings")
    today = dt.date.today()
    listings = [
        {
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
                {
                    "name": "Beras Super Tempatan 5kg",
                    "controlled_price": 12.00,
                    "market_price": 18.50,
                },
                {
                    "name": "Minyak Masak 2L",
                    "controlled_price": 6.50,
                    "market_price": 9.80,
                },
                {
                    "name": "Gula Pasir 1kg",
                    "controlled_price": 2.50,
                    "market_price": 3.20,
                },
            ],
            "verification_status": "VERIFIED",
            "source_name": "Portal Rasmi PJRM (KPDN)",
            "source_url": OFFICIAL_PJRM_URL,
            "last_verified": str(today - dt.timedelta(days=1)),
            "match_score": 96.0,
            "rescheduled": False,
        },
        {
            "name": "Jualan Rahmah Madani Bukit Mertajam",
            "organiser": "KPDN Seberang Perai Tengah & MPSP",
            "address": "Dataran Bandar, 14000 Bukit Mertajam, Seberang Perai",
            "state": "Pulau Pinang",
            "district": "Seberang Perai Tengah",
            "latitude": 5.3644,
            "longitude": 100.4661,
            "date": str(today + dt.timedelta(days=5)),
            "start_time": "08:00",
            "end_time": "12:00",
            "target_families": 350,
            "price_list": [
                {
                    "name": "Ayam Standard (Seekor)",
                    "controlled_price": 8.50,
                    "market_price": 11.00,
                },
                {
                    "name": "Telur Gred A (10 biji)",
                    "controlled_price": 4.80,
                    "market_price": 6.00,
                },
            ],
            "verification_status": "VERIFIED",
            "source_name": "Portal Rasmi PJRM (KPDN)",
            "source_url": OFFICIAL_PJRM_URL,
            "last_verified": str(today),
            "match_score": 98.0,
            "rescheduled": False,
        },
        {
            "name": "Jualan Rahmah Madani Georgetown",
            "organiser": "KPDN Daerah Timur Laut",
            "address": "Padang Kota Lama, 10200 Georgetown, Pulau Pinang",
            "state": "Pulau Pinang",
            "district": "Timur Laut",
            "latitude": 5.4200,
            "longitude": 100.3400,
            "date": str(today + dt.timedelta(days=21)),
            "start_time": "08:30",
            "end_time": "14:00",
            "target_families": 600,
            "price_list": [
                {
                    "name": "Beras Super Tempatan 5kg",
                    "controlled_price": 12.00,
                    "market_price": 18.50,
                },
                {
                    "name": "Minyak Masak 2L",
                    "controlled_price": 6.50,
                    "market_price": 9.80,
                },
                {
                    "name": "Tepung Gandum 1kg",
                    "controlled_price": 2.20,
                    "market_price": 3.00,
                },
            ],
            "verification_status": "VERIFIED",
            "source_name": "Portal Rasmi PJRM (KPDN)",
            "source_url": OFFICIAL_PJRM_URL,
            "last_verified": str(today),
            "match_score": 100.0,
            "rescheduled": False,
        },
        {
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
                {
                    "name": "Bawang Besar 1kg",
                    "controlled_price": 3.00,
                    "market_price": 4.50,
                },
                {
                    "name": "Kentang 1kg",
                    "controlled_price": 2.80,
                    "market_price": 4.00,
                },
            ],
            "verification_status": "PENDING_REVIEW",
            "source_name": "Bukan Rasmi / Permohonan Komuniti",
            "source_url": OFFICIAL_PJRM_URL,
            "last_verified": str(today),
            "match_score": 74.0,
            "rescheduled": False,
        },
        {
            "name": "Jualan Rahmah Madani Bayan Lepas (Tamat)",
            "organiser": "KPDN Daerah Barat Daya",
            "address": "Dewan Komuniti Bayan Lepas, 11900 Bayan Lepas",
            "state": "Pulau Pinang",
            "district": "Barat Daya",
            "latitude": 5.2950,
            "longitude": 100.2590,
            "date": str(today - dt.timedelta(days=4)), # Past date -> EXPIRED
            "start_time": "09:00",
            "end_time": "13:00",
            "target_families": 300,
            "price_list": [
                {
                    "name": "Beras Super Tempatan 5kg",
                    "controlled_price": 12.00,
                    "market_price": 18.50,
                }
            ],
            "verification_status": "EXPIRED",
            "source_name": "Portal Rasmi PJRM (KPDN)",
            "source_url": OFFICIAL_PJRM_URL,
            "last_verified": str(today - dt.timedelta(days=4)),
            "match_score": 92.0,
            "rescheduled": False,
        }
    ]
    for listing in listings:
        ref.add(listing)
    print(f"Seeded {len(listings)} Jualan Rahmah listing(s).")


def seed_budget(db):
    user_id = "901231045678"
    today = dt.date.today()
    ref = db.collection("budgets").document(user_id)
    budget_data = {
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
    }
    ref.set(budget_data)
    print("Seeded comprehensive budget data for user Sharvin.")


def seed_notifications(db):
    ref = db.collection("notifications")
    now_str = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
    notifications = [
        {
            "user_id": "ALL",
            "title": "🟢 Jualan Rahmah Disahkan (KPDN)",
            "message": f"Acara Jualan Rahmah Madani Butterworth telah disahkan melalui portal {OFFICIAL_PJRM_URL}. Barangan keperluan asas sedia dijual dengan diskaun sehingga 30%.",
            "type": "RESOURCE_ALERT",
            "created_at": now_str,
            "is_read": False,
            "action_route": "/jualan-rahmah",
        },
        {
            "user_id": "901231045678",
            "title": "⚠️ Amaran Bajet Makanan (81%)",
            "message": "Perbelanjaan makanan anda telah mencapai RM625 daripada bajet RM650. Sila manfaatkan barangan berdiskaun di Jualan Rahmah atau rakan niaga MyKasih.",
            "type": "BUDGET_WARNING",
            "created_at": now_str,
            "is_read": False,
            "action_route": "/belanjawan",
        },
        {
            "user_id": "ALL",
            "title": "🏪 Rakan Niaga Baharu MyKasih Disahkan",
            "message": f"99 Speedmart dan Mydin Mall disahkan sebagai rakan niaga rasmi MyKasih / SARA mengikut {OFFICIAL_MYKASIH_URL}.",
            "type": "RESOURCE_ALERT",
            "created_at": now_str,
            "is_read": True,
            "action_route": "/mykasih",
        },
    ]
    for notif in notifications:
        ref.add(notif)
    print(f"Seeded {len(notifications)} notification(s).")


if __name__ == "__main__":
    db = get_db()
    seed_users(db)
    seed_mykasih_locations(db)
    seed_jualan_rahmah(db)
    seed_budget(db)
    seed_notifications(db)
    print("Done! Start the API with: uvicorn app.main:app --reload")
