**Set Java Environment**

setx JAVA\_HOME "C:\\Program Files\\Java\\jdk-21" /M



-setx is the Windows tool that creates or modifies environment variables in the user or system environment.

-The /M flag writes the change to the system‑wide environment (for all users) instead of only the current user.



**Flutter Debug**
flutter clean

flutter pub get

flutter run



**Setup Firebase**

(first download nodejs)

\[cmd]
node -v

npm -v

npm install -g firebase-tools (-g means global, install for the whole system, not only project)



\[project terminal]

firebase --version

firebase login

firebase projects:list



**Add/Connect Flutterfire**

add to path environment variable (to use at cmd and others CLI):
C:\\Users\\ahmad\\AppData\\Local\\Pub\\Cache\\bin \[@or] %LOCALAPPDATA%\\Pub\\Cache\\bin



type dlm terminal project vscode:

\[project terminal]

flutterfire configure

(spacebar to select or unselect then enter)



**Gradle Version Mismatch Fix**
C:\\Users\\ahmad\\AppData\\Local\\Pub\\Cache\\hosted\\pub.dev\\mobile\_scanner-7.1.3\\android\\gradle\\wrapper

open file gradle-wrapper.properties

edit line> distributionUrl=https\\://services.gradle.org/distributions/gradle-8.13-bin.zip

(this change gradle version to compatible version)

flutter pub get

flutter run

flutter devices

