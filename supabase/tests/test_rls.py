"""Live RLS/auth tests against a real Supabase project using real user JWTs.
Env: SUPABASE_URL, SUPABASE_ANON_KEY (publishable key), DEMO_PASSWORD (or supabase/.demo-credentials.local).
Run: backend/.venv/bin/python -m pytest supabase/tests -q
"""
import os
import pathlib
from datetime import date, timedelta

import httpx
import pytest

URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
KEY = os.environ.get("SUPABASE_ANON_KEY", "")
_pw_file = pathlib.Path(__file__).parents[1] / ".demo-credentials.local"
PW = os.environ.get("DEMO_PASSWORD") or (_pw_file.read_text().strip() if _pw_file.exists() else "")
pytestmark = pytest.mark.skipif(not (URL and KEY and PW), reason="Supabase env not configured")

ANNA, BEN = "anna.weber.demo@example.com", "ben.schmidt.demo@example.com"
LUKAS, MIA, JONAS = "lukas.demo@example.com", "mia.demo@example.com", "jonas.demo@example.com"
ID = {LUKAS: "b0000000-0000-0000-0000-000000000001", MIA: "b0000000-0000-0000-0000-000000000002",
      JONAS: "b0000000-0000-0000-0000-000000000003", ANNA: "a0000000-0000-0000-0000-000000000001",
      BEN: "a0000000-0000-0000-0000-000000000002"}
_tokens: dict[str, str] = {}


def login(email):
    if email not in _tokens:
        r = httpx.post(f"{URL}/auth/v1/token?grant_type=password", headers={"apikey": KEY},
                       json={"email": email, "password": PW})
        assert r.status_code == 200, r.text
        _tokens[email] = r.json()["access_token"]
    return _tokens[email]


class Api:
    def __init__(self, email=None):
        self.h = {"apikey": KEY, "Content-Type": "application/json", "Prefer": "return=representation"}
        if email:
            self.h["Authorization"] = f"Bearer {login(email)}"

    def get(self, path, **params):
        return httpx.get(f"{URL}/rest/v1/{path}", headers=self.h, params=params)

    def post(self, path, body):
        return httpx.post(f"{URL}/rest/v1/{path}", headers=self.h, json=body)

    def patch(self, path, body, **params):
        return httpx.patch(f"{URL}/rest/v1/{path}", headers=self.h, json=body, params=params)

    def delete(self, path, **params):
        return httpx.delete(f"{URL}/rest/v1/{path}", headers=self.h, params=params)

    def rpc(self, fn, body):
        return httpx.post(f"{URL}/rest/v1/rpc/{fn}", headers=self.h, json=body)


def denied(r):
    return r.status_code in (400, 401, 403, 404) and r.status_code != 200


def activity_id(api, email, title):
    rows = api.get("activities", select="id,title,schedule_id", title=f"eq.{title}").json()
    return next(r["id"] for r in rows)


def test_login_and_profile_for_both_roles():
    for email, role in ((LUKAS, "participant"), (ANNA, "staff")):
        r = Api(email).get("profiles", id=f"eq.{ID[email]}")
        assert r.status_code == 200 and r.json()[0]["role"] == role
    assert httpx.post(f"{URL}/auth/v1/token?grant_type=password", headers={"apikey": KEY},
                      json={"email": LUKAS, "password": "wrong-password"}).status_code == 400


def test_anonymous_sees_nothing():
    anon = Api()
    for t in ("profiles", "schedules", "activities", "support_requests"):
        r = anon.get(t)
        assert r.status_code in (401, 403) or r.json() == []


def test_participant_isolated_from_other_participants():
    lukas = Api(LUKAS)
    assert {s["participant_id"] for s in lukas.get("schedules").json()} == {ID[LUKAS]}
    assert lukas.get("schedules", participant_id=f"eq.{ID[MIA]}").json() == []
    assert [p["id"] for p in lukas.get("profiles").json()] == [ID[LUKAS]]
    assert lukas.get("support_requests").json() and all(
        r["participant_id"] == ID[LUKAS] for r in lukas.get("support_requests").json())


def test_participant_does_not_see_drafts():
    sched = Api(LUKAS).get("schedules").json()
    assert sched and all(s["status"] == "published" for s in sched)
    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    assert Api(LUKAS).get("schedules", schedule_date=f"eq.{tomorrow}").json() == []


