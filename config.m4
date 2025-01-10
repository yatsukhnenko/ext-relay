dnl macOS requires hiredis v1.2.0
AC_CANONICAL_HOST
case "$host_os" in
  darwin*)
    HIREDIS_REQ_VERSION="1.2.0"
    ;;
  *)
    HIREDIS_REQ_VERSION="1.1.0"
    ;;
esac

dnl hiredis
PKG_CHECK_MODULES([HIREDIS], [hiredis >= $HIREDIS_REQ_VERSION])

dnl hiredis_ssl
PKG_CHECK_MODULES([HIREDIS_SSL], [hiredis_ssl >= $HIREDIS_REQ_VERSION])

dnl openssl
PKG_CHECK_MODULES([OPENSSL], [openssl >= 1.1.0])

dnl libck
PKG_CHECK_MODULES([CK], [ck >= 0.7.0])

dnl download url
AC_DEFUN([RELAY_SET_DOWNLOAD_URL], [
  AC_REQUIRE([AC_CANONICAL_HOST])dnl
  AC_REQUIRE([AC_PROG_EGREP])dnl
  AC_REQUIRE([AC_PROG_SED])dnl
  AC_REQUIRE([PKG_PROG_PKG_CONFIG])dnl

  PLATFORM=$(echo $host_cpu | $SED 's/aarch64/arm64/;s/x86_64/x86-64/')

  case "$host_os" in
    linux*)
      AC_CHECK_FILE([/etc/os-release], [
        AC_MSG_NOTICE([Extracting OS and version from /etc/os-release])
        ID=$($EGREP '^ID=' /etc/os-release | $SED 's/ID=//;s/"//g' | cut -d . -f -1)
        VERSION=$($EGREP '^VERSION_ID=' /etc/os-release | $SED 's/VERSION_ID=//;s/"//g')
        MAJOR=$(echo $VERSION | cut -d . -f -1)
        MINOR=$(echo $VERSION | cut -d . -f 2-2)
        case $ID in
          alpine)
            if test $MAJOR -ne 3 || test $MINOR -lt 9; then
              AC_MSG_ERROR([unsupported version $VERSION, please report on GitHub])
            elif test $MINOR -lt 17; then
              OS=alpine3.9
            else
              OS=alpine3.17
            fi
            ;;
          almalinux|centos|rocky)
            OS=el$MAJOR
            ;;
          fedora|sles|opensuse*)
            OS=el9
            ;;
          debian|ubuntu)
            OS=debian
            LIBSSL_VERSION=$($PKG_CONFIG --print-provides libssl | $SED 's/libssl = //' | cut -d . -f -1)
            if test $LIBSSL_VERSION -eq 3; then
              PLATFORM="$PLATFORM+libssl3"
            fi
            ;;
          *)
            AC_MSG_ERROR([unsupported OS $ID, please report on GitHub])
            ;;
        esac
      ], [
        AC_MSG_ERROR([failed to determine OS, please report on GitHub])
      ])
      ;;
    darwin*)
      OS="darwin"
      ;;
    *)
      AC_MSG_ERROR([unsupported OS])
      ;;
  esac

  VERSION=$($PHP_CONFIG --version | cut -d . -f -2)
  RELAY_DOWNLOAD_URL="https://builds.r2.relay.so/v$1/relay-v$1-php$VERSION-$OS-$PLATFORM.tar.gz"
  PHP_SUBST([RELAY_DOWNLOAD_URL])
])dnl

dnl tools
AC_DEFUN([RELAY_CHECK_PROGS], [
  m4_foreach([prog], $@, [
    AC_PATH_PROG([prog], [prog])
    if test ! -x "$prog"; then
      AC_MSG_ERROR([prog required])
    fi
    unset ac_cv_path_prog
  ])dnl
])dnl

dnl priority
AC_CHECK_FILE([composer.json], [
  RELAY_PRIORITY=$($EGREP priority composer.json | $SED 's/"priority"://' | cut -d , -f -1)
])
PHP_SUBST([RELAY_PRIORITY])
PHP_SUBST([PHP_CONFIG])

PHP_NEW_EXTENSION([relay])
RELAY_SET_DOWNLOAD_URL([0.9.1])
RELAY_CHECK_PROGS([curl, shasum, tar, uuidgen])
PHP_MODULES="$PHP_MODULES \$(PHP_PECL_EXTENSION)"
PHP_ADD_MAKEFILE_FRAGMENT([Makefile.frag])
