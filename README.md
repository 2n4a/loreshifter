# Loreshifter

Приложение: [ls.elteammate.space](https://ls.elteammate.space/).

## Локальный запуск

Вам понадобится:
- .NET 8
- docker и compose
- flutter
- Арина напиши, что еще нужно для фронта

### База данных

Чтобы запустить локальную БД для разработки:

```sh
docker compose -f db/debug-compose.yaml up --build
```

`CTRL+C` чтобы остановить. Можно добавить флаг `--detach`, чтобы запустить
БД в фоне.

Пока у нас нет нормального решения для миграций, поэтому если в БД нужно
внести изменения, вносим их сразу в [000-initial.sql](db/migrations/000-initial.sql),
потом останавливаем БД и удаляем volume:
```
docker compose -f db/debug-compose.yaml down
docker volume rm db_devdb_data
```
Это пересоздаст базу с нуля.

### Backend

Теперь, когда запущена БД, нужно запустить бэк.

```
dotnet run --project LoreshifterBackend/LoreshifterBackend.csproj
```

### Frontend

TODO
