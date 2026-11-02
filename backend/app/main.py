try:
    from fastapi import FastAPI
    from fastapi.middleware.cors import CORSMiddleware
    _has_fastapi = True
except ImportError:
    _has_fastapi = False
    from starlette.applications import Starlette
    from starlette.middleware import Middleware
    from starlette.middleware.cors import CORSMiddleware
    from starlette.responses import JSONResponse
    from starlette.requests import Request
    from starlette.routing import Route

if _has_fastapi:
    from .routers import auth, mykasih, jualan_rahmah, budget, admin, notifications

    app = FastAPI(
        title="MyKasih API",
        description="Backend for the MyKasih & BantuLife affordable-living support app "
        "(login, official verification engine, MyKasih distribution points, "
        "Jualan Rahmah Madani listings, budget planner, notifications, and admin module).",
        version="2.0.0",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router)
    app.include_router(mykasih.router)
    app.include_router(jualan_rahmah.router)
    app.include_router(budget.router)
    app.include_router(admin.router)
    app.include_router(notifications.router)

    @app.get("/")
    def health_check():
        return {
            "status": "ok",
            "service": "mykasih-api",
            "version": "2.0.0",
            "engine": "fastapi",
            "modules": [
                "auth",
                "mykasih",
                "jualan_rahmah",
                "budget",
                "admin",
                "notifications",
                "official_verification_engine"
            ]
        }

