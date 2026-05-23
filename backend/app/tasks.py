import logging
from app.core.celery_app import celery_app

logger = logging.getLogger("smartride.tasks")


@celery_app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=10,
    autoretry_for=(Exception,),
    retry_backoff=True,
)
def send_sms_task(self, to: str, body: str):
    from app.core.config import settings
    if not settings.TWILIO_ACCOUNT_SID:
        logger.info("Twilio not configured — skipping SMS to %s", to)
        return
    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        client.messages.create(to=to, from_=settings.TWILIO_FROM_NUMBER, body=body)
        logger.info("SMS sent to %s", to)
    except Exception as exc:
        logger.warning("SMS failed for %s: %s — retrying", to, exc)
        raise self.retry(exc=exc)


@celery_app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=15,
    autoretry_for=(Exception,),
    retry_backoff=True,
)
def send_hospital_alert_task(self, ride_id: str, triage: dict, hospital_id: str):
    logger.info(
        "Hospital alert — ride=%s hospital=%s severity=%s",
        ride_id,
        hospital_id,
        triage.get("severity"),
    )
