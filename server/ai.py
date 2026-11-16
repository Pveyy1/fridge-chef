from __future__ import annotations

import base64
import io
import json
import os
import re
from pathlib import Path

from dotenv import dotenv_values
from PIL import Image, ImageOps

CLAUDE_MODEL = "claude-sonnet-5-5"
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
MAX_SIDE = 1568
ENV_FILE = Path(__file__).with_name(".env")

STAPLES = ["salt", "pepper", "oil", "butter", "water"]


class AIError(Exception):
    pass


def _setting(name: str) -> str | None:
    value = os.getenv(name)
    if value:
        return value.strip()
    if ENV_FILE.exists():
        value = dotenv_values(ENV_FILE).get(name)
        if value:
            return value.strip()
    return None


def current_provider() -> str:
    forced = (_setting("AI_PROVIDER") or "").lower()
    if forced in {"claude", "gemini", "demo"}:
        return forced
    if _setting("ANTHROPIC_API_KEY"):
        return "claude"
    if _setting("GEMINI_API_KEY") or _setting("GOOGLE_API_KEY"):
        return "gemini"
    return "demo"


def prepare_image(raw: bytes) -> bytes:
    try:
        img = Image.open(io.BytesIO(raw))
        img = ImageOps.exif_transpose(img)
    except Exception as exc:
        raise AIError("One of the photos couldn't be opened. Try a JPEG or PNG.") from exc
    if img.mode != "RGB":
        img = img.convert("RGB")
    img.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=85)
    return out.getvalue()


DETECT_PROMPT = """You are a sharp-eyed chef looking into someone's fridge.

You will receive one or more photos. They may be messy: items can be hidden behind
others, stacked, half out of frame, in unlabelled tubs or foil, or shot from odd angles.
Several photos may show the same shelf, so MERGE DUPLICATES across photos (list each
ingredient once).

Rules:
- Only list food and drink ingredients. Ignore non-food items (magnets, cleaning products,
  medicine, containers that are clearly empty, packaging with nothing in it).
- Use short, plain, lowercase names a home cook would say: "eggs", "cheddar", "half a lemon",
  "leftover rice", "spinach". Not brands.
- "sure": things you can clearly identify.
- "unsure": things you can see but can't confidently identify (e.g. an opaque tub, a
  wrapped block). For each give "looks_like" (a short description of what you see) and
  "options": 2-4 likely guesses.
- "use_first": items from "sure" that look like they should be used soon (wilting greens,
  soft or browning produce, opened packs, leftovers in containers, nearly-gone items).

Return ONLY this JSON, no prose, no markdown:
{"sure": ["..."], "unsure": [{"looks_like": "...", "options": ["...", "..."]}], "use_first": ["..."]}
"""

RECIPE_PROMPT = """You are the head chef of a small, elegant restaurant whose trick is turning
ordinary leftovers into something beautiful.

Available ingredients (use ONLY these): {ingredients}
Free basic staples you may also use: salt, pepper, oil, butter, water.
Use these first (they're about to go off), and feature them prominently: {use_first}
Dietary notes from the guest: {dietary}

What the guest wants:
- Meal: {meal_type}
- Cooking for: {people}
- Flavour mood: {flavors}
- Their note to the chef: {guidance}

Create exactly 3 different dishes a home cook can make today that fit what the guest wants.
If a wish is hard to meet with these ingredients (e.g. dessert with no sweet items), get as
close as you can, but NEVER add ingredients to do it. Rules:
- Do NOT use any ingredient that isn't listed above or a staple. No "optional" extras,
  no garnishes the guest doesn't have.
- Make the 3 dishes genuinely different (e.g. not three omelettes).
- Each dish should use at least 2 listed ingredients. Prefer dishes that use more of them,
  especially the use-first items.
- "fancy_name": a restaurant-menu name, evocative but not silly (e.g. "Golden Wok-Tossed
  Rice, Soft Egg Ribbons & Scallion Oil").
- In ALL names and descriptions, only name what IS in the dish; never mention missing or
  absent ingredients (no "garlic-free", "without", "no-").
- "plain_name": what it really is, lowercase (e.g. "egg fried rice").
- "menu_description": one elegant sentence, max 25 words, like a fine-dining menu.
- "minutes": realistic total time as an integer.
- "difficulty": one of "Easy", "Medium", "Hard".
- "uses": the listed ingredients this dish uses (not the staples), lowercase.
- "steps": 4 to 7 short, clear imperative steps (max ~20 words each).
- "plating_tip": one sentence on how to plate it so it looks restaurant-worthy.
- "servings": how many people the recipe serves (integer). Match "Cooking for" if given;
  scale the quantities in the steps to it.
- "nutrition": your best estimate PER SERVING, based on realistic quantities of the
  ingredients and staples (including the oil/butter) in the steps: integers for
  "calories" (kcal), "protein_g", "carbs_g", "fat_g", "fiber_g".

Return ONLY this JSON, no prose, no markdown:
{{"dishes": [{{"fancy_name": "...", "plain_name": "...", "menu_description": "...", "minutes": 20, "difficulty": "Easy", "uses": ["..."], "steps": ["..."], "plating_tip": "...", "servings": 2, "nutrition": {{"calories": 450, "protein_g": 20, "carbs_g": 50, "fat_g": 15, "fiber_g": 4}}}}]}}
"""


