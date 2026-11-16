# Fridge Chef 🍳

*Elevate the ordinary.*

"Nothing to eat," we say, staring into a full fridge. Fridge Chef takes the most ordinary meal of the week, the leftover dinner, and gives it the fine-dining treatment:

1. **Snap** your (messy) fridge, one photo per shelf.
2. **AI finds your ingredients**, asks about anything it isn't sure of, and flags what to **use first** before it goes off.
3. Tell it **what you're making**: the meal, flavor mood, how many people, and a note to the chef. You can also leave it all to the chef.
4. Get **3 dishes made only from what you have** (plus salt, pepper, oil, butter and water). Each has a restaurant-menu name, the honest plain name ("*aka* egg fried rice"), steps, a plating tip and **calories and macros**.
5. Cook it, tap **I made it!**, and get a shareable **"Tonight at [Name]'s Kitchen"** menu card. The meal is added to your **daily nutrition log**.

Ordinary leftovers become a restaurant-worthy meal, and less food goes in the bin.

```
fridge-chef/
├── server/      Python FastAPI server (calls Claude, or Gemini)
├── mobile/      Native iOS app: SwiftUI, open FridgeChef.xcodeproj in Xcode
└── render.yaml  One-click hosting on Render
```

## Features

| Screen | What it does |
|---|---|
| **Snap** | Pick several photos or use the camera. Photos are downscaled before upload. |
| **Review** | Detected ingredients appear as chips, with common extras offered. *"Not sure about these. Is this…?"* questions offer options, *Something else* or *Skip it*. Also: a **Use these first** notice, an *anything else?* box, **meal type** (breakfast, lunch, dinner, snack, dessert), **flavor** (savory, salty, sweet, spicy, fresh & light, comfort food, high protein), **number of people**, a **note to the chef**, and dietary notes. |
| **Menu** | 3 dish cards: fancy name, *aka* plain name, description, time, difficulty, ingredients used, calories and macros. |
| **Recipe** | Steps you can tick off, nutrition per serving (kcal, protein, carbs, fat, fiber), and a plating tip. |
| **Menu card** | An elegant card with your name, shareable as an image, plus today's meal log with total calories and macros. It's saved on the phone only. |

## Quick start

### 1. Get an API key
- **Claude:** https://console.anthropic.com → API Keys → Create Key. Uses `claude-sonnet-5-5`.
- **Gemini (free tier, optional alternative):** https://aistudio.google.com → **Get API key**.

> ⚠️ **Never commit API keys.** Locally, the key goes in `server/.env`, which git ignores. Online, it goes in Render's **Environment** settings. Only `server/.env.example`, which has no keys, is in git. If a key ever leaks, delete it in the console immediately and create a new one.

### 2. Run the server on your Mac (for development)
```bash
cd server
cp .env.example .env      # then paste your key after ANTHROPIC_API_KEY=
./run.sh
```
The first run creates a virtual environment and runs `pip install -r requirements.txt`. The server listens on http://localhost:8000; open http://localhost:8000/docs to try it. With no key set, it runs in **demo mode** with sample answers, and the app shows a DEMO badge.

### 3. Run the iOS app
1. Open `mobile/FridgeChef.xcodeproj` in Xcode.
2. **Simulator:** pick an iPhone and press ▶︎.
3. **Your iPhone:** plug it in, sign in to your Apple ID under Xcode → Settings → Accounts, set **Team** under *Signing & Capabilities*, choose your phone and press ▶︎. If iOS says "Untrusted Developer", go to Settings → General → VPN & Device Management → Trust. With a free Apple ID, reinstall every 7 days.

The app uses the **online server** by default. To use your Mac's server instead, tap ⚙︎ and enter `http://localhost:8000` in the Simulator, or `http://<your Mac's Wi-Fi IP>:8000` on an iPhone on the same Wi-Fi. Clear the box to go back to the default.

## Deploy the server (Render, free)
1. Push this repo to GitHub, making sure `.env` isn't included.
2. Render → **New → Blueprint** → choose the repo. It reads `render.yaml`, which sets the root `server`, the pip install, uvicorn and a health check.
3. When asked for **`ANTHROPIC_API_KEY`**, paste your key. It stays in Render's secret storage.
4. Wait for **Live**, then set the app's default address in `mobile/FridgeChef/AppState.swift` (`defaultServerURL`).

Every push to `main` redeploys automatically. On the free plan the server sleeps after about 15 minutes idle, and the first request after that takes up to a minute.

**Cost protection:** each device is limited to `RATE_LIMIT_PER_HOUR` AI requests (default 40). Also set a monthly spending limit in the Anthropic console.

## How it works

```
iPhone (SwiftUI) ──photos──▶ FastAPI /detect ──▶ Claude vision ──▶ {sure, unsure, use_first}
                 ──choices─▶ FastAPI /recipes ─▶ Claude ─────────▶ {dishes: [...]} ──▶ checked ──▶ app
```

1. **Detect:** Pillow downscales each photo to at most 1568px JPEG, and all photos go to Claude in one request. The prompt explains that fridge photos are messy (hidden, stacked, unlabelled containers), asks it to merge duplicates across photos and ignore non-food items, and to return only `{"sure", "unsure": [{"looks_like", "options"}], "use_first"}`.
2. **Plan:** the recipe prompt includes your ingredients, use-first items, dietary notes, meal type, flavor mood, number of people and your note. It asks for exactly 3 different dishes using *only* those ingredients plus staples, each with a fancy name, plain name, description, minutes, difficulty, ingredients used, 4–7 steps, a plating tip, servings and nutrition per serving.
3. **Check:** the server parses the JSON robustly (strips ```` ```json ```` fences, falls back to the outermost `{...}`) and validates every field. Then it **checks each dish's ingredients against what you have**. If one breaks the rule, it retries once, naming the forbidden items, and drops any dish that still breaks it.
4. **Friendly errors:** every failure comes back as `{"detail": "<plain-English message>"}`, and the app shows it in an alert.
5. **On the phone:** the menu card is rendered with SwiftUI `ImageRenderer` for sharing. The meal log lives in `UserDefaults` (30 days). There's no database and no accounts.

| Endpoint | Input | Output |
|---|---|---|
| `GET /health` | – | `{"ok", "provider"}` |
| `POST /detect` | multipart `photos` (1–8) | `{"sure", "unsure", "use_first"}` |
| `POST /recipes` | `{"ingredients", "use_first", "dietary_notes", "meal_type", "people", "flavors", "guidance"}` | `{"dishes": [...]}` |

*Nutrition values are AI estimates for typical quantities, not lab measurements.*
