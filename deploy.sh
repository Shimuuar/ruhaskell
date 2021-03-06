#!/bin/bash
set -eux -o pipefail
# Скрипт для для обновления сайта на GitHub Pages.

echo "Собираем новую версию сайта..."
./just_build.sh

# запоминаем сообщение текущей ревизии
commit_message="$(git log --format=%B HEAD^1..HEAD)"

(
    cd _site
    git init
    git remote add source ..
    git fetch source

    echo "Создаём коммит из _site..."
    git add .
    git write-tree                          | xargs \
    git commit-tree                                 \
        -p source/gh-pages -p source/master         \
        -m "$commit_message" `: tree id :`  | xargs \
    git checkout --quiet `: commit id :`

    echo "Копируем коммит в оригинальный репозиторий..."
    git push source HEAD:gh-pages
)

echo "Публикуем gh-pages на сервере..."
git push --force origin gh-pages:gh-pages

echo "Готово!"
