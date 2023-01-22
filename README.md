# docker-wine

>Docker image that includes Wine (no Winetricks) for running Windows applications on Linux

This is a stripped version of https://github.com/scottyhardy/docker-wine which does **not** contain an _rdp server_. Also _winetricks_ and _pulseaudio_ were ommitted because I don't need it.
Furthermore, if you are running only 32-bit application, you can save another >600MB by simply removing 64-bit wine files with build-arg "DEL_64BIT=true". Then the resulting image is 1.56GB.

This image is intended to be used for headless builds of Windows applications, still containing xvfb to run applications that require UI.

For setup and testing, I suggest to use scottyhardy's image, and then you may switch to this image of smaller size.
