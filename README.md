# Song data updater
Downloads song data from the internet and updates a MYSQL database.

The following data is supported:

- happiness
- danceability
- energy
- accousticness
- insumentalness
- liveness
- speechiness
- album

Requires the following environment variables to be set:

- SONGS_DB_HOSTNAME: Where the database is hosted
- SONGS_DB_NAME: Database name
- SONGS_DB_USER: Username with access to the database
- SONGS_DB_PWD: Password associated with that username
