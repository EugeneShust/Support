del %~dp0res.txt
del %~dp0sig.bin

openssl base64 -d -in %~dp0sig.pem -out %~dp0sig.bin
openssl dgst -verify %~dp0PK.pem -signature %~dp0sig.bin %~dp0rec.txt >> %~dp0res.txt

del %~dp0rec.txt
del %~dp0sig.pem