else:
    # Starlette Native Server
    import json
    from datetime import date, datetime
    from .firebase import get_db
    from .security import hash_pin, verify_pin, create_access_token, decode_token
    from .verification import VerificationEngine, OFFICIAL_PJRM_URL, OFFICIAL_MYKASIH_URL
    from .utils import haversine_km
    from .routers.budget import _to_out, _default_budget

    def _json_serial(obj):
        if isinstance(obj, (date, datetime)):
            return obj.isoformat()
        if hasattr(obj, "model_dump"):
            return obj.model_dump()
        if hasattr(obj, "dict"):
            return obj.dict()
        raise TypeError(f"Type {type(obj)} not serializable")

    def _res(data, status_code=200):
        content = json.loads(json.dumps(data, default=_json_serial))
        return JSONResponse(content, status_code=status_code)

    async def health_check(request: Request):
        return _res({
            "status": "ok",
            "service": "mykasih-api",
            "version": "2.0.0",
            "engine": "starlette_native",
            "modules": [
                "auth",
                "mykasih",
                "jualan_rahmah",
                "budget",
                "admin",
                "notifications",
                "official_verification_engine"
            ]
        })

    async def api_login(request: Request):
        body = await request.json()
        ic = body.get("ic_number", "")
        pin = body.get("pin", "")
        db = get_db()
        query = db.collection("users").where("ic_number", "==", ic).limit(1).stream()
        user_doc = next(iter(query), None)
        if not user_doc:
            return _res({"detail": "Nombor MyKad/IC atau PIN tidak sah."}, 401)
        data = user_doc.to_dict()
        if not verify_pin(pin, data.get("pin_hash", "")):
            return _res({"detail": "Nombor MyKad/IC atau PIN tidak sah."}, 401)
        token = create_access_token(user_doc.id)
        return _res({
            "user_id": user_doc.id,
            "name": data.get("name", ""),
            "ic_number": ic,
            "role": data.get("role", "user"),
            "token": token
        })

    async def api_mykasih_locations(request: Request):
        db = get_db()
        lat = float(request.query_params.get("lat", 5.3991))
        lng = float(request.query_params.get("lng", 100.3638))
        radius_param = request.query_params.get("radius_km")
        radius = float(radius_param) if radius_param else 99999.0
        search = request.query_params.get("search", "").lower()
        status_filter = request.query_params.get("status_filter")
        state_filter = request.query_params.get("state")
        docs = db.collection("mykasih_locations").stream()
        results = []
        for doc in docs:
            d = doc.to_dict()
            dist = haversine_km(lat, lng, d["latitude"], d["longitude"])
            if dist > radius:
                continue
            if state_filter and state_filter.upper() != "ALL":
                if state_filter.lower() not in d.get("state", "").lower():
                    continue
            if search and search not in f"{d.get('name','')} {d.get('address','')} {d.get('state','')} {d.get('district','')}".lower():
                continue
            v_stat = d.get("verification_status", "VERIFIED")
            if status_filter and status_filter.upper() != "ALL" and v_stat != status_filter.upper():
                continue
            results.append({
                "id": doc.id,
                "name": d["name"],
                "address": d["address"],
                "state": d.get("state", "Pulau Pinang"),
                "district": d.get("district", "Seberang Perai"),
                "latitude": d["latitude"],
                "longitude": d["longitude"],
                "distance_km": round(dist, 1),
                "date": d.get("date", date.today().isoformat()),
                "start_time": d["start_time"],
                "end_time": d["end_time"],
                "quota_total": d["quota_total"],
                "quota_remaining": d["quota_remaining"],
                "items": d.get("items", []),
                "verification_status": v_stat,
                "source_name": d.get("source_name", "Yayasan MyKasih / Rakan Niaga SARA"),
                "source_url": d.get("source_url", OFFICIAL_MYKASIH_URL),
                "last_verified": d.get("last_verified", date.today().isoformat()),
            })
        results.sort(key=lambda r: r.get("distance_km") or 0)
        return _res(results)

    async def api_jualan_rahmah_listings(request: Request):
        db = get_db()
        lat = float(request.query_params.get("lat", 5.3991))
        lng = float(request.query_params.get("lng", 100.3638))
        radius_param = request.query_params.get("radius_km")
        radius = float(radius_param) if radius_param else 99999.0
        search = request.query_params.get("search", "").lower()
        status_filter = request.query_params.get("status_filter")
        state_filter = request.query_params.get("state")
        today = date.today()
        docs = db.collection("jualan_rahmah_listings").stream()
        results = []
        for doc in docs:
            d = doc.to_dict()
            dist = haversine_km(lat, lng, d["latitude"], d["longitude"])
            if dist > radius:
                continue
            if state_filter and state_filter.upper() != "ALL":
                if state_filter.lower() not in d.get("state", "").lower():
                    continue
            if search and search not in f"{d.get('name','')} {d.get('address','')} {d.get('organiser','')} {d.get('state','')} {d.get('district','')}".lower():
                continue
            event_date_str = str(d.get("date", ""))
            try:
                event_date = datetime.strptime(event_date_str, "%Y-%m-%d").date()
            except Exception:
                event_date = today
            v_stat = "EXPIRED" if event_date < today else d.get("verification_status", "VERIFIED")
            if status_filter and status_filter.upper() != "ALL" and v_stat != status_filter.upper():
                continue
            results.append({
                "id": doc.id,
                "name": d["name"],
                "organiser": d["organiser"],
                "address": d["address"],
                "state": d.get("state", "Pulau Pinang"),
                "district": d.get("district", "Seberang Perai"),
                "latitude": d["latitude"],
                "longitude": d["longitude"],
                "distance_km": round(dist, 1),
                "date": event_date.isoformat(),
                "start_time": d["start_time"],
                "end_time": d["end_time"],
                "target_families": d["target_families"],
                "price_list": d.get("price_list", []),
                "verification_status": v_stat,
                "source_name": d.get("source_name", "Portal Rasmi PJRM (KPDN)"),
                "source_url": d.get("source_url", OFFICIAL_PJRM_URL),
                "last_verified": d.get("last_verified", today.isoformat()),
                "match_score": d.get("match_score", 95.0),
                "rescheduled": d.get("rescheduled", False),
                "official_date": d.get("official_date"),
            })
        results.sort(key=lambda r: r.get("distance_km") or 0)
        return _res(results)

    async def api_get_budget(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        if not snap.exists:
            data = _default_budget()
            ref.set(data)
        else:
            data = snap.to_dict()
        return _res(_to_out(data).model_dump())

    async def api_add_income(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        body = await request.json()
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        data = snap.to_dict() if snap.exists else _default_budget()
        import uuid
        incomes = data.setdefault("incomes", [])
        incomes.append({
            "id": str(uuid.uuid4()),
            "source": body.get("source", "Pendapatan"),
            "amount": float(body.get("amount", 0.0)),
            "date": body.get("date", date.today().isoformat()),
            "is_recurring": bool(body.get("is_recurring", True)),
        })
        data["monthly_salary"] = sum(i["amount"] for i in incomes)
        ref.set(data, merge=True)
        return _res(_to_out(data).model_dump())

    async def api_delete_income(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        item_id = request.path_params.get("item_id")
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        data = snap.to_dict() if snap.exists else _default_budget()
        data["incomes"] = [i for i in data.get("incomes", []) if i["id"] != item_id]
        data["monthly_salary"] = sum(i["amount"] for i in data["incomes"])
        ref.set(data, merge=True)
        return _res(_to_out(data).model_dump())

    async def api_update_income(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        item_id = request.path_params.get("item_id")
        body = await request.json()
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        data = snap.to_dict() if snap.exists else _default_budget()
        for i in data.get("incomes", []):
            if i["id"] == item_id:
                if "source" in body: i["source"] = body["source"]
                if "amount" in body: i["amount"] = float(body["amount"])
                if "date" in body: i["date"] = body["date"]
                if "is_recurring" in body: i["is_recurring"] = bool(body["is_recurring"])
                break
        data["monthly_salary"] = sum(i["amount"] for i in data["incomes"])
        ref.set(data, merge=True)
        return _res(_to_out(data).model_dump())

    async def api_add_commitment(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        body = await request.json()
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        data = snap.to_dict() if snap.exists else _default_budget()
        import uuid
        data.setdefault("commitments", []).append({
            "id": str(uuid.uuid4()),
            "name": body.get("name", "Komitmen"),
            "amount": float(body.get("amount", 0.0)),
        })
        ref.set(data, merge=True)
        return _res(_to_out(data).model_dump())

    async def api_delete_commitment(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        item_id = request.path_params.get("item_id")
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        data = snap.to_dict() if snap.exists else _default_budget()
        data["commitments"] = [c for c in data.get("commitments", []) if c["id"] != item_id]
        ref.set(data, merge=True)
        return _res(_to_out(data).model_dump())

    async def api_update_commitment(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        item_id = request.path_params.get("item_id")
        body = await request.json()
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        data = snap.to_dict() if snap.exists else _default_budget()
        for c in data.get("commitments", []):
            if c["id"] == item_id:
                if "name" in body: c["name"] = body["name"]
                if "amount" in body: c["amount"] = float(body["amount"])
                break
        ref.set(data, merge=True)
        return _res(_to_out(data).model_dump())

    async def api_add_expense(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        body = await request.json()
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        data = snap.to_dict() if snap.exists else _default_budget()
        import uuid
        data.setdefault("monthly_expenses", []).append({
            "id": str(uuid.uuid4()),
            "name": body.get("name", "Perbelanjaan"),
            "amount": float(body.get("amount", 0.0)),
            "category": body.get("category", "Lain-lain"),
        })
        ref.set(data, merge=True)
        return _res(_to_out(data).model_dump())

    async def api_delete_expense(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        item_id = request.path_params.get("item_id")
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        data = snap.to_dict() if snap.exists else _default_budget()
        data["monthly_expenses"] = [e for e in data.get("monthly_expenses", []) if e["id"] != item_id]
        ref.set(data, merge=True)
        return _res(_to_out(data).model_dump())

    async def api_update_expense(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        item_id = request.path_params.get("item_id")
        body = await request.json()
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        data = snap.to_dict() if snap.exists else _default_budget()
        for e in data.get("monthly_expenses", []):
            if e["id"] == item_id:
                if "name" in body: e["name"] = body["name"]
                if "amount" in body: e["amount"] = float(body["amount"])
                if "category" in body: e["category"] = body["category"]
                break
        ref.set(data, merge=True)
        return _res(_to_out(data).model_dump())

    async def api_set_category_budget(request: Request):
        user_id = request.path_params.get("user_id", "901231045678")
        body = await request.json()
        db = get_db()
        ref = db.collection("budgets").document(user_id)
        snap = ref.get()
        data = snap.to_dict() if snap.exists else _default_budget()
        cat_budgets = data.setdefault("category_budgets", {})
        cat_budgets[body.get("category", "Lain-lain")] = float(body.get("budget_amount", 0.0))
        ref.set(data, merge=True)
        return _res(_to_out(data).model_dump())

    async def api_get_notifications(request: Request):
        db = get_db()
        docs = db.collection("notifications").stream()
        results = []
        for doc in docs:
            d = doc.to_dict()
            results.append({
                "id": doc.id,
                "user_id": d.get("user_id", "ALL"),
                "title": d.get("title", "Notifikasi"),
                "message": d.get("message", ""),
                "type": d.get("type", "INFO"),
                "created_at": d.get("created_at", datetime.now().strftime("%Y-%m-%d %H:%M")),
                "is_read": d.get("is_read", False),
                "action_route": d.get("action_route"),
            })
        results.sort(key=lambda x: x["created_at"], reverse=True)
        return _res(results)

    async def api_mark_notif_read(request: Request):
        notif_id = request.path_params.get("notif_id")
        db = get_db()
        ref = db.collection("notifications").document(notif_id)
        ref.update({"is_read": True})
        return _res({"status": "ok"})

    async def api_verify_event(request: Request):
        body = await request.json()
        report = VerificationEngine.verify_jualan_rahmah(body)
        return _res(report)

    async def api_verify_merchant(request: Request):
        body = await request.json()
        report = VerificationEngine.verify_mykasih_merchant(body)
        return _res(report)

    async def api_create_event(request: Request):
        body = await request.json()
        db = get_db()
        if body.get("run_verification", True):
            ver = VerificationEngine.verify_jualan_rahmah(body)
            body["verification_status"] = ver["status"]
            body["match_score"] = ver["score"]
            body["source_name"] = ver["source"]
            body["source_url"] = ver["source_url"]
            body["last_verified"] = ver["last_verified"]
            body["rescheduled"] = ver.get("rescheduled", False)
        doc_ref = db.collection("jualan_rahmah_listings").document()
        doc_ref.set(body)
        return _res({"id": doc_ref.id, "message": "Acara berjaya ditambah.", "verification": body.get("verification_status")})

    async def api_create_merchant(request: Request):
        body = await request.json()
        db = get_db()
        if body.get("run_verification", True):
            ver = VerificationEngine.verify_mykasih_merchant(body)
            body["verification_status"] = ver["status"]
            body["source_name"] = ver["source"]
            body["source_url"] = ver["source_url"]
            body["last_verified"] = ver["last_verified"]
        doc_ref = db.collection("mykasih_locations").document()
        doc_ref.set(body)
        return _res({"id": doc_ref.id, "message": "Pusat agihan berjaya ditambah.", "verification": body.get("verification_status")})

    async def api_simulate_reschedule(request: Request):
        event_id = request.path_params.get("event_id")
        new_date = request.query_params.get("new_date", "2026-10-15")
        db = get_db()
        ref = db.collection("jualan_rahmah_listings").document(event_id)
        ref.update({"date": new_date, "rescheduled": True, "official_date": new_date})
        notif_ref = db.collection("notifications").document()
        notif_ref.set({
            "user_id": "ALL",
            "title": "⚠️ Penjadualan Semula Acara",
            "message": f"Acara telah dijadualkan semula kepada {new_date}.",
            "type": "SCHEDULE_UPDATE",
            "created_at": datetime.now().strftime("%Y-%m-%d %H:%M"),
            "is_read": False,
            "action_route": "/jualan-rahmah",
        })
        return _res({"message": "Penjadualan semula dikemaskini.", "notification_id": notif_ref.id})

    async def api_sync_live(request: Request):
        from .live_scraper import populate_database_with_live_data
        db = get_db()
        result = populate_database_with_live_data(db)
        return _res(result)

    routes = [
        Route("/", health_check, methods=["GET"]),
        Route("/auth/login", api_login, methods=["POST"]),
        Route("/sync/live", api_sync_live, methods=["GET", "POST"]),
        Route("/mykasih/locations", api_mykasih_locations, methods=["GET"]),
        Route("/jualan-rahmah/listings", api_jualan_rahmah_listings, methods=["GET"]),
        Route("/budget/{user_id}", api_get_budget, methods=["GET"]),
        Route("/budget/{user_id}/incomes", api_add_income, methods=["POST"]),
        Route("/budget/{user_id}/incomes/{item_id}", api_update_income, methods=["PATCH", "PUT"]),
        Route("/budget/{user_id}/incomes/{item_id}", api_delete_income, methods=["DELETE"]),
        Route("/budget/{user_id}/commitments", api_add_commitment, methods=["POST"]),
        Route("/budget/{user_id}/commitments/{item_id}", api_update_commitment, methods=["PATCH", "PUT"]),
        Route("/budget/{user_id}/commitments/{item_id}", api_delete_commitment, methods=["DELETE"]),
        Route("/budget/{user_id}/expenses", api_add_expense, methods=["POST"]),
        Route("/budget/{user_id}/expenses/{item_id}", api_update_expense, methods=["PATCH", "PUT"]),
        Route("/budget/{user_id}/expenses/{item_id}", api_delete_expense, methods=["DELETE"]),
        Route("/budget/{user_id}/category-budgets", api_set_category_budget, methods=["POST"]),
        Route("/notifications", api_get_notifications, methods=["GET"]),
        Route("/notifications/{notif_id}/read", api_mark_notif_read, methods=["PATCH"]),
        Route("/admin/verify/event", api_verify_event, methods=["POST"]),
        Route("/admin/verify/merchant", api_verify_merchant, methods=["POST"]),
        Route("/admin/events", api_create_event, methods=["POST"]),
        Route("/admin/merchants", api_create_merchant, methods=["POST"]),
        Route("/admin/simulate-reschedule/{event_id}", api_simulate_reschedule, methods=["POST"]),
        Route("/admin/sync-live", api_sync_live, methods=["POST", "GET"]),
    ]

    middleware = [
        Middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    ]

    app = Starlette(debug=True, routes=routes, middleware=middleware)

