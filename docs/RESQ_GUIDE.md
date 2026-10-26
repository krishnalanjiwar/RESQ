# RES-Q — The Complete Guide (for beginners and for judges)

This guide explains everything about RES-Q in plain language: what it is, why it exists, how every part works, how we built it, what is proven and what is not, and how to answer the questions judges usually ask.

Read it top to bottom once. Then use **Part 12 (Judge Q&A)** and **Part 14 (Numbers cheat sheet)** the night before you present.

---

## Contents

1. RES-Q in one minute
2. The problem we are solving
3. Words you need to know (simple glossary)
4. One SOS, start to finish (the story)
5. The app, screen by screen
6. How it works inside
7. Security and trust, explained simply
8. Red Team Hour: attacks and defenses
9. Tech stack and why we chose it
10. How we built it
11. Testing: what is proven and what is not
12. Judge Q&A (by topic)
13. Live demo plan (and backup plan)
14. Numbers cheat sheet
15. Known limitations (say these honestly)
16. Roadmap
17. Where everything lives in the code

---

## 1. RES-Q in one minute

**One sentence:** RES-Q is an Android app that lets people in a disaster call for help and lets nearby volunteers respond, **even when there is no mobile network, no internet and no server**. The message jumps from phone to phone until it reaches someone who can help.

**30-second pitch (say this out loud):**

> In floods and earthquakes, the first thing to fail is the mobile network. People can't call for help, and volunteers nearby don't know who needs them. RES-Q turns every phone into a radio relay. A victim taps SOS, picks "Flood" or "Not breathing", and the message hops phone to phone over Bluetooth and Wi-Fi until it reaches a volunteer with the right skills. The app picks the best-placed volunteer, tells them why in one line, and only moves when a human taps Accept. The victim's phone rings when help accepts and again when help arrives. Messages are signed so they can't be faked, private details are encrypted so relays can't read them, and fake volunteers and fake emergencies are flagged. No towers, no internet, no central server.

**What makes it different (the 4 things to remember):**

1. **No server at all.** Every phone is equal. There is nothing to switch off or hack in the middle.
2. **It decides *who* should go, not just *that* help is needed.** The only doctor is not sent to a scraped knee while someone isn't breathing.
3. **It is built to be attacked.** Fake doctors, fake locations, fake emergencies and battery-drain floods are all defended and demonstrated.
4. **Humans stay in control.** The app recommends; only a person tapping Accept sends anyone.

---

## 2. The problem we are solving

### The real-world situation

- In disasters (floods in Assam/Kerala/Mumbai, earthquakes, cyclones), **cell towers lose power or get destroyed**. Internet goes with them.
- People still have **phones with battery**, and phones still have **Bluetooth and Wi-Fi radios** that can talk to each other directly over short distances, with no tower.
- Help is often **close by**: a neighbour with a boat, a nurse two streets away. The problem is **coordination**, not only rescue capacity.

### What the problem statement asked for (simplified)

We tracked 15 requirements (C1–C15). In simple words:

| # | What they asked | How RES-Q answers it |
|---|---|---|
| C1 | Fully decentralized, phone-to-phone only, no server | Phones talk directly (Google Nearby Connections over Bluetooth/Wi-Fi); messages hop between phones |
| C2 | Accept messy, untrusted input ("Need insulin for dad, ground floor flooded", bad GPS, 12% battery) | That exact sentence is a test case. GPS carries accuracy and age. Battery is reported and also read locally |
| C3 | Stop one phone pretending to be 40 nurses (Sybil attack) | Many identities from one radio link are flagged; real credentials need an authority's signature |
| C4 | Stop fake locations | Location is checked against how many hops it travelled, how fast it "moved", and other reports |
| C5 | Spot fake emergencies (decoys) | Each SOS gets a probability of being real; decoys are **flagged, never silently deleted** |
| C6 | Understand skills in any wording, including Hinglish ("boat hai", "can do dialysis") | Rules + Hinglish/Hindi word lists + spelling-tolerant matching; unclear text goes to human review |
| C7 | Privacy, even through untrusted relays | Relays see only a tiny routing header; text, exact location and health data are encrypted |
| C8 | Don't waste the only medic on a minor case | A "scarcity-weighted" matcher that runs the same way on every phone |
| C9 | Avoid the bystander effect ("someone else will go") | Each request is offered to **one specific best person**, then rolls over to the next if they don't answer |
| C10 | Humans accept, with a one-line reason | Every offer shows a one-line justification. Only Accept moves anyone |
| C11 | Network splits into islands, then rejoins | Event-log merge: duplicates are told to stand down, someone already at the door is never cancelled |
| C12 | Red Team Hour: forged credentials, battery drain, luring responders into floodwater | An attack button for each, a defense for each, and an automated test for each |
| C13 | A fixed 5-step evaluation chain | Claim Verification → Hazard Avoidance → Trust Scoring → Battery/Routing Cost → Safe Dispatch |
| C14 | Real battery and device topology | Real battery readings, battery-aware relaying, live neighbour view, per-peer rate limits |
| C15 | It must be a real installable app | A real Android APK at every phase |

---

## 3. Words you need to know (simple glossary)

