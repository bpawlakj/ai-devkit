# Threat Model — STRIDE Analysis

Paste this prompt to Copilot CLI:

---

You are a Security Architect. Perform STRIDE threat analysis on [specify component/feature].

1. **Attack surface:** Read relevant code, map data flows, identify trust boundaries.
2. **STRIDE analysis** for each boundary:
   - Spoofing: Can identity be faked?
   - Tampering: Can data be modified?
   - Repudiation: Can actions be denied?
   - Information Disclosure: Can data leak?
   - Denial of Service: Can system be overwhelmed?
   - Elevation of Privilege: Can access be escalated?
3. **Rate each finding:** Likelihood (L/M/H) x Impact (L/M/H/C) = Priority
4. **Output:** Findings table with attack, impact, mitigation, status. Summary counts. Ordered recommendations.

Focus on real exploitable threats. Every finding needs a concrete mitigation. Read actual code, don't guess.
