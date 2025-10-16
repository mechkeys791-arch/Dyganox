<p align="center">
  <img src="assets/logo.jpg" alt="ProMech Logo" width="200" />
</p>

<h1 align="center">🚗 ProMech – Smart Mechanic Assistance App</h1>

<p align="center">
  <b>Your Smart Roadside Mechanic Partner</b><br>
  Built with ❤️ using Flutter, Spring Boot, and AWS Cloud
</p>

---

## 🌟 Overview

**ProMech** is an intelligent, cloud-powered platform that connects vehicle owners with nearby verified mechanics in real-time.  
The app simplifies emergency roadside assistance by enabling users to find, contact, and book trusted mechanics instantly — all within one seamless mobile experience.

---

## ✨ Key Features

- 🔧 **Mechanic Finder:** Locate nearby mechanics using **Google Maps integration** and real-time GPS.
- 💬 **Instant Booking & Chat:** Connect with mechanics directly via in-app communication.
- 💳 **Secure Payments:** Pay safely using **Razorpay**, integrated through AWS-backed APIs.
- 📍 **Live Tracking:** Track mechanic arrival with real-time map updates.
- 🧾 **Service History:** View and manage your previous service requests and invoices.
- 🔐 **Dual Authentication:** Separate login/signup for **Users** and **Mechanics**.
- ☁️ **Cloud-Integrated Backend:** AWS services for storage, database, authentication, and hosting.

---

## 🏗️ Tech Stack

| Layer | Technology |
|-------|-------------|
| **Frontend (Mobile)** | Flutter (Dart) |
| **Backend (API)** | Spring Boot (Java) |
| **Database** | AWS RDS (PostgreSQL) |
| **Cloud Services** | AWS EC2, S3, Cognito, API Gateway |
| **Authentication** | JWT / AWS Cognito |
| **Payments** | Razorpay |
| **Maps** | Google Maps SDK |

---

## 🧠 Architecture Overview

```mermaid
graph TD
A[Flutter App] -->|REST API| B(Spring Boot Backend)
B --> C[(AWS RDS - PostgreSQL)]
B --> D[S3 Bucket - Media Storage]
B --> E[AWS Cognito - Authentication]
A --> F[Google Maps API]
A --> G[Razorpay Payment Gateway]

