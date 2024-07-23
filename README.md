# Via-profit automatic backup script

- This script performs automatic backups of given folder on any Linux-like OS
- Also perform automatic backup of Postgresql database if its needed
- Automatic backup rotation are included
- Logging with logs rotation are also included

## Instalation

1. Just clone this repository into any of your server folder by running

```bash
$ mkdir ~/utils
$ cd ~/utils
$ git clone git@github.com:via-profit/via-profit-backups.git
$ cd via-profit-backups 
```

2. Copy and paste `.env.example` > `.env` by running

```bash
$ cp ./.env.example .env
```

3. Modify config .env file using given tips. Set up `$TOKENS` variable and fill settings in the section below

4. If you want to exclude some files from the backup. Copy and paste `.backup.exclude.example` into the folder where you will be backing up. Rename this file to `.backup.exclude`. And write down in a file the names of the directories/files you want to exclude

```bash
$ cp ./.backup.exclude.example ~/the/backing/up/folder/.env
```

And we are ready to go

## Running
This script is designed to work with crontab, but you can run it manually by running the command in the console.

```bash
$ sh ./via-profit-backup.sh
```

If you want that script makes automatic backup you should create a crontab task by running
```bash
    
```
