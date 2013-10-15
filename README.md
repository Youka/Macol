## Add tags
<img src="http://a.imageshack.us/img507/5705/addtags.jpg" /><br/>
Adds tags to selected lines or chosen style.
## Position shifter
<img src="http://a.imageshack.us/img828/993/positionshifter.jpg" /><br/>
Shifting position values.
## Acceleration
<img src="http://a.imageshack.us/img837/4250/accelerationinput.jpg" /><br/>
Splits line into frames with changing tag values to allow accelerated moves, vector clip transform, etc.
## Jitter
<img src="http://img585.imageshack.us/img585/4034/jitterselect.png" /><img src="http://img837.imageshack.us/img837/1298/jitterrandom.jpg" /><br/>
Splits selected lines into frames and changes \pos to realize jittering (in random or selected directions).
## Sort
<img src="http://img195.imageshack.us/img195/8155/sort.jpg" /><br/>
Sorts dialog lines by selection.
## Karaoke fix
<img src="http://img838.imageshack.us/img838/4980/karaokefix.jpg" /><br/>
Fixes problems in karaoke time:
- Removes sylables with 0ms duration
- Removes first/last sylables, if they have no text
- Adjusts line start times (considers remove of first sylable) and end times (considers sum of sylable times) [ignores lines without sylables]

## Audio
<img src="http://img850.imageshack.us/img850/5469/audioc.png" />
Reads a WAVE file with PCM s16 data (CD profile) and writes dialog lines to present the amplitudes or magnitudes. Shape size and frame duration is configurable, further changes can be done afterwards like time shifting, style change or override tags addition.
