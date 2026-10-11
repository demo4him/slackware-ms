2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
	
#!/bin/sh
 
# Update the X font indexes:
if [ -x /usr/bin/fc-cache ]; then
  echo "Updating X font indexes:  /usr/bin/fc-cache -f &amp;"
  /usr/bin/fc-cache -f &amp;
fi
 
# Update any existing icon cache files:
if find /usr/share/icons 2&gt; /dev/null | grep -q icon-theme.cache ; then
  for theme_dir in /usr/share/icons/* ; do
    if [ -r ${theme_dir}/icon-theme.cache ]; then
      echo "Updating icon-theme.cache in ${theme_dir}..."
      /usr/bin/gtk-update-icon-cache -t -f ${theme_dir} 1&gt; /dev/null 2&gt; /dev/null &amp;
    fi
  done
  # This would be a large file and probably shouldn't be there.
  if [ -r /usr/share/icons/icon-theme.cache ]; then
    echo "Deleting icon-theme.cache in /usr/share/icons..."
    #/usr/bin/gtk-update-icon-cache -t -f /usr/share/icons 1&gt; /dev/null 2&gt; /dev/null &amp;
    rm -f /usr/share/icons/icon-theme.cache
  fi
fi
 
# Update mime database:
if [ -x /usr/bin/update-mime-database -a -d /usr/share/mime ]; then
  echo "Updating MIME database:  /usr/bin/update-mime-database /usr/share/mime &amp;"
  /usr/bin/update-mime-database /usr/share/mime 1&gt; /dev/null 2&gt; /dev/null &amp;
fi