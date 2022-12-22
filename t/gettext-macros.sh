#! /bin/sh
# Copyright (C) 2011-2021 Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Try to find the gettext '.m4' files and make them easily accessed
# to the test cases requiring them.
# See also automake bug#9807.

. test-init.sh

extract_program_version ()
{
  "$1" --version | sed 1q | $PERL -ne '/(\d(?:\.\d+)+)/ and print "$1\n"'
}

echo "# Automatically generated by $me." > get.sh
echo : >> get.sh

# The 'autopoint' script will look into Makefile.am.
echo ACLOCAL_AMFLAGS = -I m4 > Makefile.am

# Prefer autopoint to gettextize, since the latter unconditionally
# requires user interaction to complete; yes, this means confirmation
# from /dev/tty (!) -- see:
#  <https://lists.gnu.org/archive/html/bug-gettext/2011-12/msg00000.html>

# We will need to specify the correct autopoint version in the
# AM_GNU_GETTEXT_VERSION call in configure.ac if we want autopoint to
# setup the correct infrastructure -- in particular, for what concerns
# us, to bring in all the required .m4 files.
autopoint_version=$(extract_program_version autopoint) \
  && test -n "$autopoint_version" \
  || autopoint_version=0.10.35

cat > configure.ac <<END
AC_INIT([foo], [1.0])
AC_PROG_CC
# Both required by autopoint.
AM_GNU_GETTEXT
AM_GNU_GETTEXT_VERSION([$autopoint_version])
END

if autopoint --force && test -f m4/gettext.m4; then
  echo "ACLOCAL_PATH='$(pwd)/m4':\$ACLOCAL_PATH" >> get.sh
  echo "export ACLOCAL_PATH" >> get.sh
else
  # Older versions of gettext might not have an autopoint program
  # available, but this doesn't mean the user hasn't made the gettext
  # macros available, e.g., by properly setting ACLOCAL_PATH.
  rm -rf m4
  mkdir m4
  # See below for an explanation about the use the of '-Wno-syntax'.
  if $ACLOCAL -Wno-syntax -I m4 --install && test -f m4/gettext.m4; then
    : # Gettext macros already accessible by default.
  else
    echo "skip_all_ \"couldn't find or get gettext macros\"" >> get.sh
  fi
fi

cat >> get.sh <<'END'
# Even recent versions of gettext used the now-obsolete 'AM_PROG_MKDIR_P'
# m4 macro.  So we need the following to avoid spurious errors.
ACLOCAL="$ACLOCAL -Wno-obsolete"
AUTOMAKE="$AUTOMAKE -Wno-obsolete"
END

. ./get.sh

$ACLOCAL --force -I m4 || cat >> get.sh <<'END'
# We need to use '-Wno-syntax', since we do not want our test suite
# to fail merely because some third-party '.m4' file is underquoted.
ACLOCAL="$ACLOCAL -Wno-syntax"
END

# Remove any Makefile.in possibly created by autopoint, to avoid spurious
# maintainer-check failures.
rm -f $(find . -name Makefile.in)

# The file autopoint might have copied in the 'm4' subdirectory of the
# test directory are going to be needed by other tests, so we must not
# remove the test directory.
keep_testdirs=yes

:
