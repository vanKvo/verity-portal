# Start Auth service
1.  Start the database 
docker-compose up -d db
2. Navigate to the backend directory and ensure your dependencies are installed and migrations are applied.
cd backend
poetry install
poetry run alembic upgrade head
Note: Ensure your backend/.env has DATABASE_URL set to postgresql://user:password@localhost:5432/verity_db (which matches the docker-compose settings).
3. Start the Auth service only
poetry run uvicorn app.auth.main:app --reload --port 8000
OR
Run the FastAPI application.
poetry run uvicorn app.main:app --reload
4. Verify the backend is running.  You should see {"status": "healthy"} in the response.
curl http://localhost:8000/health
5. Testing
- Open http://localhost:8000/docs. This is the Swagger UI where you can manually test the /auth/register, /auth/login, and /auth/guest-login endpoints.
- Quick Test (Guest Login): The easiest way to verify frontend connectivity is to call the guest login endpoint, which doesn't require existing database records:
curl -X POST http://localhost:8000/auth/guest-login
6. Frontend Configuration
Ensure your Angular frontend (frontend/src/app/core/services/auth.service.ts) is pointing to http://localhost:8000. 
