update_nodejs () {
  mkdir -p $NODE_HOME && cd $NODE_HOME && cd ..

  NODEJSVERSION=$1
  if [ -z $NODEJSVERSION ]; then
    NODEJSVERSION=$(curl -s https://api.github.com/repos/nodejs/node/tags |jq '.[0].name')
    NODEJSVERSION=${NODEJSVERSION//\"/}
  fi
  
  NODEJSARCH=x64

  wget https://nodejs.org/dist/$NODEJSVERSION/node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz

  echo "update nodejs to $NODEJSVERSION"

# todo 
  OLDVERSION=$(node -v)
  echo "old version: $OLDVERSION"
  # bakeup old version
  rm -rf $PWD/$OLDVERSION
  mv $PWD/node $PWD/$OLDVERSION

  xz -d node-$NODEJSVERSION-linux-$NODEJSARCH.tar.xz
  tar -xvf node-$NODEJSVERSION-linux-$NODEJSARCH.tar && rm node-$NODEJSVERSION-linux-$NODEJSARCH.tar

  mv node-$NODEJSVERSION-linux-$NODEJSARCH node
}

update_npm () {
  # todo not found
  npm install npm@latest -g
}