def test_staff_sees_only_assigned_participants():
    anna = Api(ANNA)
    assert {p["participant_id"] for p in anna.get("staff_participants").json()} == {ID[LUKAS], ID[MIA]}
    assert {s["participant_id"] for s in anna.get("schedules").json()} <= {ID[LUKAS], ID[MIA]}
    assert anna.get("schedules", participant_id=f"eq.{ID[JONAS]}").json() == []
    assert ID[JONAS] not in [p["id"] for p in anna.get("profiles").json()]
    assert anna.get("support_requests", participant_id=f"eq.{ID[JONAS]}").json() == []
    ben = Api(BEN)
    assert ben.get("schedules", participant_id=f"eq.{ID[LUKAS]}").json() == []
    assert ben.get("support_requests").json() == []  # Lukas's request is not Ben's


def test_participant_cannot_promote_or_edit_profiles():
    lukas = Api(LUKAS)
    r = lukas.patch("profiles", {"role": "staff"}, id=f"eq.{ID[LUKAS]}")
    assert denied(r) or r.json() == []
    r = lukas.patch("profiles", {"is_active": True}, id=f"eq.{ID[LUKAS]}")
    assert denied(r) or r.json() == []
    assert lukas.get("profiles", id=f"eq.{ID[LUKAS]}").json()[0]["role"] == "participant"
    assert denied(lukas.post("staff_participants", {"staff_id": ID[ANNA], "participant_id": ID[JONAS]}))
    assert denied(lukas.post("profiles", {"id": ID[LUKAS], "display_name": "x", "role": "staff"}))


def test_participant_cannot_modify_official_schedule_fields():
    lukas = Api(LUKAS)
    act = lukas.get("activities", select="id,title,status").json()[0]
    for patch in ({"title": "hacked"}, {"start_time": "01:00"}, {"status": "completed"},
                  {"schedule_id": "00000000-0000-0000-0000-000000000000"}):
        r = lukas.patch("activities", patch, id=f"eq.{act['id']}")
        assert denied(r) or r.json() == []
    sch = lukas.get("schedules").json()[0]
    for patch in ({"status": "draft"}, {"participant_id": ID[MIA]}, {"schedule_date": "2030-01-01"}):
        r = lukas.patch("schedules", patch, id=f"eq.{sch['id']}")
        assert denied(r) or r.json() == []
    assert denied(lukas.delete("activities", id=f"eq.{act['id']}")) or \
        Api(LUKAS).get("activities", id=f"eq.{act['id']}").json()
    assert lukas.get("activities", id=f"eq.{act['id']}").json()[0]["title"] == act["title"]
    assert denied(lukas.post("schedules", {"participant_id": ID[LUKAS], "schedule_date": "2031-01-01", "created_by": ID[LUKAS]}))
    assert denied(lukas.rpc("publish_schedule", {"p_schedule_id": sch["id"]}))
    assert denied(lukas.rpc("save_schedule", {"p_participant_id": ID[LUKAS], "p_schedule_date": "2031-01-01", "p_activities": []}))


def test_completion_persists_and_is_logged():
    lukas, anna = Api(LUKAS), Api(ANNA)
    aid = activity_id(lukas, LUKAS, "Breakfast")
    steps = lukas.get("activity_steps", select="id,is_completed", activity_id=f"eq.{aid}").json()
    assert lukas.rpc("complete_activity", {"p_activity_id": aid, "p_done": True}).json()["status"] == "completed"
    assert anna.get("activities", id=f"eq.{aid}").json()[0]["status"] == "completed"
    ev = lukas.get("activity_events", activity_id=f"eq.{aid}", event_type="eq.completed").json()
    assert ev and ev[0]["actor_id"] == ID[LUKAS]
    assert lukas.rpc("complete_activity", {"p_activity_id": aid, "p_done": False}).json()["status"] == "pending"
    assert steps == []  # Breakfast has no steps; step flow below
    wid = activity_id(lukas, LUKAS, "Metal Workshop: Milling")
    sid = lukas.get("activity_steps", select="id", activity_id=f"eq.{wid}", order="sort_order").json()[0]["id"]
    assert lukas.rpc("set_step_completed", {"p_step_id": sid, "p_done": True}).json()["is_completed"] is True
    assert anna.get("activity_steps", id=f"eq.{sid}").json()[0]["is_completed"] is True
    assert lukas.rpc("set_step_completed", {"p_step_id": sid, "p_done": False}).json()["is_completed"] is False


