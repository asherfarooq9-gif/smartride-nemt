"""PHI access audit trail.

One JSON line per read of patient health data, on its own logger so it can be
routed and retained separately from request logs. Records who looked at whose
data and which fields were disclosed, never the data itself.
"""

import json
import logging
from datetime import datetime, timezone
from typing import Iterable

log = logging.getLogger("smartride.phi_audit")


def record_phi_access(
    actor_user_id: object,
    actor_role: str,
    ride_id: object,
    patient_id: object,
    fields: Iterable[str],
) -> None:
    log.info(
        json.dumps(
            {
                "event": "phi_read",
                "at": datetime.now(timezone.utc).isoformat(),
                "actor_user_id": str(actor_user_id),
                "actor_role": actor_role,
                "ride_id": str(ride_id),
                "patient_id": str(patient_id),
                "fields": sorted(fields),
            }
        )
    )
