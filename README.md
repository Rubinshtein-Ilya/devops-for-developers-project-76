### Hexlet tests and linter status:
[![Actions Status](https://github.com/Rubinshtein-Ilya/devops-for-developers-project-76/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Rubinshtein-Ilya/devops-for-developers-project-76/actions)

# Подготовка серверов к деплою (Ansible)

Учебный проект: Ansible-плейбук, который готовит серверы к запуску приложения
в Docker — ставит pip, Python-модуль `docker` (Docker SDK for Python),
Docker CE с compose-плагином и добавляет пользователя деплоя в группу `docker`.

## Требования

- [Ansible](https://docs.ansible.com/) (ansible-core 2.15 и новее)
- `make`
- SSH-доступ к серверам по ключу, пользователь с правами `sudo`
- Серверы на Ubuntu (проверено на 22.04 LTS)

Установка Ansible на macOS/Linux:

```bash
python3 -m pip install --user ansible
```

## Структура проекта

| Файл | Назначение |
| --- | --- |
| `playbook.yml` | основной плейбук (`hosts: all`) |
| `inventory.ini` | список серверов, группа `webservers` |
| `requirements.yml` | зависимости Ansible Galaxy: роли и коллекция |
| `group_vars/all.yml` | переменные для ролей |
| `Makefile` | команды установки зависимостей и подготовки серверов |

## Подготовка

### 1. Настроить инвентарь

Впишите свои серверы в `inventory.ini`: алиас, IP-адрес (`ansible_host`),
пользователя для деплоя (`ansible_user`) и путь к приватному SSH-ключу
(`ansible_ssh_private_key_file`).

```ini
[webservers]
web1 ansible_host=203.0.113.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519
web2 ansible_host=203.0.113.11 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

Публичная часть ключа должна лежать в `~/.ssh/authorized_keys` на серверах,
а пользователь — иметь `sudo` без пароля (`NOPASSWD`).

Адреса серверов хранятся в репозитории в открытом виде — это требование
задания. Держите SSH открытым только по ключам и не выкладывайте приватные
ключи в git.

### 2. Установить зависимости Ansible Galaxy

```bash
make install
```

Ставятся роли [geerlingguy.pip](https://galaxy.ansible.com/ui/standalone/roles/geerlingguy/pip/),
[geerlingguy.docker](https://galaxy.ansible.com/ui/standalone/roles/geerlingguy/docker/)
и коллекция [community.docker](https://galaxy.ansible.com/ui/repo/published/community/docker/).

Коллекция закреплена на ветке 4.x: версии 5.x требуют ansible-core 2.17 и новее.
Если у вас ansible-core 2.17+, ограничение в `requirements.yml` можно снять.

### 3. Проверить связь с серверами

```bash
make ping
```

Ожидаемый ответ по каждому хосту — `SUCCESS` и `"ping": "pong"`.

## Подготовка серверов

```bash
make setup
```

Команда сначала доустанавливает зависимости Galaxy, затем прогоняет плейбук.
Что появится на серверах:

- `python3-pip`;
- pip-пакет `docker` (Docker SDK for Python) — нужен модулям коллекции
  `community.docker`;
- Docker CE, CLI, containerd, buildx и compose-плагин из официального
  репозитория Docker;
- пользователь деплоя в группе `docker` (можно работать с Docker без `sudo`).

Плейбук идемпотентный: повторный запуск не меняет состояние серверов.

Проверить результат вручную:

```bash
ssh ubuntu@<ip> 'pip3 --version; python3 -c "import docker; print(docker.__version__)"; docker --version; id -nG'
```

## Замечания

- Роль `geerlingguy.docker` подключает официальный репозиторий Docker
  (`/etc/apt/sources.list.d/docker.sources`) и удаляет устаревшие пакеты
  (`docker.io`, `docker-compose`, `containerd`, `runc`). Если Docker на сервере
  был установлен из репозитория Ubuntu, он будет заменён на Docker CE.
- Pip-пакет `docker` ставится в системный Python
  (`/usr/local/lib/python3.10/dist-packages`) и подтягивает свежие `requests`
  и `urllib3`, перекрывая системные версии. Для учебного сервера это нормально,
  в продакшене лучше использовать virtualenv или пакет `python3-docker` из apt.
