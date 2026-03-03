# Mechanic Request & Profile – Backend Requirements

This document describes backend API and database requirements for the mechanic request flow, state management, location verification, and profile/records.

---

## 1. Request status values

Support these status values for mechanic requests (bookings):

| Status        | Description |
|---------------|-------------|
| `PENDING`     | New request; mechanic has not responded. |
| `ACCEPTED`    | Mechanic accepted; stored as "pending" in mechanic's account until completed or rejected later. |
| `IN_PROGRESS` | Mechanic reported "I have reached"; optional customer confirmation step. |
| `COMPLETED`   | Job completed; record for day summary and mechanic contribution. |
| `REJECTED`    | Mechanic declined the request. |

- When mechanic **accepts**: store/update the request as `ACCEPTED` (or keep as "pending" in mechanic account until completion).
- When job is **completed**: update status to `COMPLETED` and record for that day's summary/contribution.
- If mechanic accepts but does not reach/complete, status remains `ACCEPTED` (or `IN_PROGRESS` if they tapped "I have reached" but customer did not confirm).

---

## 2. Push notification for new job requests

- When a customer sends a request (e.g. broadcast or direct to mechanic), backend should trigger **FCM (Firebase Cloud Messaging)** to the mechanic's device so a **push notification appears in the mechanic’s mobile notification bar**.
- Use the existing FCM token registration (mechanic app registers token with backend).
- Payload should include `type: "mechanic_request"` and `requestId` so the app can open the request detail or bookings.

---

## 3. API endpoints used by the app

### 3.1 Fetch all bookings for a mechanic

- **GET** `{baseUrl}/api/mechanic-requests/mechanic/{mechanicId}/bookings`
- Returns **all** requests for this mechanic in any status: `PENDING`, `ACCEPTED`, `IN_PROGRESS`, `COMPLETED`, `REJECTED`.
- Response: JSON array of request objects (same shape as existing mechanic-requests, with `status` field).
- Used by: Mechanic Profile page (tabs: Completed, Pending, Rejected).

If this endpoint is not implemented, the app falls back to the existing **GET** `.../mechanic/{mechanicId}/pending` and only shows pending requests on the profile.

### 3.2 “I have reached” – location and verification

- **POST** `{baseUrl}/api/mechanic-requests/{requestId}/reached`
- Body: `{ "latitude": number, "longitude": number }`
- Backend should:
  1. **Record the event** with timestamp and mechanic coordinates in the database (for security/audit).
  2. Update request status to `IN_PROGRESS` (optional).
  3. **Notify the customer** (push/in-app) to confirm “Mechanic has reached – Confirm?” and optionally send customer coordinates.
  4. When **both** mechanic and customer are in proximity (e.g. within 20 m) and **both have confirmed**:
     - Record a **location verification event** (timestamp, mechanic lat/lng, customer lat/lng) in the database.
     - This increases trust and supports disputes.

---

## 4. Mechanic profile and records

- **Past completed records**: Returned by GET mechanic bookings with `status: COMPLETED`.
- **Pending requests**: `PENDING` (and optionally `ACCEPTED` / `IN_PROGRESS` for “active”).
- **Rejected records**: `REJECTED`.
- **Monthly earnings summary** and **jobs per month**: Backend should support aggregation (e.g. from wallet/transaction tables and completed requests) for the mechanic profile page.
- **Rating and reviews**: Existing mechanic profile/rating fields; optional response rate computed from (accepted + rejected) / total requests.

---

## 5. Security and data logging

- **All state changes** (pending → accepted → in_progress → completed, or rejected) should be **logged** (e.g. status history table or audit log) with timestamp and optionally actor.
- **Location verifications** (mechanic “reached” + customer confirmation, with coordinates) should be **stored** with timestamp and both coordinates for:
  - Security audits
  - Customer protection
  - Dispute resolution

---

## 6. Summary checklist for backend

1. **Request status**: Support `PENDING`, `ACCEPTED`, `IN_PROGRESS`, `COMPLETED`, `REJECTED` and transitions.
2. **GET** `/api/mechanic-requests/mechanic/{mechanicId}/bookings` – all bookings for profile/records.
3. **POST** `/api/mechanic-requests/{requestId}/reached` – body `{ latitude, longitude }`; record event, notify customer, optional proximity check and dual confirmation.
4. **Log** state changes and location verification events (timestamp, coordinates where applicable).
5. **FCM**: Send push notification to mechanic when a new customer request is created.