def parse_json(text: str) -> dict:
    if not text:
        raise AIError("The chef didn't say anything. Please try again.")
    cleaned = text.strip()
    cleaned = re.sub(r"^```[a-zA-Z]*\s*", "", cleaned)
    cleaned = re.sub(r"\s*```\s*$", "", cleaned)
    try:
        data = json.loads(cleaned)
        if isinstance(data, dict):
            return data
    except json.JSONDecodeError:
        pass
    match = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if match:
        try:
            data = json.loads(match.group(0))
            if isinstance(data, dict):
                return data
        except json.JSONDecodeError:
            pass
    raise AIError("The chef's notes came back garbled. Please try again.")


def _str_list(value) -> list[str]:
    if not isinstance(value, list):
        return []
    out, seen = [], set()
    for item in value:
        if isinstance(item, str) and item.strip():
            name = item.strip().lower()
            if name not in seen:
                seen.add(name)
                out.append(name)
    return out


def normalize_detection(data: dict) -> dict:
    sure = _str_list(data.get("sure"))
    unsure = []
    for item in data.get("unsure") or []:
        if not isinstance(item, dict):
            continue
        options = _str_list(item.get("options"))
        looks_like = str(item.get("looks_like") or "").strip()
        if looks_like and options:
            unsure.append({"looks_like": looks_like, "options": options[:4]})
    use_first = _str_list(data.get("use_first"))
    return {"sure": sure, "unsure": unsure, "use_first": use_first}


def _to_int(value, default: int = 0) -> int:
    try:
        return int(round(float(re.sub(r"[^0-9.]", "", str(value)) or default)))
    except ValueError:
        return default


NUTRIENTS = ["calories", "protein_g", "carbs_g", "fat_g", "fiber_g"]


def _nutrition(value) -> dict | None:
    if not isinstance(value, dict):
        return None
    out = {k: _to_int(value.get(k), 0) for k in NUTRIENTS}
    return out if out["calories"] > 0 else None


def normalize_dishes(data: dict) -> dict:
    dishes = []
    for d in data.get("dishes") or []:
        if not isinstance(d, dict) or not d.get("fancy_name"):
            continue
        try:
            minutes = int(re.sub(r"[^0-9]", "", str(d.get("minutes", ""))) or 20)
        except ValueError:
            minutes = 20
        difficulty = str(d.get("difficulty") or "Easy").strip().capitalize()
        if difficulty not in {"Easy", "Medium", "Hard"}:
            difficulty = "Medium"
        steps = [s.strip() for s in d.get("steps") or [] if isinstance(s, str) and s.strip()]
        dishes.append({
            "fancy_name": str(d["fancy_name"]).strip(),
            "plain_name": str(d.get("plain_name") or "").strip().lower(),
            "menu_description": str(d.get("menu_description") or "").strip(),
            "minutes": minutes,
            "difficulty": difficulty,
            "uses": _str_list(d.get("uses")),
            "steps": steps[:7],
            "plating_tip": str(d.get("plating_tip") or "").strip(),
            "servings": max(1, _to_int(d.get("servings"), 2)),
            "nutrition": _nutrition(d.get("nutrition")),
        })
    if not dishes:
        raise AIError("The chef couldn't come up with dishes. Try adding an ingredient or two.")
    return {"dishes": dishes[:3]}


