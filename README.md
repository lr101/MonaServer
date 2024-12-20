# Mona Server

## What is it for?

This spring boot application is the communicating backend server for the app [Stick-It: Geomap](https://lr-projects.de/en/index.html) which can be found in the following [repo](https://github.com/lr101/buff_lisa).
It uses a postgresql database as its storage medium and implements refresh and jwt-auth tokens for login and authentication purposes. The openapi files can be found under the [openapi](./openapi) folder or when starting the server.
Using GitHub actions a docker image is always available at Docker Hub [here](https://hub.docker.com/repository/docker/lrprojects/stick-it-server/general).

## How to run

### Production setup in docker

1. Clone the repo or copy [docker-compose.yml](./docker-compose.yml) file
2. Create a `.env` file in the root of the project:

```dotenv
POSTGRES_USER=postgres
POSTGRES_PASSWORD=root
POSTGRES_DB=sticker
PORT=8081
ADMIN_ACCOUNT_NAME=admin
DB_URL=jdbc:postgresql://db:5432/sticker
MAIL_PASSWORD=<YOUR MAIL PASSWORD>
MAIL_HOST=<YOUR EMAIL SERVER HOST>
MAIL_PORT=<YOUR EMAIL SERVER PORT>
MAIL_FROM=<YOUR EMAIL>
MAIL_PROTOCOL=smtp
APP_URL=<YOUR_PUBLIC_FACING_DOMAIN> # Set to public facing api domain
MINIO_ACCESS_KEY=<MINIO_ACCESS_KEY>
MINIO_SECRET_KEY=<MINIO_SECRET_KEY>
MINIO_ENDPOINT=https://minio.example.com # Set to public facing minio domain
MINIO_BUCKET=<MINIO_BUCKET_NAME>
MINIO_ROOT_USER: admin
MINIO_ROOT_PASSWORD: <MINIO_CONSOLE_ADMIN_PASSWORD>
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<REDIS_PASSWORD>
```
3. Add your mail login data, public facing app url and minio information and a redis password
    - You might need to start the minio container to create your access key through the admin console
4. Run `docker-compose up` to  start all services


### Development setup (in IntelliJ)

1. Clone the repo
2. Open the project with IntelliJ
3. Set the SDK Version to 17 in the *Project Structure* setting
4. Create a .env file in the root of the project:
```dotenv
POSTGRES_USER=postgres
POSTGRES_PASSWORD=root
POSTGRES_DB=sticker
PORT=8081
ADMIN_ACCOUNT_NAME=admin
DB_URL=jdbc:postgresql://db:5432/sticker
MAIL_PASSWORD=<YOUR MAIL PASSWORD>
MAIL_HOST=<YOUR EMAIL SERVER HOST>
MAIL_PORT=<YOUR EMAIL SERVER PORT>
MAIL_FROM=<YOUR EMAIL>
MAIL_PROTOCOL=smtp
APP_URL=http://localhost:8081 # Set to public facing domain
MINIO_ACCESS_KEY=<MINIO_ACCESS_KEY>
MINIO_SECRET_KEY=<MINIO_SECRET_KEY>
MINIO_ENDPOINT=https://minio.example.com # Set to public facing minio domain
MINIO_BUCKET=<MINIO_BUCKET_NAME>
MINIO_ROOT_USER: admin
MINIO_ROOT_PASSWORD: <MINIO_CONSOLE_ADMIN_PASSWORD>
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<REDIS_PASSWORD>
```
5. Create a database in an already running instance or start the db in the [docker-compose](docker-compose.yml) file
6. Run the server via the main method

## FAQ

1. How do I use my gmail address when using TFA? - *See this [link](https://support.google.com/accounts/answer/185833?hl=en#zippy=) for how to generate an app password*
2. What gmail smtp server protocol should I use? - See [this](https://developers.google.com/gmail/imap/imap-smtp?hl=de) Google developer page for mail protocol information*
3. How do I back up the database? `docker exec -it <DB DOCKER ID> /bin/bash -c 'pg_dump -U postgres -Fc mona > /backup/db.dump'`
4. How do I restore a database? `docker exec -it <DB DOCKER ID> /bin/bash -c 'pg_restore -d sticker /backup/db.dump`
5. Run spacial data import:
```shell
docker exec -it <CONTAINER_ID> ogr2ogr -f "PostgreSQL" PG:"host=localhost user=postgres dbname=geospatial_db password=your_password"     -nln states_provinces -append -t_srs "EPSG:4326"     /docker-entrypoint-initdb.d/world_admin2.geojson
```