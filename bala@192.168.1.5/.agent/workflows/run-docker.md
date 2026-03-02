---
description: How to run the project using Docker
---

To run this project in a Docker Linux environment, follow these steps:

1. **Start Docker Desktop**: Ensure that Docker Desktop is running on your Mac.

2. **Run the application**:
   Open your terminal in the project root (`/Users/bala/frame`) and run:
   ```bash
   docker-compose up --build
   ```
   This command will:
   - Build the Docker image according to the `Dockerfile`.
   - Install the necessary Python dependencies (`flask`).
   - Start the container and map port `5000` on your machine to port `5000` in the container.
   - Mount your local `files/` directory to `/app/files` in the container for data persistence.

3. **Access the app**:
   Once the container is running and the logs show the Flask app has started, open your browser and go to:
   [http://localhost:5000](http://localhost:5000)

4. **Stop the application**:
   To stop the container, press `Ctrl+C` in the terminal where it's running, or run:
   ```bash
   docker-compose down
   ```