| Word | Simple meaning | Example in RES-Q |
|---|---|---|
| **Mesh network** | Devices pass messages to each other like people passing a note down a row | Phone A → B → C → responder |
| **Peer-to-peer (P2P)** | Devices talk directly, no server in the middle | Every RES-Q phone is equal |
| **Node** | One device in the network | Each phone running RES-Q |
| **Relay** | A phone that forwards a message it isn't the target of | Your phone forwards a stranger's SOS |
| **Hop** | One jump from one phone to the next | A → B is 1 hop, A → B → C is 2 hops |
| **TTL (time to live)** | How many more hops a message may take | Starts at 8; each relay lowers it by 1 |
| **Store-and-forward** | Keep a message and pass it on when you later meet someone | You walk from one street to another and carry SOS messages with you |
| **Beacon** | A small "I'm here" message every phone sends regularly | Role, skills, battery, rough location |
| **Envelope** | The standard wrapper around every message | ID, type, sender, time, expiry, TTL, hop, body, signature |
| **Private key / public key** | A secret only you have, and a matching code you can share with everyone | Your phone's identity is its public key |
| **Digital signature** | Proof that a message really came from the owner of a key and wasn't changed | Every RES-Q message is signed (Ed25519) |
| **Encryption** | Scrambling data so only the right person can read it | SOS details and the medical card |
| **Sealed box** | A message encrypted so only specific recipients can open it | Medical card sealed to the volunteer who accepted |
| **Sybil attack** | One attacker pretending to be many people | "One phone pretending to be 40 nurses" |
| **Trust anchor** | An authority whose key everyone agrees to trust | A hospital or NDRF key |
| **Credential** | A signed statement from an authority: "this person is a nurse" | Shown as "Verified by …" |
| **Fingerprint** | A short code of a key that two people compare in person | `A1B2-C3D4-E5F6-0718` |
| **Triage** | Deciding how urgent something is | SOS-A (life-threatening) to SOS-D (minor) |
| **Deterministic** | Same input always gives the same output | Every phone computes the same match, so they agree without talking to a server |
| **Partition / island** | Part of the network cut off from the rest | Two neighbourhoods separated by floodwater |
| **Reconciliation** | Cleaning up when islands reconnect | Two volunteers went to the same person; one is told to stand down |
| **Lamport clock** | A counter that orders events without trusting phone clocks | Used to order Accept / On the way / On scene |
| **Heartbeat** | "I'm still on it" message from a responder | Every 2 minutes while helping |
| **Orphan** | A request whose volunteer went silent | Reopened after 10 minutes with no heartbeat |
| **Decoy** | A fake emergency meant to waste or trap rescuers | Flagged "could be a decoy" |
| **APK** | The Android app install file | `resq-0.13.0-b7-arm64-v8a-release.apk` |

---

## 4. One SOS, start to finish (the story)

Follow Priya (victim) and Arjun (a nurse volunteer). There is no network. Between them are two strangers' phones running RES-Q.

**Step 1 — Priya opens the app.** The dashboard shows a big red **I need help** button. She taps it.

**Step 2 — She describes the emergency in one tap.** She taps **Not breathing** (her father collapsed). She doesn't need to type. The app reads it as **SOS-A · Life-threatening**. If she taps nothing and types nothing, the SOS still goes; it's just marked "unclear".

**Step 3 — She taps SOS.** The phone:
- builds a message ("envelope") with a random ID, her identity, the time, an expiry (24 hours), TTL 8, and the body;
- **signs** it with her private key so nobody can fake or edit it;
- if verified responders are known nearby, **encrypts** the details to them; otherwise she chooses to share openly (default) or send only "type of help + rough area";
- saves it on the phone first (it's never shown as "sent" until it really left);
- sends it to every phone it's connected to.

**Step 4 — Strangers' phones relay it.** Each relay:
- checks the size, format and time limits (hostile input is rejected early);
- checks the signature (fake or edited messages are dropped and the sender is counted);
- drops duplicates it has already seen;
- lowers TTL by 1, raises hop by 1, and passes it on.
Relays can't read encrypted details. They only see a tiny header: message type, urgency class and a rough area.

**Step 5 — Arjun's phone receives it.** His phone runs the **5-stage evaluation chain** for this SOS and every nearby volunteer, and the **matcher** decides Arjun is the best person (he's a nurse, close, has battery, no hazard in the way). Every phone computes the **same** answer from the same data, so no server is needed to decide.

**Step 6 — Arjun's phone rings.** An alarm keeps ringing until he answers. He sees "SOS-A · Medical — RESPOND NOW", one line explaining why he was picked, the location (tap → opens Google Maps), and a 60-second window. If he doesn't answer in 60 seconds, it moves on to the next best volunteer. **The app never accepts for him.**

**Step 7 — He taps Accept.** His phone sends a signed "accepted" event. It hops back to Priya.

**Step 8 — Priya's phone rings: "HELP IS COMING".** She sees **"Medical volunteer · Arjun, verified by …"** (or "self-declared" if he has no credential). Her phone automatically sends Arjun her **medical card** (blood group, allergies, medicines), **encrypted so only Arjun can read it**. The relays carry it but cannot open it.

**Step 9 — Arjun heads over.** He taps **On the way**. Every 2 minutes his phone sends a heartbeat so others know he's still coming. Every 15 seconds it checks his GPS.

**Step 10 — He arrives.** When his GPS is within about 30–100 m of Priya, the app marks him **ON SCENE** automatically. His phone says "YOU HAVE ARRIVED"; Priya's phone rings "YOUR VOLUNTEER HAS ARRIVED".

**What if things go wrong?**
- *Arjun's phone dies on the way?* No heartbeat for 10 minutes → the request reopens and goes to the next volunteer.
- *Two volunteers in two cut-off islands both accepted?* When the islands reconnect, the later one is told to **stand down**. Anyone already **on scene is never cancelled**.
- *Someone faked the SOS?* It's scored for how likely it is to be real; low scores are shown as "could be a decoy — check before taking risks".

---

## 5. The app, screen by screen

### 5.1 Dashboard (first screen) — Google-style white
- **Hero:** animated logo with four-colour signal rings, the rainbow R-E-S-Q name, "Emergency help, even when the network is down.", three badges (Works offline, Verified responders, Private by design).
- **Attention banners** (pulsing) at the top if you have an active SOS or are helping someone.
- **Tiles:** I need help (big red), I can help, Medical card, Test and train.
- Android Back on this screen exits the app.

