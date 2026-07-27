### Hexlet tests and linter status:
[![Actions Status](https://github.com/Rubinshtein-Ilya/devops-for-developers-project-76/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Rubinshtein-Ilya/devops-for-developers-project-76/actions)

# Деплой Redmine с помощью Ansible

Учебный проект: Ansible готовит два сервера к работе (Docker и его зависимости),
а затем разворачивает на них [Redmine](https://hub.docker.com/_/redmine) в Docker
вместе с базой PostgreSQL. Трафик распределяет балансировщик, приложение
доступно по домену через HTTPS.

## Задеплоенное приложение

**https://rubinshtein.online**

Логин и пароль администратора по умолчанию — `admin` / `admin`
(Redmine попросит сменить пароль при первом входе).

## Как всё устроено

```
                    https://rubinshtein.online
                              |
                              v
              Application Load Balancer (94.131.95.165)
                    обработчик listener1: 443 (HTTPS)
                              |
                  распределяет по порту 8080
                    |                     |
                    v                     v
            web1 94.131.84.114     web2 94.131.80.53
            ┌──────────────────┐   ┌──────────────────┐
            │ redmine   :8080  │   │ redmine   :8080  │
            │ redmine-db (PG)  │   │ redmine-db (PG)  │
            └──────────────────┘   └──────────────────┘
```

На каждом сервере поднимаются два контейнера в общей Docker-сети
`redmine_net`: сама Redmine и PostgreSQL. Данные лежат в именованных
Docker-томах, поэтому переживают перезапуск контейнеров.

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
| `playbook.yml` | плейбук: подготовка серверов (тег `setup`) и деплой (тег `deploy`) |
| `inventory.ini` | список серверов, группа `webservers` |
| `ansible.cfg` | инвентарь по умолчанию и путь к паролю от vault |
| `requirements.yml` | зависимости Ansible Galaxy: роли и коллекция |
| `group_vars/all/vars.yml` | открытые переменные |
| `group_vars/all/vault.yml` | секреты, зашифрованы `ansible-vault` |
| `templates/.env.j2` | шаблон файла переменных окружения для контейнеров |
| `Makefile` | команды установки, подготовки серверов и деплоя |

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

### 2. Положить пароль от vault

Секреты (пароль базы и `secret_key_base`) лежат в зашифрованном файле
`group_vars/all/vault.yml`. Чтобы Ansible смог их прочитать, создайте в корне
проекта файл `.vault_pass` с паролем одной строкой:

```bash
echo 'ваш_пароль_от_vault' > .vault_pass
chmod 600 .vault_pass
```

Файл добавлен в `.gitignore` и в репозиторий не попадает — пароль передаётся
отдельно от кода. Путь к нему прописан в `ansible.cfg`, поэтому все команды
`make` работают без дополнительных флагов.

### 3. Установить зависимости Ansible Galaxy

```bash
make install
```

Ставятся роли [geerlingguy.pip](https://galaxy.ansible.com/ui/standalone/roles/geerlingguy/pip/),
[geerlingguy.docker](https://galaxy.ansible.com/ui/standalone/roles/geerlingguy/docker/)
и коллекция [community.docker](https://galaxy.ansible.com/ui/repo/published/community/docker/).

Коллекция закреплена на ветке 4.x: версии 5.x требуют ansible-core 2.17 и новее.
Если у вас ansible-core 2.17+, ограничение в `requirements.yml` можно снять.

### 4. Проверить связь с серверами

```bash
make ping
```

Ожидаемый ответ по каждому хосту — `SUCCESS` и `"ping": "pong"`.

## Подготовка серверов

```bash
make setup
```

Команда сначала доустанавливает зависимости Galaxy, затем прогоняет плейбук
с тегом `setup`. Что появится на серверах:

- `python3-pip`;
- pip-пакет `docker` (Docker SDK for Python) — нужен модулям коллекции
  `community.docker`;
- Docker CE, CLI, containerd, buildx и compose-плагин из официального
  репозитория Docker;
- пользователь деплоя в группе `docker` (можно работать с Docker без `sudo`).

Достаточно выполнить один раз при создании серверов.

## Деплой приложения

```bash
make deploy
```

Команда запускает плейбук с тегом `deploy` — настройки серверов при этом
не меняются, разворачивается только приложение. Что происходит на каждом хосте:

1. создаётся каталог `/opt/redmine`;
2. из шаблона `templates/.env.j2` генерируется файл `/opt/redmine/.env`
   с переменными окружения (права `0600`);
3. создаётся Docker-сеть `redmine_net`;
4. запускается контейнер PostgreSQL, плейбук ждёт, пока он станет `healthy`;
5. запускается контейнер Redmine, порт `redmine_port` пробрасывается
   на порт 3000 внутри контейнера;
6. плейбук ждёт, пока приложение начнёт отвечать `200` по HTTP.

Оба контейнера читают переменные окружения через опцию `env_file`, то есть
пароли не видны ни в командной строке, ни в выводе Ansible.

Плейбук идемпотентный: повторный запуск не пересоздаёт контейнеры,
если ничего не изменилось (`changed=0`).

## Переменные

Открытые переменные — `group_vars/all/vars.yml`:

| Переменная | Значение | Описание |
| --- | --- | --- |
| `redmine_port` | `8080` | внешний порт контейнера Redmine на сервере |
| `redmine_dir` | `/opt/redmine` | каталог приложения, там лежит `.env` |
| `redmine_network` | `redmine_net` | Docker-сеть для контейнеров |
| `redmine_image` | `redmine:6.1` | образ приложения |
| `redmine_db_image` | `postgres:17-alpine` | образ базы данных |
| `redmine_db_name` | `redmine` | имя базы |
| `redmine_db_user` | `redmine` | пользователь базы |

Секреты — `group_vars/all/vault.yml` (зашифрован):

| Переменная | Описание |
| --- | --- |
| `vault_redmine_db_password` | пароль пользователя базы |
| `vault_redmine_secret_key_base` | ключ Redmine для подписи сессий |

В `vars.yml` они подключаются ссылками, например
`redmine_db_password: "{{ vault_redmine_db_password }}"` — сразу видно, что
значение приходит из vault.

Работа с секретами:

```bash
make vault-view   # посмотреть содержимое
make vault-edit   # отредактировать (откроется $EDITOR)
```

Пароль базы применяется только при первом создании контейнера PostgreSQL.
Если поменять его позже, старая база не примет новый пароль — придётся
удалить том `redmine_db_data` вместе с данными.

## Балансировщик и HTTPS

Перед серверами стоит Application Load Balancer с публичным IP
`94.131.95.165`. DNS-запись домена `rubinshtein.online` типа `A` указывает
на этот адрес.

Настройка балансировщика:

- **группа бэкендов** — две виртуальные машины, порт **8080** (совпадает
  с `redmine_port`), проверка живости — HTTP-запрос по пути `/` на порт 8080;
- **обработчик `listener1`** — порт **443**, тип «HTTP» (разбор трафика на
  уровне приложения), протокол **HTTPS**, к нему привязан сертификат домена;
- **HTTP-роутер `balancer-sg`** — направляет запросы в группу бэкендов;
- **группа безопасности** балансировщика разрешает входящие подключения
  на порты 80, 443 и служебный 30080 (проверки живости от самого сервиса
  балансировщика).

Порт обработчика и порт бэкенда задаются отдельно: снаружи балансировщик
слушает 443, а к серверам ходит на 8080.

Обработчик работает только по HTTPS. Веб-консоль не позволяет повесить два
обработчика на один публичный IP-адрес: занятый адрес не появляется в списке
при создании второго обработчика. Поэтому вместо добавления нового обработчика
исходный `listener1` был переведён с порта 80 (HTTP) на порт 443 (HTTPS) —
публичный адрес при изменении обработчика сохраняется.

### Сертификат

Сертификат для домена выпущен через Certificate Manager, провайдер —
Let's Encrypt, тип `Managed` (продлевается автоматически). Права на домен
подтверждены DNS-проверкой: в зону добавлена запись

```
_acme-challenge.rubinshtein.online. CNAME <идентификатор_сертификата>.cm.yacloudkz.tech.
```

Нужна только одна запись — CNAME **либо** TXT; если добавить обе сразу,
проверка не пройдёт. После выпуска сертификат выбирается в настройках
обработчика на порту 443.

## Проверка

Приложение на самих серверах:

```bash
curl -I http://94.131.84.114:8080/
curl -I http://94.131.80.53:8080/
```

Через балансировщик по домену:

```bash
curl -I https://rubinshtein.online/
```

Ожидается `200` и cookie `_redmine_session`.

Сертификат домена:

```bash
echo | openssl s_client -connect rubinshtein.online:443 \
  -servername rubinshtein.online 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

Посмотреть, что происходит на сервере:

```bash
ssh ubuntu@94.131.84.114 'docker ps; docker logs --tail 20 redmine'
```

Убедиться, что балансировщик распределяет запросы по обоим серверам, можно
сравнив количество запросов в логах за последние минуты:

```bash
ssh ubuntu@94.131.84.114 'docker logs --since 4m redmine | grep -c "Started GET"'
ssh ubuntu@94.131.80.53  'docker logs --since 4m redmine | grep -c "Started GET"'
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
- У каждого сервера своя независимая база данных. Для учебного проекта этого
  достаточно, но в реальной системе нужна одна общая база и общее хранилище
  файлов, иначе пользователь будет видеть разные данные в зависимости от того,
  на какой сервер его отправит балансировщик.
