# Book Mechanic – Implementation Summary

This document summarizes the **Book Mechanic** and **Get to place** flow and related backend/Flutter changes.

---

## 1. User flow (app)

- **Home:** Card renamed to **"Book Mechanic"** with subtitle **"Get to place or request at your location"**. Tapping it opens the new **Book Mechanic** flow (no longer the old map-only finder as the main entry).
- **Steps:**
  1. **Select vehicle** – List of user vehicles; **Add vehicle** if none.
  2. **Select problem** – Full-page list: **Car** vs **Bike** problems (tyre puncture, battery/not starting, engine, brake, electrical, AC, general checkup).
  3. **Details** – Optional **comment** and **photo(s)**; **diagnostic questions** shown when applicable (e.g. battery: dashboard lights, clicking sound, manual/auto).
  4. **Mechanics list** – Mechanics who serve the selected **problem category**, by location. Shown **without** distance (km), **without** phone, **without** mechanic photo.
  5. **Mechanic detail (full page)** – Tap a mechanic → full-page details (no photo). **"Send request to nearby mechanics"** sends a **broadcast** request (see backend).
  6. **Rules & payment** – User must read rules (advance ₹100 refundable, platform fee ₹9, per-km charge above 5 km, mechanic’s own charges on spot). Then **"I agree & pay"** → advance payment (₹100 + ₹9; per-km added when applicable).
  7. **After payment** – Request is broadcast; when a mechanic accepts, user sees “Mechanic accepted” (further tracking/arrival/completion can be wired on top of existing APIs).

---

## 2. Backend

### 2.1 MechanicRequest (extended)

- **problemCategory**, **diagnosticAnswers** (JSON), **comment**, **photoUrls** (JSON).
- **requestRadiusKm** (5 / 10 / 20), **advanceAmount**, **platformFee**, **comingChargePerKm**, **comingChargeTotal**, **distanceKmToCustomer**, **acceptedMechanicId**.
- **userConfirmedArrival**, **mechanicConfirmedArrival**, **userConfirmedCompleted**, **mechanicConfirmedCompleted**, **userCompletionRemarks**, **mechanicCompletionRemarks**, **refundStatus**, **viewExpiryAt** (5 min), **outOfHoursRequest**.

### 2.2 Mechanic (extended)

- **maxServingRadiusKm** (default 20), **perKmCharge** (default 3), **serviceCategories** (e.g. `"tyre_puncture,battery_jump,engine_repair"`), **categoryIconUrl** (optional, for admin).

### 2.3 MechanicWallet (new)

- **mechanicId**, **balance**, **totalEarned**, **minWithdrawAmount** (100). No “add money”; min ₹100 to withdraw.

### 2.4 APIs

- **GET /api/mechanic/by-category?problemCategory=&lat=&lng=&radiusKm=**  
  Mechanics for that category in radius; response **excludes** phone and distance (for public list).
- **POST /api/mechanic-requests/broadcast**  
  Creates request (no `mechanicId`); finds mechanics in **5 km → 10 km → 20 km**; notifies all in that radius; **viewExpiryAt = now + 5 min**.
- **GET /api/mechanic-requests/nearby-for-mechanic?mechanicId=&lat=&lng=**  
  Requests in 5-min window, within mechanic’s radius and category.
- **PUT /api/mechanic-requests/{id}/accept-by/{mechanicId}**  
  **First accept wins**; others cannot accept; status → PENDING_PAYMENT.
- **GET /api/mechanic-requests/customer/{email}**  
  User’s booking history.
- **PUT …/arrived**, **…/confirm-arrival-user**, **…/confirm-arrival-mechanic**, **…/complete-user**, **…/complete-mechanic**, **…/refund-status**  
  For arrival and completion flow.
- **GET /api/mechanic-wallet/{mechanicId}**  
  Mechanic wallet (balance, totalEarned, minWithdrawAmount).

On **mechanic registration approval**, backend sets **serviceCategories** from specialty and **maxServingRadiusKm**, **perKmCharge** so they appear in by-category and broadcast.

---

## 3. Flutter

- **lib/data/book_mechanic_problems.dart** – Car/bike problem lists and diagnostic questions.
- **lib/screens/mechanic/book_mechanic_flow_page.dart** – Full flow: vehicle → problem → details/diagnostic → mechanics list → mechanic detail → rules → payment; calls broadcast and payment gateway.
- **lib/screens/mechanic/mechanic_request_detail_book_flow_page.dart** – Mechanic view: full request details and **Accept** (calls accept-by).
- **Homepage** – “Book Mechanic” card opens **BookMechanicFlowPage**.
- **Mechanic dashboard** – **Wallet** from **GET /api/mechanic-wallet/{id}**: shows **balance**, **total earned**, “Min ₹100 to withdraw” (no fake ₹17000). **“New requests near you”** from **nearby-for-mechanic**; tap opens **MechanicRequestDetailBookFlowPage** for that request.

---

## 4. Not implemented in this pass (you can add later)

- **Live map** – Mechanic/customer live location and “mechanic will arrive in X min”, smooth tracking, auto “reached destination” and “Did you get customer/mechanic?” can be wired using **arrived** and **confirm-arrival** APIs and map/location plugins.
- **Refund automation** – Refund status and rules are in place; actual refund trigger (e.g. after both confirm completion) can be implemented in backend/cron or payment provider.
- **Admin dashboard UI** – Mechanic wallet list, revenue, category icons, km range and per-km settings: backend supports **serviceCategories**, **categoryIconUrl**, **maxServingRadiusKm**, **perKmCharge** (via **PUT /api/mechanic/{id}**); admin UI can be added in `admin-dashboard/`. **Interface images and icons** for mechanics/categories should be added and managed only from the admin dashboard.
- **Photo upload** – Book flow supports picking images; **photoUrls** are sent as JSON (e.g. local paths); production should upload images (e.g. S3) and send URLs in **photoUrls**.
- **FCM “View” opens detail** – When mechanic taps “View” in the notification, app can open **MechanicRequestDetailBookFlowPage(requestId, mechanicId)** by passing **requestId** (and **mechanicId**) from FCM data in your notification handler.

---

## 5. DB

Ensure **mechanic_requests** has the new columns and **mechanic_wallets** table exists (JPA will create if using `spring.jpa.hibernate.ddl-auto=update`). For **mechanics**, add **max_serving_radius_km**, **per_km_charge**, **service_categories**, **category_icon_url** if not already present.

---

## 6. Quick test

1. **User:** Home → Book Mechanic → select vehicle → select problem → add details/diagnostic → see mechanics (no km/phone/photo) → tap mechanic → Send request to nearby mechanics → agree to rules → pay.  
2. **Mechanic:** Dashboard → “New requests near you” (or FCM) → tap request → View details → Accept.  
3. **Backend:** Create broadcast → 5/10/20 km logic and FCM; accept-by first-wins; wallet endpoint for mechanic balance.

If you tell me your priority (e.g. live map or admin UI), I can outline concrete steps or code changes next.
