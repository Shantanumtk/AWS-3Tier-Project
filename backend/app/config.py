import os
from pydantic import BaseModel


class Settings(BaseModel):
    aws_region: str = os.getenv("AWS_REGION", "us-west-2")
    aws_secret_name: str = os.getenv("AWS_SECRET_NAME", "rds-postgres-user-db-secret")
    # local fallback
    fallback_db_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg2://postgres:postgres@localhost:5432/postgres",
    )


settings = Settings()
