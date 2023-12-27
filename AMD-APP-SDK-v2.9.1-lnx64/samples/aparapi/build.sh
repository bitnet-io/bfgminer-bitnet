
#Script for build the Aparapi Examples
if ! which ant >/dev/null; then
  if [ -z "$ANT_HOME" ]
  then
    echo "ERROR: Make sure 'ant' set to PATH variable or available inside 'ANT_HOME/bin/'";
    exit
  fi
  export PATH=$ANT_HOME/bin:$PATH
fi
if ! which javac >/dev/null; then
    echo "ERROR: 'javac' not found; make sure JDK installed and set to PATH variable"
    exit
fi
if [ -z "$LIBAPARAPI" ]
then
    echo "LIBAPARAPI PATH NOT SET : export LIBAPARAPI='path to aparapi.jar'";
    exit;
fi

CUR_DIR=$PWD
APARAPIDIR=$(readlink -f $0)
APARAPIDIR=`dirname "$APARAPIDIR"`

echo Building AparapiUtil...
cd "$APARAPIDIR"/AparapiUtil
ant build
if [ "$?" != "0" ]; then
    echo "Error: build failed..."
    cd $CUR_DIR
    exit;
fi
rm -rf classes

Samples="BlackScholes Convolution Life Mandel"
for sample in $Samples;
do
    echo Building $sample...
    cd "$APARAPIDIR"/examples/$sample
    ant build
    if [ "$?" != "0" ]; then
        echo "Error: build failed..."
        cd $CUR_DIR
        exit;
    fi
	rm -rf classes
done

cd $CUR_DIR
echo "           *** Aparapi build SUCCESS! ***"
