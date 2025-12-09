# LoreShifter Backend

Это бэкенд проекта LoreShifter.

## Необходимые условия

- [uv](https://github.com/astral-sh/uv) (рекомендуется) или pip
- Python 3.14: `uv python install cpython-3.14.0-linux-x86_64-gnu`

## Установка

1.  **Клонируйте репозиторий:**

    ```bash
    git clone...
    cd loreshifter/backend
    ```

2.  **Создайте виртуальное окружение:**

    С помощью `uv`:
    ```bash
    uv venv
    ```

    С помощью `venv`:
    ```bash
    python -m venv .venv
    ```

3.  **Активируйте виртуальное окружение:**

    На macOS и Linux:
    ```bash
    source .venv/bin/activate
    ```

    На Windows:
    ```bash
    .venv\Scripts\activate
    ```

4.  **Установите зависимости из `pyproject.toml`:**

    С помощью `uv`:
    ```bash
    uv pip install -e .
    ```

    С помощью `pip`:
    ```bash
    pip install -e .
    ```

## Запуск приложения

1.  **Настройте переменные окружения:**

    Создайте файл `.env` в корне репозитория, вставьте переменные окружения

2.  **Запустите приложение:**

    ```bash
    python main.py
    ```

    Приложение будет доступно по адресу `http://127.0.0.1:8000`.

## Запуск тестов

Для запуска тестов используйте `pytest`:

```bash
pytest
```
