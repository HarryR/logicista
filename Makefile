all:

deploy:
	jekyll build
	rsync -avze ssh _site/ dave:/srv/www/logicista.com/html/

runserver:
	jekyll serve -w -H 0.0.0.0 -P 8080
