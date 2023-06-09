:: Assumes running from MountTracker\build
mkdir out\MountTracker
copy ..\extension.xml out\MountTracker\
copy ..\readme.txt out\MountTracker\
copy ..\"Open Gaming License v1.0a.txt" out\MountTracker\
mkdir out\MountTracker\campaign
copy ..\campaign\ct_client.xml out\MountTracker\campaign\
copy ..\campaign\ct_host.xml out\MountTracker\campaign\
mkdir out\MountTracker\graphics\icons
copy ..\graphics\icons\letter-c-icon-18-32.png out\MountTracker\graphics\icons\
copy ..\graphics\icons\letter-d-icon-18-32.png out\MountTracker\graphics\icons\
copy ..\graphics\icons\letter-u-icon-18-32.png out\MountTracker\graphics\icons\
copy ..\graphics\icons\mount_icon.png out\MountTracker\graphics\icons\
copy ..\graphics\icons\white_mount_icon.png out\MountTracker\graphics\icons\
mkdir out\MountTracker\scripts
copy ..\scripts\ct_client_ct_entry.lua out\MountTracker\scripts\
copy ..\scripts\ct_host_ct_entry.lua out\MountTracker\scripts\
copy ..\scripts\mounttracker.lua out\MountTracker\scripts\
cd out
CALL ..\zip-items MountTracker
rmdir /S /Q MountTracker\
copy MountTracker.zip MountTracker.ext
cd ..
explorer .\out
