# Decisions Archive

## 2026-02-06 — Backend Hosting for TestFlight

**Decision:** Railway hosting - $5-10/month managed platform
**Context:** Need to deploy Node.js backend for TestFlight users to connect bank accounts and receive AI guidance. Railway chosen for fastest deployment to user testing.
**Alternatives considered:** AWS (more control but complex setup), ngrok (fast but unreliable for real users)

## 2026-02-06 — Complete Features Before TestFlight

**Decision:** Complete missing features (allocation execution history, AI guidance triggers, transaction analysis polish) and fix UI issues before TestFlight deployment. Focus on Analysis page transaction review display and verify Plaid financial calculation accuracy.
**Context:** Ray reviewed current 80% complete state and decided TestFlight should wait for feature completion and UI polish. Specific feedback: Analysis page transaction review display is too noisy and needs redesign. Also needs verification of Plaid data calculation accuracy.
**Alternatives considered:** Ship TestFlight immediately with 80% features to get early user feedback
