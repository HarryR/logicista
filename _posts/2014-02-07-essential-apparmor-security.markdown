---
layout: post
title:  Essential AppArmor Security
date:   2014-02-07 00:00:00
categories: [security, apparmor, linux, firewall, hardening, exploit, server, devops, sysadmin]
coverimage: /img/posts/peacock.jpg
covertitle: Peacock Feathers by Johan J.Ingles-Le Nobel
---

The first port of call in most people's efforts to secure a server are to install a firewall; explicitly defining what is allowed to connect and be connected to is a well understood security practice, but what about application level firewalls?

[AppArmor](http://en.wikipedia.org/wiki/AppArmor) allows you to employ the same concepts used in network and web application firewalls on a system-call level. By confining an application's access to resources you can mitigate or completely nuke the impact of a successful exploit, a great example would be somebody managing to get a shell on a server only to find out they can't run any commands or access any files other than the bare minimum necessary for the applicaiton to run.

The Ubuntu project has excellent support for AppArmor, but sadly only a few very frequently used applications have security profiles provided for them leaving the rest of the work upto you and me.

I think the process of auditing and understanding exactly which resources a well behaving system requires access to and the security advantages obtained through locking down services with AppArmor outweighs the labour involved to configure everything.

Security is a tricky subject because it deals with speculative mitigation of risk versus the cost of compromise, something can be proven to be insecure, but never proven to be secure.

## Getting Started

On a modern Linux system one can add the `Z` flag to `ps` to add an additional column which displays the AppArmor profile the process is running confined to, it can also be used to highlight which processes are completely unconfined, as such:

```
$ ps auxZ | grep -v '^unconfined'
```

Imagine your shock and horror after auditing a network to find that every computer had many publicly accessible services, all of which could be used to further compromise the entire system. To first understand the abilities and power of AppArmor we must confine one hand within a familiar environment while the other is free to tinker with the properties of the confinement.

The best way to do this is to setup a restricted shell for a new user that can be used for experiments, because AppArmor works on a per-executable basis this involves copying `bash` to a new location.

```
$ cp /bin/bash /bin/armorshell
$ echo /bin/armorshell >> /etc/shells
$ useradd -m -s /bin/armorshell armortest
$ passwd armortest
```

The next stage is to generate and refine a profile, Ubuntu provides a utility called `aa-genprof` in the `apparmor-utils` package which will analyse the programs behaviour and will prompt you with options to aid in creating a profile. While running `aa-genprof` you must login to the shell and logout to create a baseline, the process is fairly self explanitory.

```
$ aa-genprof /bin/armorshell
``` 

After scanning and saving the profile it will be loaded and available in `/etc/apparmor.d/bin.armorshell`, the process isn't perfect and will often leave you with an environment that doesn't warns of permissions problems, in my case I could login but couldn't execute any sub commands. At this stage you must learn the syntax of the AppArmor profile file and tune it to meet your needs.


## Making it Work?

The `aa-genprof` tool has it's problems, while it does identify some capabilities like reading and writing files it doesn't output any profiles which allow you to execute commands and in some cases can give misleading results. The question arises, why can't we execute programs, and why does logging in result in a slew of permissions errors like the following when they're all readable in the profile?

```
-armorshell: /usr/bin/groups: Permission denied
-armorshell: /bin/ls: Permission denied
-armorshell: /usr/bin/lesspipe: /bin/sh: bad interpreter: Permission denied
-armorshell: /usr/bin/dircolors: Permission denied
-armorshell: /bin/ls: Permission denied
```

To solve these problems the profile must be modified to include execute permissions for these programs, AppArmor has several different modes, the simplest of which is `ix` or inherit execute - the executed program will execute in the same profile as the shell. The reason execution was failing and giving a `Permission denied` error is that AppArmor's default behaviour is to look for and switch to the profile specific to the new program, if it doesn't exist then the operation is denied.

The result, after modification should be similar to the following:

```
/bin/armorshell {
  #include <abstractions/base>

  /bin/armorshell mr,
  /bin/bash rix,
  /bin/lesspipe rix,
  /bin/ls rix,
  /bin/sed rix,
  /dev/tty rw,
  /etc/bash.bashrc r,
  /etc/bash_completion.d/ r,
  /etc/bash_completion.d/* r,
  /etc/group r,
  /etc/init.d/ r,
  /etc/inputrc r,
  /etc/nsswitch.conf r,
  /etc/passwd r,
  /etc/profile r,
  /etc/profile.d/ r,
  /etc/profile.d/*.sh r,
  /home/armortest/ r,
  /home/armortest/.bash_history rw,
  /home/armortest/.bash_logout r,
  /home/armortest/.bashrc r,
  /home/armortest/.profile r,
  /proc/filesystems r,
  /proc/meminfo r,
  /usr/bin/basename rix,
  /usr/bin/clear_console rix,
  /usr/bin/dircolors rix,
  /usr/bin/dirname rix,
  /usr/bin/groups rix,
  /usr/share/bash-completion/* r,
}
```

While this is not a complete how-to guide it should serve as a good starting point, it was relatively easy to confine publicly and internally accessible services such as nginx, Postfix and MySQL.

## Further Reading

 * [AppArmor Core Policy Reference](http://wiki.apparmor.net/index.php/AppArmor_Core_Policy_Reference)
 * [Introducing the AppArmor Framework](http://www.novell.com/documentation/apparmor/book_apparmor21_admin/data/sec_aa_whatimm_tools.html)

-------------------

[Header image](http://www.flickr.com/photos/jingleslenobel/8540120792/) by [Johan J.Ingles-Le Nobel](http://www.flickr.com/photos/jingleslenobel/)