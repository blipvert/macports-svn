--- gnect/src/adjmtrx.c.org	Sat Jul 26 15:07:58 2003
+++ gnect/src/adjmtrx.c	Sat Jul 26 15:08:14 2003
@@ -24,7 +24,7 @@
 #include <stdio.h>
 #include <string.h>
 #include <stdlib.h>
-#include <malloc.h>
+#include <sys/malloc.h>
 
 #include "connect4.h"
 #include "con4vals.h"
