---
author: Денис Шевченко
title:  Nix и Haskell: первая встреча
tags:   Nix, Haskell
description: Продолжаем разбираться с Nix, теперь уже в свете нашего любимого языка. Давайте уже создадим что-нибудь!
---

Всем привет!

[Попробовав Nix на вкус](http://ruhaskell.org/posts/utils/2015/11/26/nix-hello-world.html), идём далее. Хватит играться с `vim`, давайте уже приступим к нашему любимому Haskell!

## Готовимся

Для начала нам понадобится `cabal-install`, без него никак:

```bash
$ nix-env -iA nixos.pkgs.cabal-install
```

**ПОЯСНЕНИЕ**: В рамках данного цикла статей я не планирую использовать `stack`.

Готово. Посмотрим, что же у нас получилось, заглянем в окружение:

```bash
$ ls -al /nix/var/nix/profiles/per-user/demo/profile-4-link/bin/
... cabal -> /nix/store/n3dw12h5w0pm3001f5645xqsnqrsv42z-cabal-install-1.22.6.0/bin/cabal
...
... vim -> /nix/store/yblqgyrn4jgwfg89qp9041i0n2z26v5b-vim-7.4.827/bin/vim
```

Естественно, окружение расширилось, теперь мне доступны обе команды, `vim` и `cabal`.

Второй инструмент, который нам понадобится, это `cabal2nix`:

```bash
$ nix-env -iA nixos.pkgs.cabal2nix
```

Готово. Назначение этого инструмента я поясню ниже.

Ну хорошо, давайте уже что-нибудь сотворим!

## hello

Создадим простейшую программу и назовём её "hello":

```bash
$ cd

$ cabal init
Config file path source is default config file.
Config file /home/demo/.cabal/config not found.
Writing default configuration to /home/demo/.cabal/config
cabal: The program 'ghc' version >=6.4 is required but it could not be found.
```

Так, стоп, `ghc` же у нас есть вроде. Проверяем:

```bash
$ ghc
ghc: command not found
```

Нет, нету. Установим:

```bash
$ nix-env -iA nixos.pkgs.ghc
installing ‘ghc-7.10.2’
building path(s) ‘/nix/store/m209df88gnyqmlczk8g29mwvcbiwbmd0-user-environment’
created 62 symlinks in user environment

$ ghc --version
The Glorious Glasgow Haskell Compilation System, version 7.10.2
```

Ок, как вы уже поняли, никакой установки не было, просто появились новые символьные ссылки в моём профиле.

Возвращаемся к проекту. Прохожу диалог с `cabal init`, всё как обычно, в результате чего получаю простейший проектик:

```bash
$ tree
.
├── hello.cabal
├── LICENSE
├── Setup.hs
└── src
    └── Main.hs

1 directory, 4 files
```

Никаких зависимостей, кроме как от `base`, никакой полезной работы, кроме вывода строки "hello". Всё стандартно и примитивно.

## Nix-ификация

А вот теперь начинается самое интересное. Давайте сделаем нашу программку Nix-пакетом. Но вначале необходимо определиться с понятиями.

Когда мы говорим о Nix-пакетах, это отнюдь не то же самое, что, например, `deb`-пакеты. Как вы уже помните, в основе Nix лежит чисто-функциональных подход к управлению пакетами. Но что ещё важно, Nix - это и особый язык программирования! И когда мы говорим о создании Nix-пакета, мы на самом деле подразумеваем написание маленькой программки на языке Nix. Результатом выполнения этой маленькой программки и будет наш пакет! Это примерно как в [Hakyll](http://jaspervdj.be/hakyll/): чтобы построить статический сайт, нужно написать программу на Haskell, результатом выполнения которой и будет наш сайт.

Язык Nix похож на Haskell, но это не Haskell. Чрезмерно углубляться в детали его синтаксиса мы не станем, тем более что есть уже [отличная статья об этом](https://medium.com/@MrJamesFisher/nix-by-example-a0063a1a4c55#.1aal323q4) (я уже не говорю про [исчерпывающее официальное руководство](http://nixos.org/nix/manual/#ch-expression-language)). Будем вникать в этот язык настолько, насколько это необходимо.

Та самая маленькая программка на языке Nix, на основе которой будет построен наш будущий пакет, должна сохраняться в файле `default.nix`. Строго говоря, имя файла может быть и другим, но по умолчанию ожидается именно такое имя.

Ок, но как же мы её напишем? Да вот так и напишем:

```nixos
{ pkgs ? import <nixpkgs> {} }:

let command = name: pathToNix: 
        pkgs.runCommand name {} ''
            ${pkgs.cabal2nix}/bin/cabal2nix ${pathToNix} > $out
        '';

    haskellPackages = pkgs.haskellPackages.override {
        overrides = self: _: {
            hello = self.callPackage (command "hello.nix" ./.) {};
        };
    };
in haskellPackages.hello
```

Пока просто скопируйте это содержимое в файл `default.nix`. Я специально не стану рассказывать вам о содержимом этого файла, потому что этот вопрос заслуживает одной из будущих статей. Лишь обратите внимание на команду `cabal2nix`: вот для чего нужна была установка `cabal2nix`, о которой упомянуто ранее.

Теперь, когда у нас есть программка на языке Nix, нам нужно её собрать и запустить. Но поскольку Nix не является компилируемым языком, нам следует всего лишь передать её на вход команды `nix-build` - и работа будет сделана. Делается это так:

```bash
$ nix-build --dry-run
```

Обратите внимание, что имя `.nix` файла не передаётся команде явно. Вот почему нужно было назвать его `default.nix`: команда `nix-build` ищет в текущем каталоге файл именно с таким именем.

Вы спросите, а зачем нужен `--dry-run`? Это - холостой прогон, ничего в действительности не строящий, а лишь показывающий, что *произойдёт* при постройке. И вот что он нам покажет:

```bash
building path(s) ‘/nix/store/7pxxlhd1ypzikqmznh67igp7vabrlk5w-hello.nix’
these derivations will be built:
  /nix/store/ir5ig6dn02arjwbnkx6m008m3rqa97n2-hello-0.1.0.0.drv
```

То, что нам и нужно! Когда мы запустим эту команду по-настоящему, наш проектик станет частью `/nix/store/`, как и все остальные пакеты! Сделаем же это:

```bash
$ nix-build
```

Сборка завершится, а последней строкой будет вот что:

```bash
/nix/store/jkq9ynd6zsz9rbl1rjb7dbm0rg9dimkb-hello-0.1.0.0
```

Проверим:

```bash
$ ls /nix/store/jkq9ynd6zsz9rbl1rjb7dbm0rg9dimkb-hello-0.1.0.0/bin/
hello
```

Оно. А теперь пробуем запустить нашу программку:

```bash
$ hello
hello: command not found
```

Хм... Установить установили, а запустить не можем. К счастью, в каталоге проекта появилась специальная символьная ссылка `result`. Именно она и ведёт к нашей программке. Убедимся в этом:

```bash
$ ls -al result
... result -> /nix/store/jkq9ynd6zsz9rbl1rjb7dbm0rg9dimkb-hello-0.1.0.0
```

Тот самый хэш. Таким образом, можем запускать следующим образом:

```bash
$ ./result/bin/hello 
hello
```

Победа.

Итак, теперь наш пакетик является частью `/nix/store/`, и поэтому его содержимое теперь неизменно аки египетские пирамиды:

```bash
$ cd /nix/store/jkq9ynd6zsz9rbl1rjb7dbm0rg9dimkb-hello-0.1.0.0/bin/

$ mv hello hello_
mv: cannot move ‘hello’ to ‘hello_’: Read-only file system
```

Да, но что же будет, если мы продолжим разработку нашего проекта? Ну, скажем, изменим выводимую на консоль строку. Откроем `src/Main.hs` и напишем:

```haskell
main :: IO ()
main = putStrLn "Hi, Nix world!"
```

Если мы заново соберём этот проект командой `nix-build` и запустим через `result`, мы увидим новую строку, как и ожидается. Но тут возникает вопрос: если там, в `/nix/store/`, проект неизменен, как же произошло обновление? Давайте заглянем:

```bash
$ ls /nix/store/ | grep hello
...
jkq9ynd6zsz9rbl1rjb7dbm0rg9dimkb-hello-0.1.0.0
bv51yc31qb70mdb6yzqxsi079ywhrspm-hello-0.1.0.0
...
```

Как видите, пакетов стало два, и ссылка `result` ведёт теперь на последнюю, свежую сборку. Вспомните чисто-функциональный подход: значение, будучи однажды созданным, уже не может быть изменено.

Вы спросите, как же быть с накоплениями? Ведь мы, может быть, сделаем сто правок кода, прежде чем перейдём на следующую версию проекта. Это что же, у нас в хранилище появится сто сборок версии `0.1.0.0` с разными префиксами?! Да, именно так. Но вспомните про сборку мусора. Выполним знакомую нам команду:

```bash
$ nix-collect-garbage -d
```

и тогда всё старьё уничтожиться, а останется лишь самая последняя сборка, на которую и ведёт ссылка `result`. Таким образом, если вдруг мы осознали, что наша программа не должна быть частью нашей системы - ну не знаю, передумали её делать - её очень просто удалить. Нужно всего лишь удалить ту самую символьную ссылку `result`, а затем повторно выполнить команду `nix-collect-garbage -d`. Всё, программы в хранилище больше нет.

## Заключение

Вот наше первое знакомство с Haskell-разработкой в среде Nix. В следующих статьях мы продолжим наше Nix-путешествие и узнаем ещё очень много интересного.