def _call_claude(prompt: str, images: list[bytes]) -> str:
    import anthropic

    client = anthropic.Anthropic(api_key=_setting("ANTHROPIC_API_KEY"))
    content: list[dict] = [
        {
            "type": "image",
            "source": {"type": "base64", "media_type": "image/jpeg",
                       "data": base64.standard_b64encode(img).decode()},
        }
        for img in images
    ]
    content.append({"type": "text", "text": prompt})
    try:
        resp = client.messages.create(
            model=_setting("CLAUDE_MODEL") or CLAUDE_MODEL,
            max_tokens=3000,
            messages=[{"role": "user", "content": content}],
        )
    except anthropic.AuthenticationError as exc:
        raise AIError("The Claude API key was rejected. Check ANTHROPIC_API_KEY in server/.env.") from exc
    except anthropic.RateLimitError as exc:
        raise AIError("Claude is busy right now (rate limit). Wait a few seconds and try again.") from exc
    except anthropic.APIConnectionError as exc:
        raise AIError("Couldn't reach Claude. Check the Mac's internet connection.") from exc
    except anthropic.APIStatusError as exc:
        raise AIError(f"Claude returned an error ({exc.status_code}). Please try again.") from exc
    return "".join(block.text for block in resp.content if getattr(block, "type", "") == "text")


def _call_gemini(prompt: str, images: list[bytes]) -> str:
    from google import genai
    from google.genai import types

    client = genai.Client(api_key=_setting("GEMINI_API_KEY") or _setting("GOOGLE_API_KEY"))
    parts = [types.Part.from_bytes(data=img, mime_type="image/jpeg") for img in images]
    parts.append(prompt)
    try:
        resp = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=parts,
            config=types.GenerateContentConfig(response_mime_type="application/json"),
        )
    except Exception as exc:
        raise AIError(f"Gemini returned an error: {str(exc)[:160]}") from exc
    return resp.text or ""


def _ask(prompt: str, images: list[bytes] | None = None) -> dict:
    provider = current_provider()
    if provider == "claude":
        return parse_json(_call_claude(prompt, images or []))
    if provider == "gemini":
        return parse_json(_call_gemini(prompt, images or []))
    raise AIError("No API key is set.")


def detect_ingredients(raw_images: list[bytes]) -> dict:
    if not raw_images:
        raise AIError("Add at least one photo of your fridge.")
    if current_provider() == "demo":
        return DEMO_DETECTION
    images = [prepare_image(r) for r in raw_images]
    return normalize_detection(_ask(DETECT_PROMPT, images))


def plan_menu(ingredients: list[str], use_first: list[str], dietary: str,
              meal_type: str = "", people: int = 0, flavors: list[str] | None = None,
              guidance: str = "") -> dict:
    ingredients = _str_list(ingredients)
    if len(ingredients) < 2:
        raise AIError("Pick at least two ingredients so the chef has something to work with.")
    if current_provider() == "demo":
        return DEMO_DISHES
    flavors = _str_list(flavors or [])
    prompt = RECIPE_PROMPT.format(
        ingredients=", ".join(ingredients),
        use_first=", ".join(_str_list(use_first)) or "nothing in particular",
        dietary=dietary.strip()[:300] or "none",
        meal_type=meal_type.strip()[:40] or "chef's choice (whatever suits these ingredients best)",
        people=f"{people} {'person' if people == 1 else 'people'}" if 0 < people <= 20 else "not specified (assume 2)",
        flavors=", ".join(flavors)[:120] or "chef's choice",
        guidance=guidance.strip()[:300] or "none",
    )
    result = normalize_dishes(_ask(prompt))
    bad = _off_list(result["dishes"], ingredients)
    if bad:
        retry = prompt + (
            f"\nIMPORTANT: a previous attempt used ingredients the guest does NOT have: "
            f"{', '.join(sorted(bad))}. Do not use them or anything else not listed.\n"
        )
        result = normalize_dishes(_ask(retry))
        good = [d for d in result["dishes"] if not _off_list([d], ingredients)]
        if not good:
            raise AIError("The chef kept reaching for things you don't have. Please try again.")
        result = {"dishes": good}
    return result