def test_participant_cannot_complete_foreign_activity():
    mia_act = activity_id(Api(MIA), MIA, "Garden work")
    r = Api(LUKAS).rpc("complete_activity", {"p_activity_id": mia_act})
    assert denied(r)
    assert Api(MIA).get("activities", id=f"eq.{mia_act}").json()[0]["status"] == "pending"
    assert denied(Api(ANNA).rpc("complete_activity", {"p_activity_id": mia_act}))  # staff cannot impersonate


def test_staff_creates_publishes_and_participant_sees(request):
    anna, mia, lukas = Api(ANNA), Api(MIA), Api(LUKAS)
    day = (date.today() + timedelta(days=30)).isoformat()
    items = [{"title": "Wake up", "startTime": "07:00", "category": "PERSONAL", "subSteps": [{"title": "Brush teeth"}]},
             {"title": "Breakfast", "startTime": "08:00", "endTime": "08:30", "category": "BREAK"},
             {"title": "Training"}]
    try:
        r = anna.rpc("save_schedule", {"p_participant_id": ID[MIA], "p_schedule_date": day, "p_activities": items})
        assert r.status_code == 200 and r.json()["status"] == "draft"
        sid = r.json()["id"]
        assert mia.get("schedules", id=f"eq.{sid}").json() == []            # draft invisible to participant
        acts = anna.get("activities", schedule_id=f"eq.{sid}", order="sort_order").json()
        assert [a["start_time"] for a in acts] == ["07:00:00", "08:00:00", None]  # no invented times
        assert denied(Api(BEN).rpc("publish_schedule", {"p_schedule_id": sid})) is False  # Ben also manages Mia
        assert anna.rpc("publish_schedule", {"p_schedule_id": sid}).json()["status"] == "published"
        assert len(mia.get("activities", schedule_id=f"eq.{sid}").json()) == 3
        assert lukas.get("activities", schedule_id=f"eq.{sid}").json() == []
        assert denied(Api(LUKAS).rpc("publish_schedule", {"p_schedule_id": sid}))
        assert anna.get("schedule_changes", schedule_id=f"eq.{sid}").json()  # audit rows readable by staff
        assert mia.get("schedule_changes", schedule_id=f"eq.{sid}").json() == []
    finally:
        anna.rpc("unpublish_schedule", {"p_schedule_id": locals().get("sid", "")}) if "sid" in locals() else None
        if "sid" in locals():
            anna.delete("schedules", id=f"eq.{sid}")


def test_staff_cannot_save_for_unassigned_participant_and_overlap_blocked():
    anna = Api(ANNA)
    day = (date.today() + timedelta(days=31)).isoformat()
    assert denied(anna.rpc("save_schedule", {"p_participant_id": ID[JONAS], "p_schedule_date": day,
                                             "p_activities": [{"title": "x"}]}))
    r = anna.rpc("save_schedule", {"p_participant_id": ID[MIA], "p_schedule_date": day, "p_activities": [
        {"title": "A", "startTime": "09:00", "endTime": "10:00"}, {"title": "B", "startTime": "09:30", "endTime": "10:30"}]})
    sid = r.json()["id"]
    try:
        p = anna.rpc("publish_schedule", {"p_schedule_id": sid})
        assert p.status_code >= 400 and "overlapping_activities" in p.text
        bad = anna.rpc("save_schedule", {"p_participant_id": ID[MIA], "p_schedule_date": day, "p_activities": [
            {"title": "C", "startTime": "10:00", "endTime": "09:00"}]})
        assert bad.status_code >= 400  # end before start rejected by constraint
    finally:
        anna.delete("schedules", id=f"eq.{sid}")


