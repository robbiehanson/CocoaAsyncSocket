INFO:

This project demonstrates password protecting a specific resource. More specifically, the project allows unrestricted access to the ~/Sites folder, but requires a password for anything in the ~/Sites/secret/ subfolder.

INSTRUCTIONS:

Create the following folder:
~/Sites/secret

And then add a file to it. For example:
~/Sites/secret/doc.txt

Open the Xcode project, and build and go.

On the Xcode console you'll see a message saying something like:
"Started HTTP server on port 59123"

_The actual port the server uses is not hard-coded. You can hard-code it if you want, but by default it will just allow the operating system to provide an available port._

Now open your browser and type the URL (replacing with the proper port):<br/>
http://localhost:59123

Notice that it displays your file without password prompt:<br/>
~/Sites/index.html

Now type the URL (replacing with password prompt):<br/>
http://localhost:59123/secret/doc.txt

Notice that it prompts you for a username/password.
The sample code accepts any username, and the password is "secret".

(Replace 59123 with whatever port the server is actually running on.)

Enjoy.