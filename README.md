# backup
My backup concept using rsync and borg

## Use cases and motivation

Having many Linux machines around, some Raspberry PIs, Laptops for the wife and children, also some servers, a legacy PC that's for your own needs and some smart phones, the effort for organizing backups is really challenging. I tried to make a setup that enables to me get this done on all important data.

### What events need to be protected

Most likely people will only be affected by damaged HW or SW. To protect data loss from this failure, a single "backup copy" does the trick typically. You can do this on a raid server to have a high data availability or you can use a simple data storage, or use two of the simple ones. But all these things will be located at your home.

Now assume there is an event that destroys all your SW/HW at the same time. Perhaps a hacker that takes over all your machines. But there can also be more physical events like thefts, lightning strokes or, even worse, fire, earth quakes, ... nobody wants to think on all these impacts.

As it comes to security topic the meaning splits into many categories. One is to protect from data loss, another thing is to protect unauthorized access or an attack. The focus of my work is to protect from data loss. My home provides a certain safety against hackers, but you are free to add further measures to get also a better protection from any other impact.

Finally there is the human factor. You delete something you wanted to keep. You'll be happy to find your document in the backup, this is why backups need to be started regularly and automated.

### Ways out

The solution I found is to spread data around in the world. Depending on the importance you can perhaps find ways to store data even outside of the planet. I was happy to have my data just in another building not in the neighbourhood. 

How much spreading is required should not be discussed herein. You may book some storage at servers in the seas or get in contact with Elon Musk to put a server for you into the next car he shoots to space for fun. Many things are possible today and if you have enough money you'll find a suitable solution.

### Backup to the internet

Whatever you decide for as physical location, the data will be transferred through the internet as it leaves your home. It will be stored on some server in the world wide web.

As you store your data in the internet it also leaves the "protected" area of you home. So encryption becomes mandatory.

