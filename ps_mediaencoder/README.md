# Script sample covert Movie by FFMPEG

## Requirements

1. Install FFMPEG , best encoding tool
1. Install VB-CABLE Virtual Audio Device. https://vb-audio.com/Cable/  , Screenrecording with audio

## Scripts
1. ffmpeg.powershell.ps1 : batch file encoding from source folder to dest folder with select profile (defined in ffmpeg_profile.json)
1. video_header_trail_remove.ps1 : remove vidoe head/trail x seconds to save disk space. 
1. screencapture_sample.txt : sample command of archive playing video to local *.mp4 file