def _matches(item: str, available: list[str]) -> bool:
    def words(s: str) -> set[str]:
        return {w.rstrip("s") for w in re.findall(r"[a-z]+", s.lower()) if len(w) > 2}
    iw = words(item)
    if not iw:
        return True
    for a in available + STAPLES:
        aw = words(a)
        if item in a or a in item or (iw & aw):
            return True
    return False


def _off_list(dishes: list[dict], available: list[str]) -> set[str]:
    return {u for d in dishes for u in d["uses"] if not _matches(u, available)}


DEMO_DETECTION = {
    "sure": ["eggs", "leftover rice", "spring onions", "cheddar", "spinach", "half a lemon", "tomatoes"],
    "unsure": [
        {"looks_like": "white tub with a blue lid", "options": ["greek yogurt", "cream cheese", "sour cream"]},
        {"looks_like": "foil-wrapped block on the top shelf", "options": ["butter", "leftover chicken", "feta"]},
    ],
    "use_first": ["spinach", "leftover rice"],
}

DEMO_DISHES = {
    "dishes": [
        {
            "fancy_name": "Golden Wok-Tossed Rice, Silken Egg Ribbons & Scallion Oil",
            "plain_name": "egg fried rice",
            "menu_description": "Day-old jasmine rice seared until crisp-edged, folded with soft egg and finished with a bright scallion oil.",
            "minutes": 15,
            "difficulty": "Easy",
            "uses": ["leftover rice", "eggs", "spring onions", "spinach"],
            "steps": [
                "Slice spring onions; keep greens and whites apart.",
                "Warm oil in a large pan over high heat and fry the whites for 30 seconds.",
                "Add rice, press flat and let it crisp for 2 minutes before tossing.",
                "Push rice aside, scramble the eggs softly, then fold through.",
                "Stir in spinach until just wilted; season with salt and pepper.",
                "Warm onion greens in a spoon of oil and drizzle over the top.",
            ],
            "plating_tip": "Pack the rice into a small bowl, invert onto a warm plate and spoon the scallion oil around the base.",
            "servings": 2,
            "nutrition": {"calories": 560, "protein_g": 22, "carbs_g": 62, "fat_g": 24, "fiber_g": 3},
        },
        {
            "fancy_name": "Spinach & Aged Cheddar Soufflé Omelette, Lemon-Kissed Tomatoes",
            "plain_name": "cheese and spinach omelette",
            "menu_description": "A cloud-light omelette folded around wilted spinach and sharp cheddar, with lemon-dressed tomatoes.",
            "minutes": 12,
            "difficulty": "Medium",
            "uses": ["eggs", "spinach", "cheddar", "tomatoes", "half a lemon"],
            "steps": [
                "Separate 3 eggs; whisk whites to soft peaks, then fold in the yolks.",
                "Wilt spinach in butter, season and set aside.",
                "Pour the eggs into a buttered pan on low heat; cover for 3 minutes.",
                "Scatter spinach and grated cheddar on one half and fold over.",
                "Dice tomatoes and dress with lemon juice, oil and salt.",
            ],
            "plating_tip": "Slide the omelette onto the plate seam-down and place a neat spoon of tomatoes beside it.",
            "servings": 1,
            "nutrition": {"calories": 420, "protein_g": 26, "carbs_g": 9, "fat_g": 31, "fiber_g": 4},
        },
        {
            "fancy_name": "Crispy Rice Cakes, Molten Cheddar Heart, Charred Tomato",
            "plain_name": "cheesy rice patties",
            "menu_description": "Leftover rice reborn as golden cakes with a melting cheddar centre, served with blistered tomatoes.",
            "minutes": 25,
            "difficulty": "Medium",
            "uses": ["leftover rice", "eggs", "cheddar", "tomatoes", "spring onions"],
            "steps": [
                "Mix rice with one beaten egg, chopped spring onion, salt and pepper.",
                "Shape into 4 patties, pressing a cube of cheddar into each centre.",
                "Fry in oil over medium heat for 4 minutes per side until golden.",
                "Halve tomatoes and char cut-side down in the same pan.",
                "Drain the cakes briefly on paper towel.",
            ],
            "plating_tip": "Stack two cakes slightly offset and lean the charred tomatoes against them, cut side up.",
            "servings": 2,
            "nutrition": {"calories": 510, "protein_g": 21, "carbs_g": 58, "fat_g": 21, "fiber_g": 3},
        },
    ]
}
