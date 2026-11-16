# Fridge Chef: hackathon checklist and submission text

## Status
✅ Built: server, iOS app, nutrition and meal log, meal and flavor options, online server on Render, GitHub repo.
The full demo video script is in **[VIDEO_SCRIPT.md](VIDEO_SCRIPT.md)**.

## What's left on the day

| Step | Goal |
|---|---|
| 1 | **Full test run on the iPhone:** photos → review (try a meal type) → menu → recipe → I made it! → share. Also test on cellular. |
| 2 | **Try 3–5 real fridge photos** (a messy one, a near-empty one). Note anything badly missed or invented, and send it to Claude to tune the prompts. |
| 3 | **Prepare for the shoot:** stock the fridge with an easy dish in mind (egg fried rice works well), find a real food-waste statistic and its source, charge both phones, and turn on Do Not Disturb. |
| 4 | **Record** (VIDEO_SCRIPT.md). Wake the server first by opening the app → ⚙︎ → Test connection. Record the app screen and the camera parts separately. Keep the API key off camera. |
| 5 | **Edit** in iMovie or CapCut. Cut loading waits and keep it under 3:00. Keep the before/after shot. |
| 6 | **Submit** with at least 1 hour to spare: video, repo link (make it public in GitHub → Settings → Change visibility if required), the description below, and 3–4 screenshots (Snap, Menu, Recipe, Menu card). |

**After the hackathon:** replace the Anthropic API key. Create a new one in console.anthropic.com, update it in Render → Environment, and delete the old key.

## Project description (150 words)

"Nothing to eat," we say, staring into a full fridge, and the food goes to waste. Fridge Chef takes the week's most ordinary meal, the leftover dinner, and gives it the fine-dining treatment.

Snap your fridge, even a messy one. AI vision finds your ingredients, asks about anything it isn't sure of, and flags what to use first. Tell it what you're craving (dinner or dessert, savory or sweet, how many people) or let the chef decide. You get three dishes made only from what you have, each with an elegant menu name, the plain name ("aka egg fried rice"), steps, a plating tip and calories and macros.

When you've cooked, Fridge Chef makes a shareable "Tonight at [Your Name]'s Kitchen" menu card and logs the meal's nutrition.

Built as a native SwiftUI iPhone app with a FastAPI backend powered by Claude. Less waste, better dinners: elevate the ordinary.

## Short version (50 words)

Fridge Chef turns "nothing to eat" into a restaurant night. Snap your fridge, and AI finds your ingredients and plans three dishes using only what you have, each with a fancy menu name, steps, plating tips and macros. It ends with a shareable menu card. Less waste, better dinners.
