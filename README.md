# mi-app -- Docker Compose Example

App de tareas simple con FastAPI + PostgreSQL + Frontend estatico (HTML/JS).

## Stack

| Capa      | Tecnologia        |
|-----------|-------------------|
| Frontend  | HTML/JS + Nginx   |
| Backend   | Python + FastAPI  |
| Base datos| PostgreSQL 16     |

## Estructura

`
docker_compose/
├── docker-compose.yml
├── .env.example
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── main.py
└── frontend/
    ├── Dockerfile
    ├── nginx.conf
    └── index.html
`

## Como correr

`ash
# 1. Crear el archivo de variables de entorno
cp .env.example .env

# 2. Levantar todo
docker compose up -d --build

# 3. Abrir en el navegador
# http://localhost

# 4. Bajar todo
docker compose down

# Bajar todo y borrar la base de datos
docker compose down -v

# Para montar en host

docker_compose_prd/
├── docker-compose.prod.yml    ← copiado del proyecto
└── .env                       ← configura tus variables

cd C:\Users\User\Desktop\docker_compose_prd
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

