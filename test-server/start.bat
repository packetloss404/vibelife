@echo off
set JAVA_HOME=C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot
"%JAVA_HOME%\bin\java" -Xms1G -Xmx2G -jar paper.jar --nogui
pause
