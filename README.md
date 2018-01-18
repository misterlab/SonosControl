# SonosControl
Script for integration of SoCo python library with IFTTT

No direct intergration exists between IFTTT and Sonos at time of writing, so I have put together an alternative approach that makes use of the <a href="https://github.com/SoCo/SoCo">SoCo python library</a>, <a href="www.dropbox.com">Dropbox</a> and <a href="https://www.noodlesoft.com">Hazel</a>.

My use case is that I want to play/pause Sonos when I arrive/leave my house. To accomplish this, I use a combination of the IFTTT iOS location and Dropbox applets to create a new text file in a speficied Dropbox location (IFTTT/SonosControl) when I enter/leave a specified geo-location (my house) e.g. play.txt, pause.txt.

The text file is synchronised to my computer using Dropbox, and when Hazel sees a new file it first moves it to the trash bin before calling a bash script <a href="https://github.com/misterlab/SonosControl">(available on github.com)</a> which invokes the SoCo python library to control Sonos.

The overall approach and bash script I've thrown together isn't perfect, but has done what I've needed which is to:

<ul>

<li>Cater for multiple people (distinguished by file name e.g. play_person1.txt, play_person2.txt)</li>

<li>Dynamically determine all available players</li>

<li>Persist the state of each player so the same content can be resumed</li>

</ul>
