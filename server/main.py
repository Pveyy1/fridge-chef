from __future__ import annotations

import logging
import os
import time
from collections import defaultdict, deque

from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

import ai

log = logging.getLogger("fridge-chef")
logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(message)s")

app = FastAPI(title="Fridge Chef", version="1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

MAX_PHOTOS = 8
MAX_BYTES = 15 * 1024 * 1024

RATE_LIMIT = int(os.getenv("RATE_LIMIT_PER_HOUR", "40"))
_hits: dict[str, deque] = defaultdict(deque)


@app.middleware("http")
async def rate_limit(request: Request, call_next):
    if request.url.path in ("/detect", "/recipes") and RATE_LIMIT > 0:
        fwd = request.headers.get("x-forwarded-for", "")
        ip = fwd.split(",")[0].strip() or (request.client.host if request.client else "?")
        now = time.time()
        q = _hits[ip]
        while q and now - q[0] > 3600:
            q.popleft()
        if len(q) >= RATE_LIMIT:
            return JSONResponse({"detail": "The chef needs a breather. Too many requests this hour; try again later."},
                                status_code=429)
        q.append(now)
    return await call_next(request)


class RecipeRequest(BaseModel):
    ingredients: list[str]
    use_first: list[str] = Field(default_factory=list)
    dietary_notes: str = ""
    meal_type: str = ""
    people: int = 0
    flavors: list[str] = Field(default_factory=list)
    guidance: str = ""


@app.get("/")
def root():
    return {"name": "Fridge Chef API", "provider": ai.current_provider(), "docs": "/docs"}


@app.get("/health")
def health():
    return {"ok": True, "provider": ai.current_provider()}


@app.post("/detect")
async def detect(photos: list[UploadFile] = File(...)):
    if len(photos) > MAX_PHOTOS:
        raise HTTPException(400, f"That's a lot of photos. Please send {MAX_PHOTOS} or fewer.")
    raw = []
    for p in photos:
        data = await p.read()
        if len(data) > MAX_BYTES:
            raise HTTPException(400, "One photo is too large (over 15 MB).")
        if data:
            raw.append(data)
    log.info("detect: %d photo(s) via %s", len(raw), ai.current_provider())
    try:
        return await run_in_threadpool(ai.detect_ingredients, raw)
    except ai.AIError as exc:
        raise HTTPException(502, str(exc)) from exc
    except Exception as exc:
        log.exception("detect failed")
        raise HTTPException(500, "Something went wrong reading your fridge. Please try again.") from exc


@app.post("/recipes")
async def recipes(req: RecipeRequest):
    log.info("recipes: %d ingredient(s) via %s", len(req.ingredients), ai.current_provider())
    try:
        return await run_in_threadpool(ai.plan_menu, req.ingredients, req.use_first, req.dietary_notes,
            req.meal_type, req.people, req.flavors, req.guidance)
    except ai.AIError as exc:
        raise HTTPException(502, str(exc)) from exc
    except Exception as exc:
        log.exception("recipes failed")
        raise HTTPException(500, "Something went wrong planning the menu. Please try again.") from exc
