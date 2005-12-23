dnl $Id: aclocal.m4,v 1.1 2005-12-23 01:57:40 hww3 Exp $
AC_DEFUN([AP_CHECK_PIKE],
[
### Pike Detection ###
#
# check for a good pike with include files installed (standard)
# enables the --with-pike= option in configure.
# 
# usage: AP_CHECK_PIKE([minver],[maxver])
#  minver and maxver are optional arguments to specify minimum and maximum allowed pike versions
#  in the format MAJOR.MINOR.BUILD
#
# example: AP_CHECK_PIKE(7.4.1 7.5.0)
#  checks for a valid pike between version 7.4.1 and 7.5.0. 
######################
AC_ARG_WITH(pike, 
[  --with-pike[=binary]    Use the specified Pike. ],
[
    if test ! -z "$withval" -a "$withval" != "yes"; then 
		if test -f "$withval" -a  ! -x "$withval" ; then
			echo "$withval is not an executable file"
 			exit 1
		elif test -x "$withval" -a -f "$withval"; then
			DEFPIKE="$withval"
		else
			echo "$withval doesn't exist or isn't an executable file."
 			exit 1
		fi
	fi
])
RESULT=no

AC_MSG_CHECKING(for a working Pike)
AC_MSG_RESULT( )

#
# the standard awk supplied with unix systems may not work properly here.
# we should check for an xpg4 version, which should work correctly.
#
XPG4AWK=""
if test -x "/usr/xpg4/bin/awk"; then
  XPG4AWK="/usr/xpg4/bin/awk"
elif test $GAWK -ne ""; then
  XPG4AWK=$GAWK
else
  XPG4AWK="awk"
fi

pathpike="`type  pike |sed 's/pike is//' 2>/dev/null`"
if test "$prefix" != "NONE"; then
  PREFIXPIKE="$prefix/bin/pike"
fi
for a in $DEFPIKE $PREFIXPIKE $pathpike /usr/local/bin/pike /opt/pike/bin/pike \
  /sw/bin/pike /sw/local/bin/pike /opt/local/bin/pike /usr/gnu/bin/pike /usr/bin/pike ; do
  if test  "x$PIKE" != "x" ; then
    break;
  fi
  AC_MSG_CHECKING(${a})
  if test -x ${a}; then
    PIKE="${a}"
    if $PIKE -e 'float v; int rel;sscanf(version(), "Pike v%f release %d", v, rel);v += rel/10000.0; if(v < 0.6116) exit(1); exit(0);'; then
		PIKE_MODULE_DIR="`$PIKE --show-paths 2>&1| grep lib|grep modules|head -1 | sed -e 's/.*: //'`"
		PIKE_INCLUDE_DIRS="-I`echo "$PIKE_MODULE_DIR" | sed -e 's,lib/pike/modules,include/pike,' -e 's,lib/modules,include/pike,'`"

		if test -z "$PIKE_INCLUDE_DIRS" -o -z "$PIKE_MODULE_DIR"; then
			AC_MSG_RESULT(no dirs found)
			PIKE=""
		else
		   AC_MSG_RESULT(ok)
		fi
	else
		AC_MSG_RESULT(too old)
		PIKE=""
	fi
  else
    AC_MSG_RESULT(no)
  fi
done
if test "$PIKE" != ""; then 
  tmppike=`ls -l $PIKE | $XPG4AWK -F ' -> ' '{ print [$]2 }' 2>/dev/null`
  if test -x "$tmppike"; then
 	PIKE=$tmppike
  fi

#
#  Version checking (optional)
#
  if test "x$1" != "x"; then
    REQ_MIN_PIKE_VERSION="$1"

    AC_MSG_CHECKING(pike version)
 
    PIKE_VERSION=`$PIKE -e 'string v; int rel;sscanf(version(), "Pike v%s release %d", v, rel); write(v+"."+rel);'`

    THIS_PIKE_MAJOR=`echo $PIKE_VERSION | cut -d '.' -f 1`
    THIS_PIKE_MINOR=`echo $PIKE_VERSION | cut -d '.' -f 2`
    THIS_PIKE_BUILD=`echo $PIKE_VERSION | cut -d '.' -f 3`
    THIS_PIKE_VERNUM=$THIS_PIKE_MAJOR$THIS_PIKE_MINOR$THIS_PIKE_BUILD
    THIS_PIKE_DECNUM=`expr '(' $THIS_PIKE_MAJOR '*' 10000 ')' + '(' $THIS_PIKE_MINOR '*' 1000 ')' + $THIS_PIKE_BUILD`

    REQ_PIKE_MAJOR=`echo $REQ_MIN_PIKE_VERSION | cut -d '.' -f 1`
    REQ_PIKE_MINOR=`echo $REQ_MIN_PIKE_VERSION | cut -d '.' -f 2`
    REQ_PIKE_BUILD=`echo $REQ_MIN_PIKE_VERSION | cut -d '.' -f 3`
    REQ_PIKE_VERNUM=$REQ_PIKE_MAJOR$REQ_PIKE_MINOR$REQ_PIKE_BUILD
    REQ_PIKE_DECNUM=`expr '(' $REQ_PIKE_MAJOR '*' 10000 ')' + '(' $REQ_PIKE_MINOR '*' 1000 ')' + $REQ_PIKE_BUILD`

    if test $THIS_PIKE_DECNUM -lt $REQ_PIKE_DECNUM; then
       AC_MSG_RESULT($PIKE_VERSION is too old)
       echo "Pike version too old."
       exit 1;
    else
      if test "x$2" != "x"; then
        REQ_MAX_PIKE_VERSION="$2"
        REQ_PIKE_MAJOR=`echo $REQ_MAX_PIKE_VERSION | cut -d '.' -f 1`
        REQ_PIKE_MINOR=`echo $REQ_MAX_PIKE_VERSION | cut -d '.' -f 2`
        REQ_PIKE_BUILD=`echo $REQ_MAX_PIKE_VERSION | cut -d '.' -f 3`
        REQ_PIKE_VERNUM=$REQ_PIKE_MAJOR$REQ_PIKE_MINOR$REQ_PIKE_BUILD
        REQ_PIKE_DECNUM=`expr '(' $REQ_PIKE_MAJOR '*' 10000 ')' + '(' $REQ_PIKE_MINOR '*' 1000 ')' + $REQ_PIKE_BUILD`

        if test $THIS_PIKE_DECNUM -gt $REQ_PIKE_DECNUM; then
          AC_MSG_RESULT($PIKE_VERSION is too new)
          echo "Pike version too new."
          exit 1;
        fi
      fi
      AC_MSG_RESULT($PIKE_VERSION is ok)
    fi
  fi
  
  PIKE_1=`dirname ${PIKE}`
  PIKE_INCLUDE_DIRS=""

  echo "PIKE_1 is ${PIKE_1}"

  PIKE_C_INCLUDE_DIRS="${PIKE_C_INCLUDE_DIRS} `dirname ${PIKE_1}`/${PIKE_VERSION}/include/pike `dirname ${PIKE_1}`/include/pike /usr/include/`basename ${PIKE}`"

  echo "PIKE_C_INCLUDE_DIRS is ${PIKE_C_INCLUDE_DIRS}"
  for PIKE_C_INCLUDE in ${PIKE_C_INCLUDE_DIRS}
  do
    AC_MSG_CHECKING(for C includes in ${PIKE_C_INCLUDE})
    if test -d $PIKE_C_INCLUDE; then
      PIKE_INCLUDE_DIRS="-I$PIKE_C_INCLUDE $PIKE_INCLUDE_DIRS"
      AC_MSG_RESULT(found)
      break;		
    else
      AC_MSG_RESULT(not found)
    fi
  done
  if test "z$PIKE_INCLUDE_DIRS" = "z"; then
    echo "Failed to find pike C include files!"
    exit 1;
  fi
else
  echo "Failed to find a suitable pike!"
  exit 1;
fi

export PIKE PIKE_INCLUDE_DIRS PIKE_VERSION PIKE_MODULE_DIR
AC_SUBST(PIKE)
AC_SUBST(PIKE_VERSION)
AC_SUBST(PIKE_INCLUDE_DIRS)
AC_SUBST(PIKE_MODULE_DIR)
#############################################################################
])
