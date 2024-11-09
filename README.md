# immich-datetime-fix
This repository contains a shell script that prepares files without the necessary tags for an import to the photos app "immich". It adds the tag "DateTimeCreated" based on the last inode change of the file, which is usually available, even if the camera didn't put additional Exif datetime information.
