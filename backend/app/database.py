import json
from typing import Generator

import boto3
from botocore.exceptions import ClientError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from .config import settings


def get_secret_from_aws() -> dict | None:
    """
    Expected secret JSON:
    {
      "username": "...",
      "password": "...",
      "host": "....rds.amazonaws.com",
      "port": 5432,
      "dbname": "usersdb"
    }
    """
    try:
        client = boto3.client("secretsmanager", region_name=settings.aws_region)
        resp = client.get_secret_value(SecretId=settings.aws_secret_name)
    except ClientError as e:
        print(f"[secrets] error: {e}")
        return None

    secret_str = resp.get("SecretString")
    if not secret_str:
        return None
    return json.loads(secret_str)


def build_db_url() -> str:
    s = get_secret_from_aws()
    if s:
        return (
            f"postgresql+psycopg2://{s['username']}:{s['password']}"
            f"@{s['host']}:{s.get('port', 5432)}/{s['dbname']}"
        )
    return settings.fallback_db_url


DATABASE_URL = build_db_url()


class Base(DeclarativeBase):
    pass


engine = create_engine(DATABASE_URL, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db() -> Generator:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
