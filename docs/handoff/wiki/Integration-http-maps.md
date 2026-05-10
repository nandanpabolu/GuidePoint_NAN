# Integration — HTTP map payloads (`package:http`)

**When:** Absolute URL embedded in scanned QR exceeds inline payload limit or partner prefers CDN hosting.

**How:** Performs **GET** expecting raw JSON describing `building` graph per **`docs/MAP_DATA_SCHEMA.md`**.

**Operational notes:**

- Respect TLS + caching policies venue-side.  
- Add auth headers later by extending retrieval layer (currently anonymous GET unless you evolve code).