### 5.2 Get help (victim)
- Mesh status bar (is the mesh on? how many phones nearby?).
- Big pulsing **SOS** button.
- **Quick picks** (one tap, custom icons): Fire, Flood, Earthquake, Trapped, Injured, Not breathing, Gas leak, Stranded, Food & water, Child / elderly.
- Optional text box ("What is happening?"), any language.
- **How RES-Q reads this:** shows the SOS class and needs. "Rule-based reading, not a medical diagnosis."
- Share my location (on/off), privacy options, medical card shortcut, report a danger.
- **Your requests:** progress timeline (Saved → Sent → Received → Accepted → On the way → On scene), "Who is coming" (profession, verified or not, their location), tap-to-open map, cancel.

### 5.3 Respond (volunteer)
- Availability switch and your skills.
- **Matched to you:** offers sorted most critical first, ringing until you answer, "Why you were matched" (all 5 chain stages with scores), Accept / Decline / Silence.
- **Your assignments:** On the way / On scene / Resolved buttons, the victim's **medical card**, tap-to-open map, "you'll be marked on scene automatically when you arrive", stand-down notices.
- **Other open requests:** you can volunteer for anything (with a warning if someone better was matched).

### 5.4 Medical card
Blood group, conditions, allergies, medicines, emergency contact, notes. Stored encrypted on the phone. Sent only to a volunteer who accepts.

### 5.5 Test and train (diagnostics)
- **Simulator:** builds a virtual city of real RES-Q nodes on one phone. Buttons: Build simulated city, Run / Step / Pause, Report flood, Send SOS, Split & double dispatch, Heal network split, the five Red Team attacks, Relays to 10% battery, and Results.
- **This phone:** nearby phones, trust, message counts, battery mode.
- **Trust:** your fingerprint, pin an authority in person, issue/revoke demo credentials, vouch.

### 5.6 Everywhere
- **Home** button and **Back** on every page. Back closes the top page; on a role page it goes to the dashboard.
- **Status drawer** (top-right): mesh, permissions, battery, security status.

---

## 6. How it works inside

Think of RES-Q as **layers**, each with one job:

```
 UI (screens)                lib/features, lib/ui
 App runtime (alarms, GPS)   lib/app
 Node (the phone's brain)    lib/node
 Domain (decisions)          lib/domain  — triage, chain, matcher, trust, reconcile, power
 Protocol (message rules)    lib/protocol
 Crypto (keys, signing)      lib/crypto
 Mesh (radio)                lib/mesh
 Storage                     lib/data
 Android native (Kotlin)     android/app/src/main/kotlin — foreground service, alarm, maps, tones
```

### 6.1 The radio (mesh layer)
- Uses **Google Nearby Connections** (package `nearby_connections`), which automatically uses **Bluetooth, Bluetooth Low Energy and Wi-Fi** to connect phones directly.
- Strategy **P2P_CLUSTER**: many-to-many connections (a true mesh, not a star).
- Each phone keeps up to **6 neighbours**.
- When a new neighbour connects, the phone **replays what it knows** (up to 200 messages, most urgent first; 50 in low battery). That's how messages cross gaps and how separated islands heal.
- A **foreground service** keeps relaying with the screen off (Android shows a "RES-Q mesh active" notification).
- There is also a **simulated radio** used by the simulator and tests, so all the logic can be tested without phones.

### 6.2 The protocol (message rules)
Every message is an **envelope**:

| Field | Meaning |
|---|---|
| `v` | Protocol version (1) |
| `id` | Random unique message ID |
| `t` | Type: hello, ack, beacon, sos, event, hazard, credential, revocation, vouch |
| `o` | Origin: the sender's public key (their identity) |
| `ts`, `exp` | Created time and expiry |
| `ttl`, `hop` | Hops left and hops taken (**not signed**, because relays change them) |
| `gh`, `urg` | Optional rough area (geohash) and urgency, so relays can prioritise without reading the body |
| `b` | Body (may be encrypted) |
| `sig` | Ed25519 signature over everything except ttl/hop |

**Safety limits on every incoming message:** max 16 KB, max nesting depth 8, max lifetime per type (SOS 24 h, beacon 5 min…), not more than 30 minutes in the future, TTL capped at 8, and (new) **hop + TTL can never exceed 8**, because honest relays only move one from TTL to hop each time. A bigger claim is a forgery.

**Message types in plain words:**
- **hello / ack** — "this radio link is me" / "I got your message" (never relayed)
- **beacon** — "I'm here, this is my role, skills, battery, rough location"
- **sos** — the emergency
- **event** — a change on an SOS: accepted, on the way, on scene, resolved, declined, stand down, heartbeat, cancelled, medical card
- **hazard** — "flood / fire / collapse here, this big"
- **credential / revocation / vouch** — trust messages

