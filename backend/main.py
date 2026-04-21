import os
import time
import psycopg2
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Conexion a la base de datos
# ---------------------------------------------------------------------------

def get_conn():
    return psycopg2.connect(os.environ["DATABASE_URL"])


def init_db():
    for attempt in range(10):
        try:
            conn = get_conn()
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id    SERIAL PRIMARY KEY,
                    title TEXT    NOT NULL,
                    done  BOOLEAN NOT NULL DEFAULT FALSE
                )
            """)
            conn.commit()
            cur.close()
            conn.close()
            print("Base de datos lista.")
            return
        except Exception as e:
            print(f"Esperando a Postgres... intento {attempt + 1}/10 ({e})")
            time.sleep(2)
    raise RuntimeError("No se pudo conectar a Postgres despues de 10 intentos.")


@app.on_event("startup")
def startup():
    init_db()


# ---------------------------------------------------------------------------
# Modelos
# ---------------------------------------------------------------------------

class TaskIn(BaseModel):
    title: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.get("/tasks")
def list_tasks():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, title, done FROM tasks ORDER BY id")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [{"id": r[0], "title": r[1], "done": r[2]} for r in rows]


@app.post("/tasks", status_code=201)
def create_task(task: TaskIn):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO tasks (title) VALUES (%s) RETURNING id",
        (task.title,)
    )
    task_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return {"id": task_id, "title": task.title, "done": False}


@app.patch("/tasks/{task_id}/toggle")
def toggle_task(task_id: int):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "UPDATE tasks SET done = NOT done WHERE id = %s RETURNING id, title, done",
        (task_id,)
    )
    row = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")
    return {"id": row[0], "title": row[1], "done": row[2]}


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: int):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
    conn.commit()
    cur.close()
    conn.close()


@app.get("/health")
def health():
    return {"status": "ok"}
