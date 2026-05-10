# Workflow — Facilities QR / map rollout

**Actor:** Map owner / partner venue staff  

**Purpose:** Ensure JSON matches parser expectations documented in **`docs/MAP_DATA_SCHEMA.md`**.

**Artifacts**

| Artifact | Typical location |
|----------|------------------|
| Rich graph JSON | **`data/maps/ATL_JSON.json`** (canonical example) |
| Printable QR playground | **`tools/scan_atl_qr.html`** |

**Operational steps**

1. Validate JSON lint + load it into `AStarPathfinder` via QA build (debug “Load sample map” button shortcut).  
2. Generate QR (inline payload or shortened HTTPS URL linking raw JSON body).  
3. Print & mount at audited entrance per accessibility plan.  

**Rollback**

Replace hosted JSON endpoint or circulate new QR overlays if topology changes mid-semester.
