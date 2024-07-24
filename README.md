# Via-profit automatic backup script

- This script performs automatic backups of given folders on any Linux-like OS
- Also perform automatic backup of Postgresql database if its needed
- Automatic backup rotation are included
- Logging with logs rotation are also included

## Instalation

1. Just clone this repository into any of your server folder by running

```bash
$ mkdir ~/utils
$ cd ~/utils
$ git clone https://github.com/via-profit/via-profit-backups.git
$ cd via-profit-backups 
```

2. Copy and paste `.env.example` > `.env` by running

```bash
$ cp ./.env.example .env
```

3. Modify config `.env` file using given tips. Set up `$TOKENS` variable and fill settings in the section below

4. If you want to exclude some files from the backup. Copy and paste `.backup.exclude.example` into the folder where you will be backing up. Rename this file to `.backup.exclude`. And write down in a file the names of the directories/files you want to exclude

```bash
$ cp ./.backup.exclude.example ~/the/backing/up/folder/.env
```

5. Add execution permition to script file by running

```bash
$ chmod u+x ~/utils/via-profit-backups/via-profit-backups.sh
```

And we are ready to go

## Running
### Manual running
This script is designed to work with crontab, but you can run it manually by running the command in the console

```bash
$ sh ./via-profit-backups.sh
```

### Crontab running
If you want the script to make automatic backups, you should create a cron job by running

```bash
$ crontab -e
```

or if you want to backup multiple users you should run this script from `root` user 

```bash
$ sudo crontab -e
```


Write down a cron job to the opened file

```
30 02 * * * /bin/bash -c "/home/bablo/Projects/via-profit-backup/via-profit-backups.sh"
```

> The time pattern is `Minutes Hours Days Month Year`. So `30 02 * * *` Means that script will be running daily at 02:30 
