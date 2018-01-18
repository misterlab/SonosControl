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


The current SonosControl.sh script was written against SoCo commit hash 0532bdc4f07918acfa289c493ed2ed2d2d0b6be5 of https://github.com/rahims/SoCo, and the following changes were made to a copy of examples/commandline/sonoshell.py included in SoCo. 

<pre>9c9
<     if (len(sys.argv) != 3):
---
>     if (len(sys.argv) < 3):
18a19,21
>     if (len(sys.argv) == 4):
>         track = sys.argv[3]
>
32a36,57
>         elif (cmd == 'get_speaker_info'):
>             print sonos.get_speaker_info()
>         elif (cmd == 'get_current_transport_info'):
>             all_info = sonos.get_current_transport_info()
>             for item in all_info:
>                 print "%s: %s" % (item, all_info[item])
>         elif (cmd == 'get_current_track_info'):
>             print sonos.get_current_track_info()
>         elif (cmd == 'getvolume'):
>             print sonos.volume()
>         elif (cmd == 'setvolume'):
>             print sonos.volume(int(track))
>         elif (cmd == 'getmute'):
>             print sonos.mute()
>         elif (cmd == 'muteon'):
>             print sonos.mute(bool("true"))
>         elif (cmd == 'muteoff'):
>             print sonos.mute(bool(""))
>         elif (cmd == 'clear_queue'):
>             print sonos.clear_queue()
>         elif (cmd == 'add_to_queue'):
>             print sonos.add_to_queue(track)
34a60,67
>         elif (cmd == 'play_uri'):
>             print sonos.play_uri(track, "test")
>         elif (cmd == 'partymode'):
>             print sonos.partymode()
>         elif (cmd == 'unjoin'):
>             print sonos.unjoin()
>         elif (cmd == 'join'):
>             print sonos.join(track)
45a79,81
>   elif (cmd == 'discover'):
>             sonosD = SonosDiscovery()
>             print sonosD.get_speaker_ips()
47c83
<             print "Valid commands (with IP): info, play, pause, stop, next, previous, current, and partymode"
---
>             print "Valid commands (with IP): info, get_speaker_info, get_current_transport_info, play, pause, stop, next, previous, current, and partymode"
</pre>

and the following changes made to soco.py:

<pre>diff --git a/soco.py b/soco.py
index 563632f..8753cc7 100755
--- a/soco.py
+++ b/soco.py
@@ -637,8 +637,8 @@ class SoCo(object):
         missing an album name. In this case track['album'] will be an empty string.

         """
-        response = self.__send_command(TRANSPORT_ENDPOINT, GET_CUR_TRACK_ACTION, GET_CUR_TRACK_BODY)
-
+        response = unicode(self.__send_command(TRANSPORT_ENDPOINT, GET_CUR_TRACK_ACTION, GET_CUR_TRACK_BODY), 'utf-8')
+        #print response
         dom = XML.fromstring(response.encode('utf-8'))

         track = {'title': '', 'artist': '', 'album': '', 'album_art': '',
@@ -982,7 +982,7 @@ class SoCo(object):

         soap = SOAP_TEMPLATE.format(body=body)

-        r = requests.post('http://' + self.speaker_ip + ':1400' + endpoint, data=soap, headers=headers)
+        r = requests.post('http://' + self.speaker_ip + ':1400' + endpoint, data=soap, headers=headers, timeout=2)

         return r.content
</pre>

I may revise this script in due course to work against the current SoCo/SoCo version.
