--- ltmain.sh	Wed Apr 17 06:03:51 2002
+++ ltmain.sh	Mon Sep 23 04:27:32 2002
@@ -2894,7 +2894,23 @@
 	if test -n "$export_symbols" && test -n "$archive_expsym_cmds"; then
 	  eval cmds=\"$archive_expsym_cmds\"
 	else
+	  if test "x$verstring" = "x0.0"; then
+	    tmp_verstring=
+	  else
+	    tmp_verstring="$verstring"
+	  fi
+	  save_deplibs="$deplibs"
+	  for conv in $convenience; do
+	    tmp_deplibs=
+	    for test_deplib in $deplibs; do
+	      if test "$test_deplib" != "$conv"; then
+	        tmp_deplibs="$tmp_deplibs $test_deplib"
+	      fi
+	    done
+	    deplibs="$tmp_deplibs"
+	  done
 	  eval cmds=\"$archive_cmds\"
+	  deplibs="$save_deplibs"
 	fi
 	save_ifs="$IFS"; IFS='~'
 	for cmd in $cmds; do