To take the task to put data to the martial WWW, I decided to go with [borg backup](https://borgbackup.readthedocs.io/en/stable), a deduplicating backup solution with initial cryptography support. It is based on a similar design as rsync where you need to run an instance of it on the server and on the client side if things shall become effective. 

### Storing data locally gives speed 

So, now we are already quite close. We found a nice backend for our backups. But if you start playing with it you find it to be slow. There are promising technologies for high bandwidth coming to the end users the last years, e.g. FTTH, but a server also has to serve many clients. So most likely the storage in the internet will be always significantly slower compared to what get for your home LAN. Also there is the encryption. If it is strong it is slow. At least if you try to find low cost solutions that fit to the budget of the non enterprise family.

Also, the internet backup is only there to protect from the worst cases. So most likely, you will suffer from broken HW/SW. In this case a local access to the data is what you want to have. It is fast, easy to access and cheap. The bigger the impact, the more effort you will need to put into recovering and the less the fact that your data is on a slow machine matters.

On Linux / Unix systems, people use rsync for local backups. Files can be accessed like normal files, so restoring single files is also simple to be done. Files can be searched also reasonable fast and a protection from accidentally deleted data can also be added. 

If you want to protect your data als from unwanted access, 

## The design

The idea is to go for a cache based setup. You have a local machine that acts as a backup cache. All your local clients push the data to this one machine using rsync. From there, you are pushing the data encrypted to the internet storage using borg backup.

I am using a [cubie truck](http://cubieboard.org/tag/cubietruck/) as backup cache. This is not really fast but in combination with rsync the local backups run within a few seconds. If you start working a lot with a huge amount of data, e.g videos or raw images, you'll have to go with somethings else. However, exceeding the performance of your network technology is most likely not worth the effort.

The major work is to set things up in a suitable way. Using 2 tools require 2 setups that have to be configured to operate together smoothly. I did this using some bash scripts, along with the configuration files needed for rsync. Little tools are there to help with maintenance and configuration.

One thing I was not able to solve as of now were the credentials needed for borg backup come from. I did not want to store them somewhere. This means these secrets need to be given manually each time you want to push data to the internet. That is not automated, I know. But the risk of cyber attacks is increasing and these credentials are the last barrier that protect your data from the dark side. Depending on your nature and habits, you may get this task integrated to your morning toilette, but perhaps a reminder with a Smart Phone App would be the better solution. As of now, I went not into this task.

One thing I really wanted to do it to make things centralized. So there needs to be some configuration on the individual clients, e.g. what to backup, but as it comes to the how things are working, I found it a good idea to fetch there things on each backup from the cache. As long as the format of the configuration on the clients fits to what is required by the scripts loaded from the cache, there is no need to spread information around.

### How data is mapped to rsync

Rsync is used in daemon mode using rsync modules to separate clients. This means, there is running a rsync instance listening on port 873. Nobody would recommend this on an machine connected to the internet. There are tons of warnings about non encrypted data transfer, weak access control and other security issues. However I do not think that this really applies to a server that is only used inside your home network. If you plan to push data into this infrastructure though the internet with a non VPN solution, this part has to be made in a different way.

Using the rsync as a daemon, different archives can be distinguished using rsync modules. These use typically a double colon based syntax. E.g. to check which modules your rsync daemon running at "backup-cache" host offers, you can use this command:

```
rsync backup-cache::
```

Each client for the backup is assigned an own module. So when a new client shows up, you will have to extend this list and "register" the new client with the cache. I gave this precedence over having a single "backup" module that is used by each client. First, this protects from accidentally mistakes, 2nd it provides some isolation of data. On the down side, a new module has to be added for each client.

Another module is there for keeping files that are used by all the clients. This is the centralized "repository". I also thought on storing the configuration of each client there, but I found it a bit unhandy. This module has to have the name "backup_config". It is configured as a read-only module, while all the others are configured as r/w modules. 

On the client module templates given, rsync is configured in a way that each file that disappears in the file system of the client but is still on the cache is not deleted but moved to a "deleted" area. Like this there is also a protection for accidentally deleted files. Intentionally, the delete files area is not recognized by borg backup. 

### Setup the rsync cache

1. Ensure rsync is installed on the cache, e.g. run ```sudo apt install rsync```.
1. For setting up the rsync cache, copy the cache/rsyncd.conf file to /etc on the cache. Adapt with the modules you need for your clients. You may use the file as is for first time setup, but you should start to create dedicated modules for your clients and kick out the ones from my configuration at the end. Also ensure that the file system path given in the modules is really present, at least for the "backup_config" module.
1. Run the rsync daemon, e.g. by running ```systemctl start rsync```. 
1. Verify that the rsync service is running with ```rsync localhost::```. Check also that it can be reached by the client machines via the network.
1. To ensure the rsync service is started automatically during booting, also enable the service by running ```systemctl enable rsync```
1. Give it a try and reboot the cache host and verify that the service is up again.
1. Install the file client/backup-to-cache.sh to the path of the "backup_config" rsync module. Ensure the file can be fetched from a client, e.g. run ```rsync backup-cache::backup_config/backup-to-cache.sh .``` where backup-cache is the name of the cache server.

### A new Linux client shows up, what to do?

1. Create a rsync module on the backup cache by adding a module at the /etc/rsycnd.conf. You most likely want to use the existing entries (not the one used for the configuration!!!) as a template. The last path component needs to be the same as the module name. Restart the rsync daemon and ensure the new module is provided.
1. Install the client configuration: Create the directory /etc/backup and put the files client/client.conf and client/backup.list to this place. Adapt the name of the cache host in the client.conf. Add the directories to backup in the backup.list. You may add per location options to rsync with each line. The example in the repository should show enough examples on how your backup can be configured individually.
1. Automate the backup to the cache: Copy the file client/backup to /etc/cron.daily and make it executable. Trigger a backup by running it manually with the same user as the cron service (most likely root). Fix errors.
1. Check that the data shows up as expected on the cache.
1. On the cache, add the new clients storage to the "backup_dir" list in borg_backup.sh script. This will recognize the new data source with the next backup to borg server. Run the borg_backup.sh script and verify that the data arrives at the borg server.

### Computers never forget

People say elephants or dogs never forger somebody. Good if it the animal has a good memories. Computers are not emotional but as data is not deleted it will become more and more which will rise cost for storage. Most likely, you will not remember a letter you wrote to the teacher of you child 5 years before as it felt sick. And as you remember inexact, are you organized well enough that you know where to look for the data in all your folders?

Yes or no, it is up to you to delete data. As a helper, there is the cache/borg_amnesia.sh provided that kicks out old data from your borg repository. This will delete each backup older than 2 years from the repository.

## The current state

The thing is working for me as is. Things can be enhanced everywhere, I know.

On client side the things are a bit nicer already and can be maintained quite easily. 

On backup cache, almost nothing is automated as of now. My configuration is found as is in this repo. There, some nice helpers would be really needed. E.g., I would really like to have some templates around that help setting up a new client. Also, getting this done from the client itself would be nice. 

I know, now there are web frontends and other ideas in you mind. Nice to have, but not doable with the time budget I was spending into it as of now. 

Also, there are no installation helpers provided as of now. As things need to be installed, the files need to be copied manually as described above.

As there is not too much automation around as of now, things are also quite transparent. The whole bash code is not more than ~250 lines of code. This is the positive side of being lightweight.

## TODOS

* Check to realize things on client on top of other projects, e.g. this one: https://pypi.org/project/rsync-system-backup/
* Python is so nice, why for hell did I start with bash? If a Python based client setup is used (from pypi), everything shall be converted into Python!
* On the cache, scan the rsync.conf from borg_backup.sh and fetch all the information on backup locations from there automatically. There is some information that is not given in the rsync.conf (the level). This shall be taken from a dedicated file. The module name shall be the common key for configurations. rsync seems to be robust against options it does not undestand in the rsycnd.conf. However, this leads to an error message on daemon start.
* As a follow up to the activity before, provide a template engine that creates the rsyncd.conf from a common configuration file and fills the common parts from a template. Provide a tool to update the rsyncd.conf and perhaps also check there configuration is read without errors.
* Is there a way to register a new client from a command run on the client itself- there is but does this make sense?
* The rsync cache will not be affected by the amnesia script. Also clean things from the deleted files rsync backups. 