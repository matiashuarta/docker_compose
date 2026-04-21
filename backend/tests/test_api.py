"""
Tests de los endpoints de la API.

Usa TestClient de FastAPI (no necesita un servidor corriendo,
ni una base de datos real — mockea la conexion a Postgres).
"""
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient

from main import app

client = TestClient(app)

# ---------------------------------------------------------------------------
# Helpers para mockear psycopg2
# ---------------------------------------------------------------------------

def make_mock_conn(fetchall=None, fetchone=None):
    """Devuelve un mock de conexion + cursor de psycopg2."""
    mock_cur = MagicMock()
    mock_cur.fetchall.return_value = fetchall or []
    mock_cur.fetchone.return_value = fetchone

    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cur

    return mock_conn, mock_cur


# ---------------------------------------------------------------------------
# GET /tasks
# ---------------------------------------------------------------------------

def test_list_tasks_empty():
    """Con la base vacia debe devolver una lista vacia."""
    mock_conn, _ = make_mock_conn(fetchall=[])

    with patch("main.get_conn", return_value=mock_conn):
        response = client.get("/tasks")

    assert response.status_code == 200
    assert response.json() == []


def test_list_tasks_with_data():
    """Debe devolver las tareas que haya en la base."""
    rows = [(1, "Comprar leche", False), (2, "Estudiar Docker", True)]
    mock_conn, _ = make_mock_conn(fetchall=rows)

    with patch("main.get_conn", return_value=mock_conn):
        response = client.get("/tasks")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0] == {"id": 1, "title": "Comprar leche", "done": False}
    assert data[1] == {"id": 2, "title": "Estudiar Docker", "done": True}


# ---------------------------------------------------------------------------
# POST /tasks
# ---------------------------------------------------------------------------

def test_create_task():
    """Debe crear una tarea y devolverla con done=False."""
    mock_conn, mock_cur = make_mock_conn(fetchone=(42,))

    with patch("main.get_conn", return_value=mock_conn):
        response = client.post("/tasks", json={"title": "Nueva tarea"})

    assert response.status_code == 201
    data = response.json()
    assert data["id"] == 42
    assert data["title"] == "Nueva tarea"
    assert data["done"] is False


def test_create_task_missing_title():
    """Sin titulo debe devolver 422 (validacion de Pydantic)."""
    response = client.post("/tasks", json={})
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# PATCH /tasks/{id}/toggle
# ---------------------------------------------------------------------------

def test_toggle_task():
    """Debe alternar el estado done de la tarea."""
    mock_conn, mock_cur = make_mock_conn(fetchone=(1, "Tarea", True))

    with patch("main.get_conn", return_value=mock_conn):
        response = client.patch("/tasks/1/toggle")

    assert response.status_code == 200
    data = response.json()
    assert data["done"] is True


def test_toggle_task_not_found():
    """Si la tarea no existe debe devolver 404."""
    mock_conn, mock_cur = make_mock_conn(fetchone=None)

    with patch("main.get_conn", return_value=mock_conn):
        response = client.patch("/tasks/999/toggle")

    assert response.status_code == 404


# ---------------------------------------------------------------------------
# DELETE /tasks/{id}
# ---------------------------------------------------------------------------

def test_delete_task():
    """Debe devolver 204 sin cuerpo."""
    mock_conn, _ = make_mock_conn()

    with patch("main.get_conn", return_value=mock_conn):
        response = client.delete("/tasks/1")

    assert response.status_code == 204


# ---------------------------------------------------------------------------
# GET /health
# ---------------------------------------------------------------------------

def test_health():
    """El endpoint de health debe devolver ok."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
