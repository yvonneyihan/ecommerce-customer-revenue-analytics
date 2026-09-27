from ecommerce_pipeline.config import get_database_url


def test_get_database_url_uses_explicit_override(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql://x:y@z:5432/db")
    assert get_database_url() == "postgresql://x:y@z:5432/db"


def test_get_database_url_builds_from_parts(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setenv("POSTGRES_USER", "u")
    monkeypatch.setenv("POSTGRES_PASSWORD", "p")
    monkeypatch.setenv("POSTGRES_HOST", "dbhost")
    monkeypatch.setenv("POSTGRES_PORT", "5433")
    monkeypatch.setenv("POSTGRES_DB", "mydb")
    assert get_database_url() == "postgresql://u:p@dbhost:5433/mydb"


def test_get_database_url_has_sane_defaults(monkeypatch):
    for var in ("DATABASE_URL", "POSTGRES_USER", "POSTGRES_PASSWORD", "POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_DB"):
        monkeypatch.delenv(var, raising=False)
    assert get_database_url() == "postgresql://ecommerce:ecommerce@localhost:5432/ecommerce_analytics"
