#!/bin/bash
# historyData IDR_BTC


PATH_BS=.
DATA_DIR=data
src=$PATH_BS/$DATA_DIR/bitcoin-history.json
tar=$PATH_BS/$DATA_DIR/bitcoin-history.sql
tmp=$PATH_BS/$DATA_DIR/bitcoin-history.tmp
tmp2=$PATH_BS/$DATA_DIR/bitcoin-history.tmp2
finaltar=$PATH_BS/$DATA_DIR/gdax_0.1.db


cd $PATH_BS
echo "clearing data dir"
#rm $PATH_BS/$DATA_DIR/bitcoin*tmp*
rm -rf $PATH_BS/$DATA_DIR/*

echo "getting data ..."
node scrape.js

echo "joining databits together ..."
node combine.js $src



cat << 'EOF' > data/bitcoin-history.sql
PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE candles_IDR_BTC (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start INTEGER UNIQUE,
        open REAL NOT NULL,
        high REAL NOT NULL,
        low REAL NOT NULL,
        close REAL NOT NULL,
        vwp REAL NOT NULL,
        volume REAL NOT NULL,
        trades INTEGER NOT NULL
      );
EOF

echo "Preparing ..."
sed $src -e 's/\[//g'       \
  -e "s/],/\n/g"      \
  -e "s/\[\[//g"      \
  -e "s/\]\]/\]/g"  |   \
sed   -e "/e+308/d"     \
  -e "s/,/ /g"    | \
sort -k1,1n -u        | \
uniq >> $tmp

echo "Fixing DB holes,- This could take a long time!"
awk -f fix_DB_holes.awk $tmp > $tmp2


echo "converting Data to sqldump format ..."
cat $tmp2       | \
nl        | \
sed   -e 's/\t/,/g'       \
  -e 's/ /,/g'      \
  -e 's/^,*//g'     \
  -e 's/(,//g'      \
  -e 's/ *//g'      \
  -e 's/]//g'       \
  -e 's/,,/,/g'       \
  -e "s/\(.*\)/INSERT INTO candles_IDR_BTC VALUES(\1);/g" >> $tar

NOL=$(tail -1 $tar|sed 's/INSERT INTO candles_IDR_BTC VALUES(\([0-9]*\).*/\1/')

echo "DELETE FROM sqlite_sequence;" >> $tar
echo "INSERT INTO sqlite_sequence VALUES('candles_IDR_BTC',$NOL);"  >> $tar
echo "COMMIT;" >> $tar

echo "Creating Gekko Sqlite3 DB ..."
sqlite3 $finaltar < $tar

echo "... done"
