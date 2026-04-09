<!-- I am on a medication course of around 6 plus months or like 5 months and I have to make sure that I don't skip any medicines and I need to also make sure that I send a bit of notification or a message to my parents or my guardians or anyone who I would like to inform that I have taken the medicines at the correct time because this medication is necessary and I need to complete the complete course and don't want to skip any medication. So I am planning to build an app that will just, not an app, a web application or something simple that would be a very simple and just have some schedules and on a click of button, it will send us a notification or some message to everyone who else I would like to add that the medication is being taken or whatever like this and this. So let, tell me about that, give me an idea what we can build on that basis. -->

# 💊 Medication Adherence Notification System

## 📌 Overview

This project is a **simple, reliable, notification-first mobile application (Android-focused)** built using Flutter.

The system ensures:

* Timely medication reminders (with alarms)
* User confirmation ("Taken")
* Guardian visibility and alerts
* Two-way interaction (guardian → user)

👉 The focus is:

> **Maximum reliability with minimum complexity**

---

## 🎯 Core Objectives

* Ensure **no medication is missed**
* Provide **strong alarms + notifications**
* Enable **guardian monitoring**
* Allow **guardians to trigger alerts manually**
* Keep stack **simple (no heavy backend, no DB)**

---

## 🧠 Key Concept

This is a:

> **Local-first, state-driven reminder + alert system with guardian sync**

---

## 🧱 MVP Features

### 1. Medication Schedule

* Add medication:

  * Name
  * Time(s)
* Stored locally (JSON/CSV)

---

### 2. Alarm-Based Reminder System

* Exact-time alarms (like alarm clock)
* Works even if app is closed
* Strong alert (sound + vibration)

---

### 3. "Mark as Taken"

```
✅ Mark as Taken
```

* Saves timestamp locally
* Updates state
* Triggers guardian notification

---

### 4. Guardian Side (IMPORTANT)

Guardian can:

* See status:

  * Taken ✅
  * Pending ⏳
  * Missed ❌
* Receive alerts if missed
* **Trigger alarm on user’s phone manually**

---

## 🔔 Notification Strategy

### 🧩 Layer 1 — Alarm (Primary)

At scheduled time:

```
💊 Time to take your medicine
```

---

### 🧩 Layer 2 — Follow-up

After 5–10 mins:

```
⚠️ Reminder: please take your medicine
```

---

### 🧩 Layer 3 — Escalation to Guardian

After 15–20 mins:

```
❗ Medication not confirmed yet
```

---

### 🧩 Layer 4 — Confirmation

When marked taken:

```
✅ Medication taken at 9:02 AM
```

---

### 🧩 Layer 5 — Guardian Trigger (New Feature)

Guardian can press:

```
🚨 Trigger Alarm
```

→ This sends alert to user:

```
🚨 Please take your medicine NOW
```

---

## 🧠 State Machine

```id="pt0u0l"
SCHEDULED → ALARM_TRIGGERED → TAKEN
                            → MISSED
```

---

## ⚙️ Tech Stack (Simple)

### Mobile App

* Flutter (Android)

---

### Storage (No DB)

* JSON or CSV files (local storage)

Examples:

```id="r7z0o3"
medications.json
logs.json
users.json
```

---

### Notifications

#### Local (Primary)

* Alarm Manager
* Local Notifications

#### Remote (Lightweight)

* Firebase Cloud Messaging (only for cross-device alerts)

---

## 📲 App Architecture

### Two Roles

#### 1. User App (You)

* Set medication schedule
* Receive alarms
* Mark as taken

---

#### 2. Guardian App

* View status
* Receive alerts
* Trigger alarm remotely

---

## 🔁 Communication Flow

```id="4vqq4q"
User App → (Firebase) → Guardian App
Guardian App → (Firebase) → User App
```

👉 Firebase used only for:

* Sending simple messages
* No database usage required

---

## 🗄️ Local Data Design

### medications.json

```json
[
  {
    "id": 1,
    "name": "Medicine A",
    "times": ["09:00", "21:00"]
  }
]
```

---

### logs.json

```json
[
  {
    "medication_id": 1,
    "scheduled_time": "2026-04-07T09:00:00",
    "taken_time": "2026-04-07T09:02:00",
    "status": "taken"
  }
]
```

---

### guardian_config.json

```json
{
  "guardian_tokens": ["token_1", "token_2"]
}
```

---

## ⏱️ Alarm & Scheduler Logic

### On Device

* Register alarms for each schedule
* On trigger:

  * Show full alert
  * Start follow-up timer

---

### Timers

* +10 min → reminder
* +20 min → mark missed + notify guardian

---

## 🔥 Smart Features

### ✅ Snooze

* “Remind in 5 minutes”

---

### ✅ Escalation Logic

* Multi-step alerts before notifying guardian

---

### ✅ Guardian Trigger

* Guardian can force alarm on user device

---

### ✅ Daily Summary (optional)

* Show:

  * Taken ✅
  * Missed ❌

---

### ✅ Streak Tracking (optional)

* Track consistency

---

## 🚀 Development Plan

### Phase 1 (Core)

* Flutter setup
* Local storage (JSON)
* Schedule UI
* Alarm integration

---

### Phase 2 (Core Logic)

* State machine
* Snooze + follow-up
* Missed detection

---

### Phase 3 (Communication)

* Firebase setup
* Send/receive messages
* Guardian alerts

---

### Phase 4 (Enhancements)

* Guardian UI
* Trigger alarm feature
* Summary + streaks

---

## ⚠️ Considerations

* Android battery optimization may affect alarms
* Firebase needed for cross-device communication
* JSON must be handled carefully (no corruption)

---

## 💬 Final Principle

> **Simple stack + strong alerts = reliable system**

Avoid:

* Over-engineering
* Complex backend
* Heavy infrastructure

---

## ✅ Summary

This system provides:

* Alarm-based medication reminders
* Simple local storage (JSON/CSV)
* Guardian monitoring and alerts
* Two-way communication (guardian ↔ user)

---

**Keep it simple. Make it reliable. That’s the product.**