def test_support_requests_flow_and_authorization():
    lukas, anna, ben = Api(LUKAS), Api(ANNA), Api(BEN)
    r = lukas.post("support_requests", {"request_type": "help", "note": "test request"})
    assert r.status_code == 201, r.text
    rid = r.json()[0]["id"]
    assert r.json()[0]["participant_id"] == ID[LUKAS] and r.json()[0]["status"] == "open"
    assert any(x["id"] == rid for x in anna.get("support_requests").json())
    assert ben.get("support_requests", id=f"eq.{rid}").json() == []
    assert denied(ben.rpc("resolve_support_request", {"p_request_id": rid}))
    assert denied(lukas.rpc("resolve_support_request", {"p_request_id": rid}))
    assert denied(lukas.post("support_requests", {"request_type": "help", "participant_id": ID[MIA]}))
    assert denied(lukas.post("support_requests", {"request_type": "help", "status": "resolved"}))
    assert denied(lukas.post("support_requests", {"request_type": "bogus"}))
    res = anna.rpc("resolve_support_request", {"p_request_id": rid})
    assert res.status_code == 200 and res.json()["status"] == "resolved" and res.json()["resolved_by"] == ID[ANNA]
    assert denied(lukas.patch("support_requests", {"status": "open"}, id=f"eq.{rid}")) or \
        lukas.get("support_requests", id=f"eq.{rid}").json()[0]["status"] == "resolved"


def test_attendance_and_audit_cannot_be_forged():
    lukas, anna, ben = Api(LUKAS), Api(ANNA), Api(BEN)
    aid = activity_id(lukas, LUKAS, "Breakfast")
    jonas_act = activity_id(Api(BEN), JONAS, "Kitchen training")
    assert denied(lukas.post("attendance", {"activity_id": aid, "verified_by": ID[ANNA], "attendance_status": "present"}))
    assert denied(lukas.rpc("verify_attendance", {"p_activity_id": aid, "p_status": "present"}))
    assert denied(anna.rpc("verify_attendance", {"p_activity_id": jonas_act, "p_status": "present"}))
    assert denied(anna.post("attendance", {"activity_id": aid, "verified_by": ID[ANNA], "attendance_status": "present"}))
    assert denied(lukas.post("activity_events", {"activity_id": aid, "actor_id": ID[LUKAS], "event_type": "completed"}))
    assert denied(anna.post("activity_events", {"activity_id": aid, "actor_id": ID[ANNA], "event_type": "completed"}))
    sid = anna.get("activities", id=f"eq.{aid}", select="schedule_id").json()[0]["schedule_id"]
    assert denied(anna.post("schedule_changes", {"schedule_id": sid, "changed_by": ID[ANNA]}))
    assert denied(anna.delete("schedule_changes", schedule_id=f"eq.{sid}"))
    ok = anna.rpc("verify_attendance", {"p_activity_id": aid, "p_status": "late"})
    assert ok.status_code == 200 and ok.json()["verified_by"] == ID[ANNA]
    anna.rpc("verify_attendance", {"p_activity_id": aid, "p_status": "present"})
    assert ben.get("attendance", activity_id=f"eq.{aid}").json() == []


def test_monthly_progress_is_derived_and_scoped():
    month = date.today().replace(day=1).isoformat()
    rows = Api(LUKAS).rpc("monthly_progress", {"p_participant_id": ID[LUKAS], "p_month": month}).json()
    assert rows and all(r["activities_completed"] <= r["activities_total"] for r in rows)
    assert Api(LUKAS).rpc("monthly_progress", {"p_participant_id": ID[MIA], "p_month": month}).json() == []
    assert Api(BEN).rpc("monthly_progress", {"p_participant_id": ID[LUKAS], "p_month": month}).json() == []
    assert Api(ANNA).rpc("monthly_progress", {"p_participant_id": ID[LUKAS], "p_month": month}).json()


def test_signup_with_staff_metadata_grants_nothing():
    """Self-registration (if enabled) must yield an account with no role and no data access."""
    email = f"selfreg-{os.urandom(4).hex()}@example.com"
    r = httpx.post(f"{URL}/auth/v1/signup", headers={"apikey": KEY}, json={
        "email": email, "password": PW, "data": {"role": "staff", "is_active": True}})
    if r.status_code >= 400 or not r.json().get("access_token"):
        pytest.skip("public signup disabled/needs confirmation (good); nothing to check")
    h = {"apikey": KEY, "Authorization": f"Bearer {r.json()['access_token']}"}
    for t in ("profiles", "schedules", "activities", "support_requests", "staff_participants"):
        assert httpx.get(f"{URL}/rest/v1/{t}", headers=h).json() == []
    assert httpx.post(f"{URL}/rest/v1/rpc/save_schedule", headers=h, json={
        "p_participant_id": ID[LUKAS], "p_schedule_date": "2031-02-02", "p_activities": []}).status_code >= 400
