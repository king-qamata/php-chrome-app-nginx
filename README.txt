
php-chrome-app-nginx
=====================

Lightweight Docker image combining PHP (FPM), Nginx and Chrome/Chromedriver for running headless browser tasks (Selenium/WebDriver) or PHP scripts that require a Chrome instance.

Features
- Nginx serving PHP via FPM
- Headless Chrome + Chromedriver (init script included)
- Supervisor to run multiple background processes (PHP-FPM, Nginx, Chromedriver)
- Example scripts: basic diagnostic and WebDriver test

Repository layout
- Dockerfile — primary Docker build
- init-chromedriver.sh — helper to initialize Chromedriver
- nginx.conf / nginx-azure.conf — Nginx configuration
- php.ini / php-azure.ini — PHP configuration
- supervisord.conf / supervisord-chromedriver.conf — process supervision
- src/ — example PHP endpoints and tests
	- index.php — basic app entry
	- diagnostic.php — system diagnostic info
	- webdriver_test.php — example WebDriver client test (PHP)

Quickstart (build & run)
1. Build the Docker image from repository root:

```bash
docker build -t php-chrome-app-nginx .
```

2. Run the container (example):

```bash
docker run --rm -p 8080:80 --name php-chrome-app-nginx php-chrome-app-nginx
```

3. Open the app in your browser at http://localhost:8080/ (or call example endpoints in `src/`).

Notes on usage
- The container uses Supervisor to start multiple services; check `supervisord.conf` for configured programs.
- `init-chromedriver.sh` contains initialization logic for Chromedriver; the Docker build and/or startup scripts call it to ensure correct permissions and drivers.
- Use `webdriver_test.php` as a starting point for integrating PHP WebDriver clients.

Environment & configuration
- Adjust PHP settings in `php.ini` / `php-azure.ini` as needed.
- Nginx site configuration is in `nginx.conf` and `nginx-azure.conf` (the build may copy or select one of these).

Debugging & logs
- To inspect running containers and logs:

```bash
docker ps
docker logs -f <container-id-or-name>
```

- To get a shell inside the running container:

```bash
docker exec -it <container-id-or-name> /bin/bash
```

Troubleshooting
- If Chrome/Chromedriver fails to start, check `init-chromedriver.sh` execution and the supervisor logs.
- Verify matching Chrome and Chromedriver versions if you get version mismatch errors.

Contributing
- Fork the repo, make changes, and open a PR. Keep changes focused and update this README with any workflow or configuration changes.

License
- No license file included. Add a LICENSE to state terms.

Files to inspect first
- [Dockerfile](Dockerfile)
- [supervisord.conf](supervisord.conf)
- [init-chromedriver.sh](init-chromedriver.sh)
- [src/index.php](src/index.php) (entry example)

If you want, I can also:
- add a short `README.md` with badges and a Docker Hub deploy workflow
- create a quick `docker-compose.yml` for local development
