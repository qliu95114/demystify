# Script to covert Video/Audio by FFMPEG

## Requirements

1. **Install FFMPEG** : Best video/audio encoding tool on the planet. 
1. [**Install VB-CABLE Virtual Audio Device**](https://vb-audio.com/Cable/) : Screen-Recording with audio

## Scripts
1. ffmpeg.powershell.ps1 : batch file encoding from source folder to destination folder with selected profile (defined in ffmpeg_profile.json)
1. ffmpeg_wav2mp3.ps1 : convert *.wav to *.mp3 from source folder. 
1. video_header_trail_remove.ps1 : remove vidoe head/trail x seconds to save disk space, to avoid blank screen problem. It will re-encoding the file. 
1. screencapture_sample.txt : sample command of archiving "Playing Video" to local MP4 video file
1. getExtendedFileProperties.ps1 : Function Get-ExtendedProperties to read file meta data

## Sample - Screen capture

Get Video Duration (length)
```
.\getExtendedFileProperties.ps1 
((Get-ExtendedProperties .\xyz.h264-ggez.chs.eng.mp4)| where {$_.Property -eq "Length"}).Value
```

Get Video Duration (length) from *.mp4 in z:\Downloads\TV 
```
.\getExtendedFileProperties.ps1 
foreach ($i in (dir Z:\DOWNLOADS\tv\*.mp4)) {write-host "$($i.FullName),$(((Get-ExtendedProperties $i.FullName)| where {$_.Property -eq "Length"}).Value)" }
```

ScreenCapture Sample
```
ffmpeg -f gdigrab -framerate 30 -offset_x 2780 -offset_y 376 -video_size 1460x815 -show_region 1 -i desktop -f dshow -i audio="Microphone (Jabra Link 370)" output.mkv 

ffmpeg -f gdigrab -framerate 30 -offset_x 2780 -offset_y 376 -video_size 1460x815 -show_region 1 -i desktop -f dshow -i audio="CABLE Output (VB-Audio Virtual Cable)" output_realtek.mkv 

ffmpeg -list_devices true -f dshow -i dummy_rea

rem on screensize 1920x1080, edge full screen theater mode
set filename="D:\videocapture\Tech Talk.mp4"
ffmpeg -f gdigrab -framerate 30 -offset_x 365 -offset_y 210 -video_size 1170x665 -show_region 1 -i desktop -f dshow -i audio="Stereo Mix (Realtek High Definition Audio (Extension INF Test))" %filename%

#msit Play in 1920x1080 display 
ffmpeg -f gdigrab -framerate 30 -offset_x 365 -offset_y 210 -video_size 1170x665 -show_region 1 -i desktop -f dshow -i audio="CABLE Output (VB-Audio Virtual Cable)" %filename%

#OneDrive Play in 1920x1080 display Full Screen
set filename="D:\videocapture\Training.mp4"
ffmpeg -f gdigrab -framerate 30 -offset_x 200 -offset_y 182 -video_size 1515x848 -show_region 1 -i desktop -f dshow -i audio="CABLE Output (VB-Audio Virtual Cable)" %filename%

ffmpeg -f gdigrab -framerate 30 -offset_x 0 -offset_y 185 -video_size 2000x1200 -show_region 1 -i desktop -f dshow -i audio="CABLE Output (VB-Audio Virtual Cable)" %filename%

set filename="D:\videocapture\morningtraining.mp4"
ffmpeg -f gdigrab -framerate 30 -offset_x 145 -offset_y 116 -video_size 1628x916 -show_region 1 -i desktop -f dshow -i audio="CABLE Output (VB-Audio Virtual Cable)" %filename%


Full Screen 1920x1080
set filename="D:\videocapture\training.mp4"
ffmpeg -f gdigrab -framerate 30 -offset_x 0 -offset_y 0 -video_size 1920x1080 -show_region 1 -i desktop -f dshow -i audio="CABLE Output (VB-Audio Virtual Cable)" %filename%
```

## Sample - Extract audio to mp3
```
ffmpeg -i input.mp4 -vn -acodec libmp3lame -q:a 3 output.mp3
ffmpeg -i input.mp4 -vn -ss 00:43:01.000 -to 00:45:25.000 -acodec libmp3lame -q:a 3 -f mp3 output.mp3
```

- `-i input.mp4`: This specifies the input file, in this case, `input.mp4`. Replace `input.mp4` with the path and name of your actual MP4 file.
- `-vn`: This option tells FFmpeg to disable video processing and only extract the audio.
- `-acodec libmp3lame`: This specifies the audio codec to be used, which is `libmp3lame` for MP3 encoding.
- `-q:a 3`: This sets the audio quality. The value ranges from 0 (best) to 9 (worst), with 4 being a good balance between quality and file size.
- `output.mp3`: This specifies the output file name. Replace `output.mp3` with the desired name for your MP3 file.
- `-ss -to` : This specifies the start , end timestamp of source file input.mp4
 
## Sample - Extrat Subtitle to SRT

```
extrat one srt
ffmpeg -i input.mp4 -map 0:s:0 output.srt

for /f "delims=" %a in ('dir /b /o *.mp4') do ffmpeg -i %a -map 0:s:0 %~na.chs.srt
```

## Sample - Shift Time of Subtitle
```
ffmpeg -itsoffset -00:01:33 -i .\srt\xyz.srt -c copy .\fix\xyz.srt

for /f "delims=" %a in ('dir /b /o *.srt') do ffmpeg -itsoffset -00:01:33 -i .\%a -c copy .\%~na.chs_cut.srt
```
- `00:01:33` : delay 93 seconds
- `-00:01:33` : delay -93 seconds

## Sample - Remove all subtitle from video
```
ffmpeg -i %a -map 0 -map -0:s -c copy .\nosub\%a
```
- `-map -0:s` : remove all subtitle

## Sample - Merge subtitle + mp4 to a single file
```
rem merge one subtitle + one mp4
for /f "delims=" %a in ('dir /b /o C:\temp\*.mp4') do ffmpeg -i I:\temp\%a -i C:\temp\%~na.chs.srt -c:v copy -c:a copy -c:s mov_text "C:\TV.asia\New\%a"

rem add meta data 
for /f "delims=" %a in ('dir /b /o C:\temp\*.mp4') do ffmpeg -i I:\temp\%a -i C:\temp\%~na.chs.srt -c:v copy -c:a copy -c:s mov_text -metadata:s:s:0 language=chs -metadata:s:s:0 title="Chinese" "C:\TV.asia\New\%a"

rem merge multiple subtitle + one mp4
for /f "delims=" %a in ('dir /b /o C:\temp\*.mp4') do ffmpeg -i C:\temp\%a -i C:\temp\%~na.chs.srt -i C:\temp\%~na.cht.srt -i C:\temp\%~na.eng.srt -map 0:v -map 0:a -map 1 -map 2 -map 3 -c:v copy -c:a copy -c:s mov_text "C:\TV.asia\New\

```

## Sample - make video more smooth
```
-vf "minterpolate='mi_mode=mci:mc_mode=aobmc:vsbmc=1:fps=120:me=fss'"

-vf "minterpolate='mi_mode=mci:mc_mode=aobmc:me_mode=bidir:fps=60'" 

```
