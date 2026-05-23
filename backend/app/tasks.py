from app.core.celery_app import celery_app

# Celery tasks implemented in Milestone 5+

@celery_app.task
def send_sms_task(to: str, body: str):
    pass

@celery_app.task
def send_hospital_alert_task(ride_id: str, triage: dict, hospital_id: str):
    pass
