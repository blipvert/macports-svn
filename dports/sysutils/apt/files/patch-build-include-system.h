--- build/include/system.h.orig	2011-08-08 13:14:47.000000000 +0200
+++ build/include/system.h	2011-08-08 13:24:37.000000000 +0200
@@ -26,7 +26,7 @@
 #endif
 
 // GNU C++ has a min/max operator <coolio>
-#if defined(__GNUG__)
+#if defined(__GNUG__) && !defined(__llvm__)
 #define MIN(A,B) ((A) <? (B))
 #define MAX(A,B) ((A) >? (B))
 #endif