### 6.3 Triage (how urgent is it?)
- **Rules, not AI.** Word lists in English, Hinglish and Hindi (e.g. "saans nahi aa rahi" = can't breathe, "aag lagi" = fire, "baadh" = flood).
- **Spelling-tolerant**: long words (6+ letters) match even with small typos (Levenshtein distance).
- Result: urgency + needs (medical, water rescue, fire, trapped, evacuation, supplies, shelter).
- **Severity classes:** **SOS-A** life-threatening, **SOS-B** urgent, **SOS-C** unclear (check), **SOS-D** minor.
- **Unclear is never treated as minor.** SOS-C ranks above SOS-D, and goes to human review.
- The **receiver re-does triage** from the text; the sender's label is only a claim.

### 6.4 Skills (what can a volunteer do?)
Volunteers type freely: "staff nurse, boat hai, can swim". The parser maps it to skills: doctor/nurse, first aid, boat, water rescue, swimmer, firefighting, search & rescue, vehicle, lifting/stretcher, supplies, shelter, security/police, general help. Unrecognised text becomes "general help" for humans to judge.

### 6.5 The evaluation chain (5 stages, fixed order)
For **every SOS × every volunteer**, each phone computes:

1. **Claim Verification** — Is this SOS likely real (P(real)) and is its location believable (P(location))? Uses corroboration from other people within 600 m and 45 minutes, sender trust, identity age, hop-distance plausibility (300 m per hop, generous), and speed checks (no jumping faster than ~145 km/h). Below 0.35 = "suspected decoy" (shown, never hidden).
2. **Hazard Avoidance** — Are there reported floods/fires/collapses at the target or in the way? Reports from independent people are combined and fade over time (half-life 1 hour). A confident hazard (≥ 0.6) **blocks** volunteers who lack the needed equipment (e.g. no boat for a flood).
3. **Trust Scoring** — How much do we trust this volunteer's skills? Verified credential > vouched > self-declared. Sybil signs and penalties lower it.
4. **Battery / Routing Cost** — Distance and battery: don't send someone at 5% battery 3 km away if someone closer can go.
5. **Safe Dispatch** — Combine everything into a final score and a yes/no, with reason codes.

Each stage shows a score and reasons in **"Why you were matched"**.

### 6.6 The matcher (who goes where?)
- Sort open SOS by **urgency × probability it's real**, most important first.
- For each SOS, score each available volunteer with the chain.
- **Scarcity penalty (opportunity cost):** if a volunteer has a **rare skill that isn't needed here**, their score for this SOS is lowered (15% × how scarce the skill is, max 60%). So the only doctor is saved for the medical emergency.
- Each volunteer gets **at most one** assignment. Ties are broken by ID so **every phone gets the same answer**.
- Each phone then **only offers what is assigned to itself.** That beats the bystander effect: a specific person is asked, not "everyone".
- **Offer window: 60 seconds.** If unanswered it rolls to the next candidate. The app **never** accepts on anyone's behalf.

### 6.7 Partition reconciliation (when islands rejoin)
- All SOS events are kept as a log and ordered by **Lamport clock** (a counter), not by phone clocks (which can be wrong).
- **Precedence:** ON SCENE > ON THE WAY > ACCEPTED.
- If two volunteers hold the same SOS, the lower-precedence one gets **"Stand down — another responder has precedence"**.
- **Nobody on scene is ever cancelled** ("never cancel a responder at the door"). If two are on scene, both stay and it's shown as a conflict.
- **Heartbeats** every 2 minutes. No activity for **10 minutes** → the volunteer is treated as lost (orphan) and the SOS **reopens**.
- Only the requester can cancel their own SOS.

### 6.8 Battery-aware behaviour
| Battery | Mode | Beacon every | What gets relayed |
|---|---|---|---|
| > 20% | Normal | 60 s | Everything |
| ≤ 20% | Low | 180 s | No beacons; SOS except "low"; all events |
| ≤ 8% | Critical | 300 s | Only critical/unclear SOS, events and revocations |

### 6.9 Alerts (alarm, arrival)
- **Volunteer:** a matched request rings like an alarm (repeats) until Accept, Decline, Silence, or the offer moves on.
- **Victim:** rings when help accepts, and again when help arrives.
- Every alarm **stops by itself after 3 minutes** (battery safety).
- **Arrival detection:** while on the way, GPS is checked every 15 s. Within **30 m + GPS error, max 100 m** of the victim → automatically marked ON SCENE, both sides alerted. Done once only.
- Uses Android's "insistent" notification flag and the alarm sound. It does **not** bypass Do Not Disturb.

### 6.10 Medical card
- Saved in the app's **encrypted database** on the phone.
- When a volunteer accepts, it's **sealed to that volunteer's key only** and sent as an event. Relays carry an unreadable blob.
- Fields are length-limited; blood group must be one of the 8 valid values.

### 6.11 Maps
Tap any coordinates → opens **Google Maps** at that spot (works with offline maps downloaded in Google Maps). Falls back to any map app, then the web link, then copies the coordinates.

### 6.12 Storage
- **Hive CE** database, **AES-encrypted**. The database key is kept in Android's secure keystore.
- Identity keys are kept in **flutter_secure_storage** (backed by the Android Keystore), never in the database.
- Android backup is **disabled**, so keys and data don't leak into cloud backups.

---

## 7. Security and trust, explained simply

### 7.1 Identity
- On first launch, each phone creates **two key pairs**:
  - **Ed25519** for signing (this public key *is* your identity),
  - **X25519** for others to encrypt things to you.
- No username or password. Your identity is your key, and its **fingerprint** (like `A1B2-C3D4-E5F6-0718`) can be compared in person.

### 7.2 Why messages can't be faked
Every message is signed. If anyone changes even one letter, the signature check fails and the message is dropped. A link that sends 3 bad signatures gets its identities penalised.

### 7.3 How private details stay private
- We use the **same design as the well-known `age` encryption tool**: a random key encrypts the message once; that key is then wrapped separately for each recipient using X25519 + HKDF-SHA256, and everything uses **XChaCha20-Poly1305**.
- Recipients aren't named inside, so relays don't learn who can read it (only how many, up to 8).
- The encryption is **bound to the message ID**, so an attacker can't cut it out and paste it into another message.
- All primitives come from the established `cryptography` library. **We did not invent our own encryption algorithms.** The way we combined them still needs an independent review before any real-world claim. Say this honestly.

### 7.4 How we know a doctor is really a doctor
- An **authority** (hospital, NDRF, NGO) has its own key. Phones **pin** that authority, either pre-installed or by comparing fingerprints in person.
- The authority **signs a credential**: "this key is a nurse, valid until …".
- Others check the signature against pinned authorities: **verified**, **unknown issuer**, **expired**, **revoked** or **forged**.
- A **forged** credential = instant quarantine.
- **Vouching:** people can vouch for someone they know in person. At most 3 vouches count, and vouches from penalised identities are ignored. A vouch raises trust to "vouched", which is still below "verified".
- Without any of this, skills are shown as **self-declared** and get lower trust. In a disaster, self-declared helpers still matter; they're just ranked lower.

### 7.5 Sybil defense (one phone pretending to be many)
- **Per radio link:** if 3+ different identities send *their own* messages through one physical link, they are collapsed and marked suspicious (trust × 0.2).
- **Cluster check:** 4+ brand-new, unverified identities with identical skills, within 25 m, through the same neighbour → suspicious (trust × 0.4).
- **Forged hop counts** (pretending to be a relay) are bounded by the hop + TTL rule.
- In tests, fake nurses are **never dispatched**, including when the attacker forges hop counts and spreads fake locations.
- Honest limit: a smart attacker who fakes hops *and* spreads locations can avoid the **"suspicious" label**, but the fakes still lose to real responders because they're unverified. The real fix is the planned **RES-Q ID** (phone-verified ID + hardware attestation).

### 7.6 Flood / battery-drain defense
- Per link: max **8 messages/second**, burst of 260; repeated abuse (60 strikes) → link **quarantined for 10 minutes**.
- Per sender: max **6 SOS** and **40 events per 10 minutes** relayed.
- Duplicates are dropped before signature checks, so replays are cheap to ignore.

---

## 8. Red Team Hour: attacks and defenses

Each attack is a button in **Test and train → Simulator**, and each has an automated test.

| Attack | What the attacker does | Defense | Measured result |
|---|---|---|---|
| **Sybil: 40 fake nurses** | One phone broadcasts 40 nurse identities | Link collapse + cluster check + low trust for unverified | All flagged suspicious; **0 dispatches** to fakes |
| **Sybil with forged hops** | Same, but pretends to be a relay | Hop/TTL bound; unverified trust | **0 dispatches** to fakes |
| **Forged medical credential** | Claims a hospital signed their "doctor" credential | Signature check against pinned authority | Detected as forged, **quarantined** |
| **Spoofed location** | SOS claims to be 5 km away but arrived in 1 hop | Hop-distance plausibility | Flagged **LOCATION_IMPLAUSIBLE** |
| **Flood lure** | Fake SOS inside rising floodwater to trap rescuers | Hazard gate: high-confidence flood blocks responders without a boat/water skills | Unequipped responders **never sent** |
| **Battery-drain flood** | Spams frames to drain phones | Per-link rate limit + quarantine | Link **quarantined** |
| **Partition double-dispatch** | Two islands each send someone; then they merge | Lamport-ordered merge, precedence, stand-down | Converges; **on-scene never cancelled** |
| **Decoy emergency** | Fake SOS nobody corroborates | P(real) score | Shown as "could be a decoy", **not deleted** |

---

## 9. Tech stack and why we chose it

| Technology | What it does here | Why |
|---|---|---|
| **Flutter + Dart** | The whole app | One codebase, fast UI, good Android support, strong typing |
| **Kotlin (Android native)** | Foreground service, alarm notification, map opening, UI tones | Things Flutter can't do alone reliably |
| **nearby_connections** (Google Nearby) | Phone-to-phone radio | Handles Bluetooth/BLE/Wi-Fi automatically; no internet needed |
| **cryptography** | Ed25519, X25519, HKDF, XChaCha20-Poly1305 | Established, audited-style primitives; no home-made crypto |
| **flutter_secure_storage** | Keeps private keys in the Android Keystore | Keys never sit in plain files |
| **Hive CE** | Local encrypted database | Fast, offline, AES encryption built in |
| **Riverpod** | App state management | Clean separation between logic and screens |
| **geolocator** | GPS | Accuracy + timestamp for each fix |
| **battery_plus** | Battery level | Battery-aware relaying |
| **permission_handler** | Runtime permissions | Asked only when you turn the mesh on |
| **flutter_svg** | Custom SVG icons and logo | No emoji, consistent look |

**Why not a backend/server?** Because in a disaster the server (or the internet to reach it) is exactly what's missing. A server is also a single point of failure and a single target.

**Why not AI/LLM for triage?** It must run offline on cheap phones, be predictable, explainable and testable. Rules give the same answer every time and can explain why. (An on-device model is a possible future add-on only for text the rules don't understand.)

---

## 10. How we built it

### 10.1 Process
1. **PRD** (product requirements) with safety, honesty and security rules — `docs/PRD.md`.
2. **Architecture** and **7 decision records (ADRs)** — transport, crypto, reconciliation, triage, permissions/power, retention/privacy, UI — `docs/architecture/`.
3. **Phased plan with gates** — `docs/MVP_PHASES.md`. No phase starts without written owner approval.
4. Build phase by phase, with **automated tests** and an **APK at each gate**.
5. Code reviews and red-team passes; issues fixed with regression tests (e.g. "resolve all 23 issues from the code review").

### 10.2 Phases
| Phase | What was built |
|---|---|
| 0 | Foundation, decisions, first APK, radio spike |
| 1 | Protocol core (envelopes, signatures, limits) and the multi-node simulator |
| 2 | Victim/volunteer flows, triage, skill parsing |
| 3 | Real phone-to-phone mesh (Nearby), foreground service |
| 4 | Identity, trust anchors, Sybil defense, privacy (sealing) |
| 5 | The 5-stage evaluation chain and the distributed matcher |
| 6 | Partition reconciliation |
| 7 | Red Team Hour and diagnostics |
| 8 | Hardening, release APK, demo |
| 9 | Dashboard + Home/Back, ringing alerts, medical card, SOS-A–D, volunteer profession, new design |
| 9.1 | Tap-to-open Google Maps, SOS quick picks, SOS without text, automatic arrival alerts (a brutalist dashboard was tried and reverted to the Google style in 0.13.1) |

### 10.3 If a judge asks "Did you use AI?"
Be honest. A good answer:
> "Yes. We used AI coding assistants (Claude Code) to write a lot of the code, the way teams use any productivity tool. We wrote the requirements, chose the architecture, set the safety rules, made every design decision, and reviewed and tested the results phase by phase. The app itself uses no AI at runtime; triage is rule-based so it's predictable and works offline."

Then show you understand the system (this guide). Judges care that **you** understand the decisions.

### 10.4 Size
About **10,300 lines** of Dart app code, **1,200 lines** of tests (95 tests), plus Kotlin for Android, and about 8 design documents.

---

## 11. Testing: what is proven and what is not

### Proven by automated tests (95 tests, all passing)
- Messages: signing, tamper detection, size/depth/time limits, forged hop counts rejected.
- Encryption: sealed SOS and medical card readable only by the intended responder; a relay can't read it.
- Triage: the exact "Need insulin for dad, ground floor flooded" case and Hinglish examples.
- Matching: scarcity (don't waste the only medic), sealed SOS never offered to unverified responders, no self-matching.
- End-to-end on the simulator: SOS crosses multiple hops, a responder accepts.
- All Red Team attacks with measured outcomes.
- Reconciliation after islands merge.
- Automatic arrival: not at 400 m, yes at 20 m, only once.
- UI: every screen renders, Home/Back work everywhere, no overflow on a small phone with large text.

### Not yet proven (say this honestly)
- **Never tested on two real phones yet.** Real radio range, connection time and relay reliability are unmeasured.
- Real **battery drain** of continuous relaying is unmeasured.
- Alarm, maps opening and tones on real devices.
- Behaviour with many phones (dozens or hundreds).
- Independent review of the encryption composition.
- Release signing key (current APKs use a test key).

---

## 12. Judge Q&A (by topic)

### A. Concept and impact

**Q: What problem does this solve, in one line?**
A: Calling for and coordinating help when there's no mobile network or internet, by making phones relay to each other.

**Q: Who are the users?**
A: People in disaster zones (victims), local volunteers and trained responders (nurses, boat owners, police, NDRF), and authorities who vouch for responders.

**Q: Why would people have the app installed during a disaster?**
A: It must be installed beforehand, like a first-aid kit: through NGOs, NDRF/SDRF drills, schools, and pre-installation on partner phones. It's also small (≈20 MB), so it can be shared phone to phone offline (Android "nearby share") during an event. This adoption problem is real and every offline app faces it.

**Q: How is this different from WhatsApp, Bridgefy, Briar, FireChat or Zello?**
A: Those mostly move messages. RES-Q decides **who should go**: triage, skills matching, scarcity (don't waste the only doctor), hazard avoidance, fake-responder and decoy detection, and partition clean-up, with human accept. Zello/WhatsApp need internet. Bridgefy/Briar/FireChat are mesh chat, not dispatch.

**Q: Why not just use SMS or satellite?**
A: SMS needs towers. Satellite phones are rare and expensive. Most people already have a smartphone.

**Q: Does it replace 112 / emergency services?**
A: No. It's an auxiliary tool and says so on the first screen. If the network works, people should call official services.

### B. Networking

**Q: How do phones talk without internet?**
A: Google Nearby Connections uses Bluetooth, Bluetooth Low Energy and Wi-Fi to connect phones directly. No tower or router.

**Q: What's the range?**
A: Roughly tens of metres on Bluetooth and more on Wi-Fi, depending on walls and phones. We haven't measured it on our phones yet. The mesh extends range: every hop adds another phone's range, up to 8 hops.

**Q: What if there's no phone in between?**
A: Store-and-forward: the message waits and is sent when any phone comes in range, for example someone walking past.

**Q: How do you stop messages bouncing around forever?**
A: TTL (max 8 hops), an expiry time, and every phone remembers message IDs it has seen and drops duplicates.

**Q: How many connections per phone?**
A: Up to 6 neighbours, many-to-many (P2P_CLUSTER).

**Q: Does it work with the screen off?**
A: Yes, through an Android foreground service (persistent notification).

**Q: What about iPhones?**
A: Android only for now. Nearby Connections on iOS has limits, so iOS is future work.

**Q: How does it scale to thousands of phones?**
A: Each phone only talks to neighbours, limits are per link and per sender, and low-battery phones relay less. But flooding-style relaying has limits at very large scale; we haven't tested beyond the simulator. Next steps would be smarter routing (geographic forwarding) and testing at scale.

### C. Triage and matching

**Q: How do you know how urgent an SOS is?**
A: Rules over keywords in English, Hinglish and Hindi, tolerant to typos. "Not breathing" → SOS-A. Anything we can't understand is SOS-C (unclear), ranked above minor, and goes to human review.

**Q: Why not use an AI model?**
A: It must work offline on cheap phones, be predictable, explainable and testable. Rules give the same result every time with a reason.

**Q: What if someone writes in another language?**
A: Unrecognised text is still sent and marked unclear for human review. Nothing is dropped. Adding languages is adding word lists.

**Q: How does it choose which volunteer?**
A: A 5-stage chain scores each volunteer for each SOS (is the SOS real, hazards, trust, distance/battery, final decision). Then the matcher handles the most urgent SOS first and adds a penalty for using a rare skill that isn't needed, so the only doctor isn't spent on a minor case.

**Q: Who decides — the app or a server?**
A: Every phone runs the same deterministic calculation on the same shared data, so they agree without a server. Each phone only offers the request assigned to its own user.

**Q: What if two phones have different data and disagree?**
A: They may briefly, but the plan is recomputed as data arrives, and duplicates are cleaned up by reconciliation (stand-down). Nobody on scene is cancelled.

**Q: What's the bystander effect and how do you fix it?**
A: When everyone sees a request, everyone assumes someone else will go. We offer it to one specific best person with a 60-second window, then the next.

**Q: Does the app ever send someone automatically?**
A: Never. Only a human tapping Accept moves anyone. Arrival is the only automatic status, and it's based on the volunteer's own GPS.

### D. Security and privacy

**Q: Can someone fake an SOS or edit one?**
A: Editing breaks the signature, so it's dropped. Creating a fake SOS is possible (anyone can ask for help), but it's scored for how likely it is to be real and flagged as a possible decoy if nothing corroborates it.

**Q: Can someone pretend to be a doctor?**
A: They can *claim* it, but it shows as "self-declared". "Verified" needs a credential signed by a trusted authority. A forged credential is detected and quarantined.

**Q: Who are the authorities and how do phones trust them?**
A: Hospitals, NDRF, NGOs. Their public keys are pre-installed or pinned in person after comparing fingerprints. In the demo we use a mock authority, clearly labelled.

**Q: Can relays read my medical information?**
A: No. Details and the medical card are encrypted to the specific responder. Relays see only type, urgency class and a rough (~5 km) area.

**Q: What is visible to everyone?**
A: Message type, a rough geohash area, the urgency class, and the sender's public key. That's a deliberate trade-off so relays can prioritise. If the victim chooses "share openly" (when no verified responder is known), nearby phones can read the text. They choose this.

**Q: Did you write your own encryption?**
A: No. We use standard primitives from an established library (Ed25519, X25519, HKDF-SHA256, XChaCha20-Poly1305) in the same pattern as the `age` tool. The composition still needs an independent security review.

**Q: Where are the keys stored?**
A: In the Android Keystore through secure storage. The local database is AES-encrypted. Backups are disabled.

**Q: What if a phone is stolen?**
A: Today the thief could act as that user. The planned RES-Q ID adds an app lock (fingerprint/PIN) and key revocation.

**Q: What is a Sybil attack and how do you handle it?**
A: One attacker pretending to be many people. We flag many identities on one radio link, flag clusters of new identical identities, bound forged hop counts, and give unverified identities low trust. In tests, 40 fake nurses got zero dispatches.

**Q: Can an attacker drain everyone's battery by spamming?**
A: Rate limits per link and per sender; abusive links are quarantined for 10 minutes. Demonstrated in Red Team Hour.

**Q: Can an attacker lure rescuers into danger?**
A: Hazard reports from independent people are combined. A confident flood/fire hazard blocks responders who lack the right equipment. The flood-lure attack is tested.

### E. Safety and ethics

**Q: What if the app is wrong about urgency?**
A: It says "rule-based reading, not a medical diagnosis". Unclear cases are never downgraded. Responders see the original text and decide.

**Q: What if two volunteers go to the same person?**
A: When their phones exchange data, the lower-precedence one is told to stand down. Someone already on scene is never cancelled.

**Q: What if the volunteer disappears?**
A: No heartbeat for 10 minutes → the request reopens and goes to someone else, and the victim sees "your responder lost contact".

**Q: Is location data safe?**
A: Exact location is only inside the encrypted body. Location sharing is a switch the victim controls.

**Q: Could the arrival auto-mark be wrong?**
A: It needs a fresh GPS fix (under 2 minutes old) within 30 m + GPS error, capped at 100 m, so a bad fix can't fake an arrival from far away. It's a status only; it doesn't dispatch or cancel anyone.

### F. Battery and devices

**Q: Won't this kill the battery?**
A: It adapts: below 20% it stops relaying beacons and minor SOS; below 8% it only relays critical messages. Real-world battery use is not measured yet; that's on the test plan.

**Q: What Android versions?**
A: Modern Android, with the right permission sets for Android 12+ (Bluetooth) and 13+ (nearby Wi-Fi, notifications).

**Q: Why so many permissions?**
A: Nearby Connections needs Bluetooth, Wi-Fi and (on older Android) location to discover phones. They're only requested when you turn the mesh on, never silently.

### G. Engineering

**Q: How did you test it without many phones?**
A: A simulator runs many real RES-Q nodes over a simulated radio, so every rule (relay, matching, attacks, partitions) is tested automatically. Real-phone testing is the next step.

**Q: What's the hardest part?**
A: Making many phones agree on who goes where without a server, while assuming some phones are lying.

**Q: What would you do with more time?**
A: Real two-phone and multi-phone field tests, independent crypto review, the RES-Q ID (verified phone number + hardware-backed device key), smarter offline routing around hazards, iOS.

**Q: What's the weakest part right now?**
A: It hasn't been field-tested on real phones, and the main node class is large and should be split.

### H. Business and deployment

**Q: How would this be deployed?**
A: Through disaster agencies (NDRF/SDRF), NGOs, hospitals (who issue credentials), and community drills. Pre-install before the monsoon season in flood-prone districts.

**Q: How do you make money / sustain it?**
A: Public-good model: government and NGO partnerships, CSR funding, and paid deployments or training for agencies. The core stays free for citizens.

**Q: Is there any server at all?**
A: Not for emergencies. (The planned RES-Q ID would use a small signup server only in normal times, never during a disaster.)

### I. "What if…" scenarios

| Scenario | What happens |
|---|---|
| Victim has no text, just taps SOS | It sends as SOS-C ("help needed, no details"), above minor requests |
| Victim has no GPS | SOS sends with "location not provided"; responders see that; rough area if available |
| GPS is bad (±500 m) | Shown with its accuracy; plausibility lowered; label "low accuracy" |
| No volunteer nearby | SOS waits and is forwarded when phones meet; victim sees "Waiting for a nearby phone" |
| Volunteer doesn't answer | After 60 s it's offered to the next best person |
| Volunteer declines | Moves to the next person immediately |
| Two SOS, one doctor | Doctor goes to the most urgent; the scarcity penalty protects the doctor for medical cases |
| Network splits into two islands | Each island works on its own; on merge, duplicates stand down, on-scene kept |
| Phone clock is wrong | Ordering uses Lamport counters; clocks are only claims; a warning appears if your clock looks off |
| Attacker floods messages | Link rate-limited and quarantined |
| Fake doctor | "Self-declared", lower trust; forged credential → quarantined |
| Fake location | Flagged if implausible for its hop count or speed |
| Flood between volunteer and victim | Hazard check warns or blocks unequipped volunteers |
| Battery at 5% | Critical mode: relays only critical messages |
| Victim cancels | Only the victim can cancel; responders are told |
| Volunteer arrives | Auto ON SCENE by GPS; both phones alerted |

---

## 13. Live demo plan (and backup plan)

### With two phones (best)
1. Both phones: install APK, open, turn mesh on, allow permissions. **Airplane mode on, then turn Bluetooth and Wi-Fi back on** to prove there's no internet.
2. Phone B: **I can help** → add skills "nurse, boat hai".
3. Phone A: **I need help** → tap **Not breathing** → **SOS**.
4. Phone B rings → show **Why you were matched** (5 stages) → **Accept**.
5. Phone A rings "HELP IS COMING" → show **Who is coming** and the medical card note.
6. Phone B: show the **medical card** and tap the coordinates → Google Maps.
7. Say: "Relays can't read this; it's encrypted to the nurse only."

### Without phones, or if the radio misbehaves (backup)
Use **Test and train → Simulator** on one phone:
1. **Build simulated city** → **Report flood** → **Send SOS** → **Run**: show offers and accepts.
2. **Split & double dispatch** → two islands each send someone → **Heal network split** → show stand-down and "never cancel on scene".
3. Run each **Red Team attack** (Sybil: 40 fake nurses, Forged credential, Spoofed location, Floodwater lure, Battery-drain flood) and read out the **Results**.
4. Optional: **Relays to 10% battery** to show battery-aware relaying, then **Restore batteries**.

### Golden rules for the demo
- Charge both phones; disable Do Not Disturb; set alarm volume up.
- Rehearse twice. Have the backup ready to switch to within 10 seconds.
- If something fails, say what it shows and switch to the simulator. Don't apologise for long.

---

## 14. Numbers cheat sheet

| Thing | Value |
|---|---|
| Max hops (TTL) | 8 |
| Max frame size | 16 KB |
| SOS lifetime | 24 hours |
| Beacon lifetime | 5 minutes |
| Beacon interval | 60 s normal, 180 s low battery, 300 s critical |
| Low / critical battery | ≤ 20% / ≤ 8% |
| Neighbours per phone | up to 6 |
| Sync on connect | up to 200 messages (50 in low battery) |
| Offer window | 60 seconds |
| Heartbeat | every 2 minutes |
| Orphan timeout | 10 minutes |
| On-scene stale timeout | 30 minutes |
| Alarm auto-stop | 3 minutes |
| Arrival check | every 15 s; 30 m + GPS error, max 100 m |
| Clock skew allowed | 30 minutes |
| Per-link rate | 8 msg/s, burst 260; quarantine 10 min |
| Per-sender relay limit | 6 SOS and 40 events / 10 min |
| Sybil link threshold | 3+ identities on one link |
| Sybil cluster | 4+ new identical identities within 25 m |
| Decoy threshold | P(real) < 0.35 |
| Hazard half-life | 1 hour; blocking at ≥ 0.6 confidence |
| Plausible hop range | 300 m per hop (generous) |
| Max plausible speed | 40 m/s (~145 km/h) |
| Encrypted recipients | up to 8 |
| Counted vouches | up to 3 |
| Scarcity penalty | 15% × scarcity, max 60% |
| Severity classes | SOS-A life-threatening, B urgent, C unclear, D minor |
| Tests | 95, all passing |
| Code size | ~10,300 lines Dart + ~1,200 lines tests |
| APK size | ~20 MB (arm64) |

---

## 15. Known limitations (say these honestly)

1. **No real two-phone field test yet.** Everything is proven in the simulator and automated tests.
2. **Battery cost unmeasured** on real phones.
3. **Encryption composition not independently reviewed** (the primitives are standard).
4. **Release key not set**: current APKs use a test signing key.
5. **Android only.**
6. **Install-before-disaster** problem (shared by all offline apps).
7. **Smart Sybil attackers** can avoid the "suspicious" label (still never dispatched in tests); the fix is the planned RES-Q ID.
8. **Alarm doesn't bypass Do Not Disturb.**
9. **Rule-based triage** only knows the words it has; unknown wording is marked unclear, never dropped.

Judges respect honesty. Saying "here is exactly what's proven and what isn't" is a strength.

---

## 16. Roadmap

1. **Field testing** on 2, then 5–10 phones: range, delivery time, battery.
2. **Conflict-aware recovery:** tamper-evident event history per sender, replay detection, a "needs human review" queue.
3. **RES-Q ID:** sign up once online (phone number), get an ID card that anyone can verify offline, app lock, hardware-backed device key ("real device" badge).
4. **Adaptive offline routing:** road blocks, damaged bridges, unsafe buildings; source/time/confidence on every hazard; stale-data warnings; safer alternatives.
5. Independent **security review**; release signing; Play Store.
6. **iOS**, more languages, optional on-device model for unclear text.

---

## 17. Where everything lives in the code

| Folder / file | What's inside |
|---|---|
| `lib/main.dart` | App start |
| `lib/app/` | Startup (`bootstrap.dart`), state (`providers.dart`), alarms/GPS/arrival (`mesh_runtime.dart`), theme |
| `lib/node/resq_node.dart` | The phone's brain: receive, verify, relay, store, compute views, send SOS/events, medical card, arrival |
| `lib/protocol/` | Envelope format, limits, flood control |
| `lib/crypto/` | Identity keys, signatures, sealed boxes, key storage |
| `lib/mesh/` | Real radio (`nearby_transport.dart`) and simulated radio |
| `lib/domain/triage/` | Urgency rules, Hinglish word lists, skill parser |
| `lib/domain/chain/` | The 5-stage evaluation chain (claim, hazard, …) |
| `lib/domain/dispatch/matcher.dart` | Who goes where (scarcity-weighted) |
| `lib/domain/trust/` | Credentials, vouching, Sybil checks |
| `lib/domain/reconcile/` | Island merge, precedence, orphans |
| `lib/domain/power/` | Battery modes and relay rules |
| `lib/sim/simulator.dart` | Simulated city and Red Team attacks |
| `lib/features/` | Screens: dashboard, victim, responder, medical card, diagnostics |
| `lib/ui/` | Brand, SVG icons, animations and sounds |
| `android/app/src/main/kotlin/` | Foreground service, alarm, maps, tones |
| `test/` | 95 automated tests |
| `docs/` | PRD, architecture, ADRs, phase plan, reports, demo script, this guide |

---

*Last updated: 2026-10-26, version 0.13.1 (build 8).*
